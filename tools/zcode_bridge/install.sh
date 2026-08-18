#!/usr/bin/env bash
# Installs (or checks) the certified ZCode bridge at /usr/local/bin/zcode.
# Never touches /usr/local/bin/zcode.real.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/zcode"
DEST="/usr/local/bin/zcode"
EXPECTED_SHA="3a52eaa994c8b0256c2956115843f97e0036a9a0f897f88e4c5a2642bf45ee07"

sha256_of() {
    shasum -a 256 "$1" | awk '{print $1}'
}

if [[ "$(sha256_of "$SRC")" != "$EXPECTED_SHA" ]]; then
    echo "install.sh: repository copy of zcode does not match the certified sha256; refusing to install" >&2
    echo "  expected: $EXPECTED_SHA" >&2
    echo "  actual:   $(sha256_of "$SRC")" >&2
    exit 1
fi

if [[ "${1:-}" == "--check" ]]; then
    if [[ ! -f "$DEST" ]]; then
        echo "zcode --check: $DEST is missing" >&2
        echo "  expected: $EXPECTED_SHA" >&2
        echo "  actual:   (no file)" >&2
        exit 1
    fi
    ACTUAL_SHA="$(sha256_of "$DEST")"
    if [[ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]]; then
        echo "zcode --check: $DEST does not match the certified bridge" >&2
        echo "  expected: $EXPECTED_SHA" >&2
        echo "  actual:   $ACTUAL_SHA" >&2
        exit 1
    fi
    echo "zcode --check: OK, sha256 $ACTUAL_SHA"
    exit 0
fi

if [[ -f "$DEST" ]] && [[ "$(sha256_of "$DEST")" == "$EXPECTED_SHA" ]]; then
    echo "zcode: already up to date, sha256 $EXPECTED_SHA, nothing to do"
    exit 0
fi

cp "$SRC" "$DEST"
chmod +x "$DEST"
echo "zcode: installed, sha256 $(sha256_of "$DEST")"
