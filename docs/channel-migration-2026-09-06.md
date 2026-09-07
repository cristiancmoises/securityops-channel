# Channel mirror migration — 2026-09-06

Historical report. The [authentication fix](channel-authentication-fix.md)
supersedes its nine-channel list, unsigned small-guix pin and external XLibre
requirement. The current configuration has eight authenticated channels.

## Configuration policy

The workstation's user channel file now uses only repositories under
`https://git.securityops.com.br/cristiancmoises/`. The matching configuration
is [channels-primary.scm.in](../etc/channels-primary.scm.in).

Existing user revision pins and authentication introductions are preserved.
XLibre is explicitly included at the revision already used by the local checkout,
on the new `workstation-pinned` branch. This source migration does not perform
`guix pull`, System reconfiguration, or Home reconfiguration.

In particular, the SecurityOps pin remains `98df294`; the later package updates
in `d85fc35` require deliberately advancing that pin before pulling. A URL change
alone does not install newer packages.

## Retained channel set

All nine entries are needed by the current configuration or its dependencies.
No channel was removed merely because its packages are imported indirectly.
External and local-file URLs were replaced; the unused, commented XLibre entry
was replaced by an active, verified entry.

| Channel | Reason retained | Primary repository | Secondary repository |
|---|---|---|---|
| guix | Base package manager, packages and services | `guix` | `guix` |
| nonguix | NVIDIA, firmware and nonfree package integration | `nonguix` | `nonguix` |
| radix | System imports, including its xdisorg module | `radix` | `radix-channel` |
| rosenthal | Home imports its web packages, including Forgejo | `rosenthal` | `rosenthal` |
| small-guix | Existing Mullvad packages and service imports | `small-guix` | `small-guix` |
| gocix | Declared dependency of small-guix | `gocix` | `gocix` |
| sops-guix | Declared dependency of gocix | `sops-guix` | `sops-guix` |
| guix-xlibre | System imports `(xlibre)`; newer SecurityOps revisions also depend on it | `guix-xlibre` | `guix-xlibre` |
| securityops | Curated packages and services | `securityops-channel` | `securityops-channel` |

Both columns are under the `cristiancmoises` account on their respective forges.
The secondary forge already reserved `/radix` as a redirect to `longdong`;
`radix-channel` avoids overwriting that existing repository or its redirect.

## Mirror behavior

New upstream mirrors on the primary forge use Forgejo pull mirroring with an
eight-hour interval. New secondary mirrors pull from the primary namespace,
also every eight hours. Upstream sources remain configured on the mirror server
so it can obtain updates; they are not active workstation channel URLs.

The primary `small-guix` repository is a preserved local fork, not an upstream
pull mirror: its former remote no longer existed, and its reviewed pinned
commit was recovered from the local checkout. The secondary is a pull mirror
of that preserved fork.

Existing `guix-xlibre` and `securityops-channel` repositories remain ordinary
repositories, with their existing publication workflows. No automatic
force-push synchronization was added to those forks. XLibre's existing `master`
branch was preserved, and the required historical revision was added on
`workstation-pinned` on both forges.

## Authentication and verification

All nine pinned commit objects were verified on the primary forge. Its seven
authenticated channels retain their keyring branches. The existing unauthenticated
small-guix and XLibre pins remain explicit; this migration does not invent new
trust introductions for them.

The secondary Guix import also completed after its CPU-intensive indexing stage.
All nine pinned commits are verified on the secondary forge, and the seven
authentication keyring branch hashes match the primary forge. The initial API
timeout did not mean that the server-side import had failed.

The dependency metadata at the pinned revisions was inspected. The complete
dependency closure is listed explicitly, so Guix's breadth-first resolution uses
the user-provided pinned URLs instead of adding upstream URLs for the same names.
Upstream history and signed metadata were not rewritten. The SecurityOps
repository's own dependency URLs now point to the primary mirrors.

Scheme validation checks the exact nine-channel set, primary-only URLs and
nonempty revision pins. A full authenticated pull and deployment remain the
owner's next step; mirror-object checks are not a claim that a new Guix profile
was built or activated.

## User and root configuration

User configuration:

- Active file: `/home/berkeley/.config/guix/channels.scm`.
- Backup: `/home/berkeley/.config/guix/channels.scm.pre-forge-migration-20260906`.

Local root configuration has **not** been changed: local sudo authentication
was unavailable. Forgejo root access through `ev shell ct118` does not grant
root access to the workstation.

After reviewing the shared channel template, install it for root with:

```sh
sudo sh /home/berkeley/securityops-channel/etc/install-root-channels.sh
```

The installer backs up an existing regular root channel file and refuses to
replace a symlink without inspection. It installs the same reviewed baseline as
the user configuration. Root's installed Guix was older (`d1e9e23`), while the
user template pins `fe590af`; installing the file does not itself update root's
installed Guix.

## Maintenance tools

The [migration prompt](../etc/channel-migration-prompt.md) describes the workflow.
The API helper is read-only unless `--create-missing` is supplied:

```sh
python3 etc/mirror-channels.py --credentials-file /home/berkeley/key --host primary
python3 etc/mirror-channels.py --credentials-file /home/berkeley/key --host secondary
guix repl etc/validate-channel-config.scm.in
```

Credentials are read from the explicitly supplied file, never embedded in
tracked files or Git remote URLs. Existing repositories are not replaced by the
helper. A failed request must be re-audited before retrying creation because a
server-side migration can finish after the client times out.

Reference: [Forgejo repository mirrors](https://forgejo.org/docs/v16.0/user/repo-mirror/).
