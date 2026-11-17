# MatLivre and MatLibre for Emacs

`(securityops packages matlivre)` exports `matlivre` (the official x86_64
Linux AppImage v0.1.9, extracted without FUSE) and `emacs-matlibre` (the
MatLibre Emacs integration). The binary is pinned by SHA-256; this is a
repackaging, not a reproducible source build. Guix manages updates. Upstream's
update helper is excluded. Upstream MIT and bundled font notices accompany
the package. The Emacs integration is GPL-3.0-or-later.

This AppImage imports `GLIBC_2.43` symbols. The recipe therefore builds a private
GNU libc 2.43 runtime as a dependency, preserving Guix's Linux loader/cache and
locale patches. It does not change the system libc. RPATH keeps the runtime
local to MatLivre rather than exporting it into child programs. The runtime
inherits Guix libc's build/test policy; application smoke tests are additional
checks, not evidence that the entire libc test suite ran.

From a checkout containing the recipes:

```sh
guix install -L . matlivre emacs-matlibre
matlivre
emacs -nw
```

Once the recipes reach your authenticated channel revision, `-L .` is unnecessary.
Add `(require 'matlivre)` to Emacs init, then `M-x matlibre`. If your Emacs
configuration changes `load-path`, add the profile's `share/emacs/site-lisp`
subdirectories. Set `matlivre-program` to the installed executable when PATH
is unavailable. `matlivre-script-mode` derives from built-in Octave mode;
activate it explicitly for `.m` files to preserve existing MATLAB/Octave modes.

| Command | Action |
| --- | --- |
| `M-x matlibre` | Open the results/command window |
| `M-x matlivre-script-mode` | Edit a script with MatLivre bindings |
| `C-c C-c` / `matlivre-run-buffer` | Run the buffer, including unsaved edits |
| `C-c C-r` / `matlivre-run-region` | Run the selected region |
| `C-c C-w` / `matlivre-workspace` | Inspect variable names, types, sizes and values |
| `C-c C-z` | Return to the command window |
| `C-c C-o` / `matlivre-open-gui` | Open a file in the upstream graphical editor |
| `matlivre-tool` | Discover and call upstream tools using JSON arguments |
| `matlivre-stop` | Disconnect; discard a headless workspace |

In the results window, `e` evaluates code, `w` lists variables, `t` opens tool
selection and `k` disconnects. Run `a=40`, then `a+2`: variables persist until
the process stops. Errors appear in the results buffer. A timeout disconnects
the session to avoid mixing a late response with the next request.

Both graphical Emacs and `emacs -nw` execute code locally using `matlivre --mcp`.
PNG figures display inline when Emacs supports images; a save button appears
in terminals. The AppImage does not ship the separate upstream `matlivre-cli`.
MatLibre uses the same upstream execution interface instead.

Upstream's stdio interface automatically connects to an already open MatLivre
window; otherwise it creates a headless workspace. Restart the connection after
opening or closing the graphical app. Available tools depend on that connection:
headless execution offers `run_code` and `get_workspace`; an open window also
provides document tools through `matlivre-tool`. Arguments and descriptions
are defined by upstream. Binary `.mlx` documents must be opened with the GUI;
they are not passed as source text. Existing `.mlx` files are never rewritten
by MatLibre. The native application window remains separate from Emacs.

Code has the permissions of your account. Run trusted code only. Scripts use
the working directory where the connection was started. Use `cd` explicitly
or restart the session from the required directory for relative file access.
Remote TRAMP execution is not provided.

## Binary build farm

The existing `(securityops build-farm ci)` discovers both exported packages:
`matlivre.matlivre.x86_64-linux` and
`matlivre.emacs-matlibre.x86_64-linux`. There is no second hardcoded target list.
A channel revision must be authenticated and evaluated before these become
live Cuirass jobs. Successful builds alone do not publish substitutes: the
existing exact-closure review and publication policy still applies.

Check the build farm's exact output narinfo before claiming availability.
On a matching channel/dependency revision, require substitutes without local builds:

```sh
guix build matlivre emacs-matlibre --max-jobs=0 --no-offload \
  --substitute-urls='https://substitutes.securityops.co https://bordeaux.guix.gnu.org https://ci.guix.gnu.org'
```

For regression verification, build both packages, run
`emacs -Q --batch -L etc/matlivre -l tests/matlivre-emacs.el -f ert-run-tests-batch-and-exit`
with `MATLIVRE_PROGRAM` set to the built executable, and check both exported
bindings in the farm inventory. Graphical rendering and terminal interaction
also require actual interactive checks; batch success alone does not prove them.
