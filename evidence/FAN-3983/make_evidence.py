"""Build the immutable FAN-3983 package manifest and a sanitized build log (fixed 0.3.1, M3).

Reads the new retained release under the configured durable root, cross-checks
SHA256SUMS.txt, update-manifest.json and LOCAL_RELEASE.json against fresh
hashes, proves every artifact hash differs from the FAN-3963 package
(releases/archive/v0.3.1-attempt1-448a0cc1) and from the FAN-3980 package
(releases/archive/v0.3.1-attempt2-165f14aa), and records source pins, build
command, timing and trust results. Identity, certificate subject, team id and
Apple account values are redacted.
"""
import hashlib, json, os, pathlib, re, subprocess, sys
ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "build" / "FAN-3983"
EVID = ROOT / "evidence" / "FAN-3983"
VERSION = "0.3.1"
CFG = json.loads((pathlib.Path.home() / ".config/fantasydisk/release.json").read_text())
RELEASES = pathlib.Path(CFG["local_root"]) / "releases"
RETAINED = RELEASES / f"v{VERSION}"
OLD = RELEASES / "archive" / "v0.3.1-attempt1-448a0cc1"
OLD2 = RELEASES / "archive" / "v0.3.1-attempt2-165f14aa"
PRES = OUT / "preservation"
V032 = RELEASES / "v0.3.2"
CERT = "/Users/sergeyfomin/Certificates/developerID_application.cer"

def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()

def git(*a):
    return subprocess.run(["git", *a], cwd=ROOT, capture_output=True, text=True, check=True).stdout.strip()

# --- redaction set (values never written) ---
fp = subprocess.run(["openssl", "x509", "-inform", "DER", "-in", CERT, "-noout", "-fingerprint", "-sha1"],
                    capture_output=True, text=True, check=True).stdout.split("=")[-1].strip()
fp_nocolon = fp.replace(":", "")
subj = subprocess.run(["openssl", "x509", "-inform", "DER", "-in", CERT, "-noout", "-subject"],
                      capture_output=True, text=True, check=True).stdout
cn = re.search(r"CN\s*=\s*([^,/\n]+)", subj)
cn = cn.group(1).strip() if cn else None
ou = re.search(r"OU\s*=\s*([^,/\n]+)", subj)
team = ou.group(1).strip() if ou else None
redact = [v for v in (fp, fp_nocolon, cn, team) if v]
raw = (OUT / "build_release.raw.log").read_text(errors="replace")
san = raw
for v in redact:
    san = san.replace(v, "[REDACTED]")
san = re.sub(r"[\w.+-]+@[\w-]+\.[\w.]+", "[REDACTED-EMAIL]", san)
# drop progress spam (carriage-return updated lines) for the committed copy
san = "\n".join(l.rsplit("\r", 1)[-1] for l in san.split("\n"))

# --- package inventory ---
files = sorted(p for p in RETAINED.iterdir() if p.is_file())
inventory = {p.name: {"size": p.stat().st_size, "sha256": sha(p)} for p in files}
local_manifest = json.loads((RETAINED / "LOCAL_RELEASE.json").read_text())
sums = {}
for line in (RETAINED / "SHA256SUMS.txt").read_text().splitlines():
    h, _, name = line.partition("  ")
    sums[name.strip()] = h.strip()
upd = json.loads((RETAINED / "update-manifest.json").read_text())

checks = {}
checks["sha256sums_match_fresh"] = all(inventory[n]["sha256"] == h for n, h in sums.items())
checks["sha256sums_names"] = sorted(sums)
lm_inv = local_manifest.get("package_inventory", {})
checks["local_release_inventory_match_fresh"] = all(
    inventory.get(n, {}).get("sha256") == v.get("sha256") and inventory.get(n, {}).get("size") == v.get("size")
    for n, v in lm_inv.items()) and bool(lm_inv)
checks["local_release_inventory_names"] = sorted(lm_inv)
upd_checks = []
def walk(o):
    if isinstance(o, dict):
        if "sha256" in o and ("name" in o or "filename" in o or "url" in o):
            name = o.get("name") or o.get("filename") or o.get("url", "").rsplit("/", 1)[-1]
            upd_checks.append({"name": name, "sha256_ok": inventory.get(name, {}).get("sha256") == o["sha256"],
                               "size_ok": inventory.get(name, {}).get("size") == o.get("size"), "url": o.get("url")})
        for v in o.values(): walk(v)
    elif isinstance(o, list):
        for v in o: walk(v)
