# Authenticated Forgejo channels

The current configuration has eight channels, all with introductions and URLs
under `https://git.securityops.com.br/cristiancmoises/`:

| Channel | Purpose |
|---|---|
| guix | Base package manager and packages |
| nonguix | Nonfree firmware, drivers and packages |
| radix | Existing System module imports |
| rosenthal | Home web-package imports |
| small-guix | Existing Mullvad service integration |
| securityops | Curated packages, XLibre server, drivers and compatibility module |
| gocix | Required by small-guix |
| sops-guix | Required by gocix |

## XLibre no longer needs a separate channel

The old SecurityOps recipe inherited `(xlibre)` from an external channel. That
implementation is now bundled in SecurityOps, including the driver definitions
and configuration helpers used by the System configuration. The separate
`guix-xlibre` channel and dependency declaration have been removed. Existing
`(xlibre)` imports remain valid without changing `/etc/config.scm`.

The SecurityOps pin advances to
`5a9aec5bdf63eb1138e33621a5e0c32a3a2fc1e9`, the signed integration revision.
It also includes the earlier package updates. Other upstream pins are unchanged.
See [packaging provenance and validation](xlibre-integration.md).

## Signed small-guix fork

Both mirrors retain the workstation's existing source history:

- [Primary small-guix](https://git.securityops.com.br/cristiancmoises/small-guix)
- [Secondary small-guix](https://git.securityops.co/cristiancmoises/small-guix)

The new introduction and pin are
`59de79f673669b798f650754b629404418464784`, signed by
`0CFA 43B9 AA96 42EA AF2B E983 C4C6 61C9 ECFB 46E8`.
The checkpoint replaces the malformed authorization entry with the owner's
actual signing fingerprint and points dependencies at primary Forgejo mirrors.
The keyring branch publishes the public signing key.

Fresh clones from both Forgejo URLs passed `guix git authenticate` using this
introduction and their fetched `origin/keyring` branches.

This is an explicit trust checkpoint for the reviewed fork, not a claim that
earlier unsigned commits have become authenticated. No existing published
history was rewritten. The secondary remains an eight-hour pull mirror of the
primary and was explicitly synchronized after this change.

## Apply to root

The user channel file is updated with a backup. Local root access still requires
administrator authentication; Forgejo tokens do not grant workstation sudo.
Run the refreshed installer again, then pull:

```sh
sudo sh /home/berkeley/securityops-channel/etc/install-root-channels.sh
sudo guix pull
guix pull
```

The installer preserves the previous regular root channel file. No System/Home
reconfiguration or full local package build was run during this fix. Use your
existing substitute infrastructure for deployment.

## Validation

The channel validator requires the exact eight-channel set, primary-only URLs,
revision pins and an introduction for every channel:

```sh
guix repl etc/validate-channel-config.scm.in
guix repl -L . etc/package-inventory.scm.in
guix repl -L . etc/validate-xlibre.scm.in
```

The XLibre server derives using only the SecurityOps checkout. The old standalone
XLibre mirror repositories are preserved but no longer used by this channel list.
