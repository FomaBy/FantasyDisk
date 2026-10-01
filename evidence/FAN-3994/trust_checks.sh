#!/bin/bash
# FAN-3994: trust-channel readback of the installed app and the retained DMG
# (codesign, stapler, spctl, hdiutil verify, universal slices, Info.plist
# versions, DMG layout) plus recursive SHA-256 of the DMG app vs the installed
# app. Usage: trust_checks.sh <retained dmg> <installed app> <scratch dir> <out dir>
set -uo pipefail
DMG="$1"; APP="$2"; SCRATCH="$3"; OUT="$4"
mkdir -p "${SCRATCH}" "${OUT}"
{
echo "=== installed app"
codesign --verify --deep --strict --verbose=2 "${APP}" 2>&1
codesign -dv --verbose=2 "${APP}" 2>&1 | grep -E '^(Identifier|Format|CodeDirectory|Authority=Developer ID Application|Timestamp|Runtime Version)' | sed 's/Authority=Developer ID Application: .*/Authority=Developer ID Application: <redacted>/'
xcrun stapler validate "${APP}" 2>&1 | tail -1
spctl --assess --type execute --verbose=4 "${APP}" 2>&1
lipo "${APP}/Contents/MacOS/FantasyDisk" -verify_arch x86_64 arm64 && echo "universal x86_64+arm64 OK"
/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' -c 'Print CFBundleVersion' "${APP}/Contents/Info.plist"
echo "=== DMG"
hdiutil verify "${DMG}" 2>&1 | tail -2
codesign --verify --strict --verbose=2 "${DMG}" 2>&1
xcrun stapler validate "${DMG}" 2>&1 | tail -1
spctl --assess --type open --context context:primary-signature --verbose=4 "${DMG}" 2>&1
MNT="${SCRATCH}/mnt_new"; mkdir -p "${MNT}"
hdiutil attach "${DMG}" -readonly -nobrowse -mountpoint "${MNT}" >/dev/null
ls -la "${MNT}"
readlink "${MNT}/Applications"
codesign --verify --deep --strict --verbose=2 "${MNT}/FantasyDisk.app" 2>&1
xcrun stapler validate "${MNT}/FantasyDisk.app" 2>&1 | tail -1
spctl --assess --type execute --verbose=4 "${MNT}/FantasyDisk.app" 2>&1
/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' -c 'Print CFBundleVersion' "${MNT}/FantasyDisk.app/Contents/Info.plist"
echo "=== DMG app vs installed app (recursive sha256)"
(cd "${MNT}/FantasyDisk.app" && find . -type f -print0 | sort -z | xargs -0 shasum -a 256) > "${OUT}/dmg_app.sha256"
(cd "${APP}" && find . -type f -print0 | sort -z | xargs -0 shasum -a 256) > "${OUT}/installed_app.sha256"
wc -l "${OUT}/dmg_app.sha256" "${OUT}/installed_app.sha256"
if cmp -s "${OUT}/dmg_app.sha256" "${OUT}/installed_app.sha256"; then echo "DMG app == installed app (all files)"; else echo "DMG app != installed app"; diff "${OUT}/dmg_app.sha256" "${OUT}/installed_app.sha256"; fi
cat "${OUT}/installed_app.sha256"
hdiutil detach "${MNT}" >/dev/null
} 2>&1 | tee "${OUT}/trust_checks.txt"
