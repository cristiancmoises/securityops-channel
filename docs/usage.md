# Usage reference

Operational examples for GNU Guix System and Guix Home. For current versions
and validation, see [the package index](../PACKAGES.md).

## WhatsAppel: Emacs workspace and Guile bridge

The `whatsappel` package provides the 3.3.1 Emacs client, Python workers and
Guile bridge. Its independent module is `(securityops packages whatsappel)`;
`(securityops packages applications)` re-exports the same package binding.

```sh
guix package -L . -e '(@ (securityops packages whatsappel) whatsappel)'
whatsappel --help
```

Run `whatsappel` to launch your selected graphical Emacs with the existing
init. In an already running Emacs, use `M-x whatsapp`, or load
`(require 'whatsapp)` before using its `whatsappel` alias. The five Lisp
modules and their worker scripts remain together in the installed directory;
there is no dependency on an editable source checkout.

Configure bridge access in your existing Emacs init or protected runtime
environment. `whatsappel-bridge` requires bridge and wuzapi credentials in
its environment; it does not read or copy your source checkout's `.env`.
Installation does not start listeners, pair accounts, register callbacks,
send messages, change Guix Home, or replace your existing service.
Keep the bridge on loopback unless a separate authenticated deployment has
been configured. wuzapi remains a separately configured backend.

The package pins its Python and FFmpeg paths and provides Guile JSON/TLS and
SQLite to the bridge. External playback needs mpv separately. The optional
Rust `pqenv` helper is not included: do not expect post-quantum envelope
operations without separately installing and configuring that helper.

Build checks run `make check-client check-bridge check-python` in private
state, followed by installed-client, launcher and bridge-load checks.
The recipe also corrects a missing validation-exception handler in the send
worker. An invalid bridge URL returns a structured JSON error without a
traceback or a send attempt; an installed-worker regression checks this case.
Recipe and migration checks:

```sh
guix repl -q -L . tests/whatsappel-packages.scm
guix repl -q -L . tests/securityops-tools-packages.scm
python3 tests/package-inventory.py
```

Validation uses Emacs 31.1 and synthetic local fixtures, not live account
pairing, recipient delivery or graphical/media device certification.
The upstream minimum Emacs 28.1 was not independently tested here.

## Electronics

| Package | Version | Module | Interface |
|---|---|---|---|
| `ngspice`, `libngspice` | 47 | `(securityops packages electronics)` | Netlist simulator and shared C API |
| `arduino-ide` | 2.3.10 | `(securityops packages arduino)` | Desktop IDE and bundled `arduino-ide-cli` |

### Circuit simulation

Select the channel recipe explicitly from a checkout:

```sh
guix package -L . -e '(@ (securityops packages electronics) ngspice)'
ngspice -b circuit.cir
```

The simulator is an alternative circuit engine, not an LTspice-compatible
schematic editor. Supply a netlist or use a separately configured schematic
frontend. The CLI and library use the same release. Native builds test an
installed-header C program, a DC divider, an analytic RC transient, and an
upstream stop/resume regression. The checker also rejects interpreter errors
even when ngspice prints a success marker and exits zero.

Recipe checks: `guix repl -L . tests/ngspice-packages.scm`.

### Arduino IDE

```sh
guix package -L . -e '(@ (securityops packages arduino) arduino-ide)'
arduino-ide
arduino-ide-cli version
```

The x86_64-linux launcher provides an FHS environment for the official bundle
and the toolchains later downloaded by Board Manager. It requires a running
Guix daemon and unprivileged user namespaces. Your home, working directory,
display, network and selected device sockets are shared; this is compatibility
layout, not security isolation. Board packages and libraries are separate
downloads. Host serial permissions and access to hardware remain administrative
tasks; serial devices connected after launch may require restarting the IDE.

The upstream bundle contains unsupported Electron 30.1.2/Chromium 124, and
Theia disables its renderer sandbox. No global `--no-sandbox` switch is added,
but that does not repair upstream renderer isolation. Cortex-Debug includes
a legacy serial-console module whose runtime compatibility is unverified.
Do not interpret the latest IDE release as a security-supported runtime.

Verification covers the editor displaying Blink under Xvfb and a real Uno
compilation after downloading AVR 1.8.8. It does not cover upload, debugging
or physical-device hotplug. Repeat the compile in disposable state, without
a board or changes to your Arduino configuration:

```sh
output=$(guix build -L . -e '(@ (securityops packages arduino) arduino-ide)')
sh tests/arduino-runtime.sh "$output"
```

The test downloads toolchains and prints the retained state directory; use
an adequately sized `TMPDIR`. Metadata: `guix repl -L . tests/arduino-packages.scm`.
The graphical fixture needs Node 22+ and `xvfb-run` with the package closure.

## Remote desktop

Both packages are in `(securityops packages remote-desktop)`. Their releases
are independent: client 1.4.9 and Server OSS 1.1.16.

```sh
guix package -L . -e '(@ (securityops packages remote-desktop) rustdesk)'
guix package -L . -e '(@ (securityops packages remote-desktop) rustdesk-server)'
rustdesk --version
hbbs --help
hbbr --help
```

`rustdesk-server` includes rendezvous server `hbbs`, relay server `hbbr` and
`rustdesk-utils`. Installing them does not start listeners, create production
keys, install a privileged service or grant remote access. Configure persistent
state, server keys, authenticated clients, firewall rules and service accounts
separately before exposing a deployment.

The packages adapt official binaries, preserve matching source checkouts with
submodules, and retain upstream notices. Client ELF paths and subprocess tools
are scoped to the application; no global library paths or PAM configuration
are changed. See [licensing boundaries](../LICENSING.md) before distributing
binary substitutes.

Tests cover client startup under a private Xvfb, server TCP/WebSocket readiness
and actual peer registration in a private `hbbs` database while `hbbr` runs.
They do not demonstrate an authenticated desktop session, relayed screen data,
remote input, audio or Wayland capture. The runtime fixture refuses ordinary
host execution: use a Guix container whose only network interface is loopback
and whose profile contains the complete tested packages and test tools.

Metadata: `guix repl -L . tests/rustdesk-packages.scm`.
Runtime modes are documented by `python3 tests/rustdesk-runtime-test.py --help`.

## Monitoring

The Zabbix 7.4.15 components share one verified source release in
`(securityops packages zabbix)`.

| Package | Provided component |
|---|---|
| `zabbix-agentd`, `zabbix-agent2` | Classic and Go collectors |
| `zabbix-server` | PostgreSQL server; separate `front-end` and `schema` outputs |
| `zabbix-proxy` | SQLite proxy and its `schema` output |
| `zabbix-java-gateway` | Java/JMX collector with a foreground launcher |
| `zabbix-web-service` | Scheduled PDF report renderer with pinned Chrome |
| `zabbix-get`, `zabbix-sender`, `zabbix-js` | Query, submission and local JavaScript commands |

