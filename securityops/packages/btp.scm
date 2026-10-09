;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>

(define-module (securityops packages btp)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix build-system copy)
  #:use-module (gnu packages base)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages elf)
  #:use-module ((guix licenses) #:prefix license:))

;;; btp — Built from source (v0.7) on this host with `cargo build --release'
;;; (binaries vendored to keep the channel self-contained / buildable offline).
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
    (home-page "https://git.securityops.com.br/cristiancmoises/btp")
    (license license:asl2.0)))
