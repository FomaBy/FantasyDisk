from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / ".github" / "workflows" / "quality.yml"
CI_REQUIREMENTS = ROOT / "requirements-ci.txt"


class QualityWorkflowContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.source = WORKFLOW.read_text(encoding="utf-8")

    def test_all_candidate_event_types_are_covered(self) -> None:
        self.assertIn("push:", self.source)
        self.assertIn("pull_request:", self.source)
        self.assertIn("merge_group:", self.source)
        self.assertIn("github.event.merge_group.base_sha", self.source)

    def test_checkout_is_asserted_to_be_exact_github_sha(self) -> None:
        self.assertIn('test "$(git rev-parse HEAD)" = "$GITHUB_SHA"', self.source)
        self.assertIn("quality_gate_candidate_sha.txt", self.source)

    def test_machine_readable_evidence_is_hashed_and_uploaded(self) -> None:
        self.assertIn("build/quality_gate_report.json", self.source)
        self.assertIn("build/quality_gate_report.sha256", self.source)
        self.assertIn(
            "sha256sum quality_gate_report.json > quality_gate_report.sha256",
            self.source,
        )
        self.assertIn("sha256sum -c quality_gate_report.sha256", self.source)
        self.assertNotIn(
            "sha256sum build/quality_gate_report.json >", self.source
        )
        self.assertIn("actions/upload-artifact@v7", self.source)
        self.assertIn("quality-${{ github.event_name }}-${{ github.sha }}", self.source)
        self.assertIn("if-no-files-found: error", self.source)

    def test_job_has_bounded_runtime(self) -> None:
        self.assertIn("timeout-minutes: 30", self.source)

    def test_ci_dependencies_are_installed_before_quality_gate(self) -> None:
        self.assertEqual(CI_REQUIREMENTS.read_text(encoding="utf-8").splitlines(), [
            "# Python packages required by the repository's deterministic CI/static gates.",
            "Pillow==11.3.0",
        ])
        install = "python -m pip install --requirement requirements-ci.txt"
        self.assertIn(install, self.source)
        self.assertLess(self.source.index(install), self.source.index("tools/quality_gate.py"))

    def test_candidate_events_execute_godot_suites(self) -> None:
        # `--static-only` selects zero Godot tests by contract, so a gate that
        # ran it on every trigger certified the whole game as green without
        # executing one game test.  Candidate events run the changed profile.
        for base in (
            "${{ github.event.pull_request.base.sha }}",
            "${{ github.event.merge_group.base_sha }}",
        ):
            self.assertIn(
                f'python3 tools/quality_gate.py --profile changed --changed-ref "{base}"',
                self.source,
            )
            self.assertNotIn(
                f'python3 tools/quality_gate.py --static-only --changed-ref "{base}"',
                self.source,
            )

    def test_push_keeps_the_cheaper_static_profile(self) -> None:
        # Push to dev revalidates an already-gated candidate, so it stays on the
        # static profile and skips the engine entirely.
        self.assertIn(
            'python3 tools/quality_gate.py --static-only'
            ' --changed-ref "${{ github.event.before }}"',
            self.source,
        )
        self.assertIn("if: github.event_name != 'push'", self.source)

    def test_godot_toolchain_is_pinned_verified_and_cached(self) -> None:
        self.assertIn('GODOT_BUILD_ID: "4.7.stable.official.5b4e0cb0f"', self.source)
        self.assertIn("uses: actions/cache@v6", self.source)
        self.assertIn(
            "key: fsd-godot-${{ runner.os }}-${{ runner.arch }}-${{ env.GODOT_BUILD_ID }}",
            self.source,
        )
        # An unpinned or tampered download would silently certify on a different
        # engine than the one the release is verified with.
        self.assertIn('printf \'%s  %s\\n\' "$GODOT_ZIP_SHA512" "$archive" | sha512sum -c -', self.source)
        self.assertIn(
            'test "$("$GODOT_DIR/godot" --version | tail -n 1)" = "$GODOT_BUILD_ID"',
            self.source,
        )

    def test_candidate_evidence_must_show_executed_godot_suites(self) -> None:
        # The gate exits non-zero on a red suite, so the only way the old bug
        # can come back is a green run whose evidence lists no Godot test.
        self.assertIn("Assert the candidate executed Godot suites", self.source)
        self.assertIn(
            "json.load(open('build/quality_gate_report.json'))['godot_tests']",
            self.source,
        )
        self.assertIn('test "$executed" -gt 0', self.source)

    def test_godot_is_launched_only_through_the_semaphore_gate(self) -> None:
        # Launch logic belongs to tools/godot_gate.py; a second copy in YAML
        # would drift from the isolation and import-cache contract.
        self.assertNotIn("--script", self.source)
        self.assertNotIn("$GODOT_DIR/godot --headless", self.source)

    def test_required_check_job_id_is_stable(self) -> None:
        # Branch protection binds to the job id: renaming it detaches the
        # required gate without any visible failure.
        self.assertIn("\n  static-quality:\n", self.source)


if __name__ == "__main__":
    unittest.main()
