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
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module ((gnu packages admin) #:prefix adm:)
  #:use-module ((gnu packages databases) #:prefix db:)
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
;; mtr — the official 0.96 release is a clean version/source bump over Guix's
;; 0.95 recipe.  Both packet/utils.h and ui/utils.h are present in the release;
;; no downstream include-path patch is required.
(define-public mtr
  (package
    (inherit net:mtr)
    (version "0.96")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://www.bitwizard.nl/mtr/files/mtr-"
                           version ".tar.gz"))
       (sha256
        (base32 "0yh3544x4rhrhcp92s2svznbqf8jknzrznphl8g6qqazingrmlgz"))))))
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
;; radare2 6.1.8 needs the new system-Zydis option and sdb >= 2.4.6.  Guix has
;; Zydis/Zycore, but its sdb 2.4.2 lacks sdb_rename; package current sdb 2.4.8
;; and keep Guix's patches that force offline system sdb/QuickJS builds.
(define-public sdb
  (package
    (inherit db:sdb)
    (version "2.4.8")
    (source
     (origin
       (inherit (package-source db:sdb))
       (uri (git-reference
             (url "https://github.com/radareorg/sdb")
             (commit version)))
       (file-name (git-file-name "sdb" version))
       (sha256
        (base32 "0iwix941jbiwxw4jal6jvppvp0ls3yqjxslkw7c7g62i7d14inn8"))))))

(define-public radare2
  (package
    (inherit eng:radare2)
    (version "6.1.8")
    (source
     (origin
       (inherit (package-source eng:radare2))
       (uri (git-reference
             (url "https://github.com/radareorg/radare2")
             (commit version)))
       (file-name (git-file-name "radare2" version))
       (sha256
        (base32 "1p8h3wwmbaizxj08pif2mk8vcq2xiv5yavhdgcdwf8mcyp99c7qs"))))
    (arguments
     (substitute-keyword-arguments (package-arguments eng:radare2)
       ((#:configure-flags flags #~'())
        #~(append #$flags
                  (list "-Duse_sys_zydis=true")))))
    (inputs
     (modify-inputs (package-inputs eng:radare2)
       (replace "sdb" sdb)
       (append eng:zydis eng:zycore)))))

;; Rizin 0.9 removed the Swift-demangler option and added a Zydis backend.
;; Use Guix's system libraries except OpenSSL: 0.9.1's system-OpenSSL SHA3
;; plugin is named sha3_224 while the public API/tests require sha3-224.
;; Rizin's bundled hash implementation is offline, passes the complete suite,
;; and returns the expected digest.
(define-public rizin
  (package
    (inherit eng:rizin)
    (version "0.9.1")
    (source
     (origin
       (inherit (package-source eng:rizin))
       (uri (string-append
             "https://github.com/rizinorg/rizin/releases/download/v"
             version "/rizin-src-v" version ".tar.xz"))
       (sha256
        (base32 "1jixajg107lxhdqywvs97s0izz27yyqphm718akxvbx7miywvhbs"))))
    (arguments
     (substitute-keyword-arguments (package-arguments eng:rizin)
       ((#:configure-flags _)
        #~(list "--wrap-mode=nodownload"
                "-Dpackager=guix"
                (string-append "-Dpackager_version=" #$version)
                "-Duse_sys_capstone=enabled"
                "-Duse_sys_magic=enabled"
                "-Duse_sys_zydis=enabled"
                "-Duse_sys_libzip=enabled"
                "-Duse_sys_zlib=enabled"
                "-Duse_sys_lz4=enabled"
                "-Duse_sys_libzstd=enabled"
                "-Duse_sys_xxhash=enabled"
                "-Duse_sys_openssl=disabled"
                "-Duse_sys_tree_sitter=enabled"
                "-Duse_sys_lzma=enabled"
                "-Duse_sys_libmspack=enabled"
                "-Duse_sys_pcre2=enabled"
                "-Duse_zlib=true"
                "-Duse_lzma=true"
                "-Dinstall_sigdb=false"
                "-Duse_gpl=true"))))
    (inputs
     (modify-inputs (package-inputs eng:rizin)
       (append eng:zydis eng:zycore)))))
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
