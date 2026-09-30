#!/bin/bash
# FAN-3989: exact invocation of the maintained release build for 0.3.1.1 from
# the immutable tag v0.3.1.1 (signed channel). Run from the repository root on
# the macOS signing host. The Developer ID identity is resolved locally from
# the keychain and never written to evidence; the only environment change is
# to bypass the Multica workdir-lifecycle post-checkout hook for the build's
# own detached /tmp worktree (FAN-3963/3976/3980/3983 precedent) — the hook
# is a daemon worktree optimisation, not a build input.
set -euo pipefail
VERSION="${1:-0.3.1.1}"
RAW_LOG="${2:?raw log path}"
IDENTITY="$(security find-identity -v -p codesigning | sed -n 's/^ *[0-9]*) [0-9A-F]* "\(Developer ID Application: [^"]*\)"$/\1/p' | head -1)"
if [[ -z "${IDENTITY}" ]]; then
  echo "ERROR: no Developer ID Application identity in the keychain" >&2
  exit 2
fi
xcrun notarytool history --keychain-profile FantasyDiskRelease --output-format json >/dev/null
echo "notarytool history: exit 0 ($(date -u +%Y-%m-%dT%H:%M:%SZ))"
echo "build start $(date -u +%Y-%m-%dT%H:%M:%SZ)"
env \
  FANTASYDISK_MACOS_CHANNEL=signed \
  MACOS_NOTARY_PROFILE=FantasyDiskRelease \
  MACOS_SIGN_IDENTITY="${IDENTITY}" \
  GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath GIT_CONFIG_VALUE_0=/dev/null \
  tools/build_release.sh "${VERSION}" 2>&1 | tee "${RAW_LOG}"
STATUS="${PIPESTATUS[0]}"
echo "build end $(date -u +%Y-%m-%dT%H:%M:%SZ) exit ${STATUS}"
exit "${STATUS}"
