"""Regression coverage for the deterministic A5 raw JSON gzip wrapper."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("a5_gzip_artifact", ROOT / "tools" / "a5_gzip_artifact.py")
assert SPEC is not None and SPEC.loader is not None
ARTIFACT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ARTIFACT)


class A5GzipArtifactTest(unittest.TestCase):
    def test_reproducible_round_trip_and_fixed_header(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            source = directory / "raw.json"
            first = directory / "first.json.gz"
            second = directory / "second.json.gz"
            decoded = directory / "decoded.json"
            source.write_bytes(b'{"schema":"fan1438.a5-balance.v2","rows":[1,2,3]}\n')
            ARTIFACT.pack(source, first)
            ARTIFACT.pack(source, second)
            self.assertEqual(first.read_bytes(), second.read_bytes())
            self.assertTrue(first.read_bytes().startswith(ARTIFACT.GZIP_HEADER))
            ARTIFACT.unpack(first, decoded)
            self.assertEqual(decoded.read_bytes(), source.read_bytes())

    def test_corruption_and_size_limit_fail_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            source = directory / "raw.json"
            compressed = directory / "raw.json.gz"
            corrupt = directory / "corrupt.json.gz"
            source.write_bytes(b"telemetry\n" * 4096)
            ARTIFACT.pack(source, compressed)
            corrupted = bytearray(compressed.read_bytes())
            corrupted[-1] ^= 0x01
            corrupt.write_bytes(corrupted)
            with self.assertRaises((OSError, ValueError, EOFError)):
                ARTIFACT.unpack(corrupt, directory / "decoded.json")
            with self.assertRaises(ValueError):
                ARTIFACT.pack(source, directory / "too-small.json.gz", maximum=1)


if __name__ == "__main__":
    unittest.main()
