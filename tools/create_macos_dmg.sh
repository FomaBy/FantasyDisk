#!/bin/bash
# Build a drag-to-Applications DMG from an already finalised .app bundle.
# The caller must sign and verify the app before invoking this helper.
set -euo pipefail

APP_PATH="${1:?Usage: tools/create_macos_dmg.sh <app> <output.dmg> <version>}"
OUTPUT_DMG="${2:?Usage: tools/create_macos_dmg.sh <app> <output.dmg> <version>}"
VERSION="${3:?Usage: tools/create_macos_dmg.sh <app> <output.dmg> <version>}"

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BACKGROUND_SVG="${REPO_DIR}/tools/dmg_background.svg"
APP_NAME="$(basename "${APP_PATH}")"
VOLUME_NAME="FantasyDisk ${VERSION}"
SCRATCH_DIR="$(mktemp -d /tmp/fantasydisk-dmg-XXXXXX)"
STAGING_DIR="${SCRATCH_DIR}/staging"
RW_DMG="${SCRATCH_DIR}/FantasyDisk-${VERSION}-rw.dmg"
DMG_DEVICE=""
MOUNTED=0

cleanup() {
  if [[ "${MOUNTED}" -eq 1 ]]; then
    hdiutil detach "${DMG_DEVICE}" -force >/dev/null 2>&1 || true
  fi
  rm -rf "${SCRATCH_DIR}"
}
trap cleanup EXIT

mkdir -p "${STAGING_DIR}/.background"
ditto --rsrc --extattr "${APP_PATH}" "${STAGING_DIR}/${APP_NAME}"
ln -s /Applications "${STAGING_DIR}/Applications"

# Finder requires a bitmap background. Keep the source as portable SVG and
# rasterise it at the exact 720x480 Finder window size with the macOS toolchain.
sips -s format png "${BACKGROUND_SVG}" \
  --out "${STAGING_DIR}/.background/dmg_background.png" >/dev/null 2>&1

hdiutil create -quiet -volname "${VOLUME_NAME}" -srcfolder "${STAGING_DIR}" \
  -ov -format UDRW "${RW_DMG}"
ATTACH_OUTPUT="$(hdiutil attach -readwrite -noverify -noautoopen "${RW_DMG}")"
DMG_DEVICE="$(printf '%s\n' "${ATTACH_OUTPUT}" | awk '$2 == "Apple_HFS" || $2 == "Apple_APFS" {print $1; exit}')"
if [[ -z "${DMG_DEVICE}" ]]; then
  echo "ERROR: не удалось определить устройство смонтированного DMG"
  exit 2
fi
MOUNTED=1

osascript <<OSA
tell application "Finder"
  tell disk "${VOLUME_NAME}"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set pathbar visible of container window to false
    set bounds of container window to {120, 120, 840, 600}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 112
    set text size of viewOptions to 16
    set background picture of viewOptions to file ".background:dmg_background.png"
    set position of item "${APP_NAME}" to {190, 255}
    set position of item "Applications" to {530, 255}
    update without registering applications
    delay 2
    close
  end tell
end tell
OSA

sync
hdiutil detach -quiet "${DMG_DEVICE}"
MOUNTED=0
rm -f "${OUTPUT_DMG}"
hdiutil convert -quiet "${RW_DMG}" -format UDZO -imagekey zlib-level=9 \
  -o "${OUTPUT_DMG}"
hdiutil verify "${OUTPUT_DMG}" >/dev/null

echo "DMG layout OK: ${APP_NAME} -> Applications (arrow background, ${VOLUME_NAME})"
