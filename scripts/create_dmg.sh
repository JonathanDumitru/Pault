#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/create_dmg.sh <path-to-app> <output-dmg> [volume-name]

Example:
  scripts/create_dmg.sh build/Release/Pault.app dist/Pault.dmg "Pault"
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 2 ]]; then
  usage
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_PATH="$1"
OUTPUT_DMG="$2"
VOLUME_NAME="${3:-Pault}"
BACKGROUND_SRC="${REPO_ROOT}/scripts/dmg/dmg-background.png"

if [[ ! -d "${APP_PATH}" || "${APP_PATH##*.}" != "app" ]]; then
  echo "App bundle not found: ${APP_PATH}"
  exit 1
fi

if [[ ! -f "${BACKGROUND_SRC}" ]]; then
  echo "Missing DMG background image: ${BACKGROUND_SRC}"
  exit 1
fi

for cmd in hdiutil osascript; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "Missing required command: ${cmd}"
    exit 1
  fi
done

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pault-dmg.XXXXXX")"
RW_DMG="${TMP_DIR}/Pault-temp.dmg"
STAGE_DIR="${TMP_DIR}/stage"
APP_NAME="$(basename "${APP_PATH}")"
DEVICE=""

cleanup() {
  if [[ -n "${DEVICE}" ]]; then
    hdiutil detach "${DEVICE}" -force >/dev/null 2>&1 || true
  fi
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

mkdir -p "${STAGE_DIR}/.background"
cp -R "${APP_PATH}" "${STAGE_DIR}/${APP_NAME}"
ln -s /Applications "${STAGE_DIR}/Applications"
cp "${BACKGROUND_SRC}" "${STAGE_DIR}/.background/dmg-background.png"

hdiutil create \
  -volname "${VOLUME_NAME}" \
  -srcfolder "${STAGE_DIR}" \
  -fs HFS+ \
  -format UDRW \
  -ov \
  "${RW_DMG}" >/dev/null

ATTACH_OUTPUT="$(hdiutil attach "${RW_DMG}" -readwrite -noverify -noautoopen)"
DEVICE="$(echo "${ATTACH_OUTPUT}" | awk '/Apple_HFS/ {print $1; exit}')"

if [[ -z "${DEVICE}" ]]; then
  echo "Unable to mount temporary DMG."
  exit 1
fi

osascript <<EOF >/dev/null
tell application "Finder"
  tell disk "${VOLUME_NAME}"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {120, 120, 720, 500}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 128
    set text size of opts to 14
    set background picture of opts to file ".background:dmg-background.png"
    set position of item "${APP_NAME}" of container window to {170, 200}
    set position of item "Applications" of container window to {430, 200}
    close
    open
    update without registering applications
    delay 2
  end tell
end tell
EOF

sync
hdiutil detach "${DEVICE}" >/dev/null
DEVICE=""

mkdir -p "$(dirname "${OUTPUT_DMG}")"
hdiutil convert "${RW_DMG}" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -ov \
  -o "${OUTPUT_DMG}" >/dev/null

echo "DMG created: ${OUTPUT_DMG}"
