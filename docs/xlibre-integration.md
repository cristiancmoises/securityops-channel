# XLibre is part of SecurityOps

The separate `guix-xlibre` channel is no longer required. SecurityOps includes
the server recipe, driver definitions, source pins and configuration helpers.
Both `(securityops packages xlibre)` and the compatibility `(xlibre)` module
are provided by this repository, so existing System imports continue to work.

## Packaging provenance

The compatibility implementation was integrated from spacecadet's
`guix-xlibre` revision `09edbfa3c5c4eaafbbb1947445c219ac53c465a6`:
`https://gitlab.vulnix.sh/spacecadet/guix-xlibre.git`.
Original package descriptions, per-package licenses and driver source hashes
are retained. The server uses SecurityOps' existing 25.2.2 source/hash; the
obsolete pre-gen4 Intel patch remains removed. Driver versions are unchanged.

This replaces the previous overlay that inherited an external channel recipe.
The bundled compatibility module also exports driver packages beyond the
52-entry curated package index.

## Validation and deployment

The server derivation and channel inventory evaluate with `-L .` alone; no
external XLibre checkout is needed. The default driver module set is retained.
No full local build or system reconfiguration is performed during this change.

```sh
guix build -d --no-grafts --no-substitutes -L . \
  -e '(@ (securityops packages xlibre) xlibre-server)'
```

Remove the old `guix-xlibre` channel only while advancing the SecurityOps pin
to a revision containing this integration. Keeping the old SecurityOps pin
would retain the external dependency or omit the required compatibility module.
