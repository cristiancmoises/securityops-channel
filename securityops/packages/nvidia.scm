;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; Re-export the matching Nonguix new-feature driver stack.  Keeping these
;;; as aliases avoids maintaining a second, potentially mismatched driver.

(define-module (securityops packages nvidia)
  #:use-module (guix packages)
  #:use-module (nonguix multiarch-container)
  #:use-module ((nongnu packages game-client) #:prefix client:)
  #:use-module ((nongnu packages nvidia) #:prefix nong:)
  #:use-module ((securityops packages games) #:prefix channel:))

(define-public nvidia-driver-new-feature nong:nvidia-driver-new-feature)
(define-public nvidia-firmware-new-feature nong:nvidia-firmware-new-feature)
(define-public nvidia-module-new-feature nong:nvidia-module-new-feature)
(define-public nvda-new-feature nong:nvda-new-feature)
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
