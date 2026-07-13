#!/bin/bash
# Релизная сборка FantasyDisk для macOS (dmg) и Windows (exe + NSIS installer + zip).
#
# Использование: tools/build_release.sh <версия>   # пример: tools/build_release.sh 0.1.0
#
# Сборка идет из git-тега v<версия> через ОТДЕЛЬНЫЙ git worktree, чтобы не трогать
# рабочую ветку dev (в каталоге параллельно работают другие агенты — checkout тега
# в основном дереве запрещен). Свежая инфраструктура сборки (export_presets.cfg,
# assets/icon.ico, tools/windows_installer.nsi) копируется в worktree поверх тега.
set -euo pipefail

# КРИТИЧНО для makensis: в C-локали iconv("wchar_t"->...) падает на не-ASCII
# символах NSIS-констант с фиктивным std::bad_alloc. Нужна UTF-8 локаль.
export LC_ALL=en_US.UTF-8

VERSION="${1:?Usage: tools/build_release.sh <version>}"
TAG="v${VERSION}"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_PATH="${GODOT_BIN:-${GODOT:-/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot}}"
WORKTREE_DIR="$(mktemp -d /tmp/fantasydisk-build-XXXXXX)/src"
RELEASE_DIR="${REPO_DIR}/releases/${TAG}"
DMG_MOUNT_DIR=""

run_godot() {
  GODOT_BIN="${GODOT_PATH}" python3 "${REPO_DIR}/tools/godot_gate.py" "$@"
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

echo "==> Перенос свежей сборочной инфраструктуры в worktree"
cp "${REPO_DIR}/export_presets.cfg" "${WORKTREE_DIR}/export_presets.cfg"
mkdir -p "${WORKTREE_DIR}/assets"
cp "${REPO_DIR}/assets/icon.ico" "${WORKTREE_DIR}/assets/icon.ico"

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

echo "==> Экспорт macOS (dmg, ad-hoc подпись)"
run_godot --headless --path "${WORKTREE_DIR}" \
  --export-release "macOS" "${WORKTREE_DIR}/build/FantasyDisk-${VERSION}-macos.dmg"

echo "==> Экспорт Windows (x86_64, embed_pck)"
run_godot --headless --path "${WORKTREE_DIR}" \
  --export-release "Windows Desktop" "${WORKTREE_DIR}/build/FantasyDisk-Windows.exe"

echo "==> NSIS-инсталлер"
makensis -DVERSION="${VERSION}" \
  -DSRC_EXE="${WORKTREE_DIR}/build/FantasyDisk-Windows.exe" \
  -DOUT_FILE="${WORKTREE_DIR}/build/FantasyDisk-${VERSION}-windows-setup.exe" \
  "${REPO_DIR}/tools/windows_installer.nsi"

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

echo "==> Zip-запаска Windows"
(cd "${WORKTREE_DIR}/build" && cp FantasyDisk-Windows.exe "FantasyDisk-${VERSION}.exe" \
  && zip -q "FantasyDisk-${VERSION}-windows.zip" "FantasyDisk-${VERSION}.exe")

echo "==> Read-only mount macOS DMG для secret scan app/PCK"
DMG_MOUNT_DIR="${WORKTREE_DIR}/build/secret-scan-dmg"
mkdir -p "${DMG_MOUNT_DIR}"
hdiutil attach "${WORKTREE_DIR}/build/FantasyDisk-${VERSION}-macos.dmg" \
  -readonly -nobrowse -mountpoint "${DMG_MOUNT_DIR}" >/dev/null

echo "==> Secret scan staged player payloads до публикации"
set +e
python3 "${REPO_DIR}/tools/scan_release_secrets.py" \
  "${DMG_MOUNT_DIR}" \
  "${WORKTREE_DIR}/build/FantasyDisk-Windows.exe" \
  "${WORKTREE_DIR}/build/FantasyDisk-${VERSION}-windows-setup.exe" \
  "${WORKTREE_DIR}/build/FantasyDisk-${VERSION}-windows.zip"
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
cp "${WORKTREE_DIR}/build/FantasyDisk-${VERSION}-macos.dmg" "${RELEASE_DIR}/"
cp "${WORKTREE_DIR}/build/FantasyDisk-${VERSION}-windows-setup.exe" "${RELEASE_DIR}/"
cp "${WORKTREE_DIR}/build/FantasyDisk-${VERSION}-windows.zip" "${RELEASE_DIR}/"

echo "==> SHA256SUMS.txt (контроль порчи при передаче файлов)"
(cd "${RELEASE_DIR}" && shasum -a 256 FantasyDisk-* > SHA256SUMS.txt && cat SHA256SUMS.txt)

echo "==> Готово:"
ls -lh "${RELEASE_DIR}"
