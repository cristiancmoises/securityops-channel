;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2025 Noé Lopez <noelopez@free.fr>
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; This file is part of the securityops channel.
;;;
;;; Guix Xsearch extension, vendored from the upstream channel
;;; https://codeberg.org/Baleine/guix-xsearch (module (guix-xsearch channel))
;;; so no separate channel is needed.
;;;
;;; The upstream 2.3 release tree carries an entry point whose embedded
;;; version string (0.1) predates the tag, so the package pins the 2.3 tag
;;; commit and records it in the version string.
;;; Hash: `guix hash -rx' on a checkout of the 2.3 tag; identical to the
;;; upstream channel's own source pin.

(define-module (securityops packages xsearch)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system guile)
  #:use-module (guix search-paths)
  #:use-module (gnu packages guile)
  #:use-module (gnu packages guile-xyz)
  #:use-module (gnu packages package-management)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module ((guix licenses) #:prefix license:))

(define %guix-xsearch-commit "1af46e0505512901d932f64244483b3ad00cd79f")

(define-public guix-xsearch
  (package
    (name "guix-xsearch")
    (version (git-version "2.3" "0" %guix-xsearch-commit))
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://codeberg.org/Baleine/guix-xsearch.git")
             (commit %guix-xsearch-commit)))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0id4g9slkciirmr442ygyb2044h3fhr5vavsy024g470qr6nz4vs"))))
    (build-system guile-build-system)
    (arguments
     (list
      #:source-directory "src"
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'set-load-paths-in-entry-point
            (lambda _
              (define load-path
                (cons (string-append #$output "/share/guile/site/3.0")
                      (parse-path (getenv "GUILE_LOAD_PATH"))))
              (define load-compiled-path
                (cons (string-append #$output "/lib/guile/3.0/site-ccache")
                      (parse-path (getenv "GUILE_LOAD_COMPILED_PATH"))))
              (define search-paths-header
                `(begin
                   (set! %load-path
                         (append (list ,@load-path) %load-path))
                   (set! %load-compiled-path
                         (append (list ,@load-compiled-path) %load-compiled-path))))

              (substitute* "src/guix/extensions/xsearch.scm"
                ((";;@load-paths@")
                 (with-output-to-string (lambda () (write search-paths-header)))))))
          (add-after 'build 'add-extension-to-search-path
            (lambda _
              (with-directory-excursion #$output
                (mkdir-p "share/guix/extensions")
                (symlink
                 (string-append #$output "/share/guile/site/3.0/guix/extensions/xsearch.scm")
                 "share/guix/extensions/xsearch.scm")))))))
    (native-inputs (list guile-3.0
                         guile-xapian
                         guix))
    (native-search-paths
     (list (search-path-specification
            (variable "GUILE_LOAD_PATH")
            (files '("share/guile/site/3.0")))
           (search-path-specification
            (variable "GUILE_LOAD_COMPILED_PATH")
            (files '("lib/guile/3.0/site-ccache")))
           $GUIX_EXTENSIONS_PATH))
    (home-page "https://codeberg.org/Baleine/guix-xsearch")
    (synopsis "Faster Guix search using a Xapian cache")
    (description
     "The Guix Xsearch extension is a new implementation of Guix search,
sped up by using a Xapian cache.  Before searching, build the cache with
@command{guix xsearch --index}; queries then use Xapian syntax such as
@code{name:hello} or @code{name:emacs AND description:mail}.")
    (license (list license:gpl3+ license:cc0))))
