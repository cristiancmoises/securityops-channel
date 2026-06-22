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
