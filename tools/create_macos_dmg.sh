#!/bin/bash
# Build a minimal drag-to-Applications DMG from an already finalised .app bundle.
# The caller must add the arrow-only Finder background, then sign and verify the
# app before invoking this helper. The background lives inside the app bundle so
# the DMG root exposes only the app and the Applications alias.
set -euo pipefail

APP_PATH="${1:?Usage: tools/create_macos_dmg.sh <app> <output.dmg> <version>}"
OUTPUT_DMG="${2:?Usage: tools/create_macos_dmg.sh <app> <output.dmg> <version>}"
VERSION="${3:?Usage: tools/create_macos_dmg.sh <app> <output.dmg> <version>}"

APP_NAME="$(basename "${APP_PATH}")"
VOLUME_NAME="FantasyDisk ${VERSION}"
BACKGROUND_RESOURCE_NAME="FantasyDiskDmgBackground.png"
BACKGROUND_RESOURCE="${APP_PATH}/Contents/Resources/${BACKGROUND_RESOURCE_NAME}"
SCRATCH_DIR="$(mktemp -d /tmp/fantasydisk-dmg-XXXXXX)"
STAGING_DIR="${SCRATCH_DIR}/staging"
RW_DMG="${SCRATCH_DIR}/FantasyDisk-${VERSION}-rw.dmg"
RW_MOUNT_DIR=""
VERIFY_MOUNT_DIR="${SCRATCH_DIR}/verify-mount"
DMG_DEVICE=""
MOUNTED=0

cleanup() {
  if [[ "${MOUNTED}" -eq 1 ]]; then
    hdiutil detach "${DMG_DEVICE}" -force >/dev/null 2>&1 || true
  fi
  rm -rf "${SCRATCH_DIR}"
}
trap cleanup EXIT

if [[ ! -d "${APP_PATH}" ]]; then
  echo "ERROR: app bundle not found: ${APP_PATH}"
  exit 2
fi
if [[ ! -f "${BACKGROUND_RESOURCE}" ]]; then
  echo "ERROR: arrow-only Finder background missing from signed app: ${BACKGROUND_RESOURCE}"
  exit 2
fi

mkdir -p "${STAGING_DIR}" "${VERIFY_MOUNT_DIR}"
ditto --rsrc --extattr "${APP_PATH}" "${STAGING_DIR}/${APP_NAME}"
ln -s /Applications "${STAGING_DIR}/Applications"

hdiutil create -quiet -volname "${VOLUME_NAME}" -srcfolder "${STAGING_DIR}" \
  -ov -format UDRW "${RW_DMG}"
RW_ATTACH_PLIST="${SCRATCH_DIR}/rw-attach.plist"
hdiutil attach -readwrite -noverify -noautoopen -plist "${RW_DMG}" >"${RW_ATTACH_PLIST}"
for entity_index in $(seq 0 12); do
  candidate_mount="$(/usr/libexec/PlistBuddy \
    -c "Print :system-entities:${entity_index}:mount-point" \
    "${RW_ATTACH_PLIST}" 2>/dev/null || true)"
  if [[ -n "${candidate_mount}" ]]; then
    RW_MOUNT_DIR="${candidate_mount}"
    DMG_DEVICE="$(/usr/libexec/PlistBuddy \
      -c "Print :system-entities:${entity_index}:dev-entry" \
      "${RW_ATTACH_PLIST}" 2>/dev/null || true)"
    break
  fi
done
if [[ -z "${DMG_DEVICE}" || -z "${RW_MOUNT_DIR}" || ! -d "${RW_MOUNT_DIR}" ]]; then
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
    set icon size of viewOptions to 128
    set text size of viewOptions to 14
    set background picture of viewOptions to file "${APP_NAME}:Contents:Resources:${BACKGROUND_RESOURCE_NAME}"
    set position of item "${APP_NAME}" to {190, 235}
    set position of item "Applications" to {530, 235}
    update without registering applications
    delay 2
    close
  end tell
end tell
OSA

