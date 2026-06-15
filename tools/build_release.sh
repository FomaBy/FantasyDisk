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
GODOT="/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORKTREE_DIR="$(mktemp -d /tmp/fantasydisk-build-XXXXXX)/src"
RELEASE_DIR="${REPO_DIR}/releases/${TAG}"

PROJECT_VERSION="$(grep 'config/version' "${REPO_DIR}/project.godot" | cut -d'"' -f2)"
if [[ "${PROJECT_VERSION}" != "${VERSION}" ]]; then
  echo "ВНИМАНИЕ: config/version в dev = ${PROJECT_VERSION}, собираем тег ${TAG} (это нормально для ретро-сборки)."
fi

echo "==> Worktree из тега ${TAG}"
git -C "${REPO_DIR}" worktree add --detach "${WORKTREE_DIR}" "${TAG}"
cleanup() {
  git -C "${REPO_DIR}" worktree remove --force "${WORKTREE_DIR}" 2>/dev/null || true
}
trap cleanup EXIT

echo "==> Перенос свежей сборочной инфраструктуры в worktree"
cp "${REPO_DIR}/export_presets.cfg" "${WORKTREE_DIR}/export_presets.cfg"
mkdir -p "${WORKTREE_DIR}/assets"
cp "${REPO_DIR}/assets/icon.ico" "${WORKTREE_DIR}/assets/icon.ico"
# Бандлим gitignored секрет вебхука фидбека в билд (иначе на чужих ПК «вебхук не
# настроен» → локальное сохранение). include_filter в export_presets.cfg его включает.
if [[ -f "${REPO_DIR}/feedback_webhook.cfg" ]]; then
  cp "${REPO_DIR}/feedback_webhook.cfg" "${WORKTREE_DIR}/feedback_webhook.cfg"
  echo "    feedback_webhook.cfg скопирован в worktree (фидбек заработает на тестерских ПК)"
else
  echo "    ВНИМАНИЕ: feedback_webhook.cfg не найден — фидбек в сборке будет сохранять локально"
fi

echo "==> Импорт ресурсов (headless)"
"${GODOT}" --headless --import --path "${WORKTREE_DIR}" >/dev/null 2>&1 || true

mkdir -p "${RELEASE_DIR}" "${WORKTREE_DIR}/build"

echo "==> Экспорт macOS (dmg, ad-hoc подпись)"
"${GODOT}" --headless --path "${WORKTREE_DIR}" \
  --export-release "macOS" "${WORKTREE_DIR}/build/FantasyDisk-${VERSION}-macos.dmg"
cp "${WORKTREE_DIR}/build/FantasyDisk-${VERSION}-macos.dmg" "${RELEASE_DIR}/"

echo "==> Экспорт Windows (x86_64, embed_pck)"
"${GODOT}" --headless --path "${WORKTREE_DIR}" \
  --export-release "Windows Desktop" "${WORKTREE_DIR}/build/FantasyDisk-Windows.exe"

echo "==> NSIS-инсталлер"
makensis -DVERSION="${VERSION}" \
  -DSRC_EXE="${WORKTREE_DIR}/build/FantasyDisk-Windows.exe" \
  -DOUT_FILE="${RELEASE_DIR}/FantasyDisk-${VERSION}-windows-setup.exe" \
  "${REPO_DIR}/tools/windows_installer.nsi"

echo "==> Верификация NSIS CRC (точный алгоритм exehead: crc32 файла с байта 512 до поля CRC)"
python3 - "$RELEASE_DIR/FantasyDisk-${VERSION}-windows-setup.exe" <<'PYCRC'
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
  && zip -q "${RELEASE_DIR}/FantasyDisk-${VERSION}-windows.zip" "FantasyDisk-${VERSION}.exe")

echo "==> SHA256SUMS.txt (контроль порчи при передаче файлов)"
(cd "${RELEASE_DIR}" && shasum -a 256 FantasyDisk-* > SHA256SUMS.txt && cat SHA256SUMS.txt)

echo "==> Готово:"
ls -lh "${RELEASE_DIR}"
