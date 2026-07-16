#!/bin/bash
# Релизная сборка FantasyDisk для macOS (drag-to-Applications DMG) и Windows
# (только NSIS installer).
#
# Использование: tools/build_release.sh <версия>   # пример: tools/build_release.sh 0.1.0
#
# macOS-канал выбирается ЯВНО через FANTASYDISK_MACOS_CHANNEL:
#   signed (default) — строгий production-канал: Developer ID + notarization
#     обязательны; отсутствие credentials — ошибка, а не тихий downgrade.
#   unsigned — одобренный владельцем канал без Apple credentials (FAN-1121,
#     после отмены FAN-1094): codesign/notarytool/stapler/spctl не выполняются,
#     все остальные гейты (exact tag, layout, secret scan, SHA-256, manifest)
#     сохраняются, а клиент/док обязаны честно помечать сборку как unsigned.
#
# Сборка идет только из git-тега v<версия> через ОТДЕЛЬНЫЙ git worktree, чтобы не
# трогать рабочую ветку dev. Build inputs поверх тега не накладываются: сохранённый
# source snapshot должен соответствовать проекту, из которого экспортирован релиз.
set -euo pipefail

# КРИТИЧНО для makensis: в C-локали iconv("wchar_t"->...) падает на не-ASCII
# символах NSIS-констант с фиктивным std::bad_alloc. Нужна UTF-8 локаль.
export LC_ALL=en_US.UTF-8

VERSION="${1:?Usage: tools/build_release.sh <version>}"
TAG="v${VERSION}"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_PATH="${GODOT_BIN:-${GODOT:-/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot}}"
WORKTREE_DIR="$(mktemp -d /tmp/fantasydisk-build-XXXXXX)/src"
RELEASE_DIR="${WORKTREE_DIR}/build/release-package"
DMG_MOUNT_DIR=""
MACOS_SIGN_IDENTITY="${MACOS_SIGN_IDENTITY:-}"
MACOS_NOTARY_PROFILE="${MACOS_NOTARY_PROFILE:-}"
MACOS_CHANNEL="${FANTASYDISK_MACOS_CHANNEL:-signed}"
MACOS_ARROW_REL="docs/design/references/fan1094_macos_installer/pixellab_arrow.png"

if [[ "${MACOS_CHANNEL}" != "signed" && "${MACOS_CHANNEL}" != "unsigned" ]]; then
  echo "ERROR: FANTASYDISK_MACOS_CHANNEL must be 'signed' or 'unsigned', got '${MACOS_CHANNEL}'"
  exit 2
fi
if [[ "${MACOS_CHANNEL}" == "unsigned" ]]; then
  # Fail-closed в обе стороны: unsigned-канал запускается только явным выбором
  # и отказывается работать, когда signing credentials присутствуют, чтобы
  # никогда не выпустить unsigned там, где возможен signed.
  if [[ -n "${MACOS_SIGN_IDENTITY}" || -n "${MACOS_NOTARY_PROFILE}" ]]; then
    echo "ERROR: unsigned channel refuses to run while MACOS_SIGN_IDENTITY/MACOS_NOTARY_PROFILE are set; use the signed channel or unset them"
    exit 2
  fi
else
  if [[ -z "${MACOS_SIGN_IDENTITY}" ]]; then
    echo "ERROR: MACOS_SIGN_IDENTITY is required; release builds may not use ad-hoc signing (owner-approved credential-free builds must set FANTASYDISK_MACOS_CHANNEL=unsigned explicitly)"
    exit 2
  fi
  if [[ -z "${MACOS_NOTARY_PROFILE}" ]]; then
    echo "ERROR: MACOS_NOTARY_PROFILE is required; release builds must be notarized"
    exit 2
  fi
  if ! security find-identity -v -p codesigning 2>/dev/null \
      | grep -F "${MACOS_SIGN_IDENTITY}" | grep -q "Developer ID Application"; then
    echo "ERROR: MACOS_SIGN_IDENTITY is not an installed Developer ID Application identity"
    exit 2
  fi
  if ! xcrun notarytool history --keychain-profile "${MACOS_NOTARY_PROFILE}" \
      --output-format json >/dev/null 2>&1; then
    echo "ERROR: MACOS_NOTARY_PROFILE is missing or cannot authenticate with Apple"
    exit 2
  fi
