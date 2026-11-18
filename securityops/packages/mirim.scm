;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>

(define-module (securityops packages mirim)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages python)
  #:use-module (gnu packages rust)
  #:use-module (securityops packages mirim-crates)
  #:use-module ((guix licenses) #:prefix license:))

(define %mirim-cargo-vendor-helper
  (local-file (canonicalize-path
               (search-path %load-path
                            "securityops/packages/aux-files/guixvis-vendor.py"))))

(define-public mirim
  (package
    (name "mirim")
    (version "1.1.1")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://codeberg.org/berkeley/mirim")
             (commit "5a8f90cc2d3b627c31777671815befc8c119631f")))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0zs6701ji0fwd5bhmzrfswqyiwks4d2b68lrwb2m5jkpk50qw83x"))))
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
              (apply invoke "python3"
                     #$%mirim-cargo-vendor-helper
                     (map cdr
                          (filter (lambda (input)
                                    (string-prefix? "crate-" (car input)))
                                  inputs)))
              (mkdir-p ".cargo")
              (call-with-output-file ".cargo/config.toml"
                (lambda (port)
                  (display "[source.crates-io]
replace-with = 'vendored-sources'
[source.vendored-sources]
directory = 'vendor'
" port)))
              (setenv "CARGO_HOME" (string-append (getcwd) "/.cargo"))
              (setenv "CARGO_BUILD_JOBS" (number->string (parallel-job-count)))
              (setenv "CC" #$(cc-for-target))))
          (replace 'build
            (lambda _
              (invoke "cargo" "build" "--frozen" "--offline" "--release"
                      "--features" "sign")))
          (replace 'check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (invoke "cargo" "test" "--frozen" "--offline"
                        "--features" "sign"))))
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
     (append `(("rust" ,rust)
               ("rust:cargo" ,rust "cargo")
               ("python" ,python))
             mirim-crates))
    (supported-systems '("x86_64-linux"))
    (home-page "https://mirim.securityops.co")
    (synopsis "Encrypted embedded SQL database with post-quantum exports")
    (description
     "Mirim is an embedded SQL database encrypted at rest with
XChaCha20-Poly1305 and Argon2id.  It supports ML-KEM-768 sealed exports,
ML-DSA-87 detached signatures and a durable write-ahead log.  This package
installs the mirim command line interface and mirim-sign.")
    (license license:agpl3)))
