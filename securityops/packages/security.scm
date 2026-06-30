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
  #:use-module (guix git-download)
  #:use-module (guix utils)
  #:use-module ((gnu packages admin) #:prefix adm:)
  #:use-module ((gnu packages networking) #:prefix net:)
  #:use-module ((gnu packages password-utils) #:prefix pw:)
  #:use-module ((gnu packages engineering) #:prefix eng:)
  #:use-module ((gnu packages firmware) #:prefix fw:)
  #:use-module ((gnu packages golang-crypto) #:prefix gc:))

;;; Recon / network mapping
(define-public nmap adm:nmap)
(define-public masscan adm:masscan)
(define-public arp-scan net:arp-scan)
(define-public netdiscover net:netdiscover)
(define-public fping net:fping)
(define-public mtr net:mtr)
(define-public whois net:whois)
(define-public proxychains-ng net:proxychains-ng)

;;; Wireless
(define-public aircrack-ng net:aircrack-ng)
(define-public reaver net:reaver)
(define-public kismet net:kismet)

;;; Password / login cracking
(define-public hydra pw:hydra)                  ;THC-Hydra

;;; Reverse engineering / firmware / forensics
(define-public radare2 eng:radare2)
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
