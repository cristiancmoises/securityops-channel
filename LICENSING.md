# Licensing scope

The original Security Ops Guix channel code is GPL-3.0-or-later, as stated in
`LICENSE`, except where an individual file carries a different notice. In
particular, `vpn.scm` retains the upstream small-guix notices from which it was
vendored.

A Guix package definition does not relicense the program it packages. Each
program keeps its canonical upstream license, recorded in its package
definition and installed notices. The public Guix recipe selects a
redistributable public option; it does not put a private commercial agreement,
license key, signing key, or customer entitlement in the Guix store.

Several separately maintained, first-party Security Ops projects provide a
public copyleft option and may provide different terms through a separately
executed commercial agreement. In the local repositories inspected for this
release, that model is documented for Evelin, Evelin Cells, Esquema, VaptVupt,
VaptVupt Codec, libvuptsdk, Mirim, and Cofre Soberano PQ. Their exact public
licenses differ: VaptVupt contains AGPL and GPL scopes, VaptVupt Codec is GPL,
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
