#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

PROJECT_PATH="${PROJECT_PATH:-AynaMobile.xcodeproj}"
SCHEME="${SCHEME:-Ayna-iOS}"
CONFIGURATION="${CONFIGURATION:-Release}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$PWD/build-artifacts}"
DERIVED_DATA="$OUTPUT_ROOT/DerivedData"
PACKAGE_ROOT="$OUTPUT_ROOT/package"
IPA_OUTPUT_DIR="$OUTPUT_ROOT/ipa"
DIAGNOSTICS_DIR="$OUTPUT_ROOT/diagnostics"
RESULT_BUNDLE="$DIAGNOSTICS_DIR/Ayna-iOS.xcresult"
BUILD_LOG="$DIAGNOSTICS_DIR/xcodebuild.log"
ENVIRONMENT_LOG="$DIAGNOSTICS_DIR/environment.txt"
PREFLIGHT_LOG="$DIAGNOSTICS_DIR/preflight.txt"
ERROR_SUMMARY="$DIAGNOSTICS_DIR/errors-and-warnings.txt"
STATUS_FILE="$DIAGNOSTICS_DIR/build-status.txt"

mkdir -p "$OUTPUT_ROOT"
rm -rf "$DERIVED_DATA" "$PACKAGE_ROOT" "$IPA_OUTPUT_DIR" "$DIAGNOSTICS_DIR"
mkdir -p "$DERIVED_DATA" "$PACKAGE_ROOT" "$IPA_OUTPUT_DIR" "$DIAGNOSTICS_DIR"

log() {
  printf '[%s] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"
}