```sh
guix package -L . -e '(@ (securityops packages zabbix) zabbix-agent2)'
guix build -L . -e '(@ (securityops packages zabbix) zabbix-server)'
```

The build command returns the server, `front-end` and `schema` store paths.
For all components, frontend, schemas, PostgreSQL and PHP, use the dedicated
manifest in a separate profile so your existing default profile is unchanged:

```sh
mkdir -p "$HOME/.guix-extra-profiles/zabbix"
guix package -L . -p "$HOME/.guix-extra-profiles/zabbix/profile" \
  -m etc/zabbix-manifest.scm.in
```

The PDF service and therefore this complete manifest require x86_64-linux,
matching the supported Chrome archive.

The frontend is installed at `share/zabbix/php`; its immutable maintenance
template remains available before setup. The administrator-managed database
configuration is `/etc/zabbix/zabbix.conf.php`, and certificate configuration
is `/etc/zabbix/certs`. Package installation does not initialize databases or
enable a web server, collector, monitoring target or production credentials.
Provision TLS, least-privilege accounts, persistent state and an appropriate
PHP/web-server deployment separately.

Native builds and temporary loopback tests cover both collectors, PostgreSQL
schema initialization, server startup, SQLite proxy initialization and PHP 8.4/8.5
setup rendering. The tests do not constitute a complete production deployment
or a metrics-to-dashboard acceptance test. Metadata:
`guix repl -L . tests/zabbix-packages.scm`.

### Java and scheduled reports

The gateway installs `zabbix-java-gateway` for foreground service supervision,
along with the upstream example settings and startup scripts. Configure
`zabbix.*` JVM properties through `JAVA_TOOL_OPTIONS`. The runtime is Guix's
OpenJDK 25.0.2; the five bundled Android JSON, Logback, SLF4J and dnsjava JARs
retain their own licenses. They are upstream binaries, not locally rebuilt
dependencies. Java version updates and production JMX authentication/TLS need
their own review.

