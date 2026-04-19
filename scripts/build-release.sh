#!/usr/bin/env bash
# build-release.sh — Pault distribution build script
#
# Usage:
#   scripts/build-release.sh --appstore   Build and export for App Store (no upload)
#   scripts/build-release.sh --dmg        Build, notarize, staple, and package DMG
#
# One-time notarytool credential setup (run once per machine):
#   xcrun notarytool store-credentials "pault-notarytool" \
#     --apple-id "YOUR_APPLE_ID" \
#     --team-id 93QQU293YD
#   (You will be prompted for an app-specific password from appleid.apple.com)
#
# Environment variables:
#   KEEP_BUILD=1   Skip removal of the build/ directory on exit (useful for debugging)

set -euo pipefail

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

SCHEME="Pault"
PROJECT="Pault.xcodeproj"
ARCHIVE_PATH="build/Pault.xcarchive"
EXPORT_PATH="build/export"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Read marketing version from build settings; fall back to 1.0
VERSION="$(xcodebuild -project "${REPO_ROOT}/${PROJECT}" -scheme "${SCHEME}" \
  -showBuildSettings 2>/dev/null | awk '/MARKETING_VERSION/ {print $3; exit}')"
VERSION="${VERSION:-1.0}"

# ---------------------------------------------------------------------------
# Cleanup trap
# ---------------------------------------------------------------------------

cleanup() {
  if [[ "${KEEP_BUILD:-0}" != "1" ]]; then
    echo "Cleaning up build/ directory..."
    rm -rf "${REPO_ROOT}/build"
  fi
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

run_tests() {
  echo "==> Running test suite (safety gate)..."
  if ! xcodebuild test \
    -project "${REPO_ROOT}/${PROJECT}" \
    -scheme "${SCHEME}" \
    -destination 'platform=macOS' \
    -quiet; then
    echo "ERROR: Tests failed. Aborting release build."
    exit 1
  fi
  echo "==> Tests passed."
}

archive() {
  echo "==> Archiving ${SCHEME} (Release)..."
  xcodebuild archive \
    -project "${REPO_ROOT}/${PROJECT}" \
    -scheme "${SCHEME}" \
    -configuration Release \
    -archivePath "${REPO_ROOT}/${ARCHIVE_PATH}"
  echo "==> Archive created at ${ARCHIVE_PATH}"
}

# ---------------------------------------------------------------------------
# build_appstore: export for App Store Connect (no upload)
# ---------------------------------------------------------------------------

build_appstore() {
  run_tests
  archive

  echo "==> Exporting App Store archive..."
  xcodebuild -exportArchive \
    -archivePath "${REPO_ROOT}/${ARCHIVE_PATH}" \
    -exportOptionsPlist "${SCRIPT_DIR}/ExportOptions-AppStore.plist" \
    -exportPath "${REPO_ROOT}/${EXPORT_PATH}"

  echo "==> Verifying code signature..."
  codesign --verify --deep --strict "${REPO_ROOT}/${EXPORT_PATH}/Pault.app"

  echo ""
  echo "SUCCESS: Archive ready at ${ARCHIVE_PATH}"
  echo "Open in Xcode Organizer (Window > Organizer) to validate and upload to App Store Connect."
}

# ---------------------------------------------------------------------------
# build_dmg: notarized, stapled DMG for direct distribution
# ---------------------------------------------------------------------------

build_dmg() {
  run_tests
  archive

  echo "==> Exporting Developer ID archive..."
  xcodebuild -exportArchive \
    -archivePath "${REPO_ROOT}/${ARCHIVE_PATH}" \
    -exportOptionsPlist "${SCRIPT_DIR}/ExportOptions-DeveloperID.plist" \
    -exportPath "${REPO_ROOT}/${EXPORT_PATH}"

  local zip_path="${REPO_ROOT}/${EXPORT_PATH}/Pault-notarize.zip"
  local app_path="${REPO_ROOT}/${EXPORT_PATH}/Pault.app"

  echo "==> Creating zip for notarization..."
  ditto -c -k --keepParent "${app_path}" "${zip_path}"

  echo "==> Submitting to Apple notary service (this may take a few minutes)..."
  xcrun notarytool submit "${zip_path}" \
    --keychain-profile "pault-notarytool" \
    --wait

  echo "==> Stapling notarization ticket to app bundle..."
  xcrun stapler staple "${app_path}"

  echo "==> Verifying Gatekeeper acceptance..."
  spctl -a -v "${app_path}"

  echo "==> Packaging DMG..."
  local dmg_path="${REPO_ROOT}/dist/Pault-${VERSION}.dmg"
  mkdir -p "${REPO_ROOT}/dist"
  "${SCRIPT_DIR}/create_dmg.sh" "${app_path}" "${dmg_path}" "Pault"

  echo "==> Stapling notarization ticket to DMG..."
  xcrun stapler staple "${dmg_path}"

  echo ""
  echo "SUCCESS: Notarized DMG ready at dist/Pault-${VERSION}.dmg"
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

usage() {
  echo "Usage: build-release.sh --appstore | --dmg"
  echo ""
  echo "  --appstore   Build and export for App Store Connect (export only, no upload)"
  echo "  --dmg        Build, notarize, staple, and package a Developer ID DMG"
}

case "${1:-}" in
  --appstore)
    build_appstore
    ;;
  --dmg)
    build_dmg
    ;;
  *)
    usage
    exit 1
    ;;
esac
