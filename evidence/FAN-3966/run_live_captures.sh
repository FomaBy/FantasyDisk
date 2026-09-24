#!/usr/bin/env bash
# FAN-3966: windowed live certification captures of the six repaired scenes.
# Source pin: ref agent/fable/6de34bd5a1d4 sha ebaf22c113b7e91137eeb1066cc37d322eedab96 tree 7d4dd4fd6ecdbfc32cec8e7acc0fcfeb551e1ae5
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
export FSD_GODOT_EXCLUSIVE=1
export KNIGHT_CERT_SOURCE_REF=agent/fable/6de34bd5a1d4 KNIGHT_CERT_SOURCE_SHA=ebaf22c113b7e91137eeb1066cc37d322eedab96 KNIGHT_CERT_SOURCE_TREE=7d4dd4fd6ecdbfc32cec8e7acc0fcfeb551e1ae5
export KNIGHT_CERT_FRAME_DIR=$ROOT/evidence/FAN-3966/captures/knight/frames
export ELEMENTALIST_CERT_SOURCE_REF=agent/fable/6de34bd5a1d4 ELEMENTALIST_CERT_SOURCE_SHA=ebaf22c113b7e91137eeb1066cc37d322eedab96 ELEMENTALIST_CERT_SOURCE_TREE=7d4dd4fd6ecdbfc32cec8e7acc0fcfeb551e1ae5
export ELEMENTALIST_CERT_FRAME_DIR=$ROOT/evidence/FAN-3966/captures/elementalist/frames
echo "knight capture start $(date -u +%FT%TZ)"
python3 tools/godot_gate.py --path . --windowed --fixed-fps 60 --script res://tests/ultimates/presentation/knight_certification_live_capture.gd
echo "knight capture exit=$? $(date -u +%FT%TZ)"
echo "elementalist capture start $(date -u +%FT%TZ)"
python3 tools/godot_gate.py --path . --windowed --fixed-fps 60 --script res://tests/ultimates/presentation/elementalist_certification_live_capture.gd
echo "elementalist capture exit=$? $(date -u +%FT%TZ)"
echo "ALL_CAPTURES_DONE"
