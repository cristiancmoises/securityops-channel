;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>

(define-module (securityops packages mirim)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages rust)
  #:use-module ((guix licenses) #:prefix license:))

;;; mirim 1.1.1 CLI and signing tool, built from tagged sources with offline
;;; Cargo dependencies.  Source: 5a8f90cc2d3b627c31777671815befc8c119631f.
;;; Keep vendor files unchanged so Cargo can verify their original checksums.
(define-public mirim
  (package
    (name "mirim")
    (version "1.1.1")
    (source (local-file "sources/mirim-1.1.1-source.tar.gz"))
    (build-system gnu-build-system)
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          ;; Cargo verifies the original vendor file checksums during --frozen builds.
          ;; The Rust build does not execute the repository's shell scripts.
          (delete 'patch-source-shebangs)
          (delete 'patch-generated-file-shebangs)
          (replace 'configure
            (lambda* (#:key inputs #:allow-other-keys)
              (invoke "tar" "xf" (assoc-ref inputs "vendor"))
              (setenv "CARGO_HOME" (string-append (getcwd) "/.cargo"))
              (setenv "CC" #$(cc-for-target))))
          (replace 'build
            (lambda _
              (invoke "cargo" "build" "--frozen" "--release" "--features" "sign")))
          (replace 'check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (invoke "cargo" "test" "--frozen" "--features" "sign"))))
          (replace 'install
            (lambda _
              (let ((bin (string-append #$output "/bin"))
                    (doc (string-append #$output "/share/doc/mirim")))
                (install-file "target/release/mirim" bin)
                (install-file "target/release/mirim-sign" bin)
                (for-each (lambda (file) (install-file file doc))
                          '("README.md" "README.pt-BR.md" "SECURITY.md"
                            "LICENSE" "LICENSE-AGPL-3.0" "LICENSE-COMMERCIAL"
                            "NOTICE" "LICENSING.md" "LICENSING.pt-BR.md"))
                (copy-recursively "docs" (string-append doc "/docs"))
                (copy-recursively "samples" (string-append doc "/samples"))))))))
    (native-inputs
     `(("rust" ,rust)
       ("rust:cargo" ,rust "cargo")
       ("vendor" ,(local-file "sources/mirim-1.1.1-vendor.tar.gz"))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://mirim.securityops.co")
    (synopsis "Encrypted embedded SQL database with post-quantum exports")
    (description
     "Mirim is an embedded SQL database encrypted at rest with
XChaCha20-Poly1305 and Argon2id.  It supports ML-KEM-768 sealed exports,
ML-DSA-87 detached signatures and a durable write-ahead log.  This package
installs the mirim command line interface and mirim-sign.")
    (license license:agpl3)))
