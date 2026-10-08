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

The River integration fixtures under `tests/` carry BSD-3-Clause notices; the recipe
exception above does not change the GPL license of the River patches.

A Guix package definition does not relicense the program it packages. Each
program keeps its canonical upstream license, recorded in its package
definition and installed notices. The public Guix recipe selects a
redistributable public option; it does not put a private commercial agreement,
license key, signing key, or customer entitlement in the Guix store.

Lacuna's Web PKI RPM declares MIT in its package metadata but does not include
a separate license text. Its self-contained .NET application bundles third
party components whose individual notices were not separately audited here.
The channel fetches the RPM by hash and does not vendor or relicense it.

Arduino IDE and RustDesk retain the upstream copyleft licenses and bundled
third-party notices. Their recipes adapt official binaries; they do not rebuild
the applications. Arduino installs source directions and its license text;
RustDesk includes matching recursive source checkouts and dated packaging-change
notices. This does not establish that every embedded dependency's Corresponding
Source has been collected. Before distributing binary substitutes, review and
satisfy the applicable source-availability and notice requirements, including
required dependency sources and build instructions. Publishing these recipes
is not a blanket certification of binary-distribution compliance.

ngspice retains its inherited upstream license families; Zabbix retains AGPLv3.
Zabbix Java Gateway preserves five bundled upstream dependency JARs under
their respective Apache, MIT, BSD and Logback dual-license terms. These are
binary dependencies; publishing the recipe does not certify their complete
source-availability compliance. The PDF service uses a separately licensed
Google Chrome package as an external runtime dependency.
The new fixtures use their individual notices or the channel's default license,
not the River-specific exception above.

AutoFirma is distributed under GPL-2.0-or-later or EUPL-1.1. The package
reuses the official Linux distribution and retains its JAR and bundled
third-party license notices. Those dependencies keep their own licenses;
the package definition lists their license families, not a new license grant.
Building AutoFirma from source would require separately packaging its Maven
dependency graph and is not implemented by this recipe.
Its private Eclipse Temurin Java 17 runtime preserves the upstream GPL-2.0
license with the Classpath exception and the full third-party legal notices.

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
