#!/bin/bash
# FAN-3980 signed exact-tag 0.3.1 build launcher (same shape as FAN-3963/FAN-3976).
# The Developer ID identity is resolved locally from the owner-selected certificate
# and never printed or stored.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${ROOT}/build/FAN-3980"
CERT="/Users/sergeyfomin/Certificates/developerID_application.cer"
FP="$(openssl x509 -inform DER -in "${CERT}" -noout -fingerprint -sha1 | sed 's/.*=//; s/://g')"
if [[ ${#FP} -ne 40 ]]; then echo "cert fingerprint unresolved"; exit 2; fi
if ! security find-identity -v -p codesigning | grep -F "${FP}" | grep -q "Developer ID Application"; then
  echo "selected certificate is not an installed Developer ID Application identity"; exit 2
fi
# The Multica cow_checkout post-checkout hook (core.hooksPath in the shared bare
# repository) rejects worktrees outside the workspace allowlist and would abort
# build_release.sh at its /tmp worktree step (FAN-3963 attempt 1). Override the
# hooks path only inside this build process; the shared config stays unchanged.
mkdir -p "${OUT}/no-hooks"
export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath GIT_CONFIG_VALUE_0="${OUT}/no-hooks"
export FANTASYDISK_MACOS_CHANNEL=signed
export MACOS_NOTARY_PROFILE=FantasyDiskRelease
export MACOS_SIGN_IDENTITY="${FP}"
xcrun notarytool history --keychain-profile "${MACOS_NOTARY_PROFILE}" --output-format json --no-progress >/dev/null 2>&1
HIST=$?
echo "pre-build notarytool history exit=${HIST}" | tee "${OUT}/prebuild_notary_history_exit.txt"
if [[ ${HIST} -ne 0 ]]; then echo "BLOCKER: notary profile not authenticated"; exit 2; fi
echo "build_started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "${OUT}/build_timing.txt"
cd "${ROOT}"
tools/build_release.sh 0.3.1 > "${OUT}/build_release.raw.log" 2>&1
RC=$?
echo "build_finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "${OUT}/build_timing.txt"
echo "build_exit=${RC}" | tee -a "${OUT}/build_timing.txt"
exit ${RC}
