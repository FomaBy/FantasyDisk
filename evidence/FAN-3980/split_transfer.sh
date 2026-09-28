#!/usr/bin/env bash
# FAN-3980 same-run transfer prep for FAN-3964: split the exact retained Windows
# Setup into 50,000,000-byte parts (split -b 50000000 -a 2, part-aa...), write
# PARTS.sha256, copy SHA256SUMS.txt and update-manifest.json, and prove the
# byte-exact rejoin hash equals the retained installer.
set -euo pipefail
RETAINED="$1"; OUT="$2"; VERSION="0.3.1"
SETUP="FantasyDisk-${VERSION}-windows-setup.exe"
rm -rf "$OUT"; mkdir -p "$OUT"
cd "$OUT"
split -b 50000000 -a 2 "$RETAINED/$SETUP" "$SETUP.part-"
shasum -a 256 "$SETUP".part-* > PARTS.sha256
cp "$RETAINED/SHA256SUMS.txt" "$RETAINED/update-manifest.json" .
cat "$SETUP".part-* > rejoin.tmp
REJOIN="$(shasum -a 256 rejoin.tmp | cut -d' ' -f1)"
ORIG="$(shasum -a 256 "$RETAINED/$SETUP" | cut -d' ' -f1)"
LISTED="$(grep " $SETUP\$" SHA256SUMS.txt | cut -d' ' -f1)"
rm -f rejoin.tmp
{
  echo "setup=$SETUP bytes=$(stat -f %z "$RETAINED/$SETUP")"
  echo "setup_sha256_retained=$ORIG"
  echo "setup_sha256_in_SHA256SUMS=$LISTED"
  echo "rejoin_sha256=$REJOIN"
  echo "rejoin_equal=$([ "$REJOIN" = "$ORIG" ] && [ "$ORIG" = "$LISTED" ] && echo true || echo false)"
  echo "parts=$(ls "$SETUP".part-* | wc -l | tr -d ' ')"
  ls -l "$SETUP".part-* | awk '{print $5, $9}'
  echo "PARTS.sha256 bytes=$(stat -f %z PARTS.sha256) sha256=$(shasum -a 256 PARTS.sha256 | cut -d' ' -f1)"
  echo "SHA256SUMS.txt bytes=$(stat -f %z SHA256SUMS.txt) sha256=$(shasum -a 256 SHA256SUMS.txt | cut -d' ' -f1)"
  echo "update-manifest.json bytes=$(stat -f %z update-manifest.json) sha256=$(shasum -a 256 update-manifest.json | cut -d' ' -f1)"
} | tee transfer_record.txt
[ "$REJOIN" = "$ORIG" ] && [ "$ORIG" = "$LISTED" ]
