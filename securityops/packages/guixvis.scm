;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>

(define-module (securityops packages guixvis)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages python)
  #:use-module (gnu packages rust)
  #:use-module (securityops packages guixvis-crates)
  #:use-module ((guix licenses) #:prefix license:))

;;; guixvis — first-party TUI + local web explorer for GNU Guix packages.
;;; Pure-Rust: package search with per-tab filters, exact dependency and
;;; reverse-dependency browsing, terminal graphs, a local web UI with bubble
;;; and rectangle views, and an Emacs library.
(define-public guixvis
  (package
    (name "guixvis")
    (version "0.10.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://codeberg.org/berkeley/guixvis")
             (commit "43bb9a7a9d0dcd5c400227ef734077c8e0587004")))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1ib2cfcgqzhlxix2zbmzgkznxsxk4q5dj2jnlh9mn10pvmnbg5l9"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          ;; Cargo verifies the vendored sources during the frozen build.
          (delete 'patch-source-shebangs)
          (delete 'patch-generated-file-shebangs)
          (replace 'configure
            (lambda* (#:key inputs #:allow-other-keys)
              (apply invoke "python3"
                     #$(local-file "aux-files/guixvis-vendor.py")
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
     (append `(("rust" ,rust)
               ("rust:cargo" ,rust "cargo")
               ("python" ,python))
             guixvis-crates))
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
