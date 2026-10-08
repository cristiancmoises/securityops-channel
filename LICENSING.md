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

Wazuh's C/C++ core and private CPython interpreter are compiled from source,
but upstream dependency libraries and Python wheels remain pinned binaries.
Indexer, dashboard, Filebeat, Java and Node adapt official binary distributions.
The packages retain their original notices and source directions, including
MITRE data terms; the recipes' license fields summarize multiple component
licenses, not one common grant. The exact corresponding-source mapping for
every bundled component has not been established. Before distributing binary
substitutes, verify and fulfill each applicable source, build-instruction and
notice obligation. Publication of these recipes is not authorization or
certification for distributing the resulting binaries.

PHIVE preserves the original eight framework JARs, dependency JARs, published
sources, POMs and notices. Its Apache-2.0 framework does not relicense Saxon
(MPL-2.0), JAXB/activation (EDL-1.0), SchXslt and other dependencies. XMLresolver's
original XML/DTD data retains its distinct W3C Software and Document notice.
Exact full-source/legal supplements are installed under `share/phive`; the
separate test output retains JUnit EPL-1.0 and Hamcrest BSD notices. These
technical inventories and byte pins are not signer authentication or a blanket
legal certification. The package adapts published artifacts, not a Maven rebuild.

OpenPACE retains GPL-3.0-or-later and the exact section-7 OpenSSL/OpenSC linking
permissions and corresponding-source clauses from its original header. Its output
includes the original OpenPACE archive, the official OpenSSL 3.5.9 gzip archive
and the effective Guix-patched OpenSSL source as a separate Zstandard archive.
The included OpenSSL source keeps Apache-2.0 terms; clearing transformations on
the archival-only origin does not remove patches from the actual crypto input.
These preserved sources and notices are not a blanket legal certification.

AusweisApp retains EUPL-1.2. Its native Qt libraries retain their inherited
LGPL-2.1/LGPL-3 notices and original license files. The pinned upstream fixes
and two Qt patch files do not place Qt under the channel recipe's GPL license.
This package is compiled from source; its packaging does not grant rights
over identity data or certify a card, provider or qualified authentication flow.

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
