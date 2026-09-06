;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; This file is part of the securityops channel.
;;;
;;; Emacs — curated set for the securityops workstation.

(define-module (securityops packages emacs)
  #:use-module (gnu packages)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module ((gnu packages emacs) #:prefix gnu:))

;;; Stable Emacs 31.1, retaining Guix's native-compilation integration.
(define (latest-emacs base)
  (package
    (inherit base)
    (version "31.1")
    (source
     (origin
       (inherit (package-source base))
       (uri (string-append "mirror://gnu/emacs/emacs-" version ".tar.xz"))
       ;; The Guix development recipe carries these patches for Emacs 31's
       ;; source layout, preserving its native-compilation and store policy.
       (patches
        (search-patches "emacs-next-disable-jit-compilation.patch"
                        "emacs-next-exec-path.patch"
                        "emacs-fix-scheme-indent-function.patch"
                        "emacs-native-comp-driver-options.patch"
                        "emacs-next-native-comp-fix-filenames.patch"
                        "emacs-native-comp-pin-packages.patch"))
       (sha256
        (base32 "11j59ybvzbkxfsm9zmhj6ixxls2424rhcw5znlr1kj40jl6pk98x"))))))

(define-public emacs (latest-emacs gnu:emacs))
(define-public emacs-pgtk (latest-emacs gnu:emacs-pgtk))
