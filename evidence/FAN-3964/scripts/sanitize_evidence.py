"""Copy FAN-3964 evidence from the task workdir into the repository tree with personal paths
and user-data listings removed. Run from the task workdir; output goes to
FantasyDisk/evidence/FAN-3964/."""
import os
import re
import shutil

W = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(W, "evidence", "FAN-3964")
DST = os.path.join(W, "FantasyDisk", "evidence", "FAN-3964")
USER = os.environ["USERNAME"]
BS = chr(92)
EXCLUDE_DIRS = {"userdata_copy", "lnk"}
SCRIPTS = [
    "host_gate.ps1", "verify_pkg.py", "list_embedded_pck.py", "preimage.ps1", "install_run.ps1",
    "launch_run.ps1", "userdata_integrity.ps1", "uninstall_rollback.ps1", "rollback_only.ps1",
    "manifest_check.py", "override.cfg", "shrink_shot.ps1", "sanitize_evidence.py",
]

WORKDIR_RX = re.compile(r"%USERPROFILE%[\\/]multica_workspaces_desktop-api\.multica\.ai[\\/][^\\/]+[\\/][^\\/]+[\\/]workdir")
DESKTOP_RX = re.compile(r"%USERPROFILE%[\\/]OneDrive[\\/][^\\/]*?(?=[\\/]FantasyDisk)")


def san(text: str) -> str:
    for needle in ("C:" + BS + "Users" + BS + USER, "C:/Users/" + USER,
                   "c:" + BS + "users" + BS + USER.lower(), "c:/users/" + USER.lower()):
        text = text.replace(needle, "%USERPROFILE%")
    text = WORKDIR_RX.sub("<workdir>", text)
    text = DESKTOP_RX.sub("<Desktop>", text)
    text = text.replace("C:" + BS + "Users" + BS + "Public", "<PublicProfile>")
    text = re.sub("%USERPROFILE%[" + BS + BS + "/]OneDrive[" + BS + BS + "/][^" + BS + BS + "/" + BS + "s]*", "<Desktop>", text)
    text = text.replace("whoami: " + USER, "whoami: <user>")
    return text


def filter_lines(rel: str, text: str) -> str:
    lines = text.splitlines()
    out = []
    dropped = 0
    if rel.endswith("host_gate_raw.txt"):
        skip = False
        for line in lines:
            if line.startswith("### godot user data"):
                skip = True
                out.append(line)
                out.append("  (per-file listing of the whole Godot user-data tree omitted from the public copy: "
                           "it enumerates other games. FantasyDisk game data lives in "
                           "%APPDATA%/Godot/app_userdata/FantasyDisk; see preimage/userdata_listing_before.txt)")
                continue
            if line.startswith("### registry"):
                skip = False
            if skip:
                dropped += 1
                continue
            if ("name=claude" in line or "name=codex" in line or "name=Multica" in line
                    or "steamwebhelper" in line):
                dropped += 1
                continue
            out.append(line)
    else:
        for line in lines:
            if (BS + "feedback" + BS) in line or "/feedback/" in line:
                dropped += 1
                continue
            out.append(line)
    if dropped:
        out.append(f"# sanitizer: {dropped} line(s) omitted from the public copy "
                   "(user feedback-report entries / unrelated process rows)")
    return "\n".join(out) + "\n"


def main() -> None:
    if os.path.isdir(DST):
        shutil.rmtree(DST)
    for root, dirs, files in os.walk(SRC):
        dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS]
        for f in files:
            sp = os.path.join(root, f)
            rel = os.path.relpath(sp, SRC)
            dp = os.path.join(DST, rel)
            os.makedirs(os.path.dirname(dp), exist_ok=True)
            if f.endswith((".png", ".reg")):
                shutil.copyfile(sp, dp)
                continue
            raw = open(sp, "rb").read()
            try:
                text = raw.decode("utf-8")
            except UnicodeDecodeError:
                text = raw.decode("cp1251", errors="replace")
            text = filter_lines(rel, san(text.replace("\r\n", "\n")))
            if rel.endswith("host_gate_raw.txt"):
                dp = os.path.join(DST, "host-gate", "host_gate.txt")
            open(dp, "w", encoding="utf-8", newline="\n").write(text)
    os.makedirs(os.path.join(DST, "scripts"), exist_ok=True)
    for s in SCRIPTS:
        t = open(os.path.join(W, s), encoding="utf-8").read().replace("\r\n", "\n")
        open(os.path.join(DST, "scripts", s), "w", encoding="utf-8", newline="\n").write(san(t))
    open(os.path.join(DST, ".gdignore"), "w").write("")
    bad = []
    total = 0
    for root, _, files in os.walk(DST):
        for f in files:
            p = os.path.join(root, f)
            total += os.path.getsize(p)
            if f.endswith((".png", ".reg")) or f == "sanitize_evidence.py":
                continue
            t = open(p, encoding="utf-8", errors="replace").read().lower()
            for needle in (USER.lower(), "onedrive" + BS, "onedrive/", "multica_workspaces"):
                if needle in t:
                    bad.append((os.path.relpath(p, DST), needle))
    print("leak check:", "CLEAN" if not bad else bad)
    print("total bytes", total)


if __name__ == "__main__":
    main()
