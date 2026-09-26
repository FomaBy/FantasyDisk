"""Build the immutable FAN-3963 package manifest and a sanitized build log.

Reads the retained release under the configured durable root, cross-checks
SHA256SUMS.txt, update-manifest.json and LOCAL_RELEASE.json against fresh
hashes, and records source pins, build command, timing and trust results.
Identity, certificate subject, team id and Apple account values are redacted.
"""
import hashlib, json, os, pathlib, re, subprocess, sys
ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "build" / "FAN-3963"
EVID = ROOT / "evidence" / "FAN-3963"
VERSION = "0.3.1"
CFG = json.loads((pathlib.Path.home() / ".config/fantasydisk/release.json").read_text())
RETAINED = pathlib.Path(CFG["local_root"]) / "releases" / f"v{VERSION}"
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
san = re.sub(r"\(\[REDACTED\]\)", "([REDACTED])", san)

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
checks["local_release_tag"] = local_manifest.get("tag")
checks["local_release_tag_commit"] = local_manifest.get("tag_commit")
checks["local_release_macos_channel"] = local_manifest.get("macos_channel")
checks["local_release_source_tree_sha256"] = local_manifest.get("source_tree_sha256")
checks["project_snapshot_present"] = (RETAINED / "project" / "project.godot").is_file()
checks["godot_project_present"] = (RETAINED / "godot-project" / "project.godot").is_file()
cur = pathlib.Path(CFG["local_root"]) / "releases" / "current-project"
checks["current_project_target"] = os.readlink(cur) if cur.is_symlink() else (cur.read_text().strip() if cur.is_file() else None)

def grab(pattern):
    return [l.strip() for l in raw.splitlines() if re.search(pattern, l)]
trust = {
    "channel": "signed",
    "notarization_accepted_lines": [l for l in grab(r"Apple notarization (accepted|rejected|request failed)")],
    "spctl_lines": [re.sub("|".join(map(re.escape, redact)), "[REDACTED]", l) for l in grab(r"source=|accepted|rejected") if "spctl" in l or "source=" in l or ": accepted" in l or ": rejected" in l],
    "stapler_lines": grab(r"The validate action worked|The staple and validate action worked"),
    "codesign_verify_lines": grab(r"valid on disk|satisfies its Designated Requirement"),
    "nsis_crc_line": grab(r"NSIS CRC"),
    "secret_scan_error": grab(r"secret scan failed"),
}
timing = dict(l.split("=", 1) for l in (OUT / "build_timing.txt").read_text().splitlines() if "=" in l)
pre_hist = (OUT / "prebuild_notary_history_exit.txt").read_text().strip()

manifest = {
    "schema": 1,
    "issue": "FAN-3963",
    "version": VERSION,
    "source_pins": {
        "tag": "v0.3.1",
        "tag_object_sha": git("rev-parse", "v0.3.1"),
        "tag_target_commit": git("rev-parse", "v0.3.1^{commit}"),
        "tag_target_tree": git("rev-parse", "v0.3.1^{tree}"),
        "remote_tag": dict(l.split("\t")[::-1] for l in git("ls-remote", "--tags", "origin", "v0.3.1", "v0.3.1^{}").splitlines()),
        "origin_main": git("ls-remote", "origin", "refs/heads/main").split()[0],
        "origin_dev": git("ls-remote", "origin", "refs/heads/dev").split()[0],
        "build_checkout_head": git("rev-parse", "HEAD"),
        "build_checkout_tree": git("rev-parse", "HEAD^{tree}"),
    },
    "build": {
        "command": "FANTASYDISK_MACOS_CHANNEL=signed MACOS_NOTARY_PROFILE=FantasyDiskRelease MACOS_SIGN_IDENTITY=<local, redacted> tools/build_release.sh 0.3.1",
        "launcher": "build/FAN-3963/run_build.sh (identity resolved locally from the owner-selected Developer ID Application certificate fingerprint)",
        "prebuild_notarytool_history": pre_hist,
        **timing,
        "godot": subprocess.run(["/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot", "--version"], capture_output=True, text=True).stdout.strip().splitlines()[-1],
        "makensis": subprocess.run(["makensis", "-VERSION"], capture_output=True, text=True).stdout.strip(),
        "macos": subprocess.run(["sw_vers", "-productVersion"], capture_output=True, text=True).stdout.strip(),
    },
    "retained_release_dir": str(RETAINED),
    "package_inventory": inventory,
    "cross_checks": checks,
    "trust_channel": trust,
    "local_release_manifest": local_manifest,
    "update_manifest": upd,
}
EVID.mkdir(parents=True, exist_ok=True)
(EVID / "package_manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False, sort_keys=False) + "\n")
(EVID / "build_release.log").write_text(san)
for name in ("SHA256SUMS.txt", "update-manifest.json", "LOCAL_RELEASE.json", f"CHANGELOG-{VERSION}.md"):
    (EVID / name).write_bytes((RETAINED / name).read_bytes())
print(json.dumps({k: v for k, v in checks.items() if not isinstance(v, list)}, indent=2))
print("notarization:", trust["notarization_accepted_lines"])
print("nsis:", trust["nsis_crc_line"])
print("redacted_tokens:", len(redact), "raw_len", len(raw), "san_len", len(san))
