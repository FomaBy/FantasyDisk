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
        start = cls.source.index("\n  static-quality:\n")
        end = cls.source.index("\n  dev-runtime-health-static:\n", start)
        cls.candidate_job = cls.source[start:end]

    def test_all_candidate_event_types_are_covered(self) -> None:
        self.assertIn("push:", self.source)
        self.assertIn("pull_request:", self.source)
        self.assertIn("merge_group:", self.source)
        self.assertIn("github.event.merge_group.base_sha", self.source)

    def test_checkout_is_asserted_to_be_exact_github_sha(self) -> None:
        self.assertIn('test "$(git rev-parse HEAD)" = "$GITHUB_SHA"', self.source)
        self.assertIn("quality_gate_candidate_sha.txt", self.source)

    def test_candidate_checkout_is_sparse_and_event_specific(self) -> None:
        checkout_end = self.candidate_job.index("- uses: actions/setup-python@v6")
        checkout = self.candidate_job[:checkout_end]

        self.assertEqual(checkout.count("uses: actions/checkout@v6"), 1)
        self.assertIn(
            "fetch-depth: ${{ github.event_name != 'push' && 2 || 0 }}",
            checkout,
        )
        self.assertIn("lfs: false", checkout)
        self.assertIn("sparse-checkout: |", checkout)
        for required_path in (
            ".claude",
            ".github",
            "assets",
            "data",
            "references",
            "scenes",
            "scripts",
            "services",
            "skills",
            "source_docs",
            "tests",
            "tools",
            "build/qa/scrum434_soldier_pixellab",
            "docs/process",
            "docs/tasks",
            "docs/design/data",
            "docs/design/templates/release_notes",
            "docs/design/mockups/release_0_2_4",
            "docs/design/mockups/scrum1061_semantic_typography",
            "docs/design/references/weapon_ultimates",
        ):
            self.assertIn(f"          {required_path}\n", checkout)

    def test_shallow_candidate_events_fetch_pinned_legacy_commits(self) -> None:
        start = self.candidate_job.index(
            "- name: Fetch pinned legacy commits for shallow candidates"
        )
        end = self.candidate_job.index("- uses: actions/setup-python@v6", start)
        history_step = self.candidate_job[start:end]

        self.assertIn("if: github.event_name != 'push'", history_step)
        self.assertIn(
            "BASE_SHA: ${{ github.event_name == 'pull_request'"
            " && github.event.pull_request.base.sha"
            " || github.event.merge_group.base_sha }}",
            history_step,
        )
        self.assertIn("git fetch --no-tags --depth=2 origin", history_step)
        self.assertIn(
            '"+$BASE_SHA:refs/remotes/origin/dev"',
            history_step,
        )
        self.assertIn("git fetch --no-tags --depth=1 origin", history_step)
        self.assertIn(
            "2cba1b7050cb168bca70b6354cc7b654334dd53e",
            history_step,
        )
        self.assertIn(
            "5d23555117c11620ee0f0834e6c30877fd1dafb8",
            history_step,
        )

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

    def test_coverage_ratchet_reports_are_uploaded_with_quality_evidence(self) -> None:
        self.assertIn("tools/test_coverage_gate.py", self.source)
        self.assertIn("build/test_coverage_report.json", self.source)
        self.assertIn("build/test_coverage_report.md", self.source)
        self.assertIn("test_coverage_report.sha256", self.source)

    def test_job_has_bounded_runtime(self) -> None:
        self.assertIn("timeout-minutes: 60", self.candidate_job)

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
        # executing one game test. Candidate events must use the fetched
        # integration ref, which is the only certifying changed-profile base.
        canonical_gate = (
            'python3 tools/quality_gate.py --profile changed '
            '--changed-ref origin/dev'
        )
        self.assertEqual(self.candidate_job.count(canonical_gate), 2)
        for raw_base in (
            "${{ github.event.pull_request.base.sha }}",
            "${{ github.event.merge_group.base_sha }}",
        ):
            self.assertNotIn(
                f'python3 tools/quality_gate.py --profile changed --changed-ref "{raw_base}"',
                self.candidate_job,
            )
            self.assertNotIn(
                f'python3 tools/quality_gate.py --static-only --changed-ref "{raw_base}"',
                self.candidate_job,
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

    def test_candidate_jobs_expose_the_pinned_engine_to_the_gate(self) -> None:
        # The live signature probe in tests/test_quality_tools.py skips where
        # no engine exists, so candidate jobs must keep advertising the pinned
        # binary to the gate's environment — otherwise the probe would demote
        # itself to a skip in CI and the push_error frame the failure detector
        # reads would again be guarded by nothing.
        self.assertIn('echo "GODOT_BIN=$GODOT_DIR/godot" >> "$GITHUB_ENV"', self.source)

    def test_import_cache_key_contains_engine_and_asset_fingerprint(self) -> None:
        start = self.source.index("- name: Restore Godot import cache")
        end = self.source.index("- name: Report Godot import cache", start)
        cache_step = self.source[start:end]
        key_line = next(
            line.strip()
            for line in cache_step.splitlines()
            if line.strip().startswith("key:")
        )

        self.assertIn("id: godot-import-cache", cache_step)
        self.assertIn("if: github.event_name != 'push'", cache_step)
        self.assertIn("path: .godot", cache_step)
        self.assertIn("${{ env.GODOT_BUILD_ID }}", key_line)
        self.assertIn("${{ hashFiles(", key_line)
        for import_input in (
            "'project.godot'",
            "'export_presets.cfg'",
            "'**/*.import'",
            "'**/*.png'",
            "'**/*.ogg'",
            "'**/*.glb'",
        ):
            self.assertIn(import_input, key_line)
        # A partial restore would populate `.godot/` and let the presence-based
        # pre-pass check skip reimporting an asset whose fingerprint changed.
        self.assertNotIn("restore-keys:", cache_step)
        self.assertIn(
            'godot import cache-hit: ${{ steps.godot-import-cache.outputs.cache-hit }}',
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

    def test_full_profile_health_jobs_budget_resources_and_resolve_base(self) -> None:
        shards_start = self.source.index("  dev-runtime-health-godot:\n")
        summary_start = self.source.index("  dev-runtime-health:\n", shards_start)
        shards = self.source[shards_start:summary_start]
        summary = self.source[summary_start:]

        before_cache = "Capture resource diagnostics before cache and swap"
        before_gate = "Capture resource diagnostics before full-profile gate"
        post_shard = "Capture post-shard resource diagnostics"
        self.assertIn(before_cache, shards)
        self.assertIn(before_gate, shards)
        self.assertIn(post_shard, shards)
        self.assertLess(shards.index(before_cache), shards.index("Restore Godot import cache"))
        self.assertLess(shards.index(before_cache), shards.index("Configure disk-budgeted extra swap"))
        self.assertLess(shards.index(before_gate), shards.index("Repository, Python and Godot gates (full profile shard)"))
        self.assertLess(shards.index(post_shard), shards.index("Hash shard quality evidence"))
        self.assertIn("df --output=avail -B1", shards)
        self.assertIn("free -m", shards)
        self.assertIn("min_free_bytes=$((4 * 1024 * 1024 * 1024))", shards)
        self.assertIn("max_swap_bytes=$((8 * 1024 * 1024 * 1024))", shards)
        self.assertIn("swap_bytes=$((available_bytes - min_free_bytes))", shards)
        self.assertIn('sudo fallocate -l "$swap_bytes" "$swap_file"', shards)
        self.assertNotIn("sudo fallocate -l 8G", shards)
        self.assertIn("git fetch --no-tags --depth=300 origin", shards)
        self.assertIn("git fetch --no-tags --depth=1 origin dev:refs/remotes/origin/dev", shards)
        self.assertIn("Fetch integration base for canonical report", summary)
        self.assertIn("git fetch --no-tags --depth=1 origin dev:refs/remotes/origin/dev", summary)
        self.assertLess(summary.index("Fetch integration base for canonical report"), summary.index("Combine static and Godot shard reports"))

    def test_required_check_job_id_is_stable(self) -> None:
        # Branch protection binds to the job id: renaming it detaches the
        # required gate without any visible failure.
        self.assertIn("\n  static-quality:\n", self.source)


if __name__ == "__main__":
    unittest.main()
