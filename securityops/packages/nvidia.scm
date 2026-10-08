;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; Refresh the matching new-feature stack using Nonguix's extraction,
;;; integration and library-union helpers.  This does not activate a driver.

(define-module (securityops packages nvidia)
  #:use-module (guix packages)
  #:use-module (nonguix multiarch-container)
  #:use-module (nonguix utils)
  #:use-module ((nongnu packages game-client) #:prefix client:)
  #:use-module ((nongnu packages nvidia) #:prefix nong:)
  #:use-module ((securityops packages games) #:prefix channel:))

(define %nvidia-version "615.78.08")

(define %nvidia-sources
  `(("x86_64-linux"
     . ,((@@ (nongnu packages nvidia) make-nvidia-source)
         %nvidia-version "x86_64"
         (base32 "1zkzs219fn946pg2v3b9fv76wa6bwdxsy02k3047lxpfqbfnsgry")))
    ("aarch64-linux"
     . ,((@@ (nongnu packages nvidia) make-nvidia-source)
         %nvidia-version "aarch64"
         (base32 "0dvs8jpr9a5anwgna3c2qwvvxr2zwcph3zgh66h827hqa09h2xjh")))))

(define-public nvidia-driver-new-feature
  (binary-package-from-sources
   %nvidia-sources
   (package
     (inherit nong:nvidia-driver-new-feature)
     ;; Restore the base unpack phase before mapping new sources.  The mapped
     ;; inherited phase captures the previous installer and ignores #:source.
     (arguments
      ((@@ (nongnu packages nvidia) %nvidia-driver-arguments-595))))))

(define-public nvidia-firmware-new-feature
  (binary-package-from-sources
   %nvidia-sources
   (package
     (inherit nong:nvidia-firmware-new-feature)
     (version %nvidia-version)
     (arguments
      ((@@ (nongnu packages nvidia) %nvidia-firmware-arguments)
       %nvidia-version)))))

(define-public nvidia-module-new-feature
  (binary-package-from-sources
   %nvidia-sources
   (package
     (inherit nong:nvidia-module-new-feature)
     (arguments
      ((@@ (nongnu packages nvidia) %nvidia-module-arguments))))))

(define-public nvda-new-feature
  (package
    (inherit
     (hidden-package
      ((@@ (nongnu packages nvidia) make-nvda) nvidia-driver-new-feature)))
    ;; The upstream helper pads/truncates to Mesa's version width.  Keep the
    ;; complete driver release so the public stack cannot conceal a mismatch.
    (version %nvidia-version)
    (location (package-location nvidia-driver-new-feature))))
(define-public steam-nvidia-new-feature
  (let* ((client (lookup-package-input channel:steam "wrap-package"))
         (container
          (nonguix-container
           (inherit (client:steam-container-for nvda-new-feature))
           (version (package-version client))
           (wrap-package client)
           (preserved-env
            (@@ (nongnu packages nvidia)
                %nvidia-environment-variable-regexps))))
         (updated (nonguix-container->package container)))
    ;; Keep Nonguix's NVIDIA policy and metadata; share the channel bootstrap.
    ;; Steam downloads its current client through its own self-update mechanism.
    (package
      (inherit nong:steam-nvidia-new-feature)
      (location (package-location nong:steam-nvidia-new-feature))
      (version (package-version updated))
      (inputs (package-inputs updated))
      (arguments (package-arguments updated)))))