fi
run_godot() {
  # Fresh macOS headless imports in Godot 4.7 can otherwise dispatch an audio
  # reimport notification from a worker thread and crash in
  # Node::propagate_notification. Release inputs are immutable and do not need
  # sub-thread scene groups, so make the build path deterministic.
  GODOT_BIN="${GODOT_PATH}" python3 "${WORKTREE_DIR}/tools/godot_gate.py" \
    --single-threaded-scene "$@"
}

submit_notary_artifact() {
  local artifact="$1"
  local label="$2"
  local report="$3"
  if ! xcrun notarytool submit "${artifact}" \
      --keychain-profile "${MACOS_NOTARY_PROFILE}" \
      --wait --output-format json >"${report}"; then
    echo "    ERROR: Apple notarization request failed for ${label}"
    [[ -s "${report}" ]] && cat "${report}"
    exit 2
  fi
  local status
  status="$(/usr/bin/plutil -extract status raw -o - "${report}" 2>/dev/null || true)"
  if [[ "${status}" != "Accepted" ]]; then
    echo "    ERROR: Apple notarization rejected ${label} (status: ${status:-unknown})"
    cat "${report}"
    exit 2
  fi
  echo "    Apple notarization accepted ${label}"
}

echo "==> Worktree из тега ${TAG}"
git -C "${REPO_DIR}" worktree add --detach "${WORKTREE_DIR}" "${TAG}"
cleanup() {
  if [[ -n "${DMG_MOUNT_DIR}" ]]; then
    hdiutil detach "${DMG_MOUNT_DIR}" -force >/dev/null 2>&1 || true
  fi
  git -C "${REPO_DIR}" worktree remove --force "${WORKTREE_DIR}" 2>/dev/null || true
}
trap cleanup EXIT

echo "==> Проверка точных build inputs внутри тега"
for required_input in \
  export_presets.cfg \
  assets/icon.ico \
  "${MACOS_ARROW_REL}" \
  tools/build_release.sh \
  tools/create_macos_dmg.sh \
  tools/godot_gate.py \
  tools/scan_release_secrets.py \
  tools/windows_installer.nsi \
  skills/codex/fantasydisk-release-director/scripts/build_update_manifest.py \
  skills/codex/fantasydisk-release-director/scripts/local_release.py; do
  if [[ ! -f "${WORKTREE_DIR}/${required_input}" ]]; then
    echo "    ERROR: тег ${TAG} не содержит build input ${required_input}"
    exit 2
  fi
done
if ! cmp -s "${REPO_DIR}/tools/build_release.sh" "${WORKTREE_DIR}/tools/build_release.sh"; then
  echo "    ERROR: запущенный build_release.sh отличается от exact tag ${TAG}"
  exit 2
fi
MACOS_ARROW_SOURCE="${WORKTREE_DIR}/${MACOS_ARROW_REL}"

echo "==> Проверка версии тега и export presets"
TAG_PROJECT_VERSION="$(grep 'config/version' "${WORKTREE_DIR}/project.godot" | cut -d'"' -f2)"
if [[ "${TAG_PROJECT_VERSION}" != "${VERSION}" ]]; then
  echo "    ERROR: config/version в теге ${TAG} = ${TAG_PROJECT_VERSION}, ожидали ${VERSION}"
  exit 2
fi
if ! grep -q "application/short_version=\"${VERSION}\"" "${WORKTREE_DIR}/export_presets.cfg" \
    || ! grep -q "application/version=\"${VERSION}\"" "${WORKTREE_DIR}/export_presets.cfg" \
    || ! grep -q "application/product_version=\"${VERSION}\"" "${WORKTREE_DIR}/export_presets.cfg" \
    || ! grep -q "application/file_version=\"${VERSION}.0\"" "${WORKTREE_DIR}/export_presets.cfg"; then
  echo "    ERROR: export_presets.cfg версии не совпадают с ${VERSION}"
  exit 2
fi

echo "==> Проверка честной маркировки macOS-канала в клиенте тега"
CLIENT_MACOS_CHANNEL="$(sed -n 's/^const MACOS_UPDATE_CHANNEL := "\([a-z]*\)".*$/\1/p' \
  "${WORKTREE_DIR}/scripts/update_manager.gd" | head -1)"