walk(upd)
checks["update_manifest_entries"] = upd_checks
checks["update_manifest_all_ok"] = bool(upd_checks) and all(u["sha256_ok"] and u["size_ok"] for u in upd_checks)
checks["update_manifest_urls_under_v0.3.1"] = all(
    u["url"].startswith("https://github.com/FomaBy/FantasyDisk-Releases/releases/download/v0.3.1/") for u in upd_checks)
checks["local_release_tag"] = local_manifest.get("tag")
checks["local_release_tag_commit"] = local_manifest.get("tag_commit")
checks["local_release_macos_channel"] = local_manifest.get("macos_channel")
checks["local_release_source_tree_sha256"] = local_manifest.get("source_tree_sha256")
checks["project_snapshot_present"] = (RETAINED / "project" / "project.godot").is_file()
checks["godot_project_present"] = (RETAINED / "godot-project" / "project.godot").is_file()
cur = RELEASES / "current-project"
checks["current_project_target"] = os.readlink(cur) if cur.is_symlink() else (cur.read_text().strip() if cur.is_file() else None)

# --- every new artifact hash differs from the FAN-3963 (attempt 1) and FAN-3980 (attempt 2) packages ---
def old_inventory(path):
    inv = json.loads((path / "LOCAL_RELEASE.json").read_text())["package_inventory"]
    return {n: v.get("sha256") for n, v in inv.items()} | {"LOCAL_RELEASE.json": sha(path / "LOCAL_RELEASE.json")}
old1 = old_inventory(OLD)
old2 = old_inventory(OLD2)
diff_rows = {}
for name, item in inventory.items():
    diff_rows[name] = {"new_sha256": item["sha256"],
                       "old_fan3963_sha256": old1.get(name), "differs_from_fan3963": item["sha256"] != old1.get(name),
                       "old_fan3980_sha256": old2.get(name), "differs_from_fan3980": item["sha256"] != old2.get(name)}
checks["all_new_hashes_differ_from_fan3963"] = all(r["differs_from_fan3963"] for r in diff_rows.values())
checks["all_new_hashes_differ_from_fan3980"] = all(r["differs_from_fan3980"] for r in diff_rows.values())
checks["new_vs_old_packages"] = diff_rows
BUILT = ("FantasyDisk-0.3.1-macos.dmg", "FantasyDisk-0.3.1-windows-setup.exe", "SHA256SUMS.txt", "update-manifest.json", "LOCAL_RELEASE.json")
checks["all_built_artifacts_differ_from_fan3980"] = all(diff_rows[n]["differs_from_fan3980"] for n in BUILT)
checks["files_equal_to_fan3980_package"] = sorted(n for n, r in diff_rows.items() if not r["differs_from_fan3980"])
checks["files_equal_to_fan3980_note"] = ("CHANGELOG-0.3.1.md and fantasydisk_031_announcement.png are copied release inputs; the v0.3.1 tag tree "
    "(f4d05fea) carries the same CHANGELOG 0.3.1 section and the same poster blob 51803688 as the FAN-3980 tag tree (165f14aa), "
    "so these two files are byte-identical by construction (poster provenance = tag blob is itself an acceptance check). Every built artifact differs.")

def grab(pattern):
    return [l.strip() for l in raw.splitlines() if re.search(pattern, l)]
trust = {
    "channel": "signed",
    "notarization_accepted_lines": [l for l in grab(r"Apple notarization (accepted|rejected|request failed)")],
    "spctl_lines": [re.sub("|".join(map(re.escape, redact)), "[REDACTED]", l) for l in grab(r"source=|accepted|rejected") if "spctl" in l or "source=" in l or ": accepted" in l or ": rejected" in l],
    "stapler_lines": grab(r"The validate action worked|The staple and validate action worked"),
    "codesign_verify_lines": grab(r"valid on disk|satisfies its Designated Requirement"),
    "nsis_crc_line": grab(r"NSIS CRC"),
    "secret_scan_lines": grab(r"secret scan"),
    "hdiutil_verify_lines": grab(r"verified|VALID"),
    "local_release_status_lines": grab(r'"status"'),
}
timing = dict(l.split("=", 1) for l in (OUT / "build_timing.txt").read_text().splitlines() if "=" in l)
pre_hist = (OUT / "prebuild_notary_history_exit.txt").read_text().strip()

