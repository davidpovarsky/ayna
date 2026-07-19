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
BUILD_LOG="$