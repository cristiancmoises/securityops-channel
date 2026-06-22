;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; This file is part of the securityops channel.
;;;
;;; First-party applications from git.securityops.co/cristiancmoises.
;;;
;;; The forge is SSH-key-only (anonymous HTTP is disabled), so the Guix daemon
;;; cannot fetch these with a normal git-fetch/url-fetch origin.  Sources/release
;;; artifacts are therefore VENDORED into this channel under packages/sources/
;;; and referenced with `local-file' (content-addressed by Guix at add time, so
;;; no hash field is needed).  This keeps the channel self-contained and buildable
;;; by the daemon with no network or SSH access.

(define-module (securityops packages apps)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix build-system copy)
  #:use-module (gnu packages base)               ;glibc
  #:use-module (gnu packages gcc)                ;gcc:lib (libgcc_s)
  #:use-module (gnu packages elf)                ;patchelf
  #:use-module ((guix licenses) #:prefix license:))

;;; evelin — post-quantum transport (ML-KEM-1024 / ML-DSA-87 / ChaCha20-Poly1305).
;;; Packaged from the OFFICIAL upstream static-musl release tarball (v4.1.1),
;;; matching your existing ~/Downloads/evelin.scm.  Fully static (musl,
;;; link-self-contained): no runtime inputs, no patchelf, no grafting.
;;; Ships ev + client/server/agent/keygen/keyscan/multisig-verify, man pages, docs.
(define-public evelin-bin
  (package
    (name "evelin-bin")
    (version "4.1.1")
    (source (local-file "sources/evelin-v4.1.1-linux-x86_64-musl.tar.gz"))
    (build-system copy-build-system)
    (arguments
     (list
      #:install-plan
      #~'(("bin/" "bin/")
          ("share/man/" "share/man/")
          ("share/doc/evelin/" "share/doc/evelin/"))
      #:phases
      #~(modify-phases %standard-phases
          ;; Release binaries are stripped already; static PIE has no runpath.
          (delete 'strip)
          (delete 'validate-runpath))))
    (supported-systems '("x86_64-linux"))
    (synopsis "Evelin post-quantum transport (prebuilt static release binaries)")
    (description
     "Client, server, agent, and key tools from the official Evelin x86_64
musl-static release: ML-KEM-1024 key exchange, ML-DSA-87 authentication,
ChaCha20-Poly1305 AEAD.  Binaries are fully static and carry no runtime
dependencies.")
    (home-page "https://git.securityops.co/cristiancmoises/evelin")
    (license license:agpl3+)))

;;; btp — Built from source (v0.7) on this host with `cargo build --release'
;;; (the forge is SSH-only, so the daemon can't fetch it; binaries are vendored).
;;; The two core binaries (btpctl CLI, btpd daemon) are dynamic Rust binaries;
;;; their build-time RUNPATH points at an ephemeral `guix shell' profile, so we
;;; patchelf the interpreter + RPATH onto the declared glibc / gcc:lib inputs.
;;; GUI/Python/JS bindings from the workspace are intentionally excluded.
(define-public btp
  (package
    (name "btp")
    (version "0.7")
    (source (local-file "sources/btp-0.7-bin-x86_64-linux.tar.gz"))
    (build-system copy-build-system)
    (inputs (list glibc `(,gcc "lib")))
    (native-inputs (list patchelf))
    (arguments
     (list
      #:install-plan
      #~'(("bin/" "bin/")
          ("share/man/" "share/man/"))
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'install 'patchelf-binaries
            (lambda* (#:key inputs #:allow-other-keys)
              (let* ((glibc (assoc-ref inputs "glibc"))
                     (gcclib (assoc-ref inputs "gcc"))
                     (ld (string-append glibc "/lib/ld-linux-x86-64.so.2"))
                     (rpath (string-append glibc "/lib:" gcclib "/lib")))
                (for-each
                 (lambda (b)
                   (let ((f (string-append #$output "/bin/" b)))
                     (invoke "patchelf" "--set-interpreter" ld f)
                     (invoke "patchelf" "--set-rpath" rpath f)))
                 '("btpctl" "btpd"))))))))
    (supported-systems '("x86_64-linux"))
    (synopsis "BTP — bundle transparency protocol (CLI + daemon)")
    (description
     "@code{btpctl} (command-line client) and @code{btpd} (daemon) from the BTP
project, built from the v0.7 source release.  Built-from-source dynamic binaries
relinked against Guix's glibc.")
    (home-page "https://git.securityops.co/cristiancmoises/btp")
    (license license:asl2.0)))
