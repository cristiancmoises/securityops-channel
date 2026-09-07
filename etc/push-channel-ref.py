#!/usr/bin/env python3
"""Push explicit channel refs without saving credentials or force-pushing."""
import argparse
import os
from pathlib import Path
import runpy
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--host", choices=("primary", "secondary"), required=True)
parser.add_argument("--credentials-file", required=True)
parser.add_argument("--source", required=True)
parser.add_argument("--repo", required=True)
parser.add_argument("refs", nargs="+")
args = parser.parse_args()
api = runpy.run_path(str(Path(__file__).with_name("mirror-channels.py")))
if args.repo not in api["CHANNELS"]:
    parser.error("repository must belong to the audited channel set")
if any(ref.startswith(("+", "-", ":")) or ":refs/" not in ref for ref in args.refs):
    parser.error("use explicit non-deleting, non-forced source:refs/... refspecs")
host = api["HOSTS"][args.host]
env = os.environ.copy()
env["SECURITYOPS_PUSH_TOKEN"] = api["token_from_file"](args.credentials_file, host)
env["GIT_TERMINAL_PROMPT"] = "0"
helper = '!f() { printf "username=cristiancmoises\\npassword=%s\\n" "$SECURITYOPS_PUSH_TOKEN"; }; f'
result = subprocess.run([
    "git", "-C", args.source, "-c", "credential.helper=",
    "-c", "credential.helper=" + helper, "-c", "http.version=HTTP/1.1",
    "-c", "http.postBuffer=524288000", "-c", "http.extraHeader=Expect:",
    "-c", "http.lowSpeedLimit=100", "-c", "http.lowSpeedTime=60", "push",
    host + "/cristiancmoises/" + args.repo + ".git", *args.refs],
    env=env, timeout=180)
raise SystemExit(result.returncode)
