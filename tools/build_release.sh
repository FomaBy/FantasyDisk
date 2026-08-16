#!/bin/bash
# Релизная сборка FantasyDisk для macOS (drag-to-Applications DMG) и Windows
# (только NSIS installer).
#
# Использование: tools/build_release.sh <версия> [candidate options]
#
# macOS-канал выбирается ЯВНО через FANTASYDISK_MACOS_CHANNEL:
#   signed (default) — строгий production-канал: Developer ID + notarization
#     обязательны; отсутствие credentials — ошибка, а не тихий downgrade.
#   unsigned — одобренный владельцем канал без Apple credentials (FAN-1121,
#     после отмены FAN-1094): финальный bundle получает только ad-hoc seal,
#     чтобы заменить унаследованную подпись export template и проверить
#     целостность. Developer ID/notarytool/stapler/spctl не выполняются; все
#     остальные гейты (exact tag, layout, secret scan, SHA-256, manifest)
#     сохраняются, а клиент/док обязаны честно помечать сборку как unsigned.
#
# Сборка идет из immutable тега или явно закреплённого remote candidate через
# ОТДЕЛЬНЫЙ git worktree, чтобы не трогать рабочую ветку dev. Build inputs поверх
# выбранного snapshot не накладываются: сохранённый source snapshot должен
# соответствовать проекту, из которого экспортирован релиз.
#
# --candidate-presign-verify — QA-only pre-sign verification (FAN-2426): режим
#   доступен ТОЛЬКО вместе с полным candidate pin и доказывает, что закреплённый
#   candidate импортируется и экспортируется без credentials. Он останавливается
#   на post-export/pre-sign checkpoint, поэтому packaging, подпись, notarization,
#   tag, GitHub Release и публикация не выполняются, publishable artifact не
#   создаётся, а disposable output удаляется. Обычные каналы этот режим не
#   ослабляет: signed по-прежнему требует Developer ID + notary profile, unsigned
#   остаётся отдельно выбираемым каналом с честной клиентской меткой.
set -euo pipefail

# КРИТИЧНО для makensis: в C-локали iconv("wchar_t"->...) падает на не-ASCII
# символах NSIS-констант с фиктивным std::bad_alloc. Нужна UTF-8 локаль.
export LC_ALL=en_US.UTF-8

usage() {
  echo "Usage: tools/build_release.sh <version> [--candidate-repository <repo> --candidate-ref <refs/heads/...> --candidate-sha <40-hex> [--candidate-presign-verify]]"
}

if [[ "$#" -lt 1 ]]; then
  usage
  exit 2
fi
VERSION="$1"
shift
CANDIDATE_REPOSITORY=""
CANDIDATE_REF=""
CANDIDATE_SHA=""
PRESIGN_MODE=0
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --candidate-presign-verify)
      PRESIGN_MODE=1
      shift
      ;;
    --candidate-repository|--candidate-ref|--candidate-sha)
      if [[ "$#" -lt 2 ]]; then
        echo "ERROR: $1 requires a value"
        exit 2
      fi
      case "$1" in
        --candidate-repository) CANDIDATE_REPOSITORY="$2" ;;
        --candidate-ref) CANDIDATE_REF="$2" ;;
        --candidate-sha) CANDIDATE_SHA="$2" ;;
      esac
      shift 2
      ;;
    *)
      echo "ERROR: unknown argument: $1"
      usage
      exit 2
      ;;
  esac
done
TAG="v${VERSION}"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_PATH="${GODOT_BIN:-${GODOT:-/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot}}"
WORKTREE_DIR=""
RELEASE_DIR=""
DMG_MOUNT_DIR=""
MACOS_SIGN_IDENTITY="${MACOS_SIGN_IDENTITY:-}"
MACOS_NOTARY_PROFILE="${MACOS_NOTARY_PROFILE:-}"
MACOS_CHANNEL="${FANTASYDISK_MACOS_CHANNEL:-signed}"
MACOS_ARROW_REL="docs/design/references/fan1094_macos_installer/pixellab_arrow.png"

RELEASE_VERSION_RE='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(\.(0|[1-9][0-9]*))?$'
if ! [[ "${VERSION}" =~ ${RELEASE_VERSION_RE} ]]; then
  echo "ERROR: version must have format X.Y.Z or X.Y.Z.R"
  exit 2
fi
if [[ "${MACOS_CHANNEL}" != "signed" && "${MACOS_CHANNEL}" != "unsigned" ]]; then
  echo "ERROR: FANTASYDISK_MACOS_CHANNEL must be 'signed' or 'unsigned', got '${MACOS_CHANNEL}'"
  exit 2
