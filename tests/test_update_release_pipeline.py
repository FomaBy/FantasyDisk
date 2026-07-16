from __future__ import annotations

import hashlib
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "skills" / "codex" / "fantasydisk-release-director" / "scripts"


def _load(name: str):
    script = SCRIPTS / f"{name}.py"
    spec = importlib.util.spec_from_file_location(f"fan1112_{name}", script)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


build_update_manifest = _load("build_update_manifest")
github_release_publish = _load("github_release_publish")
github_release_verify = _load("github_release_verify")
local_release = _load("local_release")
telegram_publish = _load("telegram_publish")

VERSION_CONTRACT = json.loads(
    (ROOT / "tests" / "release_version_contract.json").read_text(encoding="utf-8")
)
SUPPORTED_RELEASE_VERSIONS = tuple(VERSION_CONTRACT["valid"])
INVALID_RELEASE_VERSIONS = tuple(VERSION_CONTRACT["invalid"])


class UpdateReleasePipelineTests(unittest.TestCase):
    def test_manifest_matches_both_installers_and_public_urls(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            release = Path(temporary)
            mac = release / "FantasyDisk-0.2.4-macos.dmg"
            windows = release / "FantasyDisk-0.2.4-windows-setup.exe"
            mac.write_bytes(b"signed dmg")
            windows.write_bytes(b"nsis setup")
            manifest = build_update_manifest.build_manifest(
                version="0.2.4", release_dir=release
            )
            self.assertEqual(manifest["schema_version"], 1)
            self.assertEqual(manifest["minimum_supported_version"], "0.2.2")
            self.assertEqual(
                manifest["assets"]["macos"]["sha256"],
                hashlib.sha256(mac.read_bytes()).hexdigest(),
            )
            self.assertEqual(manifest["assets"]["windows"]["size"], windows.stat().st_size)
            self.assertEqual(
                manifest["release_url"],
                "https://github.com/FomaBy/FantasyDisk-Releases/releases/tag/v0.2.4",
            )
            self.assertIn("/releases/download/v0.2.4/", manifest["assets"]["macos"]["url"])

    def test_manifest_supports_four_component_technical_hotfix(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            release = Path(temporary)
            version = "0.2.3.1"
            for name in (
                f"FantasyDisk-{version}-macos.dmg",
                f"FantasyDisk-{version}-windows-setup.exe",
            ):
                (release / name).write_bytes(name.encode("utf-8"))
            manifest = build_update_manifest.build_manifest(
                version=version,
                minimum_supported_version="0.2.3",
                release_dir=release,
            )
            self.assertEqual(manifest["version"], version)
            self.assertEqual(manifest["minimum_supported_version"], "0.2.3")
            self.assertIn("/releases/download/v0.2.3.1/", manifest["assets"]["windows"]["url"])

    def test_github_asset_order_publishes_manifest_last(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            release = Path(temporary)
            version = "0.2.4"
            names = [
                f"FantasyDisk-{version}-macos.dmg",
                f"FantasyDisk-{version}-windows-setup.exe",
                "SHA256SUMS.txt",
                f"CHANGELOG-{version}.md",
                "fantasydisk_023_announcement.png",
            ]
            for name in names:
                (release / name).write_bytes(b"fixture")
            (release / "update-manifest.json").write_text(
                json.dumps({"version": version}), encoding="utf-8"
            )
            files, _changelog = github_release_publish.release_files(release, version)
            self.assertEqual(files[-1].name, "update-manifest.json")
            self.assertEqual(len(files), 6)

    def test_telegram_delivery_is_allowed_for_current_stable_versions(self) -> None:
        telegram_publish.ensure_telegram_release_version("0.2.2")
        telegram_publish.ensure_telegram_release_version("0.2.4")
        telegram_publish.ensure_telegram_release_version("0.2.3.1")
        with self.assertRaisesRegex(SystemExit, "формат X.Y.Z"):
            telegram_publish.ensure_telegram_release_version("0.2.03")

    def test_public_distribution_publisher_allows_only_metadata_in_git_tree(self) -> None:
        self.assertEqual(
            github_release_publish.DEFAULT_REPOSITORY,
            "FomaBy/FantasyDisk-Releases",
        )
        self.assertEqual(github_release_publish.safe_distribution_paths(["README.md"]), [])
        self.assertEqual(
            github_release_publish.safe_distribution_paths(["README.md", "project.godot"]),
            ["project.godot"],
        )

    def test_public_distribution_verifier_rejects_source_or_secret_like_readme_content(self) -> None:
        self.assertEqual(github_release_verify.DEFAULT_REPOSITORY, "FomaBy/FantasyDisk-Releases")
        self.assertEqual(github_release_verify.EXPECTED_ROOT_PATHS, {"README.md"})
        self.assertIn("project.godot", github_release_verify.README_FORBIDDEN_MARKERS)
        self.assertIn("authorization:", github_release_verify.README_FORBIDDEN_MARKERS)

    def test_rejects_non_strict_release_version(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            for version in INVALID_RELEASE_VERSIONS:
                with self.subTest(version=version), self.assertRaises(
                    build_update_manifest.ManifestError
                ):
                    build_update_manifest.build_manifest(
                        version=version, release_dir=Path(temporary)
                    )

    def test_rejects_minimum_newer_than_release(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaises(build_update_manifest.ManifestError):
                build_update_manifest.build_manifest(
                    version="0.2.2",
                    minimum_supported_version="0.2.3",
                    release_dir=Path(temporary),
                )

    def test_all_publication_gates_accept_both_supported_version_shapes(self) -> None:
        gates = (
            build_update_manifest,
            github_release_publish,
            github_release_verify,
            local_release,
            telegram_publish,
        )
        for version in SUPPORTED_RELEASE_VERSIONS:
            for gate in gates:
                with self.subTest(version=version, gate=gate.__name__):
                    self.assertTrue(gate.RELEASE_VERSION_RE.fullmatch(version))
        for invalid in INVALID_RELEASE_VERSIONS:
            for gate in gates:
                with self.subTest(version=invalid, gate=gate.__name__):
                    self.assertIsNone(gate.RELEASE_VERSION_RE.fullmatch(invalid))

    def test_publisher_refuses_existing_immutable_tag(self) -> None:
        existing = subprocess.CompletedProcess(
            ["gh", "release", "view"], 0, stdout='{"url":"https://example.invalid"}', stderr=""
        )
        with mock.patch.object(github_release_publish.shutil, "which", return_value="gh"), \
             mock.patch.object(github_release_publish, "assert_safe_public_distribution_repository", return_value="main"), \
             mock.patch.object(github_release_publish, "run", return_value=existing):
            with self.assertRaisesRegex(RuntimeError, "never overwrite"):
                github_release_publish.publish(
                    "FomaBy/FantasyDisk-Releases", "0.2.3.1", [], Path("CHANGELOG.md")
                )

    def test_public_verifier_cannot_prune_immutable_releases(self) -> None:
        source = (SCRIPTS / "github_release_verify.py").read_text(encoding="utf-8")
        self.assertNotIn("--prune-previous", source)
        self.assertNotIn('"gh", "release", "delete"', source)


class UnsignedChannelLabelingTests(unittest.TestCase):
    """FAN-1121: the unsigned macOS channel must be labeled truthfully everywhere."""

    # Every canonical release document a release agent may follow. FAN-1123
    # extended coverage beyond game_updates.md after current_game_state.md and
    # release_versioning.md kept mandating signed-only delivery.
    ACTIVE_RELEASE_DOCS = (
        Path("docs") / "process" / "game_updates.md",
        Path("docs") / "design" / "current_game_state.md",
        Path("docs") / "process" / "release_versioning.md",
    )

    def test_client_labels_unsigned_macos_channel_truthfully(self) -> None:
        manager = (ROOT / "scripts" / "update_manager.gd").read_text(encoding="utf-8")
        self.assertIn('const MACOS_UPDATE_CHANNEL := "unsigned"', manager)
        self.assertIn("без подписи Apple Developer ID", manager)
        self.assertIn("Конфиденциальность и безопасность", manager)
        self.assertIn("«Всё равно открыть» (Open Anyway)", manager)
        self.assertNotIn("подписанный установщик", manager)

        dialog = (ROOT / "scripts" / "ui" / "update_dialog.gd").read_text(encoding="utf-8")
        self.assertIn("MACOS_UNSIGNED_NOTICE", dialog)
        self.assertIn("macos_update_is_unsigned", dialog)

    def test_release_docs_do_not_claim_apple_trust_for_unsigned_channel(self) -> None:
        docs = (ROOT / "docs" / "process" / "game_updates.md").read_text(encoding="utf-8")
        self.assertNotIn("signed/notarized", docs)
        self.assertIn("FANTASYDISK_MACOS_CHANNEL=unsigned", docs)
        self.assertIn("Всё равно открыть", docs)
        skill = (
            ROOT / "skills" / "codex" / "fantasydisk-release-director" / "SKILL.md"
        ).read_text(encoding="utf-8")
        self.assertIn("FANTASYDISK_MACOS_CHANNEL", skill)
        self.assertIn("unsigned", skill)

    def test_every_active_release_doc_describes_both_channels(self) -> None:
        # FAN-1123: all canonical release documents must present the explicit
        # signed/unsigned channels and name unsigned as the current selection, so
        # a release agent cannot follow one document into a signed-only block.
        for relative in self.ACTIVE_RELEASE_DOCS:
            with self.subTest(doc=str(relative)):
                doc = (ROOT / relative).read_text(encoding="utf-8")
                self.assertIn("FANTASYDISK_MACOS_CHANNEL", doc)
                self.assertIn("unsigned", doc)
                self.assertIn("FAN-1121", doc)
                self.assertNotIn("signed/notarized", doc)

    def test_snapshot_and_versioning_docs_supersede_fan1094_signed_only(self) -> None:
        # FAN-1123 regression: these two documents previously mandated signed-only
        # macOS delivery and presented cancelled FAN-1094 as the current rule.
        state = (ROOT / "docs" / "design" / "current_game_state.md").read_text(
            encoding="utf-8"
        )
        self.assertNotIn("FAN-1094 делает macOS installer fail-closed", state)
        self.assertIn("текущий выбранный канал", state)

        versioning = (ROOT / "docs" / "process" / "release_versioning.md").read_text(
            encoding="utf-8"
        )
        # codesign/notarytool/stapler/spctl must be scoped to the signed channel,
        # not asserted as a universal release blocker.
        self.assertNotIn(
            "отсутствие Developer ID/notary profile является release blocker",
            versioning,
        )
        self.assertIn("Канал `unsigned`", versioning)

    def test_build_script_cross_checks_client_channel_label(self) -> None:
        script = (ROOT / "tools" / "build_release.sh").read_text(encoding="utf-8")
        label_check_at = script.index("const MACOS_UPDATE_CHANNEL := ")
        export_at = script.index('--export-release "macOS"')
        self.assertLess(label_check_at, export_at)
        self.assertIn('CLIENT_MACOS_CHANNEL="$(sed -n', script)
        self.assertIn('if [[ "${CLIENT_MACOS_CHANNEL}" != "${MACOS_CHANNEL}" ]]', script)


class Published024ReleaseDocumentationTests(unittest.TestCase):
    """FAN-1226: operator docs must describe the already published 0.2.4 release."""

    def test_snapshot_marks_024_as_the_current_published_stable_release(self) -> None:
        state = (ROOT / "docs" / "design" / "current_game_state.md").read_text(
            encoding="utf-8"
        )
        self.assertIn("опубликован stable release 0.2.4", state)
        self.assertIn("Текущий опубликованный stable release: `0.2.4`", state)
        self.assertNotIn("release snapshot 0.2.3", state)
        self.assertNotIn("`0.2.4`, готовится из `dev`", state)
        self.assertNotIn("Игровой баланс и контент принятой версии 0.2.3 не меняются", state)

    def test_readme_requires_current_telethon_session_for_every_stable_release(self) -> None:
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        self.assertIn(
            "текущая локальная Telethon-сессия (секрет) для\n"
            "  обязательной Telegram-доставки файлов каждого stable release",
            readme,
        )
        self.assertNotIn("legacy Telethon-сессия только для релиза 0.2.2", readme)

    def test_canonical_release_docs_keep_the_public_github_and_telegram_contract(self) -> None:
        documents = ReleaseDocumentationConsistencyTests.read_documents()
        self.assertEqual(
            ReleaseDocumentationConsistencyTests.delivery_contract_errors(documents),
            [],
        )


class ReleaseDocumentationConsistencyTests(unittest.TestCase):
    """FAN-1235: release instructions must preserve the hotfix delivery contract."""

    SKILL = Path("skills") / "codex" / "fantasydisk-release-director" / "SKILL.md"
    RELEASE_VERSIONING = Path("docs") / "process" / "release_versioning.md"
    BRANCHING = Path("docs") / "process" / "versioning_and_branching.md"
    TELEGRAM_SETUP = Path("docs") / "release_telegram_setup.md"
    GAME_UPDATES = Path("docs") / "process" / "game_updates.md"
    CURRENT_STATE = Path("docs") / "design" / "current_game_state.md"

    # These are operational examples, not the SemVer/hotfix policy examples that
    # intentionally retain X.Y.Z and X.Y.Z.R terminology.
    OPERATIONAL_PLACEHOLDERS = {
        SKILL: (
            "## [<version>] — YYYY-MM-DD",
            "fantasydisk_<version>_announcement.png",
            "exact release commit as `v<version>`",
            "CHANGELOG-<version>.md",
            "<local_root>/releases/v<version>/",
        ),
        RELEASE_VERSIONING: (
            "тегом v<version>",
            "## [<version>] — дата",
            "releases/v<version>/CHANGELOG-<version>.md",
            "exact tag `v<version>`",
            "FantasyDisk-<version>-macos.dmg",
            "FantasyDisk-<version>-windows-setup.exe",
            "tools/build_release.sh <version>",
            "git worktree add --detach /tmp/... v<version>",
        ),
        TELEGRAM_SETUP: ("--version <version>",),
    }
    OPERATIONAL_XYZ_ONLY = {
        SKILL: (
            "## [X.Y.Z] — YYYY-MM-DD",
            "fantasydisk_XYZ_announcement.png",
            "exact release commit as `vX.Y.Z`",
            "CHANGELOG-X.Y.Z.md",
            "<local_root>/releases/vX.Y.Z/",
        ),
        RELEASE_VERSIONING: (
            "тегом vX.Y.Z",
            "## [X.Y.Z] — дата",
            "releases/vX.Y.Z/",
            "CHANGELOG-X.Y.Z.md",
            "exact tag `vX.Y.Z`",
            "FantasyDisk-X.Y.Z-macos.dmg",
            "FantasyDisk-X.Y.Z-windows-setup.exe",
            "tools/build_release.sh X.Y.Z",
            "git worktree add --detach /tmp/... vX.Y.Z",
        ),
        TELEGRAM_SETUP: ("--version X.Y.Z",),
    }
    DELIVERY_CONTRACTS = {
        GAME_UPDATES: (
            "канонический источник клиентских обновлений — отдельный публичный binary-only репозиторий [FomaBy/FantasyDisk-Releases]",
            "Telegram обязателен для каждого stable release: dry-run, затем отправка poster, DMG, Windows Setup и SHA256SUMS из verified durable path.",
            "После успешной Telegram delivery опубликовать Discord news с Telegram download link и ссылкой на public GitHub latest release.",
        ),
        RELEASE_VERSIONING: (
            "public binary-only repository `FomaBy/FantasyDisk-Releases`",
            "Каждый stable release обязательно отправляется в Telegram (poster, DMG, Windows Setup, SHA256SUMS), после чего Discord публикует Telegram download link и GitHub release URL.",
        ),
        TELEGRAM_SETUP: (
            "Telegram — обязательный канал файловой доставки, а public binary-only GitHub repository `FomaBy/FantasyDisk-Releases` — канонический источник updater manifest и latest downloads.",
            "Telegram получает release poster, macOS DMG, Windows Setup и `SHA256SUMS.txt`; затем Discord публикует player-facing новость с Telegram download link.",
        ),
    }

    @staticmethod
    def normalize(document: str) -> str:
        return " ".join(document.split())

    @classmethod
    def read_documents(cls) -> dict[Path, str]:
        paths = set(cls.OPERATIONAL_PLACEHOLDERS) | set(cls.DELIVERY_CONTRACTS) | {
            cls.BRANCHING,
            cls.CURRENT_STATE,
        }
        return {relative: (ROOT / relative).read_text(encoding="utf-8") for relative in paths}

    @classmethod
    def operational_version_errors(cls, documents: dict[Path, str]) -> list[str]:
        errors: list[str] = []
        for relative, placeholders in cls.OPERATIONAL_PLACEHOLDERS.items():
            document = documents[relative]
            for placeholder in placeholders:
                if placeholder not in document:
                    errors.append(f"{relative}: missing operational placeholder {placeholder}")
            for xyz_only in cls.OPERATIONAL_XYZ_ONLY[relative]:
                if xyz_only in document:
                    errors.append(f"{relative}: X.Y.Z-only operational example {xyz_only}")
        return errors

    @classmethod
    def delivery_contract_errors(cls, documents: dict[Path, str]) -> list[str]:
        errors: list[str] = []
        for relative, clauses in cls.DELIVERY_CONTRACTS.items():
            document = cls.normalize(documents[relative])
            for clause in clauses:
                if clause not in document:
                    errors.append(f"{relative}: missing delivery contract clause {clause}")
        return errors

    @classmethod
    def published_release_lifecycle_errors(cls, documents: dict[Path, str]) -> list[str]:
        errors: list[str] = []
        required = {
            cls.CURRENT_STATE: "Текущий опубликованный stable release: `0.2.4`",
            cls.RELEASE_VERSIONING: "его historical release freeze в рамках FAN-1128/FAN-1210 завершён.",
            cls.BRANCHING: "Release freeze FAN-1128/FAN-1210 завершён публикацией `0.2.4`; новые продуктовые изменения идут в следующую SemVer-версию.",
        }
        forbidden = {
            cls.BRANCHING: (
                "На время FAN-1128 действует release freeze:",
                "новые продуктовые изменения не входят в 0.2.3",
            ),
            cls.RELEASE_VERSIONING: ("`0.2.4` готовится из `dev`",),
        }
        for relative, clause in required.items():
            if clause not in cls.normalize(documents[relative]):
                errors.append(f"{relative}: missing published-release lifecycle clause {clause}")
        for relative, stale_clauses in forbidden.items():
            for clause in stale_clauses:
                if clause in cls.normalize(documents[relative]):
                    errors.append(f"{relative}: stale active/frozen release clause {clause}")
        return errors

    def test_operational_examples_support_both_release_version_shapes(self) -> None:
        documents = self.read_documents()
        self.assertEqual(self.operational_version_errors(documents), [])

        mutations = (
            (self.SKILL, "## [<version>] — YYYY-MM-DD", "## [X.Y.Z] — YYYY-MM-DD"),
            (self.RELEASE_VERSIONING, "releases/v<version>/", "releases/vX.Y.Z/"),
            (self.TELEGRAM_SETUP, "--version <version>", "--version X.Y.Z"),
        )
        for relative, expected, xyz_only in mutations:
            with self.subTest(document=str(relative), mutation=xyz_only):
                mutated = dict(documents)
                mutated[relative] = mutated[relative].replace(expected, xyz_only, 1)
                self.assertTrue(
                    any(xyz_only in error for error in self.operational_version_errors(mutated))
                )

    def test_delivery_contract_is_semantic_and_rejects_token_only_mutations(self) -> None:
        documents = self.read_documents()
        self.assertEqual(self.delivery_contract_errors(documents), [])

        mutations = (
            (self.GAME_UPDATES, "канонический источник клиентских обновлений", "дополнительный источник клиентских обновлений"),
            (self.RELEASE_VERSIONING, "Каждый stable release обязательно отправляется", "Каждый stable release может отправляться"),
            (self.TELEGRAM_SETUP, "обязательный канал файловой доставки", "дополнительный канал файловой доставки"),
        )
        for relative, expected, replacement in mutations:
            with self.subTest(document=str(relative), mutation=replacement):
                mutated = dict(documents)
                mutated[relative] = mutated[relative].replace(expected, replacement, 1)
                self.assertNotEqual(self.delivery_contract_errors(mutated), [])

    def test_published_024_cannot_be_described_as_an_active_frozen_release(self) -> None:
        documents = self.read_documents()
        self.assertEqual(self.published_release_lifecycle_errors(documents), [])

        stale = "На время FAN-1128 действует release freeze: новые продуктовые изменения не входят в 0.2.3."
        mutated = dict(documents)
        mutated[self.BRANCHING] = mutated[self.BRANCHING].replace(
            "Release freeze FAN-1128/FAN-1210 завершён публикацией `0.2.4`;\nновые продуктовые изменения идут в следующую SemVer-версию.",
            stale,
            1,
        )
        errors = self.published_release_lifecycle_errors(mutated)
        self.assertTrue(any("published-release lifecycle" in error for error in errors))
        self.assertTrue(any("stale active/frozen" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