The web service installs `zabbix_web_service`; explicitly supply its configuration
with `-c`. It uses the channel's Chrome release for PDF rendering. Run it under
an unprivileged dedicated account. Set `AllowedIP`, certificate-based TLS,
the server's `WebServiceURL` and report writers, and the frontend URL before
enabling scheduled reports. The upstream listener has no `ListenIP` setting;
restrict its network exposure with a firewall or isolated network namespace.
Do not expose it as an unauthenticated public rendering endpoint. See the
[upstream report setup](https://www.zabbix.com/documentation/7.4/en/manual/config/reports).

Isolated tests perform real Java/JMX queries, verify peer/path rejection,
generate a PDF from a local dashboard fixture and check its extracted text.
They do not prove production TLS, arbitrary dashboards or scheduled e-mail
delivery. The extra fixture rejects ordinary host execution:
`python3 tests/zabbix-extra-runtime.py --help`.

## Wazuh

The channel packages Wazuh 4.14.8, matching indexer/dashboard 4.14.8-1 and
the compatible Filebeat 7.10.2-2 distribution for x86_64-linux.

| Role | Module export | Installed command |
|---|---|---|
| Endpoint | `(securityops packages wazuh)` → `wazuh-agent` | `wazuh-agentd`, `wazuh-control` and endpoint tools |
| Manager | `(securityops packages wazuh)` → `wazuh-manager` | Native core tools, `wazuh-apid` and `wazuh-control` |
| Indexer | `(securityops packages wazuh-search)` → `wazuh-indexer` | `wazuh-indexer`, `wazuh-indexer-securityadmin` |
| Dashboard | `(securityops packages wazuh-search)` → `wazuh-dashboard` | `wazuh-dashboard` |
| Alert forwarding | `(securityops packages wazuh-search)` → `wazuh-filebeat` | `wazuh-filebeat`; package name `filebeat` |

### Separate installation profiles

From a channel checkout, select all four server packages without replacing
your default profile:

```sh
mkdir -p "$HOME/.guix-extra-profiles/wazuh-server"
guix package -L . -p "$HOME/.guix-extra-profiles/wazuh-server/profile" \
  -m etc/wazuh-manifest.scm.in
```

On an endpoint, use a separate profile:

```sh
mkdir -p "$HOME/.guix-extra-profiles/wazuh-endpoint"
guix package -L . -p "$HOME/.guix-extra-profiles/wazuh-endpoint/profile" \
  -e '(@ (securityops packages wazuh) wazuh-agent)'
```

Do not install the endpoint package alongside the manager in one profile:
their commands and libraries overlap. Installation does not initialize
mutable state, register accounts or certificates, start listeners or create
a Guix System service. The complete server manifest was actually installed
with default Guix grafts and without a collision override.

### Core state and API initialization

Native tools and the private Python framework use an explicit absolute
`WAZUH_HOME`. Provision the appropriate immutable `share/wazuh` templates,
configuration, keys, databases, queues and service-account permissions before
starting processes. Keep binaries/libraries in the Guix store; writable data
must live outside it. Preserve upstream privilege separation and chroot
requirements; changing the environment variable alone is not a deployment.

The supplied and canonical state path and its ancestors must be safely owned
and not group/world-writable. Root-owned sticky ancestors such as `/tmp` are
allowed, but the selected state itself cannot be writable by others. Root-run
executable aliases also require root-owned, non-writable ancestry.
`wazuh-control` accepts only ASCII letters, digits, `/`, `_`, `.` and `-` in
both the supplied and canonical state path. Native tools' path handling is
not a reason to bypass that control-script restriction.

The first manager API startup requires an explicitly provisioned regular,
private `api/configuration/security/initial-users.yaml` under `WAZUH_HOME`.
Retain the reserved `wazuh` and `wazuh-wui` accounts with independently chosen
passwords of at least 16 characters and an explicit boolean `allow_run_as`
policy; own the file as root or the API account and use mode 0600. Existing
RBAC databases keep their authentication policies. No public example password
is activated as a first-boot default. Provision HTTPS and private key ownership
for the account the API actually runs under.

### Search state, credentials and TLS

Each search launcher requires its own existing `WAZUH_SEARCH_STATE` directory,
owned by its service account with mode 0700, containing `config`, `data` and
`logs`. Configuration/state must remain beneath that directory and have safe
ownership; credential-bearing files must be private. Indexer and dashboard
must run under non-root accounts.

| Component | Required configuration |
|---|---|
| Indexer | `config/opensearch.yml`, TLS/hostname verification, enabled security plugin and private `config/opensearch-security/internal_users.yml`; no demo initialization |
| Dashboard | Private `config/opensearch_dashboards.yml`, HTTPS, explicit indexer credentials/full peer verification; private `data/wazuh/config/wazuh.yml` and `config/manager-ca.pem` for the manager API |
| Filebeat | Private `config/filebeat.yml`, HTTPS indexer credentials/full peer verification and a private byte-identical copy of the installed `module/wazuh` |

The dashboard manager client validates the selected CA and does not forward
authenticated requests through redirects. Ambient Node TLS bypass/startup
options are removed. Filebeat retains its native default-deny seccomp filter
and `NoNewPrivs`; only its private libc's compatible thread-creation path and
process-local `rseq=0` are selected. No global libc or kernel policy changes.
Even `--version` through these launchers requires explicit state/configuration.

### Validation boundaries

The installed stack passed an isolated QEMU guest test using an already-synced
default group, actual endpoint/manager processes, encrypted event transport,
native rule/CDB/MITRE processing, authenticated syscollector queries, real
Filebeat forwarding and authenticated indexer/dashboard/manager requests.
Invalid state metadata, credentials, JWTs and CAs were rejected. The endpoint
control socket was present with active response disabled; no response actions
or changed-configuration lifecycle reload were tested.

Cluster operation, cloud integrations, live vulnerability feeds, inventory
export directly to the indexer and production SSO/TLS remain outside this test.
The optional OpenSCAP helper is unavailable. Diagnostic logs are retained,
including the VM initrd fallback and the unprovisioned inventory/indexer path;
passing the tested flow does not mean the logs contain no warnings.

The C/C++ core and CPython are native builds, but upstream dependency libraries
and Python wheels remain pinned binaries. Search components and Java/Node
adapt official distributions. CPython 3.10.22 and Node 18.20.8 are upstream EOL;
Java 21.0.12.1 and Filebeat 7.10.2 are compatibility pins, not claims that every
dependency is globally latest. Review those limits before a production
deployment and the [licensing scope](../LICENSING.md) before binary distribution.

Non-privileged metadata and inventory checks from the checkout:

```sh
guix repl -L . tests/wazuh-packages.scm
guix repl -L . tests/wazuh-manifest.scm
python3 tests/package-inventory.py
```

The runtime fixtures deliberately refuse ordinary host execution.
`tests/wazuh-core-runtime.py` requires a disposable QEMU guest with loopback
only and a dedicated Wazuh account; the search/TLS fixtures require a private
loopback-only environment and an unprivileged account. They are acceptance
tools, not production provisioning scripts.

## AutoFirma

The channel provides the official stable **Linux release, 1.9**, through
`(securityops packages autofirma)`. The 1.9.1 and 1.9.2 downloads are macOS
releases, not Linux upgrades. See the [official downloads](https://firmaelectronica.gob.es/descargas).

Installation is optional and separate from adding the channel:

```sh
guix install autofirma
autofirma
autofirmacl -help
```

### Runtime and certificates

The recipe preserves the official signed JAR and its bundled Java libraries.
It uses a private, Guix-linked Eclipse Temurin **17.0.20.1+1** runtime rather
than depending on whichever Java version happens to be in your profile.
NSS 3.129 and NSPR 4.40 reuse the channel's LibreWolf inputs; the native
library directory also includes SQLite 3.53.4. The package exposes the
standard NSS `certutil` command and makes the matching tools available to
AutoFirma's Java subprocesses.

It includes a desktop entry for `afirma://` links, but does not register it as
your default handler. It does not run privileged installer scripts, import
certificates or alter Firefox settings. Browser signing requires separate
provisioning and trust of the local-service certificate; smart cards require
a running PC/SC service.

### Launchers and external documents

The graphical launcher and command-line operations using `-store mozilla`
or `-store auto` (the default) use Bubblewrap to supply conventional NSS paths
and a readable `/opt` without changing the host filesystem. They require
unprivileged user namespaces. This is a compatibility layout, not a security
sandbox: your home, network and selected display, session-bus and PC/SC sockets
remain accessible. Help, signature verification and explicitly selected
non-NSS stores, such as `-store pkcs12:…`, run directly without this layout.

Documents in your home are available by default. To select documents from
other existing directories, explicitly share them before launching:

```sh
AUTOFIRMA_SHARED_DIRECTORIES="/mnt/documents:/media/archive" autofirma
```

Use absolute directory paths separated by colons. Broad system roots and
invalid paths are rejected; spaces within a directory name are supported.
NSS-backed command-line operations preserve your working directory and
relative document paths. Run them from your home or an explicitly shared
directory:

```sh
cd /mnt/documents
AUTOFIRMA_SHARED_DIRECTORIES="/mnt/documents" \
  autofirmacl listaliases -store mozilla -xml
```

### Verification

The command-line checks use disposable PKCS12 and NSS identities. They list
the NSS aliases through both launchers and independently verify detached
signatures with OpenSSL, including relative paths and a home containing
spaces. An isolated Java test checks that AutoFirma can run `certutil` inside
the compatibility layout. No personal certificates or live preferences are
used. Separate tests exercise Java subprocess creation and reject eight
invalid directory shares.

Desktop metadata and GUI startup under Xvfb have also been checked. Signing
through the graphical interface, smart cards, Wayland and end-to-end browser
integration remain untested.

To verify the package without installing it:

```sh
output=$(guix build -L . -e '(@ (securityops packages autofirma) autofirma)')
guile -s tests/autofirma.scm.in "$output"
bash tests/autofirma-gui.sh "$output"
```

The NSS integration test is `tests/autofirma-nss.sh`. Pass the package output
and the matching NSS tools output as its two arguments; it also needs OpenSSL
and Java 17's `javac` and `jar` on `PATH`. Run it outside the Guix build sandbox,
where unprivileged user namespaces are available. Normal builds retain Guix's
default grafting and substitute authentication.

## Structured reporting

| Package | Version | Module | Interface |
|---|---|---|---|
| `arelle` | 2.46.0 | `(securityops packages reporting)` | `arelle`, upstream `arelleCmdLine` and Python modules |

### Offline XBRL validation

Select the channel recipe explicitly when installing from a checkout:

```sh
guix install -L . -e '(@ (securityops packages reporting) arelle)'
arelle --file instance.xbrl --validate \
  --internetConnectivity=offline --disablePersistentConfig \
  --plugins=inlineXbrlDocumentSet --logFile report.json
```

Provide any required taxonomy locally. Offline mode refuses missing remote
resources rather than fetching them. Inspect the JSON log for `error` and
`critical` entries: upstream Arelle can exit zero even for an invalid document.
The package retains its plugins and standard-schema cache; it does not install
SBR-NL or other national taxonomies automatically.

### Verification and graphical scope

The build passes 5,424 selected upstream tests, not the entire conformance
suite. Installed acceptance validates real local XBRL, a missing-context
negative, an explicit offline refusal, Python-library fact values, plugin/cache
availability and the actual XML/XSLT/TLS versions. Dependency ranges and script
entry points are checked without skipping or weakening upstream requirements.

The original Linux TkTable payload is replaced by the tested, source-built
2.12.1 widget and its required copyright notice. Private Xvfb tests cover
graphical entry-point loading and table editing/reading on x86_64. They do not
prove a complete graphical workflow, optional-plugin integration or live
regulatory acceptance.

From a checkout, repeat installed acceptance without installing or using your
own display, configuration or credentials:

```sh
guix build -L . -e '(@ (securityops packages reporting) arelle)'
guix build -L . -f tests/reporting-acceptance.scm.in --check
```

The acceptance builder uses a private display, scratch Home and an allowlisted
environment in the network-isolated Guix sandbox. Resource limits apply before
target imports or execution. `--check` repeats this deterministic marker-only
build even if an earlier successful result exists; timestamped validation logs
remain in the build output, not in the marker.

## Identity and official schema data

These packages are optional. They do not activate services, import certificates
or change user, Home or system profiles when you add the channel.

| Package | Module | Installed interface |
|---|---|---|
| `libdigidocpp` 4.5.1 | `(securityops packages eid)` | Native library, headers and upstream `digidoc-tool` |
| `digidoc4` 4.11.1 | `(securityops packages digidoc4)` | Native Qt desktop, `qdigidoc4`, desktop entry and signed bootstrap |
| `eid-mw` 5.1.31 | `(securityops packages belgian-eid)` | Belgian eID GTK3 viewer and `lib/libbeidpkcs11.so` |
| `ausweisapp` 2.6.0 | `(securityops packages ausweisapp)` | Native `AusweisApp` desktop and loopback SDK |
| `openpace` 1.1.4 | `(securityops packages openpace)` | Native `libeac.so.3`, C headers, `libeac.pc` and CVC tools |
| `icp-brasil-roots` 2026.10.05 | `(securityops packages icp-brasil)` | Explicit-purpose PEM bundles and original public root data |
| `esocial-schemas` 1.3-20260701 | `(securityops packages brazil-tax)` | `share/esocial/events`, S-1.3 / NT 06/2026 |
| `esocial-communication-schemas` 1.6 | `(securityops packages brazil-tax)` | `share/esocial/communication`, separate envelope/WSDL format |

### Native identity library

Use the channel module explicitly in a manifest to distinguish it from an older
Guix package with the same name:

```scheme
(use-modules ((securityops packages eid) #:prefix eid:) (guix profiles))
(packages->manifest (list eid:libdigidocpp))
```

The library supports DigiDoc/ASiC operations; it is not the DigiDoc4 desktop
application or an all-in-one Open-EID installation. Installed acceptance checks
create and reopen containers, validate signed local fixtures, and reject
tampered timestamps, forged keys, ZIP truncation and unsafe paths. The actual
loaded libxml2, libxslt and OpenSSL versions are checked after default grafting.
Smart cards, live SiVa/OCSP/TSA, online renewal and fresh legal trust decisions
are not covered by these offline tests.

To build from a checkout and freshly check the completed, default-grafted
library without installing:

```sh
library=$(guix build -L . -e '(@ (securityops packages eid) libdigidocpp)')
SECURITYOPS_EID_OUTPUT="$library" guix build -L . \
  -e '((@@ (securityops packages eid) libdigidocpp-acceptance-for)
       (getenv "SECURITYOPS_EID_OUTPUT"))' --check
```

The explicit store path prevents a grafted or cached acceptance marker from
standing in for execution against the completed library. `--check` repeats
the deterministic acceptance build even when its result already exists.

### DigiDoc4 desktop

Install the desktop separately from the library:

```sh
guix install digidoc4
qdigidoc4
```

The native Qt application includes libdigidocpp 4.5.1 and libcdoc. Its own XML
input is aligned with the signature library: libxml2 2.15.4, libxslt 1.1.45 and
OpenSSL 3.5.9 are checked in the running process after default grafting. The
signed public configuration bootstrap has serial 212; invalid cached payloads
are rejected and replaced. TLS errors are not ignored.

The embedded EU list was issued on 24 September 2026 and has its next update
on 17 March 2027. There is no newly bundled Estonian country list. Country
trust lists retain upstream's signed online update flow, so first-use signature
validation can require internet access. The application does not import its
bootstrap or Mozilla certificate data into the system trust store. A running
PC/SC service and supported reader are required for card operations.

The desktop was tested in an unprivileged, loopback-only container with Xvfb:
an unsigned ASiC-E with a proper manifest displayed its payload and missing
signatures; malformed input displayed an error. Both screenshots were inspected.
Live cards, qualified signatures, SiVa/OCSP/TSA, online country-list updates and
a live negative-TLS endpoint were not tested. This package is not the complete
Open-EID browser/driver suite.

Reproduce the graphical checks from a checkout without installing or activating
services. The private directory retains screenshots and application logs:

```sh
securityops_digidoc4=$(guix build -L . -e '(@ (securityops packages digidoc4) digidoc4)')
securityops_digidoc4_state=$(mktemp -d -t digidoc4-test.XXXXXX)
guix shell -L . -m etc/digidoc4-test-manifest.scm.in --container --no-cwd \
  --share="$securityops_digidoc4_state=/state" --expose="$PWD/tests=/tests" \
  --expose="$securityops_digidoc4" -- \
  python3 -B /tests/digidoc4-runtime.py "$securityops_digidoc4" /state
```

### Belgian eID

Select the channel recipe explicitly from a checkout:

```sh
guix shell -L . -e '(@ (securityops packages belgian-eid) eid-mw)' -- eid-viewer
```

Version 5.1.31 is the verified official Linux source release; the separate
5.1.34 Windows installers are not used. The package preserves upstream GTK3,
the PC/SC reader contract and LGPL-3.0-or-later notices. Its PKCS#11 provider is
`lib/libbeidpkcs11.so` under the package output. Applications must select that
provider explicitly; adding the package neither registers it in browsers nor
starts PC/SC.

The native check phase passed 15 tests with 27 unchanged upstream skips.
An unprivileged, loopback-only container exercised the installed PKCS#11
function table, initialization/finalization, invalid arguments and empty slots.
The viewer and its About dialog were inspected, including the displayed
5.1.31 version and the loaded OpenSSL 3.5.9/libxml2 2.15.4/GTK3 libraries.
Card readers, real cards, PIN operations, signatures, browser integration and
online update success were not tested. Those workflows require supported
hardware and a separately configured PC/SC service.

Source: [official Linux tag](https://github.com/Fedict/eid-mw/tree/v5.1.31).

### AusweisApp desktop and local SDK

Select the channel package explicitly from a checkout, rather than an older
Guix recipe with the same name:

```sh
guix build -L . -e '(@ (securityops packages ausweisapp) ausweisapp)'
guix package -L . -e '(@ (securityops packages ausweisapp) ausweisapp)'
AusweisApp
```

The application is compiled from the official 2.6.0 source. Its private Qt
6.9.2 family includes pinned upstream fixes; QML is rebuilt against the matching
SVG-private headers, while the inherited Qt checks and exclusions are retained.
Live process maps confirm the exact Qtbase, SVG and QML outputs. Matching
version numbers alone are not an ABI guarantee, and this recipe does not
upgrade Qt globally or certify that every Qt vulnerability has been addressed.

The normal SVG default is `NoOption`, not `AssumeTrustedSource`. Upstream's
explicit `QT_SVG_DEFAULT_OPTIONS` override still exists; the installed fixture
clears it to check the ordinary default, not to claim an unchangeable policy.
Adding this package does not start PC/SC, register trust anchors or configure
a reader. Real card operations require supported hardware and a separately
configured PC/SC service.

#### Checks and boundaries

| Check | Result | Boundary |
|---|---|---|
| Optimized native build | Four QML checks passed | Separate from the Debug suite |
| Native Debug suite | 368 of 370 passed | Broadcast/provider checks failed in the builder environment; the original failure is retained |
| Controlled full Debug replay | All 370 CTest entries passed; 6,571 internal cases passed | Same 300 executables and original commands; 35 original conditional skips remain |
| Installed application | Desktop inspected; local SDK, invalid inputs and Origin refusal passed | No real card, PIN or production authentication |
| Bundled images | 135 common/desktop images reached `Image.Ready` with positive dimensions: 94 SVG and 41 PNG | Not a pixel-perfect or complete composite-image check |

The controlled replay used a non-root guest with IPv4/IPv6 and access restricted
to the official test provider, without changing TLS or CVC checks. It is not an
error-free native Debug build, universal ABI proof or a hardware certification.
The detailed QML test log retains 86 logger-connection warnings, identical to
the earlier test baseline: its runner does not initialize the logger before
creating the models. The application initializes it before its controller;
these warnings were absent from the checked installed SDK/desktop logs.
Passing CTest therefore does not mean warning-free fixtures or complete coverage
of live log/notification updates inside those fixtures.
The stable desktop also preloads an invisible beta watermark. Its embedded SVG
background is refused by the SVG protection, despite both original files being
packaged. The normal stable setup screen was inspected; the beta watermark is
not certified intact. The protection is not bypassed to hide this limitation.
The first QML build wrapper timed out; the subsequent completion succeeded,
and both original receipts were preserved.

Metadata checks are available from the checkout:

```sh
guix repl -q -L . tests/ausweisapp-packages.scm
python3 -B tests/package-inventory.py
```

Reproduce the installed SDK and stable desktop checks using the seven-package
test manifest. This requires the completed output and may realize uncached
build inputs; it does not install packages into your profile or start PC/SC.
The reference lookup below is read-only. Each selected Qt path must exist as
one directory, so missing or ambiguous results stop the check.

```sh
ausweisapp_store=$(guix build -L . -e '(@ (securityops packages ausweisapp) ausweisapp)')
ausweisapp_refs=$(guix gc --references "$ausweisapp_store")
ausweisapp_qtbase=$(printf '%s\n' "$ausweisapp_refs" | sed -n '/-qtbase-6\.9\.2$/p')
ausweisapp_qtsvg=$(printf '%s\n' "$ausweisapp_refs" | sed -n '/-qtsvg-6\.9\.2$/p')
ausweisapp_qml=$(printf '%s\n' "$ausweisapp_refs" | sed -n '/-qtdeclarative-6\.9\.2$/p')
test -d "$ausweisapp_qtbase" && test -d "$ausweisapp_qtsvg" && test -d "$ausweisapp_qml" || exit 1
ausweisapp_state=$(mktemp -d -t ausweisapp-test.XXXXXX)
guix shell -L . -m etc/ausweisapp-test-manifest.scm.in \
  --container --user=ausweis-fixture --no-cwd \
  --share="$ausweisapp_state=/state" \
  --expose="$PWD/tests/ausweisapp-runtime.py=/fixture.py" -- \
  python3 -B /fixture.py "$ausweisapp_store" /state \
  --qtbase "$ausweisapp_qtbase" --qtsvg "$ausweisapp_qtsvg" \
  --qtdeclarative "$ausweisapp_qml"
```

The container has loopback only. Its private state retains the screenshot,
application logs and loaded-library evidence; inspect the screenshot as well
as the exit status. The fixture exercises normal SDK commands and refuses
invalid input and an unauthorized Origin, without cards or remote providers.

Source: [official AusweisApp 2.6.0 release](https://github.com/Governikus/AusweisApp/releases/tag/2.6.0).

### OpenPACE native EAC library

OpenPACE provides the native C library for PACE, terminal authentication and
chip authentication, plus `eactest`, `cvc-create`, `cvc-print` and the upstream
example executable. Optional language bindings are not selected. This is an
independent library package, not the Autenticação.gov desktop or a card service.

Build or install the channel recipe explicitly from a checkout:

```sh
guix build -L . -e '(@ (securityops packages openpace) openpace)'
guix package -L . -e '(@ (securityops packages openpace) openpace)'
```

OpenSSL 3.5.9 is a propagated development dependency: a consumer selecting
OpenPACE can resolve `pkg-config --cflags --libs libeac` without adding a second
crypto package. The native build preserves upstream `make check`, including
`eactest` and all three CVC utility terminal chains. Separate unprivileged,
offline checks confirmed the installed SONAME, actual loaded library paths,
context lifecycle and ordinary downstream compilation/linking.

| Path under the package output | Purpose |
|---|---|
| `lib/libeac.so.3`, `include/eac`, `lib/pkgconfig/libeac.pc` | Native C interface and development metadata |
| `share/openpace/trust/cvc`, `share/openpace/trust/x509` | Empty immutable compiled defaults; not a usable issuer trust store |
| `share/openpace/examples` | Four unchanged upstream certificate examples, separate from trust |
| `share/openpace/source` | Original OpenPACE/OpenSSL archives and effective Guix-patched OpenSSL source |
| `share/doc/openpace/license-source/eac.h` | Original linking permissions and corresponding-source clauses |

Applications must explicitly select their operator-managed certificate roots
and validation policy. The installed test's positive CVCA lookup uses a private
copy of an original example; lookup alone is not signature, chain, expiry or
legal-trust validation. Nothing is imported into host trust stores. Real cards,
readers, PINs, providers and hardware interoperability were not tested.
Upstream `eactest --version` still prints its historical 0.6 tool identifier;
the library's pinned source and `pkg-config` metadata report 1.1.4.

Reproduce the installed consumer check without changing a host profile:

```sh
openpace_store=$(guix build -L . -e '(@ (securityops packages openpace) openpace)')
guix shell -L . -e '(@ (securityops packages openpace) openpace)' \
  gcc-toolchain pkg-config python --container --user=openpace-fixture \
  --no-cwd --expose="$PWD/tests/openpace-runtime.py=/fixture.py" \
  --expose="$PWD/tests/fixtures/openpace-lifecycle.c=/probe.c" -- \
  python3 -B /fixture.py "$openpace_store" --consumer --probe /probe.c
```

The container selects OpenPACE and generic development tools only; OpenSSL
arrives through propagation. Use the complete `gcc-toolchain` without adding
a standalone `binutils`: a profile conflict can replace Guix's linker wrapper
and omit runtime search paths. The toolchain already supplies `readelf`.
The check requires a non-root UID and an isolated
network namespace, preserves exact source/example hashes and default trust,
and rejects development paths outside that profile. It does not contact an
identity provider or activate PC/SC. Metadata checks are available separately:

```sh
guix repl -L . tests/openpace-packages.scm
```

### ICP-Brasil root data

The package preserves the eight active public roots listed in the ITI registry
snapshot of October 5, 2026. It does not install intermediates, CRLs, signing
applications or an Ed521 implementation. Installation never registers trust or
changes browser, Java, Home or system certificate stores.

| Path under `share/icp-brasil` | Content |
|---|---|
| `document-signing.pem` | General roots v4, v5, v6, v12 and v13 for explicit application policy selection |
| `tls.pem` | TLS root v10 only |
| `code-signing.pem` | Code-signing root v11 only |
| `roots/` | Seven original OpenSSL-compatible certificate files and attribution |
| `reference-ed521/ICP-Brasilv7.crt` | Original v7, reference-only; not included in any usable bundle |

OpenSSL cannot verify v7's Ed521 algorithm. Its exact certificate fingerprint
is retained and checked, but its self-signature is not claimed as verified.
Do not concatenate this reference file into the provided OpenSSL bundles.
Expired roots v0/v1/v2 and revoked roots v3/v8/v9 are excluded. Bundle separation
is a packaging aid, not a substitute for certificate policy, current chains,
revocation checks or the legal requirements of a document workflow.

Get the data without changing any profile:

```sh
securityops_icp=$(guix build -L . -e '(@ (securityops packages icp-brasil) icp-brasil-roots)')
printf '%s\n' "$securityops_icp/share/icp-brasil/document-signing.pem"
guix repl -L . -- tests/icp-brasil-packages.scm
guix shell python openssl bash-minimal --container --pure --no-cwd \
  --expose="$PWD/tests=/tests" --expose="$securityops_icp" -- \
  sh -c 'python3 -B /tests/icp-brasil-runtime.py "$1" "$(command -v openssl)"' \
  sh "$securityops_icp"
```

Native checks verify the seven supported self-signatures at the registry date.
Installed checks verify original bytes and DER fingerprints, current validity,
refusal of modified signatures and invalid dates, exact purpose selections and
the actual CA loader. The v7 test requires native verification to refuse its
unsupported algorithm. These tests do not sign a document or import roots.
Original public files and ITI attribution are retained under the registry's
CC-BY-ND-3.0 terms; no endorsement or affiliation is implied.

Sources: [ITI root registry](https://www.gov.br/iti/pt-br/assuntos/repositorio/repositorio-ac-raiz),
[WebTrust algorithm/fingerprint reference, Appendix A](https://www.gov.br/iti/pt-br/assuntos/comite-gestor/iti_2019_-_webtrust_for_ca_report_consolidado.pdf).

### ICP-Brasil CA collection

`icp-brasil-ca-data` preserves the 180 original PEM files in the ITI
«Cadeia Vigente» archive dated August 26, 2026. This is a separate, opt-in
data package, not a trust store or signing client. It retains every filename
and original byte, including CRLF files and the file without a final newline.

| Path under `share/icp-brasil-ca-data` | Content |
|---|---|
| `certificates/` | 179 original CA files: 175 RSA and four Ed448 |
| `reference-ed521/ICP-Brasilv7.crt` | Unchanged unsupported Ed521 reference; never a usable trust bundle |
| `manifest.json` | Original-file hashes, DER fingerprints, algorithms and source provenance |
| `SHA256SUMS`, `NOTICE` | Integrity inventory, attribution, official archive SHA-512 and redistribution terms |

No combined bundle, trust activation, CA environment variable or profile hook
is installed. Do not turn intermediate CA files into trust anchors merely
because they appear in this archive. This dated collection is not identical
to the later root registry: choose appropriate roots and issuer certificates
for the application, and obtain current revocation information separately.

Build and inspect the data without installing it:

```sh
securityops_icp_ca=$(guix build -L . -e '(@ (securityops packages icp-brasil-chain) icp-brasil-ca-data)')
printf '%s\n' "$securityops_icp_ca/share/icp-brasil-ca-data/manifest.json"
guix repl -L . -- tests/icp-brasil-chain-packages.scm
guix shell -L . python bash-minimal \
  -e '(@@ (securityops packages tls-security) openssl-security)' \
  --container --pure --no-cwd \
  --expose="$PWD/tests=/tests" --expose="$securityops_icp_ca" -- \
  sh -c 'python3 -B /tests/icp-brasil-chain-runtime.py "$1" "$(command -v openssl)" --isolated' \
  sh "$securityops_icp_ca"
```

Native and installed tests check exact original bytes, DER fingerprints,
CA constraints, algorithm separation and the data-only layout. The isolated
test runs without privileges and with loopback-only networking. The original
ZIP was independently checked against ITI's published SHA-512; supplying it
to the runtime test with `--source-archive` also checks every original file.
These checks do not claim cryptographic chain verification, present validity,
revocation status, permitted purposes or legal acceptance. Original data
retain the registry's CC-BY-ND-3.0 attribution; no affiliation is implied.

Source: [ITI CA archive and snapshot date](https://www.gov.br/iti/pt-br/assuntos/repositorio/certificados-das-acs-da-icp-brasil-arquivo-unico-compactado).

### eSocial schema data

The event package contains 52 original XSD files effective July 1, 2026.
Communication 1.6 contains 15 XSD files, WSDL, the official response example
and change log. Both retain the original ZIP, attribution and embedded notices.
All imports resolve locally; neither data package has runtime dependencies.

Get the data directory without installing a parser or changing a profile:

```sh
events=$(guix build -L . -e '(@ (securityops packages brazil-tax) esocial-schemas)')
printf '%s\n' "$events/share/esocial/events"
guix build -L . -f tests/brazil-tax-acceptance.scm.in
```

Use an XML Schema validator with networking disabled and this directory's local
imports. A successful XSD check is not signature verification, complete business
validation or government acceptance. The S-1.3 event schemas support
alphanumeric CNPJ; communication 1.6 does not gain that support by association.
Its envelope deliberately skips embedded-event validation, so validate the event
separately. The original data is distributed unchanged under the official site's
CC-BY-ND-3.0 terms, with its original XMLDSig third-party notice preserved.

## XML validation with PHIVE

`phive` 12.2.0, in `(securityops packages phive)`, is the Java XML/Schematron
validation framework, not the unrelated PHP tool. It includes all eight
framework modules and 42 runtime dependencies, including the reference JAXB
provider. The original 50 JARs remain separate; there is no invented PHIVE CLI,
shaded JAR or national fiscal-rule bundle.

Use the explicit module expression from the checkout. Building produces both
declared outputs; installing this expression adds only the normal `out` library:

```sh
guix build -L . -e '(@ (securityops packages phive) phive)'
guix package -L . -e '(@ (securityops packages phive) phive)'
```

For your own Java application, obtain the explicit classpath and selected
runtime from the installed package. The filter selects the normal output from
the two build results. Run these commands from the checkout:

```sh
phive_store=$(guix build -L . -e '(@ (securityops packages phive) phive)' |
  sed -n '/-phive-12\.2\.0$/p')
IFS= read -r phive_classpath < "$phive_store/share/phive/classpath"
IFS= read -r phive_java < "$phive_store/share/phive/java"
```

Pass `"$phive_classpath"` to your Java compiler's `-cp` option and combine it
with your application's classes when invoking `"$phive_java"`. The selected
runtime is Temurin 17.0.20.1+1; this is a compatible fixed runtime, not a claim
that every dependency is the latest global release. Neither file configures
your shell or changes JVM policies automatically.

| Installed path | Content |
|---|---|
| `share/phive/lib` | Original runtime JARs, including JAXB services |
| `share/phive/maven` | Exact artifact POMs; not a complete Maven bootstrap repository |
| `share/phive/source` | Published sources and full-source/legal supplements |
| `share/phive/notices` | Original embedded and supplemental notices |
| `share/phive/artifacts.tsv` | Artifact coordinates and JAR/POM/source hashes |

The separate `phive:tests` output contains five test-only libraries and its own
classpath. It is not propagated into the normal runtime. The packaging adapts
published artifacts rather than rebuilding PHIVE or its dependency graph with
Maven. Original selected upstream tests are compiled separately with `--release
17`, then run against the installed JARs in an unprivileged offline container.
The 63 selected unchanged upstream cases exercise XSD/Schematron positives and
negatives, seven original nonempty VES examples, JAXB, local repository storage
and its CSV index, XML sources and XML/JSON/HTML results. This is not the entire
upstream test suite.

Use trusted VES definitions and configure XML parser/resource-resolver policies
in your application. The acceptance fixture checks explicit schema/stylesheet
resource refusals and matching owned-file positives; this does not establish
secure defaults for arbitrary callers or a process sandbox. No documents are
submitted to tax authorities, and no current Peppol, XRechnung or SBR-NL rules
are supplied by association. Preserved source hashes do not authenticate JAR
signers or certify all redistribution obligations.

## Electronic invoicing

| Package | Version | Purpose |
|---|---|---|
| `kosit-validator` | 1.6.3 | Generic scenario-based XML/Schematron validator |
| `xrechnung-validator-configuration` | 2026-08-31 | Complete offline XRechnung 3.0.2 / CEN 1.3.16 rules and convenience launcher |

Both are in `(securityops packages einvoicing)`. The configuration installs
`xrechnung-validator`, which selects its immutable `share/xrechnung/scenarios.xml`
and repository automatically. Install it only if you want these commands:

```sh
guix install kosit-validator xrechnung-validator-configuration
kosit-validator --version
mkdir -p reports
xrechnung-validator -o reports invoice.xml
```

Check both the exit code and the generated assessment report. Accepted invoices
exit 0; rejected invoices exit 1; bad arguments exit 255; configuration errors
exit 254. The complete installed tests exercise real UBL/CII positives and
business-rule negatives through XSD, CEN and XRechnung Schematron stages.
They also cover named/shared repositories, malformed XML and explicit policy
refusal of XXE, external stylesheets and entity expansion.

The original distribution JARs remain unchanged. Exact corresponding source
and third-party notices are retained under `share/kosit-validator`; a small
compiled entrypoint supplies correct argument-error exits and `--version`.
The fixed Java runtime is independent of your profile's Java and the launcher
clears JVM option/classpath injection variables. The runtime closure does not
retain the compiler/JDK used for that entrypoint.

Default resolution uses KoSIT's STRICT_RELATIVE policy and pinned local rules.
This is not a general process sandbox or a guarantee for arbitrary custom
repositories/direct API callers. Validation does not transmit invoices, prove
tax acceptance or test daemon-mode service operation. No service is activated.

Build the complete installed acceptance suite in a network-isolated Guix build:

```sh
guix build -L . -e '(@ (securityops packages einvoicing) kosit-validator-tests)'
```

Guix may reuse an existing successful result. For a separate execution, give
the acceptance derivation a new name that you have not built before:

```sh
guix build -L . -e '(begin
  (use-modules (guix gexp) (securityops packages einvoicing))
  (computed-file "kosit-validator-local-check"
    (computed-file-gexp kosit-validator-tests)))'
```

Keep its detailed `tests.log` and reports. Do not use `--check` as a functional
rerun here: upstream reports include timestamps, so byte-for-byte reproducibility
is a separate concern from validation results.

## Services

Two native **GNU Shepherd** service types for `guix system reconfigure` — the
systemd units shipped in the upstream packages are inert on Guix System, so the
channel supplies real Shepherd services:

| Service type | Module | Purpose |
|---|---|---|
| `torando-gui-service-type` | `(securityops services torando)` | Run Torando Control as root under Shepherd |
| `esquema-service-type` | `(esquema esquema-service)`, included in `esquema` | Supervise one rootless container |

Configuration and `(operating-system …)` examples follow below.

### Running torando-gui as a Shepherd service (Guix System)

Guix System runs daemons under the **GNU Shepherd**, not systemd — so the
systemd unit inside the `torando-gui` package is inert on Guix. The channel
ships a native service type in `(securityops services torando)`. Add it to your
`operating-system`:

```scheme
(use-modules (guix gexp)
             (gnu services networking)
             (securityops services torando))

(operating-system
  ;; …
  (services
   (cons* (service torando-gui-service-type)
          (service tor-service-type
                   (tor-configuration
                    ;; Supply the Tor configuration you have prepared and tested.
                    (config-file (local-file "torrc"))))
          %desktop-services)))
```

`guix system reconfigure`, then `herd start torando-gui` (or reboot). The daemon
runs as root under Shepherd, logs to `/var/log/torando-gui.log`, and serves the
token-injected UI on `http://127.0.0.1:8088/`; run the `torando-gui` launcher to
open it. It manages netfilter and `resolv.conf`, requires the `networking`
target and should be paired with `tor-service-type`.

The `torando-gui-configuration` fields are:

| Field | Use |
|---|---|
| `host` | Listen address; defaults to `127.0.0.1` |
| `port` | Web interface port; defaults to `8088` |
| `package` | Torando package used by the service |
| `config-file` | Daemon configuration file |
| `seed-config` | Initial configuration when no daemon configuration exists |
| `extra-options` | Additional daemon arguments |

Guix generates Tor's configuration in the read-only store. The Torando service seeds
its own `/etc/torando-gui/config.json` only when that file is absent, with
`manage_torrc` disabled. It therefore does not configure Tor's listeners.
Its seed expects DNS port 5353, transparent proxy port 9040, SOCKS port 9050
and control port 9051. Prepare Tor's `config-file` to match the listeners and
authentication you intend to use, or adapt Torando's `seed-config` accordingly.
The default `tor-service-type` alone does not establish this integration.

Changing `seed-config` does not overwrite an existing Torando configuration.
Review that file as well when changing Tor's ports. The GUI's `systemctl` calls
do not manage Tor on Guix; use Shepherd (`herd`). Installing these services is
not a validation of DNS routing, firewall rules or the killswitch on a machine.

### Esquema — rootless Guile-native container runtime

`esquema` (new module `(securityops packages containers)`) is a first-party,
security-first container runtime built natively in Scheme. A small C core
(`libesquema.so`, seccomp-BPF via libseccomp) performs the whole isolation
sequence in async-signal-safe code between `fork` and `execve`: user + mount +
PID + UTS + IPC + net + cgroup namespaces, rootless uid/gid maps, `pivot_root`
into the rootfs with the host tree detached, a full capability drop
(bounding set + ambient + `capset` + securebits + `no_new_privs`), a seccomp
allowlist with a stacked filter that kills TIOCSTI/TIOCLINUX terminal
injection, and best-effort cgroup v2 limits — stronger isolation than a plain
`guix shell` while staying daemon-free and rootless (~13 ms startup).

```sh
guix pull                 # or: -L ~/securityops-channel for the working tree
guix install esquema
```

```scheme
(use-modules (esquema runtime) (esquema container))
(run-container
 (make-container "web" "/path/to/rootfs" '("/bin/httpd" "-p" "8080")
                 #:rootfs-ro? #t
                 #:limits (make-limits (* 256 1024 1024) 128 50000 100000)))
```

`make-container` is secure-by-default (all namespaces, seccomp on, every
capability dropped). Installing the package puts the `(esquema …)` Guile
modules on `GUILE_LOAD_PATH` and repoints the FFI at the store `libesquema.so`,
so a bare `(use-modules (esquema runtime))` works. To supervise a container as
a Guix System service, use the bundled service type:

```scheme
(use-modules (esquema esquema-service)
             (securityops packages containers))   ; for the esquema package binding
;; esquema-configuration is a plain SRFI-9 record — POSITIONAL args, in order:
;; name, rootfs, command, scheme-dir.
(service esquema-service-type
         (esquema-configuration
          "web"
          "/srv/web"
          '("/bin/httpd" "-p" "8080")
          (file-append esquema "/share/guile/site/3.0")))
```

---

### Consuming the channel from `/etc/config.scm` and `home.scm`

`xlibre-server`, its drivers and the compatibility `(xlibre)` module are
included in SecurityOps. No external XLibre channel is required. Use
`((securityops packages xlibre) #:prefix so:)` and `so:xlibre-server`.
The server source remains pinned to 25.2.2; the obsolete Intel-driver patch
is omitted because its policy is already upstream.

Scheme resolves a package through the module you import. Importing the channel
with a prefix makes that choice explicit, including for packages whose names
also exist in Guix or Nonguix:

```scheme
(use-modules ((securityops packages terminals) #:prefix so:)
             ((securityops packages shells) #:prefix so:)
             ((securityops packages browsers) #:prefix so:)
             ((securityops packages tor) #:prefix so:)
             ((securityops packages river) #:prefix river:)
             ((securityops packages audio) #:prefix audio:))

;; Use these bindings in an operating-system or home-environment package list:
(list so:kitty so:fish so:librewolf so:google-chrome-stable
      so:torbrowser river:foot-latest river:fuzzel-latest)
```

For a separate profile, save a manifest such as `river-tools.scm`:

```scheme
(use-modules (guix profiles)
             ((securityops packages river) #:prefix river:)
             ((securityops packages audio) #:prefix audio:))

(packages->manifest
 (list river:river-xmonad-runtime river:channel-river-input
       river:foot-latest river:fuzzel-latest river:wlr-randr-latest
       river:swaybg-latest river:mako-latest river:swaylock-latest
       audio:pipewire-latest audio:wireplumber-latest))
```

```sh
guix package -p "$HOME/.local/share/river-tools" -m river-tools.scm
```

This installs programs; it does not select a login session, start audio services
or configure authentication for the screen locker. River 0.4 requires a separate
window manager. The XMonad-style manager under development is not included in
this channel refresh; see its [validation status](refresh-2026-09-17.md#river-runtime).

A service has its own package field. Adding a package to a profile does not
change an already configured service. For example:

```scheme
(use-modules (gnu services)
             (gnu services networking)
             ((securityops packages tor) #:prefix so:))

(service tor-service-type
         (tor-configuration (tor so:tor)))
```

After pulling the channel, rebuild the configuration that owns the package:
`guix system build /etc/config.scm` or
`guix home build ~/.config/guix/home.scm`. Reconfigure that same configuration
when you are ready to activate its changes. To use a local checkout, add
`-L /path/to/securityops-channel` to the Guix command.

For Lacuna Web PKI, see the [native host and Guix Home guide](webpki.md).

---

## Layout

| Path | Purpose |
| --- | --- |
| `securityops/packages/` | Package modules; see the [index](../PACKAGES.md) for exports and versions |
| `securityops/patches/` | Downstream patches with their upstream license notices |
| `securityops/services/` | Shepherd service definitions |
| `tests/` | Integration checks for River patches and the Web PKI package |
| `xlibre.scm`, `xlibre-sources.scm` | Bundled XLibre compatibility module and source pins |
| `.guix-channel`, `.guix-authorizations` | Channel dependencies and authorized signing keys |
| `etc/` | Inventory, channel configuration and maintenance tools |
| `docs/` | Usage, integration and dated validation reports |
| `LICENSE`, `LICENSES/`, `LICENSING.md` | License text and file-level exceptions |

Package modules import Guix or Nonguix definitions with prefixes. Some inherit
those definitions, while others provide source assemblers, additional inputs or
build phases. A Guix pin is part of the tested build context; inherited recipes
can change when that pin changes.

---
