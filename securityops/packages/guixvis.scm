;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>

(define-module (securityops packages guixvis)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages rust)
  #:use-module ((guix licenses) #:prefix license:))

;;; guixvis — first-party TUI + local web explorer for GNU Guix packages.
;;; Pure-Rust: package search with per-tab filters, exact dependency and
;;; reverse-dependency browsing, terminal graphs, a local web UI with bubble
;;; and rectangle views, and an Emacs library.  Its registry crates
;;; are vendored (cargo --frozen, no network in the build), following the
;;; Mirim pattern; source and vendor snapshots live under packages/sources/.
(define-public guixvis
  (package
    (name "guixvis")
    (version "0.10.0")
    (source (local-file "sources/guixvis-0.10.0-src.tar"))
    (build-system gnu-build-system)
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          ;; Cargo verifies the original vendor checksums during --frozen
          ;; builds; keep the shebangs untouched.
          (delete 'patch-source-shebangs)
          (delete 'patch-generated-file-shebangs)
          (replace 'configure
            (lambda* (#:key inputs #:allow-other-keys)
              (invoke "tar" "xf" (assoc-ref inputs "vendor"))
              (setenv "CARGO_HOME" (string-append (getcwd) "/.cargo"))
              (setenv "CC" #$(cc-for-target))))
          (replace 'build
            (lambda _
              (invoke "cargo" "build" "--frozen" "--offline" "--release"
                      "--features" "web")))
          (replace 'check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (invoke "cargo" "test" "--frozen" "--offline"
                        "--features" "web"))))
          (replace 'install
            (lambda _
              (let ((bin (string-append #$output "/bin"))
                    (doc (string-append #$output "/share/doc/guixvis")))
                (install-file "target/release/guixvis" bin)
                (for-each (lambda (file) (install-file file doc))
                          '("README.md" "README.pt-BR.md" "LICENSE"
                            "SECURITY.md"))
                (install-file "elisp/guixvis.el"
                              (string-append #$output "/share/emacs/site-lisp"))
                (install-file "elisp/guixvis-graph.el"
                              (string-append #$output "/share/emacs/site-lisp"))
                (copy-recursively "assets" (string-append doc "/assets"))
                (copy-recursively "docs" (string-append doc "/docs"))))))))
    (native-inputs
     `(("rust" ,rust)
       ("rust:cargo" ,rust "cargo")
       ("vendor" ,(local-file "sources/guixvis-0.1.0-vendor.tar.gz"))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://codeberg.org/berkeley/guixvis")
    (synopsis "Interactive package explorer and dependency visualizer for GNU Guix")
    (description
     "guixvis indexes GNU Guix packages for a keyboard-first terminal UI, a
local web application, and an Emacs library.  The terminal has per-tab filters,
exact dependency and reverse-dependency searches, and quieter dependency
graphs.  The web UI (@command{guixvis web}) serves bubble and rectangle graph
views on 127.0.0.1 with right-click Back navigation, deep links, and browser
history.  The Emacs libraries provide terminal and browser commands, native
package search with exact variant selection, and keyboard-driven dependency
and reverse-dependency graphs with local filtering and navigation history.")
    (license license:gpl3+)))
