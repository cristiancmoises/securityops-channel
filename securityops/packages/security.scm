;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; This file is part of the securityops channel.
;;;
;;; Curated security / pentest toolset.  These are tools that Guix already ships
;;; at a current version, re-exported here so the channel is a single place to
;;; pull the securityops toolkit (they transparently track Guix).  Tools NOT yet
;;; in Guix (sqlmap, ffuf, gobuster, rustscan, mitmproxy, sleuthkit, volatility3,
;;; …) are tracked as TODO in README.md and added as they are packaged.

(define-module (securityops packages security)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix utils)
  #:use-module ((gnu packages admin) #:prefix adm:)
  #:use-module ((gnu packages networking) #:prefix net:)
  #:use-module ((gnu packages password-utils) #:prefix pw:)
  #:use-module ((gnu packages engineering) #:prefix eng:)
  #:use-module ((gnu packages firmware) #:prefix fw:)
  #:use-module ((gnu packages golang-crypto) #:prefix gc:))

;;; Recon / network mapping.  nmap/fping/mtr are bumped ahead of Guix (Guix lags
;;; upstream); inherit Guix's package and override only version + source hash.
(define-public nmap
  (package
    (inherit adm:nmap)
    (version "7.99")                    ;Guix lags at 7.98
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://nmap.org/dist/nmap-" version ".tar.bz2"))
       (sha256
        (base32 "1cjibl1qq1ggzz45sib9wph8kgjvcgc2cvx04wxfa26izy928lfz"))))))
(define-public masscan adm:masscan)
(define-public arp-scan net:arp-scan)
(define-public netdiscover net:netdiscover)
(define-public fping
  (package
    (inherit net:fping)
    (version "5.5")                     ;Guix lags at 5.3
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://fping.org/dist/fping-" version ".tar.gz"))
       (sha256
        (base32 "1zhqxs3pif3b68kp36mz67d2w6yaqy8qqgp0mxdi1zsmdhmy7i0m"))))))
;; mtr: kept on Guix (0.95).  Upstream 0.96 moved `utils.h' to ui/ but its
;; packet/*.c still `#include "utils.h"' without that path, so a plain
;; version+source bump fails to build; leave it tracking Guix until upstream
;; (or Guix) fixes the include path.
(define-public mtr net:mtr)
(define-public whois net:whois)
(define-public proxychains-ng net:proxychains-ng)

;;; Wireless
(define-public aircrack-ng net:aircrack-ng)
(define-public reaver net:reaver)
(define-public kismet net:kismet)

;;; Password / login cracking — THC-Hydra, bumped ahead of Guix (9.6 -> 9.7).
(define-public hydra
  (package
    (inherit pw:hydra)
    (version "9.7")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/vanhauser-thc/thc-hydra")
             (commit (string-append "v" version))))
       (file-name (git-file-name "hydra" version))
       (sha256
        (base32 "13l0kfi97mmiizk0j68wyfmwrr9hiz48s4rxc8crjd1zv75lg0z9"))))))

;;; Reverse engineering / firmware / forensics.
;; radare2: kept on Guix.  Upstream 6.1.x made `zydis' (github zyantific/zydis)
;; a hard meson subproject for x86 disassembly; it is not in Guix, so an offline
;; build of 6.1.8 fails fetching zydis-amalgamated.  Needs zydis packaged first;
;; leave tracking Guix until then.
(define-public radare2 eng:radare2)
;; rizin: kept on Guix (0.8.2).  Upstream 0.9 reworked its meson options (Guix's
;; inherited configure-flags pass `-Duse_swift_demangler=true', removed in 0.9),
;; so a bump needs the flag set re-derived against 0.9; deferred — leave tracking
;; Guix until its own bump.
(define-public rizin eng:rizin)
(define-public binwalk fw:binwalk)

;;; Crypto
(define-public age gc:age)

;;; System auditing / hardening — bumped ahead of Guix: 3.1.1 -> 3.1.7 (latest).
;;; Lynis is a pure-shell auditing tool; inherit Guix's package and override only
;;; version + source (git tag, commit = version), keeping Guix's snippet that
;;; strips the proprietary bundled plugins.  Guix's arguments (incl. the check
;;; phase that runs the separate `lynis-sdk' suite, which Guix pins to the 3.1.1
;;; release) are inherited unchanged: that suite RUNS and PASSES against 3.1.7,
;;; so tests are kept.  (A future bump may need the `lynis-sdk' input re-pinned,
;;; as Guix's own comment notes.)
;;; Hash: `guix hash -rx' on a checkout of the 3.1.7 tag.
(define-public lynis
  (package
    (inherit adm:lynis)
    (version "3.1.7")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/CISOfy/lynis")
             (commit version)))
       (file-name (git-file-name "lynis" version))
       (sha256
        (base32 "0l51ksc7x6zv7li5wljzrh8q09wnhqkjynpzjshr1p6zvvzg9c5n"))
       (modules '((guix build utils)))
       (snippet
        ;; All bundled plugins are proprietary; drop them.
        '(begin
           (for-each delete-file (find-files "plugins"))))))))