collect_diagnostics() {
  local exit_code=$?
  set +e

  {
    echo "exit_code=$exit_code"
    echo "project=$PROJECT_PATH"
    echo "scheme=$SCHEME"
    echo "configuration=$CONFIGURATION"
    echo "finished_utc=$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  } > "$STATUS_FILE"

  if [[ -f "$BUILD_LOG" ]]; then
    grep -E -i -n -C 2 '(^|[[:space:]])(error|fatal error|warning):|BUILD FAILED|The following build commands failed' \
      "$BUILD_LOG" > "$ERROR_SUMMARY" || true
  fi

  if [[ -d "$RESULT_BUNDLE" ]]; then
    xcrun xcresulttool get object --legacy --path "$RESULT_BUNDLE" --format json \
      > "$DIAGNOSTICS_DIR/xcresult.json" 2> "$DIAGNOSTICS_DIR/xcresult-export-error.txt" || true
  fi

  {
    echo "=== Output tree ==="
    find "$OUTPUT_ROOT" -maxdepth 5 -print 2>/dev/null | sort
    echo
    echo "=== Disk usage ==="
    du -sh "$OUTPUT_ROOT"/* 2>/dev/null || true
  } > "$DIAGNOSTICS_DIR/output-tree.txt"

  if [[ $exit_code -ne 0 ]]; then
    log "Build failed with exit code $exit_code. Diagnostics were preserved in $DIAGNOSTICS_DIR."
  fi
}
trap collect_diagnostics EXIT

{
  echo "=== Date ==="
  date -u
  echo
  echo "=== Host ==="
  uname -a
  sw_vers
  echo
  echo "=== Architecture ==="
  uname -m
  echo
  echo "=== Xcode selection ==="
  xcode-select -p
  xcodebuild -version
  echo
  echo "=== Swift ==="
  swift --version
  echo
  echo "=== SDKs ==="
  xcodebuild -showsdks
  echo
  echo "=== Disk ==="
  df -h
  echo
  echo "=== Git revision ==="
  git rev-parse HEAD 2>/dev/null || true
  git status --short 2>/dev/null || true
} > "$ENVIRONMENT_LOG" 2>&1

log "Running fast preflight checks before compilation."

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "Missing Xcode project: $PROJECT_PATH" >&2
  exit 10
fi

if ! xcodebuild -version | head -n 1 | grep -Eq '^Xcode 26([.]|$)'; then
  echo "Ayna requires Xcode 26, but the selected toolchain is:" >&2
  xcodebuild -version >&2
  exit 11
fi

if ! xcodebuild -showsdks | grep -q 'iphoneos26'; then
  echo "The selected Xcode installation does not include an iOS 26 SDK." >&2
  exit 12
fi

{
  echo "=== Project targets and schemes ==="
  xcodebuild -project "$PROJECT_PATH" -list
  echo
  echo "=== Effective build settings ==="
  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -sdk iphoneos \
    -destination 'generic/platform=iOS' \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY='' \
    DEVELOPMENT_TEAM='' \
    -showBuildSettings
} > "$PREFLIGHT_LOG" 2>&1

if ! grep -q "TARGET_NAME = Ayna-iOS" "$PREFLIGHT_LOG"; then
  echo "The expected Ayna-iOS target was not found in the selected scheme." >&2
  cat "$PREFLIGHT_LOG" >&2
  exit 13
fi

log "Preflight passed. Building the device app without code signing."
set +e
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$DERIVED_DATA" \
  -resultBundlePath "$RESULT_BUNDLE" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY='' \
  DEVELOPMENT_TEAM='' \
  COMPILER_INDEX_STORE_ENABLE=NO \
  build 2>&1 | tee "$BUILD_LOG"
build_exit_code=${PIPESTATUS[0]}
set -e

if [[ $build_exit_code -ne 0 ]]; then
  exit "$build_exit_code"
fi

APP_PATH="$DERIVED_DATA/Build/Products/${CONFIGURATION}-iphoneos/Ayna.app"
if [[ ! -d "$APP_PATH" ]]; then
  APP_PATH="$(find "$DERIVED_DATA/Build/Products" -type d -name 'Ayna.app' -path '*-iphoneos/*' -print -quit 2>/dev/null || true)"
fi

if [[ -z "${APP_PATH:-}" || ! -d "$APP_PATH" ]]; then
  echo "The build reported success, but Ayna.app was not found." >&2
  exit 20
fi

EXECUTABLE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP_PATH/Info.plist" 2>/dev/null || true)"
if [[ -z "$EXECUTABLE_NAME" || ! -f "$APP_PATH/$EXECUTABLE_NAME" ]]; then
  echo "The app bundle is missing its executable." >&2
  exit 21
fi

rm -rf "$APP_PATH/_CodeSignature"
find "$APP_PATH" -name 'embedded.mobileprovision' -delete

mkdir -p "$PACKAGE_ROOT/Payload"
ditto "$APP_PATH" "$PACKAGE_ROOT/Payload/Ayna.app"

IPA_PATH="$IPA_OUTPUT_DIR/Ayna-unsigned.ipa"
(
  cd "$PACKAGE_ROOT"
  /usr/bin/ditto -c -k --sequesterRsrc --keepParent Payload "$IPA_PATH"
)

if ! unzip -t "$IPA_PATH" > "$DIAGNOSTICS_DIR/ipa-integrity.txt" 2>&1; then
  echo "The generated IPA archive failed its integrity check." >&2
  exit 22
fi

unzip -l "$IPA_PATH" > "$DIAGNOSTICS_DIR/ipa-contents.txt"
/usr/bin/codesign -dvvv "$PACKAGE_ROOT/Payload/Ayna.app" \
  > "$DIAGNOSTICS_DIR/codesign-check.txt" 2>&1 || true
shasum -a 256 "$IPA_PATH" | tee "$IPA_OUTPUT_DIR/SHA256SUMS.txt"

{
  echo "app_path=$APP_PATH"
  echo "ipa_path=$IPA_PATH"
  echo "ipa_size_bytes=$(stat -f%z "$IPA_PATH")"
  echo "bundle_identifier=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Info.plist")"
  echo "bundle_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Info.plist")"
  echo "short_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Info.plist")"
} > "$DIAGNOSTICS_DIR/artifact-metadata.txt"

log "Unsigned IPA created successfully: $IPA_PATH"