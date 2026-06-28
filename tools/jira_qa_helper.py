#!/usr/bin/env python3
"""QA helper: read comments, post comment, transition issue, create bug.
Usage:
  jira_qa_helper.py comments SCRUM-505
  jira_qa_helper.py comment SCRUM-505 "text"
  jira_qa_helper.py transition SCRUM-505 "Готово"
  jira_qa_helper.py status SCRUM-505
"""
import sys, os, json, base64, subprocess, urllib.request, urllib.parse, urllib.error

SITE = "https://fantasydisk.atlassian.net"
PROJECT = "SCRUM"
EMAIL = "fomamoney@gmail.com"
KEYCHAIN_SERVICE = "fantasydisk-jira"


def token():
    return subprocess.check_output(
        ["security", "find-generic-password", "-s", KEYCHAIN_SERVICE, "-w"],
        text=True).strip()


def api(method, path, payload=None):
    req = urllib.request.Request(SITE + path, method=method)
    auth = base64.b64encode(f"{EMAIL}:{token()}".encode()).decode()
    req.add_header("Authorization", f"Basic {auth}")
    req.add_header("Content-Type", "application/json")
    data = json.dumps(payload).encode() if payload is not None else None
    try:
        with urllib.request.urlopen(req, data=data) as r:
            body = r.read().decode()
            return json.loads(body) if body else {}
    except urllib.error.HTTPError as e:
        sys.stderr.write(f"HTTP {e.code} {path}: {e.read().decode()[:400]}\n")
        raise


def adf(text):
    return {"type": "doc", "version": 1, "content": [
        {"type": "paragraph", "content": [{"type": "text", "text": line}]}
        for line in text.split("\n")] or [{"type": "paragraph", "content": []}]}


def adf_text(node):
    out = []
    if isinstance(node, dict):
        if node.get("type") == "text":
            out.append(node.get("text", ""))
        for c in node.get("content", []):
            out.append(adf_text(c))
        if node.get("type") == "paragraph":
            out.append("\n")
    elif isinstance(node, list):
        for c in node:
            out.append(adf_text(c))
    return "".join(out)


def cmd_comments(key):
    data = api("GET", f"/rest/api/3/issue/{key}/comment?maxResults=50")
    for c in data.get("comments", []):
        who = c.get("author", {}).get("displayName", "?")
        when = c.get("created", "")[:19]
        print(f"=== {who} | {when} ===")
        print(adf_text(c.get("body", {})).strip())
        print()


def cmd_comment(key, text):
    api("POST", f"/rest/api/3/issue/{key}/comment", {"body": adf(text)})
    print("posted")


def cmd_status(key):
    data = api("GET", f"/rest/api/3/issue/{key}?fields=status,summary")
    print(data["fields"]["status"]["name"], "|", data["fields"]["summary"])


def cmd_transition(key, target):
    trs = api("GET", f"/rest/api/3/issue/{key}/transitions")
    for t in trs.get("transitions", []):
        if t["to"]["name"].lower() == target.lower() or t["name"].lower() == target.lower():
            api("POST", f"/rest/api/3/issue/{key}/transitions",
                {"transition": {"id": t["id"]}})
            print(f"transitioned to {t['to']['name']}")
            return
    print("AVAILABLE:", [t["to"]["name"] for t in trs.get("transitions", [])])
    sys.exit(1)


if __name__ == "__main__":
    a = sys.argv
    if a[1] == "comments":
        cmd_comments(a[2])
    elif a[1] == "comment":
        cmd_comment(a[2], a[3])
    elif a[1] == "status":
        cmd_status(a[2])
    elif a[1] == "transition":
        cmd_transition(a[2], a[3])
    else:
        print("unknown", a[1]); sys.exit(1)
