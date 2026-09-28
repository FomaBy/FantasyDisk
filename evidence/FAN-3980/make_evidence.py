"""Build the immutable FAN-3980 package manifest and a sanitized build log (fixed 0.3.1).

Reads the new retained release under the configured durable root, cross-checks
SHA256SUMS.txt, update-manifest.json and LOCAL_RELEASE.json against fresh
hashes, proves every artifact hash differs from the FAN-3963 package (now at
releases/archive/v0.3.1-attempt1-448a0cc1), and records source pins, build
command, timing and trust results. Identity, certificate subject, team id and
Apple account values are redacted.
"""
import hashlib, json, os, pathlib, re, subprocess, sys
ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "build" / "FAN-3980"
EVID = ROOT / "evidence" / "FAN-3980"
VERSION = "0.3.1"
CFG = json.loads((pathlib.Path.home() / ".config/fantasydisk/release.json").read_text())
RELEASES = pathlib.Path(CFG["local_root"]) / "releases"
RETAINED = RELEASES / f"v{VERSION}"
OLD = RELEASES / "archive" / "v0.3.1-attempt1-448a0cc1"
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

# --- every new artifact hash differs from the FAN-3963 package (archived old 0.3.1) ---
old_manifest = json.loads((OLD / "LOCAL_RELEASE.json").read_text())
old_inv = old_manifest["package_inventory"]
diff_rows = {}
for name, item in inventory.items():
    if name == "LOCAL_RELEASE.json":
        old_hash = sha(OLD / "LOCAL_RELEASE.json")
    else:
        old_hash = old_inv.get(name, {}).get("sha256")
    diff_rows[name] = {"new_sha256": item["sha256"], "old_fan3963_sha256": old_hash, "differs": item["sha256"] != old_hash}
checks["all_new_hashes_differ_from_fan3963"] = all(r["differs"] for r in diff_rows.values())
checks["new_vs_fan3963"] = diff_rows

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
    "issue": "FAN-3980",
    "version": VERSION,
    "release_decision_ref": "FAN-3964 comment 01a0e4b2-794b-7b49-b1cd-31650d322d95 (owner direct instruction 2026-09-27: all fixes in 0.3.1, no new versions)",
    "source_pins": {
        "tag": "v0.3.1",
        "tag_object_sha": git("rev-parse", "v0.3.1"),
        "tag_target_commit": git("rev-parse", "v0.3.1^{commit}"),
        "tag_target_tree": git("rev-parse", "v0.3.1^{tree}"),
        "remote_tag": dict(l.split("\t")[::-1] for l in git("ls-remote", "--tags", "origin", "v0.3.1", "v0.3.1^{}").splitlines()),
        "archive_tag": dict(l.split("\t")[::-1] for l in git("ls-remote", "--tags", "origin", "archive/v0.3.1-attempt1-448a0cc1", "archive/v0.3.1-attempt1-448a0cc1^{}").splitlines()),
        "origin_main": git("ls-remote", "origin", "refs/heads/main").split()[0],
        "origin_dev": git("ls-remote", "origin", "refs/heads/dev").split()[0],
        "build_checkout_head": git("rev-parse", "HEAD"),
        "build_checkout_tree": git("rev-parse", "HEAD^{tree}"),
        "fan3978_passed_candidate": {"sha": "165f14aa0ce5bcbd884e4dfde137283a8010e863", "tree": "9dd96fa9cec99be330b638cdd04dfd1a42d4840d",
                                     "qa_reviewer": "d7bc8435-0d2d-44f8-b77a-bd9723a3880e", "qa_run": "01a0e4f9-e6c9-78d7-bf87-ed23f4965689"},
        "fan3979_qa": {"verdict": "PASSED", "reviewer": "8ceb4992-a213-4090-8db0-51eb9c8fdb94", "run": "01a0e547-7c29-7f3c-8fb0-1ce488e03997"},
        "old_package_source": {"tag_object": "676c0f6fdc6d6edd64ad7a2429d0ad5edb6e7c71", "commit": "448a0cc12f02eb05bc16becc69fde365021a9a17", "tree": "3e02df83290741b21d4de37c4fa03e356e20c591"},
    },
    "build": {
        "command": "FANTASYDISK_MACOS_CHANNEL=signed MACOS_NOTARY_PROFILE=FantasyDiskRelease MACOS_SIGN_IDENTITY=<local, redacted> tools/build_release.sh 0.3.1",
        "launcher": "evidence/FAN-3980/run_build.sh (identity resolved locally from the owner-selected Developer ID Application certificate fingerprint; core.hooksPath overridden only in the build process environment)",
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
        "old_0.3.1_package_relocated_to": str(OLD),
        "relocation_record": (OUT / "preserve_relocation.txt").read_text().splitlines(),
        "v0.3.1_manifest_before_sha256": sha(OUT / "preserve_v0.3.1_before.sha256"),
        "v0.3.1_manifest_after_sha256": sha(OUT / "preserve_v0.3.1_after.sha256"),
        "v0.3.1_manifests_equal": (OUT / "preserve_v0.3.1_before.sha256").read_bytes() == (OUT / "preserve_v0.3.1_after.sha256").read_bytes(),
        "v0.3.1_file_count": sum(1 for _ in (OUT / "preserve_v0.3.1_before.sha256").open()),
        "v0.3.2_manifest_before_sha256": sha(OUT / "preserve_v0.3.2_before.sha256"),
        "v0.3.2_manifest_after_sha256": sha(OUT / "preserve_v0.3.2_after.sha256") if (OUT / "preserve_v0.3.2_after.sha256").exists() else None,
        "v0.3.2_manifests_equal": ((OUT / "preserve_v0.3.2_after.sha256").exists() and
                                   (OUT / "preserve_v0.3.2_before.sha256").read_bytes() == (OUT / "preserve_v0.3.2_after.sha256").read_bytes()),
        "v0.3.2_file_count": sum(1 for _ in (OUT / "preserve_v0.3.2_before.sha256").open()),
        "v0.3.0_LOCAL_RELEASE_sha256": sha(RELEASES / "v0.3.0" / "LOCAL_RELEASE.json"),
        "old_0.3.1_LOCAL_RELEASE_sha256": sha(OLD / "LOCAL_RELEASE.json"),
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
print(json.dumps({k: v for k, v in checks.items() if not isinstance(v, (list, dict))}, indent=2))
print("notarization:", trust["notarization_accepted_lines"])
print("nsis:", trust["nsis_crc_line"])
print("preservation equal:", manifest["preservation"]["v0.3.1_manifests_equal"], manifest["preservation"]["v0.3.2_manifests_equal"])
print("redacted_tokens:", len(redact), "raw_len", len(raw), "san_len", len(san))
