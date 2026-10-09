;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>

(define-module (securityops packages evelin)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix build-system copy)
  #:use-module ((guix licenses) #:prefix license:))

;;; evelin — post-quantum transport (ML-KEM-1024 / ML-DSA-87 / ChaCha20-Poly1305).
;;; Packaged from the official upstream static-musl release tarball (v4.4.0),
;;; with a self-contained toolchain.  Fully static (musl,
;;; link-self-contained): no runtime inputs, no patchelf, no grafting.
;;; Ships ev + client/server/agent/keygen/keyscan/multisig-verify, man pages, docs.
(define-public evelin-bin
  (package
    (name "evelin-bin")
    (version "4.4.0")
    (source (local-file "sources/evelin-v4.4.0-linux-x86_64-musl.tar.gz"))
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
    (home-page "https://git.securityops.com.br/cristiancmoises/evelin")
    (license license:agpl3+)))
