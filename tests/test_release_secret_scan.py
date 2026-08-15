from __future__ import annotations

import base64
import importlib.util
import tempfile
import unittest
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "scan_release_secrets_tested", ROOT / "tools" / "scan_release_secrets.py"
)
scanner = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(scanner)


class ReleaseSecretScanTests(unittest.TestCase):
    def setUp(self) -> None:
        self.webhook = (
            b"https://discord.com/api/webhooks/123456789012345678/"
            b"abcdefghijklmnopqrstuvwxyz_123456"
        )

    def test_rejects_raw_complete_base64_and_split_base64(self) -> None:
        self.assertIn("raw-discord-webhook", scanner.finding_kinds(b"prefix" + self.webhook))
        encoded = base64.b64encode(self.webhook)
        self.assertIn("base64-discord-webhook", scanner.finding_kinds(encoded))
        # Widths 2 and 1 exceed the former MAX_JOINED_CHUNKS = 32 join window
        # (58 and 116 fragments), so they regress the bounded-join bypass.
        for width in (1, 2, 5):
            with self.subTest(width=width):
                chunks = [encoded[index:index + width] for index in range(0, len(encoded), width)]
                split = b'"' + b'","'.join(chunks) + b'"'
                self.assertIn("base64-discord-webhook", scanner.finding_kinds(split))

    def test_safe_public_relay_url_and_random_binary_pass(self) -> None:
        safe = b"https://feedback.fantasydisk.example/v1/session\x00" + bytes(range(256))
        self.assertEqual(scanner.finding_kinds(safe), set())

    def test_cli_reports_only_path_and_kind_not_secret(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            artifact = Path(tmp) / "FantasyDisk.exe"
            artifact.write_bytes(b"header" + self.webhook + b"tail")
            with _captured_streams() as captured:
                code = scanner.main([str(artifact)])
            self.assertEqual(code, 1)
            output = captured.stderr.getvalue()
            self.assertIn(str(artifact), output)
            self.assertIn("raw-discord-webhook", output)
            self.assertNotIn(self.webhook.decode("ascii"), output)

    def test_scans_compressed_zip_entries_not_only_container_bytes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            archive_path = Path(tmp) / "FantasyDisk.zip"
            with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
                archive.writestr("FantasyDisk.app/Contents/Resources/game.pck", b"noise" + self.webhook)
            findings = scanner.scan_paths([archive_path])
            self.assertTrue(
                any(
                    "!FantasyDisk.app/Contents/Resources/game.pck" in path.as_posix()
                    for path, _kind in findings
                )
            )
            self.assertTrue(any(kind == "raw-discord-webhook" for _path, kind in findings))

    def _assert_release_pipeline_order(self, script: str) -> None:
        source_start = script.index('SOURCE_COMMIT=""\nSOURCE_TREE=""\nSOURCE_LABEL=""')
        source_end = script.index('WORKTREE_DIR="$(mktemp -d', source_start)
        source_selection = script[source_start:source_end]
        candidate_branch = source_selection.index('if [[ "${CANDIDATE_MODE}" -eq 1 ]]; then')
        tag_branch = source_selection.index(
            'else\n  if ! SOURCE_COMMIT="$(git -C "${REPO_DIR}" rev-parse "${TAG}^{commit}")"; then',
            candidate_branch,
        )
        candidate_label = 'SOURCE_LABEL="candidate ${CANDIDATE_SHA} from ${CANDIDATE_REF}"'
        tag_label = 'SOURCE_LABEL="tag ${TAG}"'
        self.assertEqual(source_selection[candidate_branch:tag_branch].count(candidate_label), 1)
        self.assertNotIn(tag_label, source_selection[candidate_branch:tag_branch])
        self.assertEqual(source_selection[tag_branch:].count(tag_label), 1)
        self.assertNotIn(candidate_label, source_selection[tag_branch:])

        markers = (
            ("signed credentials", 'if [[ -z "${MACOS_SIGN_IDENTITY}" ]]'),
            ("source worktree", 'echo "==> Worktree из ${SOURCE_LABEL}"'),
            ("clear xattr", 'xattr -cr "${APP_PATH}"'),
            ("Developer ID sign", 'codesign --force --deep --options runtime --timestamp'),
            ("verify app signature", 'codesign --verify --deep --strict --verbose=4 "${APP_PATH}"'),
            ("notarize app", 'submit_notary_artifact "${APP_NOTARY_ZIP}"'),
            ("staple app", 'xcrun stapler staple "${APP_PATH}"'),
            ("build DMG", 'bash "${WORKTREE_DIR}/tools/create_macos_dmg.sh"'),
            ("notarize DMG", 'submit_notary_artifact "${MAC_DMG}"'),
            ("staple DMG", 'xcrun stapler staple "${MAC_DMG}"'),
            ("staged secret scan", 'echo "==> Secret scan staged player payloads до публикации"'),
            ("publish", 'echo "==> Публикация проверенных staged artifacts"'),
        )
        positions = {}
        for name, marker in markers:
            self.assertIn(marker, script, name)
            positions[name] = script.index(marker)
        for before, after in zip(markers, markers[1:]):
            self.assertLess(positions[before[0]], positions[after[0]])

        adhoc_sign_at = script.index('codesign --force --sign - "${APP_PATH}"')
        self.assertLess(positions["clear xattr"], adhoc_sign_at)
        self.assertLess(adhoc_sign_at, positions["build DMG"])

    def test_worktree_source_checkpoint_is_required_for_order_oracle(self) -> None:
        script = (ROOT / "tools" / "build_release.sh").read_text(encoding="utf-8")
        checkpoint = 'echo "==> Worktree из ${SOURCE_LABEL}"'

        deleted = script.replace(checkpoint + "\n", "", 1)
        with self.assertRaises(AssertionError):
            self._assert_release_pipeline_order(deleted)

        moved = script.replace(checkpoint + "\n", "", 1)
        moved = moved.replace(
            'xattr -cr "${APP_PATH}"\n',
            'xattr -cr "${APP_PATH}"\n' + checkpoint + "\n",
            1,
        )
        with self.assertRaises(AssertionError):
            self._assert_release_pipeline_order(moved)

    def test_release_pipeline_scans_staging_before_publish(self) -> None:
        script = (ROOT / "tools" / "build_release.sh").read_text(encoding="utf-8")
        scan_at = script.index('echo "==> Secret scan staged player payloads до публикации"')
        publish_at = script.index('echo "==> Публикация проверенных staged artifacts"')
        self.assertLess(scan_at, publish_at)
        self.assertIn('MAC_DMG="${WORKTREE_DIR}/build/FantasyDisk-${VERSION}-macos.dmg"', script)
        self.assertIn('hdiutil attach "${MAC_DMG}"', script)
        self.assertIn('"${DMG_MOUNT_DIR}"', script[scan_at:publish_at])
        self.assertNotIn('"${RELEASE_DIR}/FantasyDisk-', script[:publish_at])

    def test_release_pipeline_notarizes_final_app_before_dmg_and_publishes_installer_only(self) -> None:
        script = (ROOT / "tools" / "build_release.sh").read_text(encoding="utf-8")
        self._assert_release_pipeline_order(script)
        self.assertIn('Signature=adhoc', script)
        self.assertNotIn('Notarization пропущена', script)
        self.assertIn('spctl --assess --type execute', script)
        self.assertIn('spctl --assess --type open --context context:primary-signature', script)

        publish_at = script.index('echo "==> Публикация проверенных staged artifacts"')
        dmg_staple_at = script.index('xcrun stapler staple "${MAC_DMG}"')
        self.assertLess(dmg_staple_at, publish_at)
        published = script[publish_at:]
        self.assertIn(
            'cp "${WORKTREE_DIR}/build/FantasyDisk-${VERSION}-windows-setup.exe"',
            published,
        )
        self.assertNotIn('cp "${WORKTREE_DIR}/build/FantasyDisk-Windows.exe"', published)
        self.assertNotIn('cp "${WORKTREE_DIR}/build/FantasyDisk-${VERSION}-windows.zip"', published)

    def test_macos_dmg_root_is_minimal_and_has_no_internal_background_folder(self) -> None:
        script = (ROOT / "tools" / "create_macos_dmg.sh").read_text(encoding="utf-8")
        self.assertNotIn('STAGING_DIR}/.background', script)
        self.assertNotIn('file ".background:', script)
        self.assertIn('FantasyDiskDmgBackground.png', script)
        self.assertIn('! -name "${APP_NAME}" ! -name "Applications" ! -name ".DS_Store"', script)
        self.assertIn('"${RW_MOUNT_DIR}/.fseventsd"', script)
        self.assertIn('final DMG exposes unexpected root items', script)
        self.assertIn('set icon size of viewOptions to 128', script)
        self.assertIn('set text size of viewOptions to 14', script)


class _captured_streams:
    def __enter__(self):
        import io
        import sys

        self.stdout = io.StringIO()
        self.stderr = io.StringIO()
        self._old = (sys.stdout, sys.stderr)
        sys.stdout, sys.stderr = self.stdout, self.stderr
        return self

    def __exit__(self, _type, _value, _traceback):
        import sys

        sys.stdout, sys.stderr = self._old


if __name__ == "__main__":
    unittest.main()
