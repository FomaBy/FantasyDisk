#!/usr/bin/env bash
# FAN-3983 preflight: exact-tag readback, worktree state, release inputs on S, signed channel, toolchain.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; OUT="$ROOT/build/FAN-3983"; cd "$ROOT"
{
echo "# FAN-3983 preflight — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "## task worktree"
echo "path=$ROOT"; echo "branch=$(git branch --show-current)"; echo "HEAD=$(git rev-parse HEAD)"; echo "HEAD_tree=$(git rev-parse HEAD^{tree})"
echo "status_porcelain_lines=$(git status --porcelain | wc -l | tr -d ' ')"
echo "## remote readback (git ls-remote origin)"
git ls-remote origin refs/heads/dev refs/heads/main 'refs/tags/v0.3.1*' 'refs/tags/v0.3.2*' 'refs/tags/archive/*' | tee "$OUT/pre_build_ls_remote.txt"
echo "## local tag after 'git fetch --force origin +refs/tags/*:refs/tags/*'"
git fetch --force origin '+refs/tags/*:refs/tags/*' 2>&1 | tail -3
echo "v0.3.1_object=$(git rev-parse v0.3.1) type=$(git cat-file -t v0.3.1)"
echo "v0.3.1_commit=$(git rev-parse 'v0.3.1^{commit}')"
echo "v0.3.1_tree=$(git rev-parse 'v0.3.1^{tree}')"
git cat-file -p v0.3.1 | sed -E 's/^tagger .*/tagger <redacted line>/'
echo "archive_attempt2_tag=$(git rev-parse archive/v0.3.1-attempt2-165f14aa) -> $(git rev-parse 'archive/v0.3.1-attempt2-165f14aa^{commit}') tree $(git rev-parse 'archive/v0.3.1-attempt2-165f14aa^{tree}')"
echo "archive_attempt1_tag=$(git rev-parse archive/v0.3.1-attempt1-448a0cc1) -> $(git rev-parse 'archive/v0.3.1-attempt1-448a0cc1^{commit}') tree $(git rev-parse 'archive/v0.3.1-attempt1-448a0cc1^{tree}')"
echo "## dispatch contract pins"
echo "approved_source_sha=f4d05fea91a5ce8b3fb858a5035df1fe54236369 approved_tree=e659e92afdd2dad1a3aec8ca7bce49cfac250ec6 tag_object=8c2cbdf89f07f8d63417303fb35387a29250b446"
T="$(git rev-parse 'v0.3.1^{tree}')"; C="$(git rev-parse 'v0.3.1^{commit}')"; O="$(git rev-parse v0.3.1)"
echo "pins_match=$([ "$T" = e659e92afdd2dad1a3aec8ca7bce49cfac250ec6 ] && [ "$C" = f4d05fea91a5ce8b3fb858a5035df1fe54236369 ] && [ "$O" = 8c2cbdf89f07f8d63417303fb35387a29250b446 ] && echo true || echo false)"
echo "HEAD_equals_tag_commit=$([ "$(git rev-parse HEAD)" = "$C" ] && echo true || echo false)"
echo "## refined AC1 tree equality: FAN-3984 PASSED candidate_sha=f4d05fea91a5ce8b3fb858a5035df1fe54236369 candidate_tree_sha=e659e92afdd2dad1a3aec8ca7bce49cfac250ec6 (QA PASSED d7bc8435 run 01a0e72d-041c-70ed-bc08-0a3a9a418c4d); FAN-3982 done QA PASSED run 01a0e7b2-33d4-7bc3-a0a1-12909a47fc0f"
echo "tree_equal_S_vs_FAN3984=$([ "$T" = e659e92afdd2dad1a3aec8ca7bce49cfac250ec6 ] && echo true || echo false)"
echo "origin_dev_equals_S=$([ "$(git rev-parse origin/dev)" = "$C" ] && echo true || echo false)"
echo "fan3981_fix_scripts_present=$([ -f scripts/full_frame_trim_atlas.gd ] && [ -f scripts/full_frame_canvas_texture.gd ] && echo true || echo false)"
echo "## release inputs on exact S"
echo "release_version_mapping: $(python3 tools/release_version_mapping.py --version 0.3.1)"; echo "release_version_mapping_exit=$?"
grep -n "^## \[0.3.1\]" CHANGELOG.md | head -2
grep -n -E '"version": "0.3.1"|"date": "2026' scripts/patch_notes_data.gd | head -2
echo "poster_sha256=$(shasum -a 256 assets/marketing/fantasydisk_031_announcement.png | cut -d' ' -f1) blob=$(git rev-parse HEAD:assets/marketing/fantasydisk_031_announcement.png)"
echo "client_channel=$(grep -o 'MACOS_UPDATE_CHANNEL := "[a-z]*"' scripts/update_manager.gd | cut -d'"' -f2)"
echo "release_scope_guard: $(python3 tools/release_scope_guard.py --version 0.3.1 2>&1 | tail -1)"; echo "exit=${PIPESTATUS[0]:-$?}"
echo "visual_claims_guard: $(python3 tools/release_notes_visual_claims_guard.py --version 0.3.1 2>&1 | tail -1)"
python3 tools/release_notes_visual_claims_guard.py --version 0.3.1 >/dev/null 2>&1; echo "exit=$?"
python3 -m unittest tests/test_export_presets_exclusions.py 2>&1 | tail -1 | sed 's/^/export_exclusions_test: /'
echo "## signed channel"
echo "developer_id_application_identities=$(security find-identity -v -p codesigning | grep -c 'Developer ID Application')"
xcrun notarytool history --keychain-profile FantasyDiskRelease >/dev/null 2>&1; echo "notarytool_history_exit=$?"
echo "## toolchain"
echo "godot=$(/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --version 2>/dev/null | tail -1)"
echo "makensis=$(makensis -VERSION)"; echo "macos=$(sw_vers -productVersion)"
df -h /Users/sergeyfomin/FantasyDisk | tail -1
echo "## installed operator app before"
echo "app_short=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' /Applications/FantasyDisk.app/Contents/Info.plist) app_build=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' /Applications/FantasyDisk.app/Contents/Info.plist)"
echo "current_project=$(readlink /Users/sergeyfomin/FantasyDisk/releases/current-project)"
echo "current_v0.3.1_LOCAL_RELEASE_tag_commit=$(python3 -c "import json;print(json.load(open('/Users/sergeyfomin/FantasyDisk/releases/v0.3.1/LOCAL_RELEASE.json'))['tag_commit'])")"
} | tee "$OUT/00_preflight.txt"