# Finder/FSEvents may create implementation folders while the writable image is
# open. Remove them immediately and fail closed if any non-layout root item
# remains. Users who show hidden files must still see only the two drag targets.
rm -rf \
  "${RW_MOUNT_DIR}/.background" \
  "${RW_MOUNT_DIR}/.fseventsd" \
  "${RW_MOUNT_DIR}/.Spotlight-V100" \
  "${RW_MOUNT_DIR}/.Trashes" \
  "${RW_MOUNT_DIR}/.TemporaryItems" \
  "${RW_MOUNT_DIR}/.metadata_never_index"
UNEXPECTED_ROOT_ITEMS="$(find "${RW_MOUNT_DIR}" -mindepth 1 -maxdepth 1 \
  ! -name "${APP_NAME}" ! -name "Applications" ! -name ".DS_Store" -print)"
if [[ -n "${UNEXPECTED_ROOT_ITEMS}" ]]; then
  echo "ERROR: unexpected DMG root items before sealing:"
  printf '%s\n' "${UNEXPECTED_ROOT_ITEMS}"
  exit 2
fi

sync
hdiutil detach -quiet "${DMG_DEVICE}"
MOUNTED=0
rm -f "${OUTPUT_DMG}"
hdiutil convert -quiet "${RW_DMG}" -format UDZO -imagekey zlib-level=9 \
  -o "${OUTPUT_DMG}"
hdiutil verify "${OUTPUT_DMG}" >/dev/null

VERIFY_ATTACH_PLIST="${SCRATCH_DIR}/verify-attach.plist"
hdiutil attach -readonly -noverify -noautoopen -nobrowse -plist \
  -mountpoint "${VERIFY_MOUNT_DIR}" "${OUTPUT_DMG}" >"${VERIFY_ATTACH_PLIST}"
DMG_DEVICE=""
for entity_index in $(seq 0 12); do
  candidate_mount="$(/usr/libexec/PlistBuddy \
    -c "Print :system-entities:${entity_index}:mount-point" \
    "${VERIFY_ATTACH_PLIST}" 2>/dev/null || true)"
  if [[ -n "${candidate_mount}" ]]; then
    DMG_DEVICE="$(/usr/libexec/PlistBuddy \
      -c "Print :system-entities:${entity_index}:dev-entry" \
      "${VERIFY_ATTACH_PLIST}" 2>/dev/null || true)"
    break
  fi
done
if [[ -z "${DMG_DEVICE}" ]]; then
  echo "ERROR: unable to mount final DMG for layout verification"
  exit 2
fi
MOUNTED=1

if [[ ! -d "${VERIFY_MOUNT_DIR}/${APP_NAME}" ]]; then
  echo "ERROR: final DMG does not contain ${APP_NAME}"
  exit 2
fi
if [[ ! -L "${VERIFY_MOUNT_DIR}/Applications" ]] \
    || [[ "$(readlink "${VERIFY_MOUNT_DIR}/Applications")" != "/Applications" ]]; then
  echo "ERROR: final DMG does not contain a valid Applications alias"
  exit 2
fi
if [[ ! -f "${VERIFY_MOUNT_DIR}/${APP_NAME}/Contents/Resources/${BACKGROUND_RESOURCE_NAME}" ]]; then
  echo "ERROR: final DMG app is missing the arrow-only Finder background"
  exit 2
fi
UNEXPECTED_ROOT_ITEMS="$(find "${VERIFY_MOUNT_DIR}" -mindepth 1 -maxdepth 1 \
  ! -name "${APP_NAME}" ! -name "Applications" ! -name ".DS_Store" -print)"
if [[ -n "${UNEXPECTED_ROOT_ITEMS}" ]]; then
  echo "ERROR: final DMG exposes unexpected root items:"
  printf '%s\n' "${UNEXPECTED_ROOT_ITEMS}"
  exit 2
fi

hdiutil detach -quiet "${DMG_DEVICE}"
MOUNTED=0

echo "DMG layout OK: only ${APP_NAME} -> Applications, with one arrow (${VOLUME_NAME})"
