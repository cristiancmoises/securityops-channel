#!/usr/bin/env python3
"""Create missing Forgejo channel mirrors; never overwrite existing repositories.

Default is read-only. Credentials are supplied only through
SECURITYOPS_API_TOKEN; they are never written to output or configuration.
"""

import argparse
import json
import os
from pathlib import Path
import re
import urllib.error
import urllib.parse
import urllib.request

OWNER = "cristiancmoises"
HOSTS = {"primary": "https://git.securityops.com.br",
         "secondary": "https://git.securityops.co"}
# The secondary forge reserves /radix as a redirect to an existing longdong
# repository. Preserve that unrelated repository and its redirect.
REPO_NAMES = {("secondary", "radix"): "radix-channel"}


def token_from_file(path, host):
    """Read only the explicitly labelled token for the requested forge."""
    hostname = urllib.parse.urlsplit(host).hostname
    for line in Path(path).read_text().splitlines():
        if re.search(re.escape(hostname) + r"(?![A-Za-z0-9.])", line):
            match = re.search(r"\b[0-9a-fA-F]{40}\b", line)
            if match:
                return match.group()
    raise RuntimeError("No labelled forge token found in the credentials file")
CHANNELS = {
    "guix": ("https://gitlab.com/debdistutils/guix/mirror.git", "fe590afef7319a8ea921d35b67fb39fb79f5a3b3"),
    "nonguix": ("https://github.com/nonguix/nonguix.git", "bf39542ca537fde8839b209ac21d6f3254469b15"),
    "radix": ("https://codeberg.org/anemofilia/radix.git", "2bbcb60e08bf34241cf7120e35b7a01d06b661b0"),
    "rosenthal": ("https://codeberg.org/hako/rosenthal.git", "05ac833e359ad1c40341052caec4ea391e353eed"),
    "small-guix": (None, "59de79f673669b798f650754b629404418464784"),
    "gocix": ("https://github.com/fishinthecalculator/gocix.git", "5cbc7d0cb911dd27eb364d350ac5a1ef43308316"),
    "sops-guix": ("https://github.com/fishinthecalculator/sops-guix.git", "c53e27e533836ea8595626ba6796dee5362f8c4a"),
    "securityops-channel": (None, "5a9aec5bdf63eb1138e33621a5e0c32a3a2fc1e9"),
}


def request(host, path, method="GET", data=None):
    headers = {"Accept": "application/json"}
    token = os.environ.get("SECURITYOPS_API_TOKEN")
    if token:
        headers["Authorization"] = "token " + token
    if data is not None:
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(
        host + "/api/v1" + path,
        data=None if data is None else json.dumps(data).encode(),
        headers=headers, method=method)
    # Do not follow redirects with an Authorization header to another origin.
    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, req, fp, code, msg, headers, newurl):
            return None
    try:
        with urllib.request.build_opener(NoRedirect).open(req, timeout=300 if method == "POST" else 45) as response:
            body = response.read()
            return json.loads(body) if body else {}
    except urllib.error.HTTPError as error:
        if error.code == 404 and method == "GET":
            return None
        detail = error.read().decode(errors="replace")[:1500]
        if token:
            detail = detail.replace(token, "[redacted]")
        raise RuntimeError(f"{method} {path}: HTTP {error.code}: {detail}") from None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", choices=HOSTS, required=True)
    parser.add_argument("--channel", choices=CHANNELS, action="append")
    parser.add_argument("--create-missing", action="store_true")
    parser.add_argument("--credentials-file")
    args = parser.parse_args()
    host = HOSTS[args.host]
    if args.credentials_file:
        os.environ["SECURITYOPS_API_TOKEN"] = token_from_file(args.credentials_file, host)
    for name in args.channel or CHANNELS:
        source, commit = CHANNELS[name]
        repo_name = REPO_NAMES.get((args.host, name), name)
        path = f"/repos/{OWNER}/{repo_name}"
        repo = request(host, path)
        action = "existing" if repo else "missing"
        if repo is None and args.create_missing:
            if not os.environ.get("SECURITYOPS_API_TOKEN"):
                raise RuntimeError("SECURITYOPS_API_TOKEN is required for creation")
            if args.host == "secondary":
                source = HOSTS["primary"] + f"/{OWNER}/{name}.git"
            if source is None:
                raise RuntimeError("This primary fork must already exist with its reviewed history")
            print(json.dumps({"host": args.host, "channel": name, "action": "creating"}), flush=True)
            repo = request(host, "/repos/migrate", "POST", {
                "repo_owner": OWNER, "repo_name": repo_name,
                "clone_addr": source, "service": "git", "mirror": True,
                "mirror_interval": "8h0m0s", "private": False,
                "description": "GNU Guix channel mirror; preserve upstream history and authentication",
                "issues": False, "pull_requests": False, "releases": False,
                "wiki": False, "lfs": False})
            action = "created"
        found = (request(host, path + "/git/commits/" + commit)
                 if repo and not repo.get("empty") else None)
        print(json.dumps({"host": args.host, "channel": name, "action": action,
                          "mirror": repo.get("mirror") if repo else None,
                          "branch": repo.get("default_branch") if repo else None,
                          "pinned_commit_present": bool(found and found.get("sha") == commit)}), flush=True)


if __name__ == "__main__":
    main()
