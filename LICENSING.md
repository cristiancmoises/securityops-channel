# Licensing scope

The original Security Ops Guix channel code is GPL-3.0-or-later, as stated in
`LICENSE`, except where an individual file carries a different notice. In
particular, `vpn.scm` retains the upstream small-guix notices from which it was
vendored.

`securityops/packages/river.scm` adapts the BSD-3-Clause packaging recipes
from xmonad-wayland. Its notice is retained in
[`LICENSES/xmonad-wayland-BSD3.txt`](LICENSES/xmonad-wayland-BSD3.txt).
This exception covers the recipe code; River and its dependencies retain
their respective upstream licenses.
The River patches under `securityops/patches/` follow River's GPL-3.0-only
license; their notices are recorded in the patch files.

The integration fixtures under `tests/` carry BSD-3-Clause notices; the recipe
exception above does not change the GPL license of the River patches.

A Guix package definition does not relicense the program it packages. Each
program keeps its canonical upstream license, recorded in its package
definition and installed notices. The public Guix recipe selects a
redistributable public option; it does not put a private commercial agreement,
license key, signing key, or customer entitlement in the Guix store.

Several separately maintained, first-party Security Ops projects provide a
public copyleft option and may provide different terms through a separately
executed commercial agreement. In the local repositories inspected for this
release, that model is documented for Evelin, Evelin Cells, Esquema, Zupt, its
bundled compression codec, libvuptsdk, Mirim, and Cofre Soberano PQ. Their exact
public licenses differ: Zupt contains AGPL and GPL scopes, the bundled codec is GPL,
Mirim is AGPLv3-only, and the other named code is generally AGPLv3-or-later.

That statement is not a commercial license grant. A project-specific
commercial option exists only through a written agreement signed by the
applicable copyright holder and licensee. One agreement does not cover another
project unless its executed text says so. Dependencies, contributed code,
GNU Guix, Linux, firmware, applications, and other third-party components
retain their own licenses.

BTP is intentionally Apache-2.0 for its reference implementation and CC-BY-4.0
for its specification. Apache-2.0 already permits commercial and proprietary
use subject to its conditions; this checkout does not declare a separate BTP
commercial-license option.

Commercial licensing inquiries for an eligible first-party component:
`sac@securityops.co`. Identify the exact project and commit. This document is a
scope summary, not legal advice.