if [[ "${CLIENT_MACOS_CHANNEL}" != "${MACOS_CHANNEL}" ]]; then
  echo "    ERROR: клиент тега помечает macOS-канал как '${CLIENT_MACOS_CHANNEL:-<нет метки>}', сборка идёт в канале '${MACOS_CHANNEL}'; трастовые подсказки в UI стали бы ложью"
  exit 2
fi

echo "==> Feedback delivery"
RELAY_SESSION_URL="$(sed -n 's/^relay_session_url="\([^"]*\)"$/\1/p' "${WORKTREE_DIR}/project.godot" | head -1)"
if [[ -n "${RELAY_SESSION_URL}" ]]; then
  echo "    production relay endpoint задан (public URL; credential остаётся server-side)"
else
  echo "    production relay не задан; player feedback сохраняется в user://feedback"
fi
if [[ -f "${REPO_DIR}/feedback_webhook.cfg" || -n "${FANTASYDISK_FEEDBACK_WEBHOOK:-}" ]]; then
  echo "    raw Discord webhook обнаружен только как dev override; release-клиент его игнорирует"
fi

echo "==> Импорт ресурсов (headless)"
mkdir -p "${WORKTREE_DIR}/build"
IMPORT_LOG="${WORKTREE_DIR}/build/godot_import.log"
if ! run_godot --headless --import --path "${WORKTREE_DIR}" >"${IMPORT_LOG}" 2>&1; then
  echo "    ERROR: headless import failed; tail ${IMPORT_LOG}:"
  tail -80 "${IMPORT_LOG}" || true
  exit 2
fi

echo "==> Экспорт macOS (.app в zip; подпись будет последним изменением bundle)"
run_godot --headless --path "${WORKTREE_DIR}" \
  --export-release "macOS" "${WORKTREE_DIR}/build/FantasyDisk-${VERSION}-macos.zip"

echo "==> Финализация и подпись готового .app"
MAC_STAGE="${WORKTREE_DIR}/build/macos-stage"
mkdir -p "${MAC_STAGE}"
ditto -x -k "${WORKTREE_DIR}/build/FantasyDisk-${VERSION}-macos.zip" "${MAC_STAGE}"
APP_PATH="$(find "${MAC_STAGE}" -maxdepth 2 -type d -name '*.app' -print -quit)"
if [[ -z "${APP_PATH}" ]]; then
  echo "    ERROR: macOS export не содержит .app"
  exit 2
fi

echo "==> Минималистичный Finder layout: две системные иконки и одна стрелка"
DMG_BACKGROUND_RESOURCE="${APP_PATH}/Contents/Resources/FantasyDiskDmgBackground.png"
DMG_ARROW_STAGE="${MAC_STAGE}/dmg-arrow-170x64.png"
mkdir -p "$(dirname "${DMG_BACKGROUND_RESOURCE}")"
sips --resampleHeightWidth 64 170 "${MACOS_ARROW_SOURCE}" \
  --out "${DMG_ARROW_STAGE}" >/dev/null
sips --padToHeightWidth 480 720 --padColor F7F7F7 "${DMG_ARROW_STAGE}" \
  --out "${DMG_BACKGROUND_RESOURCE}" >/dev/null
DMG_BACKGROUND_WIDTH="$(sips -g pixelWidth "${DMG_BACKGROUND_RESOURCE}" | awk '/pixelWidth/ {print $2}')"
DMG_BACKGROUND_HEIGHT="$(sips -g pixelHeight "${DMG_BACKGROUND_RESOURCE}" | awk '/pixelHeight/ {print $2}')"
if [[ "${DMG_BACKGROUND_WIDTH}x${DMG_BACKGROUND_HEIGHT}" != "720x480" ]]; then
  echo "    ERROR: Finder background must be exactly 720x480"
  exit 2
fi

xattr -cr "${APP_PATH}"
if [[ "${MACOS_CHANNEL}" == "signed" ]]; then
  echo "    Подпись Developer ID Application (hardened runtime + timestamp)"
  codesign --force --deep --options runtime --timestamp \
    --sign "${MACOS_SIGN_IDENTITY}" "${APP_PATH}"
  codesign --verify --deep --strict --verbose=4 "${APP_PATH}"

  echo "==> Apple notarization + stapling приложения"
  APP_NOTARY_ZIP="${WORKTREE_DIR}/build/FantasyDisk-${VERSION}-macos-notary.zip"
  APP_NOTARY_REPORT="${WORKTREE_DIR}/build/notary-app.json"
  ditto -c -k --sequesterRsrc --keepParent "${APP_PATH}" "${APP_NOTARY_ZIP}"
  submit_notary_artifact "${APP_NOTARY_ZIP}" "FantasyDisk.app" "${APP_NOTARY_REPORT}"
  rm -f "${APP_NOTARY_ZIP}"
  xcrun stapler staple "${APP_PATH}"
  xcrun stapler validate "${APP_PATH}"
  codesign --verify --deep --strict --verbose=4 "${APP_PATH}"
  spctl --assess --type execute --verbose=4 "${APP_PATH}"
else
  echo "    Канал unsigned (FAN-1121): Developer ID подпись и Apple notarization не выполняются; Gatekeeper потребует ручного «Всё равно открыть»"
fi

echo "==> Создание DMG с ярлыком Applications и стрелкой"
MAC_DMG="${WORKTREE_DIR}/build/FantasyDisk-${VERSION}-macos.dmg"
bash "${WORKTREE_DIR}/tools/create_macos_dmg.sh" "${APP_PATH}" "${MAC_DMG}" "${VERSION}"
if [[ "${MACOS_CHANNEL}" == "signed" ]]; then
  codesign --force --timestamp --sign "${MACOS_SIGN_IDENTITY}" "${MAC_DMG}"
  codesign --verify --strict --verbose=4 "${MAC_DMG}"

  echo "==> Apple notarization + stapling DMG"
  DMG_NOTARY_REPORT="${WORKTREE_DIR}/build/notary-dmg.json"
  submit_notary_artifact "${MAC_DMG}" "FantasyDisk DMG" "${DMG_NOTARY_REPORT}"
  xcrun stapler staple "${MAC_DMG}"
  xcrun stapler validate "${MAC_DMG}"
  codesign --verify --strict --verbose=4 "${MAC_DMG}"
  spctl --assess --type open --context context:primary-signature --verbose=4 "${MAC_DMG}"
fi

echo "==> Экспорт Windows (x86_64, embed_pck)"
run_godot --headless --path "${WORKTREE_DIR}" \
  --export-release "Windows Desktop" "${WORKTREE_DIR}/build/FantasyDisk-Windows.exe"

echo "==> NSIS-инсталлер"
makensis -DVERSION="${VERSION}" \
  -DSRC_EXE="${WORKTREE_DIR}/build/FantasyDisk-Windows.exe" \
  -DOUT_FILE="${WORKTREE_DIR}/build/FantasyDisk-${VERSION}-windows-setup.exe" \
  "${WORKTREE_DIR}/tools/windows_installer.nsi"

echo "==> Верификация NSIS CRC (точный алгоритм exehead: crc32 файла с байта 512 до поля CRC)"
python3 - "${WORKTREE_DIR}/build/FantasyDisk-${VERSION}-windows-setup.exe" <<'PYCRC'
import sys, zlib, struct
path = sys.argv[1]
data = open(path, "rb").read()
FH_SIG, I1, I2, I3 = 0xDEADBEEF, 0x6C6C754E, 0x74666F73, 0x74736E49
fh_off = None
for off in range(0, len(data) - 28, 512):
    flags, sig, a, b, c = struct.unpack_from("<5I", data, off)
    if sig == FH_SIG and (a, b, c) == (I1, I2, I3):
        fh_off = off
        break
assert fh_off is not None, "NSIS firstheader не найден"
length_following = struct.unpack_from("<I", data, fh_off + 24)[0]
crc_off = fh_off + length_following - 4
stored = struct.unpack_from("<I", data, crc_off)[0]
computed = zlib.crc32(data[512:crc_off]) & 0xFFFFFFFF
assert stored == computed, "NSIS CRC битый: stored %08x != computed %08x" % (stored, computed)
print("NSIS CRC OK (firstheader @ %d, crc @ %d)" % (fh_off, crc_off))
PYCRC

echo "==> Read-only mount macOS DMG для проверки подписи, layout и secret scan"
DMG_MOUNT_DIR="${WORKTREE_DIR}/build/secret-scan-dmg"
mkdir -p "${DMG_MOUNT_DIR}"
hdiutil attach "${MAC_DMG}" \
  -readonly -nobrowse -mountpoint "${DMG_MOUNT_DIR}" >/dev/null
if [[ ! -L "${DMG_MOUNT_DIR}/Applications" ]] \
    || [[ "$(readlink "${DMG_MOUNT_DIR}/Applications")" != "/Applications" ]]; then
  echo "    ERROR: DMG не содержит корректный ярлык Applications"
  exit 2
fi
MOUNTED_APP="${DMG_MOUNT_DIR}/$(basename "${APP_PATH}")"
if [[ ! -d "${MOUNTED_APP}" ]]; then
  echo "    ERROR: DMG не содержит ${MOUNTED_APP}"
  exit 2
fi
if [[ "${MACOS_CHANNEL}" == "signed" ]]; then
  codesign --verify --deep --strict --verbose=4 "${MOUNTED_APP}"
  xcrun stapler validate "${MOUNTED_APP}"
  spctl --assess --type execute --verbose=4 "${MOUNTED_APP}"
fi

echo "==> Secret scan staged player payloads до публикации"
set +e
python3 "${WORKTREE_DIR}/tools/scan_release_secrets.py" \
  "${DMG_MOUNT_DIR}" \
  "${WORKTREE_DIR}/build/FantasyDisk-Windows.exe" \
  "${WORKTREE_DIR}/build/FantasyDisk-${VERSION}-windows-setup.exe"
SECRET_SCAN_STATUS=$?
set -e
hdiutil detach "${DMG_MOUNT_DIR}" >/dev/null
DMG_MOUNT_DIR=""
if [[ "${SECRET_SCAN_STATUS}" -ne 0 ]]; then
  echo "    ERROR: publishable release artifacts were not created because secret scan failed"
  exit "${SECRET_SCAN_STATUS}"
fi

echo "==> Публикация проверенных staged artifacts"
mkdir -p "${RELEASE_DIR}"
rm -f "${RELEASE_DIR}/FantasyDisk-${VERSION}-windows.zip"
rm -f "${RELEASE_DIR}/FantasyDisk-Windows.exe"
cp "${MAC_DMG}" "${RELEASE_DIR}/"
cp "${WORKTREE_DIR}/build/FantasyDisk-${VERSION}-windows-setup.exe" "${RELEASE_DIR}/"
awk -v marker="## [${VERSION}]" '
  index($0, marker) == 1 { capture = 1 }
  capture && printed && index($0, "## [") == 1 { exit }
  capture { print; printed = 1 }
' "${WORKTREE_DIR}/CHANGELOG.md" > "${RELEASE_DIR}/CHANGELOG-${VERSION}.md"
if [[ ! -s "${RELEASE_DIR}/CHANGELOG-${VERSION}.md" ]]; then
  echo "    ERROR: раздел ${VERSION} не найден в CHANGELOG.md"
  exit 2
fi
if [[ "${VERSION}" == "0.2.2" ]]; then
  POSTER_NAME="fantasydisk_${VERSION//./}_announcement_telegram_discord.png"
else
  POSTER_NAME="fantasydisk_${VERSION//./}_announcement.png"
fi
POSTER_PATH="${WORKTREE_DIR}/assets/marketing/${POSTER_NAME}"
if [[ ! -f "${POSTER_PATH}" ]]; then
  echo "    ERROR: обязательный release poster отсутствует: ${POSTER_PATH}"
  exit 2
fi
cp "${POSTER_PATH}" "${RELEASE_DIR}/"

echo "==> SHA256SUMS.txt (контроль порчи при передаче файлов)"
(cd "${RELEASE_DIR}" && shasum -a 256 FantasyDisk-* > SHA256SUMS.txt && cat SHA256SUMS.txt)

echo "==> Публичный update-manifest.json для клиента 0.2.2+"
python3 "${WORKTREE_DIR}/skills/codex/fantasydisk-release-director/scripts/build_update_manifest.py" \
  --version "${VERSION}" \
  --minimum-supported-version "0.2.2" \
  --release-dir "${RELEASE_DIR}"

echo "==> Постоянная локальная копия, Godot snapshot и установка macOS"
python3 "${WORKTREE_DIR}/skills/codex/fantasydisk-release-director/scripts/local_release.py" \
  materialize \
  --version "${VERSION}" \
  --repo-root "${REPO_DIR}" \
  --release-dir "${RELEASE_DIR}" \
  --macos-channel "${MACOS_CHANNEL}"

echo "==> Готово:"
ls -lh "${RELEASE_DIR}"
