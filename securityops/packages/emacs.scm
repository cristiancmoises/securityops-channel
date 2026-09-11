;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; This file is part of the securityops channel.
;;;
;;; Emacs 31.1 for the SecurityOps workstation.

(define-module (securityops packages emacs)
  #:use-module (gnu packages)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module ((gnu packages emacs) #:prefix gnu:))

;; In this Guix snapshot, stable Emacs is still 30.2 while emacs-next
;; already carries the Emacs 31 test selector.  Reuse only that selector;
;; keep the stable tarball-based package as the base.
(define %emacs-31-selector
  (@@ (gnu packages emacs) %emacs-next-selector))

(define (latest-emacs base)
  (package
    (inherit base)
    (version "31.1")
    (source
     (origin
       (inherit (package-source base))
       (method url-fetch)
       (uri (string-append "mirror://gnu/emacs/emacs-" version ".tar.xz"))
       (file-name (string-append "emacs-" version ".tar.xz"))
       (patches
        (search-patches "emacs-next-disable-jit-compilation.patch"
                        "emacs-next-exec-path.patch"
                        "emacs-fix-scheme-indent-function.patch"
                        "emacs-native-comp-driver-options.patch"
                        "emacs-next-native-comp-fix-filenames.patch"
                        "emacs-native-comp-pin-packages.patch"))
       (sha256
        (base32 "11j59ybvzbkxfsm9zmhj6ixxls2424rhcw5znlr1kj40jl6pk98x"))))
    (arguments
     (substitute-keyword-arguments (package-arguments base)
       ((#:make-flags flags)
        #~(list
           (string-append "SELECTOR=" #$%emacs-31-selector)
           (let ((release-date "2026-08-24 10:35:47"))
             (string-append
              "RUN_TEMACS= "
              #$(this-package-native-input "libfaketime")
              "/bin/faketime -m -f '" release-date "' ./temacs"))))))))

(define-public emacs
  (latest-emacs gnu:emacs))

(define-public emacs-pgtk
  (latest-emacs gnu:emacs-pgtk))