fi
CANDIDATE_MODE=0
if [[ -n "${CANDIDATE_REPOSITORY}${CANDIDATE_REF}${CANDIDATE_SHA}" ]]; then
  CANDIDATE_MODE=1
  if [[ -z "${CANDIDATE_REPOSITORY}" || -z "${CANDIDATE_REF}" || -z "${CANDIDATE_SHA}" ]]; then
    echo "ERROR: candidate mode requires --candidate-repository, --candidate-ref, and --candidate-sha together"
    exit 2
  fi
  if [[ "${CANDIDATE_REPOSITORY}" == -* || "${CANDIDATE_REPOSITORY}" == *$'\n'* ]]; then
    echo "ERROR: candidate repository is unsafe"
    exit 2
  fi
  if [[ ! "${CANDIDATE_REF}" =~ ^refs/heads/[A-Za-z0-9][A-Za-z0-9._/-]*$ ]] \
      || [[ "${CANDIDATE_REF}" == *..* || "${CANDIDATE_REF}" == *//* || "${CANDIDATE_REF}" == */ ]]; then
    echo "ERROR: candidate ref must be a safe refs/heads/* remote ref"
    exit 2
  fi
  if [[ ! "${CANDIDATE_SHA}" =~ ^[0-9a-fA-F]{40}$ ]]; then
    echo "ERROR: candidate SHA must be a full 40-hex commit"
    exit 2
  fi
  CANDIDATE_SHA="$(tr '[:upper:]' '[:lower:]' <<< "${CANDIDATE_SHA}")"
fi
if [[ "${PRESIGN_MODE}" -eq 1 && "${CANDIDATE_MODE}" -eq 0 ]]; then
  echo "ERROR: --candidate-presign-verify is candidate-only and cannot run the tag/final-release path; pin --candidate-repository, --candidate-ref and --candidate-sha"
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
elif [[ "${PRESIGN_MODE}" -eq 1 ]]; then
  # Pre-sign verification останавливается до подписи и notarization, поэтому
  # Developer ID и notary profile ему не нужны. Требование credentials остаётся
  # обязательным для обычного signed-канала ниже, который действительно подписывает.
  echo "==> Pre-sign verification: Developer ID/notary credentials не требуются, подпись и notarization не выполняются"
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
  # sub-thread scene groups, so make the build path deterministic.  Clear an
  # inherited timing-run flag too: import/export must use the ordinary gate and
  # never reserve the machine-wide exclusive admission.
  GODOT_BIN="${GODOT_PATH}" env FSD_GODOT_EXCLUSIVE= python3 "${WORKTREE_DIR}/tools/godot_gate.py" \
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

SOURCE_COMMIT=""
SOURCE_TREE=""
SOURCE_LABEL=""
if [[ "${CANDIDATE_MODE}" -eq 1 ]]; then
  REMOTE_LINE="$(git ls-remote --refs "${CANDIDATE_REPOSITORY}" "${CANDIDATE_REF}" || true)"
  if [[ ! "${REMOTE_LINE}" =~ ^([0-9a-fA-F]{40})$'\t'(.+)$ ]]; then
    echo "ERROR: candidate remote ref cannot be resolved exactly"
    exit 2
  fi
  REMOTE_SHA="$(tr '[:upper:]' '[:lower:]' <<< "${BASH_REMATCH[1]}")"
  REMOTE_REF="${BASH_REMATCH[2]}"
  if [[ "${REMOTE_REF}" != "${CANDIDATE_REF}" || "${REMOTE_SHA}" != "${CANDIDATE_SHA}" ]]; then
    echo "ERROR: candidate remote ref does not resolve to the pinned SHA"
    exit 2
  fi
  if ! git -C "${REPO_DIR}" fetch --no-tags "${CANDIDATE_REPOSITORY}" "${CANDIDATE_REF}"; then
    echo "ERROR: candidate remote ref could not be fetched"
    exit 2
  fi
  if ! SOURCE_COMMIT="$(git -C "${REPO_DIR}" rev-parse "FETCH_HEAD^{commit}")"; then
    echo "ERROR: fetched candidate remote ref has no commit"
    exit 2
  fi
  SOURCE_COMMIT="$(tr '[:upper:]' '[:lower:]' <<< "${SOURCE_COMMIT}")"
  if [[ "${SOURCE_COMMIT}" != "${CANDIDATE_SHA}" ]]; then
    echo "ERROR: fetched candidate remote ref does not match the pinned SHA"
    exit 2
  fi
  SOURCE_TREE="$(git -C "${REPO_DIR}" rev-parse "${SOURCE_COMMIT}^{tree}")"
  SOURCE_TREE="$(tr '[:upper:]' '[:lower:]' <<< "${SOURCE_TREE}")"
  SOURCE_LABEL="candidate ${CANDIDATE_SHA} from ${CANDIDATE_REF}"
else
  if ! SOURCE_COMMIT="$(git -C "${REPO_DIR}" rev-parse "${TAG}^{commit}")"; then
    echo "ERROR: immutable tag ${TAG} is unavailable"
    exit 2
  fi
  SOURCE_TREE="$(git -C "${REPO_DIR}" rev-parse "${SOURCE_COMMIT}^{tree}")"
  SOURCE_LABEL="tag ${TAG}"
fi

WORKTREE_DIR="$(mktemp -d /tmp/fantasydisk-build-XXXXXX)/src"
RELEASE_DIR="${WORKTREE_DIR}/build/release-package"
echo "==> Worktree из ${SOURCE_LABEL}"
git -C "${REPO_DIR}" worktree add --detach "${WORKTREE_DIR}" "${SOURCE_COMMIT}"
cleanup() {
  if [[ -n "${DMG_MOUNT_DIR}" ]]; then
    hdiutil detach "${DMG_MOUNT_DIR}" -force >/dev/null 2>&1 || true
  fi
  git -C "${REPO_DIR}" worktree remove --force "${WORKTREE_DIR}" 2>/dev/null || true
}
trap cleanup EXIT

echo "==> Проверка точных build inputs внутри ${SOURCE_LABEL}"
for required_input in \
  export_presets.cfg \
  assets/icon.ico \
  "${MACOS_ARROW_REL}" \
  tools/build_release.sh \
  tools/create_macos_dmg.sh \
  tools/godot_gate.py \
  tools/release_version_contract.py \
  tools/release_version_mapping.py \
  tools/scan_release_secrets.py \
  tools/windows_installer.nsi \
  skills/codex/fantasydisk-release-director/scripts/build_update_manifest.py \
  skills/codex/fantasydisk-release-director/scripts/local_release.py; do
  if [[ ! -f "${WORKTREE_DIR}/${required_input}" ]]; then
    echo "    ERROR: ${SOURCE_LABEL} не содержит build input ${required_input}"
    exit 2
  fi
done
if ! cmp -s "${REPO_DIR}/tools/build_release.sh" "${WORKTREE_DIR}/tools/build_release.sh"; then
  echo "    ERROR: запущенный build_release.sh отличается от ${SOURCE_LABEL}"
  exit 2
fi
MACOS_ARROW_SOURCE="${WORKTREE_DIR}/${MACOS_ARROW_REL}"

if [[ "${CANDIDATE_MODE}" -eq 1 ]]; then
  CANDIDATE_PROVENANCE_PATH="${WORKTREE_DIR}/build/CANDIDATE_PROVENANCE.json"
  mkdir -p "$(dirname "${CANDIDATE_PROVENANCE_PATH}")"
  python3 - "${CANDIDATE_PROVENANCE_PATH}" "${CANDIDATE_REPOSITORY}" \
    "${CANDIDATE_REF}" "${CANDIDATE_SHA}" "${SOURCE_TREE}" <<'PY'
import json
import pathlib
import sys

path, repository, ref, commit, tree = sys.argv[1:]
pathlib.Path(path).write_text(
    json.dumps(
        {"repository": repository, "ref": ref, "commit": commit, "tree": tree},
        ensure_ascii=False,
        indent=2,
        sort_keys=True,
    ) + "\n",
    encoding="utf-8",
)
PY
fi

echo "==> Проверка версии ${SOURCE_LABEL} и export presets"
if ! VERSION_MAPPING="$(python3 "${WORKTREE_DIR}/tools/release_version_mapping.py" \
  --version "${VERSION}" \
  --project "${WORKTREE_DIR}/project.godot" \
  --export-presets "${WORKTREE_DIR}/export_presets.cfg")"; then
  echo "    ERROR: version assignments в project.godot/export_presets.cfg не точны, конфликтуют или находятся не в своём preset"
  exit 2
fi
IFS=$'\t' read -r MACOS_SHORT_VERSION MACOS_BUILD_VERSION WINDOWS_PRODUCT_VERSION WINDOWS_FILE_VERSION <<< "${VERSION_MAPPING}"

echo "==> Проверка честной маркировки macOS-канала в клиенте ${SOURCE_LABEL}"
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

if [[ "${PRESIGN_MODE}" -eq 1 ]]; then
  # Pre-sign отчитывается только о том, что действительно делает.
  EXPORT_LABEL="Экспорт macOS (.app в zip; подпись не выполняется)"
  MATERIALIZE_LABEL="Материализация .app из экспорта без подписи"
else
  EXPORT_LABEL="Экспорт macOS (.app в zip; подпись будет последним изменением bundle)"
  MATERIALIZE_LABEL="Финализация и подпись готового .app"
fi
echo "==> ${EXPORT_LABEL}"
run_godot --headless --path "${WORKTREE_DIR}" \
  --export-release "macOS" "${WORKTREE_DIR}/build/FantasyDisk-${VERSION}-macos.zip"

echo "==> ${MATERIALIZE_LABEL}"
MAC_STAGE="${WORKTREE_DIR}/build/macos-stage"
mkdir -p "${MAC_STAGE}"
ditto -x -k "${WORKTREE_DIR}/build/FantasyDisk-${VERSION}-macos.zip" "${MAC_STAGE}"
APP_PATH="$(find "${MAC_STAGE}" -maxdepth 2 -type d -name '*.app' -print -quit)"
if [[ -z "${APP_PATH}" ]]; then
  echo "    ERROR: macOS export не содержит .app"
  exit 2
fi

if [[ "${PRESIGN_MODE}" -eq 1 ]]; then
  echo "==> PRE-SIGN CHECKPOINT: ${SOURCE_LABEL} прошёл version mapping, честную метку канала, headless import и macOS export/материализацию $(basename "${APP_PATH}")"
  echo "    QA-only режим: packaging, подпись, notarization, tag, GitHub Release и публикация не выполняются; publishable artifact не создан"
  rm -rf "${WORKTREE_DIR}/build"
  echo "    disposable output удалён"
  exit 0
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
  echo "    Канал unsigned (FAN-1121): ставим только ad-hoc seal без Apple identity"
  # Godot export templates can carry an embedded vendor signature.  Adding the
  # DMG background invalidates its resource seal, which Tahoe treats as a
  # damaged app instead of a normal unsigned app.  Replace it with a local
  # ad-hoc seal: it verifies bundle integrity but does not identify a publisher
  # or change the manual Gatekeeper/Open Anyway requirement.
  codesign --force --sign - "${APP_PATH}"
  codesign --verify --deep --strict --verbose=4 "${APP_PATH}"
  APP_SIGNATURE_DETAILS="$(codesign -dv --verbose=4 "${APP_PATH}" 2>&1)"
  if ! grep -Fqx "Signature=adhoc" <<< "${APP_SIGNATURE_DETAILS}"; then
    echo "    ERROR: unsigned app was not sealed with an ad-hoc signature"
    exit 2
  fi
  echo "    Developer ID и Apple notarization не выполняются; Gatekeeper потребует ручного «Всё равно открыть»"
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
else
  codesign --verify --deep --strict --verbose=4 "${MOUNTED_APP}"
  MOUNTED_SIGNATURE_DETAILS="$(codesign -dv --verbose=4 "${MOUNTED_APP}" 2>&1)"
  if ! grep -Fqx "Signature=adhoc" <<< "${MOUNTED_SIGNATURE_DETAILS}"; then
    echo "    ERROR: mounted unsigned app lost its ad-hoc integrity seal"
    exit 2
  fi
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
if [[ "${CANDIDATE_MODE}" -eq 1 ]]; then
  cp "${CANDIDATE_PROVENANCE_PATH}" "${RELEASE_DIR}/CANDIDATE_PROVENANCE.json"
fi

echo "==> SHA256SUMS.txt (контроль порчи при передаче файлов)"
(cd "${RELEASE_DIR}" && shasum -a 256 FantasyDisk-* > SHA256SUMS.txt && cat SHA256SUMS.txt)

echo "==> Публичный update-manifest.json для клиента 0.2.2+"
python3 "${WORKTREE_DIR}/skills/codex/fantasydisk-release-director/scripts/build_update_manifest.py" \
  --version "${VERSION}" \
  --minimum-supported-version "0.2.2" \
  --release-dir "${RELEASE_DIR}"

echo "==> Постоянная локальная копия, Godot snapshot и установка macOS"
LOCAL_RELEASE_ARGS=(
  materialize
  --version "${VERSION}"
  --repo-root "${REPO_DIR}"
  --release-dir "${RELEASE_DIR}"
  --macos-channel "${MACOS_CHANNEL}"
)
if [[ "${CANDIDATE_MODE}" -eq 1 ]]; then
  LOCAL_RELEASE_ARGS+=(
    --candidate-repository "${CANDIDATE_REPOSITORY}"
    --candidate-ref "${CANDIDATE_REF}"
    --candidate-sha "${CANDIDATE_SHA}"
    --candidate-tree "${SOURCE_TREE}"
  )
fi
python3 "${WORKTREE_DIR}/skills/codex/fantasydisk-release-director/scripts/local_release.py" \
  "${LOCAL_RELEASE_ARGS[@]}"

echo "==> Готово:"
ls -lh "${RELEASE_DIR}"