manifest = {
    "schema": 1,
    "issue": "FAN-3983",
    "version": VERSION,
    "release_decision_ref": "FAN-3964 comment 01a0e4b2-794b-7b49-b1cd-31650d322d95 (owner direct instruction 2026-09-27: all fixes in 0.3.1, no new versions)",
    "source_pins": {
        "tag": "v0.3.1",
        "tag_object_sha": git("rev-parse", "v0.3.1"),
        "tag_target_commit": git("rev-parse", "v0.3.1^{commit}"),
        "tag_target_tree": git("rev-parse", "v0.3.1^{tree}"),
        "remote_tag": dict(l.split("\t")[::-1] for l in git("ls-remote", "--tags", "origin", "v0.3.1", "v0.3.1^{}").splitlines()),
        "archive_tags": dict(l.split("\t")[::-1] for l in git("ls-remote", "--tags", "origin", "archive/v0.3.1-attempt1-448a0cc1", "archive/v0.3.1-attempt1-448a0cc1^{}", "archive/v0.3.1-attempt2-165f14aa", "archive/v0.3.1-attempt2-165f14aa^{}").splitlines()),
        "origin_main": git("ls-remote", "origin", "refs/heads/main").split()[0],
        "origin_dev": git("ls-remote", "origin", "refs/heads/dev").split()[0],
        "build_checkout_head": git("rev-parse", "HEAD"),
        "build_checkout_tree": git("rev-parse", "HEAD^{tree}"),
        "fan3984_passed_candidate": {"sha": "f4d05fea91a5ce8b3fb858a5035df1fe54236369", "tree": "e659e92afdd2dad1a3aec8ca7bce49cfac250ec6",
                                     "qa_reviewer": "d7bc8435-0d2d-44f8-b77a-bd9723a3880e", "qa_run": "01a0e72d-041c-70ed-bc08-0a3a9a418c4d"},
        "fan3981_fix": {"candidate_sha": "338fb7bf4d0cfcf9bd9a896fc0afcf0e5c4e816a", "qa_verdict": "PASSED", "qa_reviewer": "d7bc8435-0d2d-44f8-b77a-bd9723a3880e", "qa_run": "01a0e60c-6f2c-75ef-a361-15c488ac4895"},
        "fan3982_qa": {"verdict": "PASSED", "run": "01a0e7b2-33d4-7bc3-a0a1-12909a47fc0f", "verdict_comment": "01a0e7b8-e94f-7ea7-8085-34a5782a3355"},
        "old_package_sources": {
            "fan3963_attempt1": {"tag_object": "676c0f6fdc6d6edd64ad7a2429d0ad5edb6e7c71", "commit": "448a0cc12f02eb05bc16becc69fde365021a9a17", "tree": "3e02df83290741b21d4de37c4fa03e356e20c591"},
            "fan3980_attempt2": {"tag_object": "c692d01973a7e4765807bd5fcae11c6bb74df5e6", "commit": "165f14aa0ce5bcbd884e4dfde137283a8010e863", "tree": "9dd96fa9cec99be330b638cdd04dfd1a42d4840d"}},
    },
    "build": {
        "command": "FANTASYDISK_MACOS_CHANNEL=signed MACOS_NOTARY_PROFILE=FantasyDiskRelease MACOS_SIGN_IDENTITY=<local, redacted> tools/build_release.sh 0.3.1",
        "launcher": "evidence/FAN-3983/run_build.sh (identity resolved locally from the owner-selected Developer ID Application certificate fingerprint; core.hooksPath overridden only in the build process environment)",
        "prebuild_notarytool_history": pre_hist,
        **timing,
        "godot": subprocess.run(["/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot", "--version"], capture_output=True, text=True).stdout.strip().splitlines()[-1],
        "makensis": subprocess.run(["makensis", "-VERSION"], capture_output=True, text=True).stdout.strip(),
        "macos": subprocess.run(["sw_vers", "-productVersion"], capture_output=True, text=True).stdout.strip(),
        "raw_log_sha256": sha(OUT / "build_release.raw.log"),
        "raw_log_bytes": (OUT / "build_release.raw.log").stat().st_size,
    },
    "retained_release_dir": str(RETAINED),
    "package_inventory": inventory,
    "cross_checks": checks,
    "trust_channel": trust,
    "preservation": {
        "fan3980_0.3.1_package_relocated_to": str(OLD2),
        "relocation_record": (PRES / "preserve_relocation.txt").read_text().splitlines(),
        "attempt2_manifest_before_sha256": sha(PRES / "preserve_v0.3.1_before.sha256"),
        "attempt2_manifest_after_sha256": sha(PRES / "preserve_v0.3.1_after.sha256"),
        "attempt2_manifest_after2_sha256": sha(PRES / "preserve_v0.3.1_after2.sha256") if (PRES / "preserve_v0.3.1_after2.sha256").exists() else None,
        "attempt2_manifests_equal": (PRES / "preserve_v0.3.1_before.sha256").read_bytes() == (PRES / "preserve_v0.3.1_after.sha256").read_bytes()
            and ((not (PRES / "preserve_v0.3.1_after2.sha256").exists()) or (PRES / "preserve_v0.3.1_before.sha256").read_bytes() == (PRES / "preserve_v0.3.1_after2.sha256").read_bytes()),
        "attempt2_file_count": sum(1 for _ in (PRES / "preserve_v0.3.1_before.sha256").open()),
        "attempt1_manifest_before_sha256": sha(PRES / "preserve_attempt1_before.sha256"),
        "attempt1_manifest_after_sha256": sha(PRES / "preserve_attempt1_after.sha256") if (PRES / "preserve_attempt1_after.sha256").exists() else None,
        "attempt1_manifests_equal": (PRES / "preserve_attempt1_after.sha256").exists() and (PRES / "preserve_attempt1_before.sha256").read_bytes() == (PRES / "preserve_attempt1_after.sha256").read_bytes(),
        "attempt1_file_count": sum(1 for _ in (PRES / "preserve_attempt1_before.sha256").open()),
        "v0.3.2_manifest_before_sha256": sha(PRES / "preserve_v0.3.2_before.sha256"),
        "v0.3.2_manifest_after_sha256": sha(PRES / "preserve_v0.3.2_after.sha256") if (PRES / "preserve_v0.3.2_after.sha256").exists() else None,
        "v0.3.2_manifests_equal": ((PRES / "preserve_v0.3.2_after.sha256").exists() and
                                   (PRES / "preserve_v0.3.2_before.sha256").read_bytes() == (PRES / "preserve_v0.3.2_after.sha256").read_bytes()),
        "v0.3.2_file_count": sum(1 for _ in (PRES / "preserve_v0.3.2_before.sha256").open()),
        "v0.3.0_LOCAL_RELEASE_sha256": sha(RELEASES / "v0.3.0" / "LOCAL_RELEASE.json"),
        "attempt1_LOCAL_RELEASE_sha256": sha(OLD / "LOCAL_RELEASE.json"),
        "attempt2_LOCAL_RELEASE_sha256": sha(OLD2 / "LOCAL_RELEASE.json"),
        "v0.3.2_LOCAL_RELEASE_sha256": sha(V032 / "LOCAL_RELEASE.json"),
    },
    "local_release_manifest": local_manifest,
    "update_manifest": upd,
}
extra = OUT / "extra_checks.json"
if extra.is_file():
    manifest["built_bytes_checks"] = json.loads(extra.read_text())
EVID.mkdir(parents=True, exist_ok=True)
(EVID / "package_manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False, sort_keys=False) + "\n")
(EVID / "build_release.log").write_text(san)
for name in ("SHA256SUMS.txt", "update-manifest.json", "LOCAL_RELEASE.json", f"CHANGELOG-{VERSION}.md"):
    (EVID / name).write_bytes((RETAINED / name).read_bytes())
print(json.dumps({k: v for k, v in checks.items() if not isinstance(v, dict)}, indent=2, ensure_ascii=False))
print("notarization:", trust["notarization_accepted_lines"])
print("nsis:", trust["nsis_crc_line"])
print("preservation equal:", manifest["preservation"]["attempt2_manifests_equal"], manifest["preservation"]["attempt1_manifests_equal"], manifest["preservation"]["v0.3.2_manifests_equal"])
print("redacted_tokens:", len(redact), "raw_len", len(raw), "san_len", len(san))
