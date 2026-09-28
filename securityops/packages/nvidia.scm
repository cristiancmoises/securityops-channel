;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; Re-export the matching Nonguix new-feature driver stack.  Keeping these
;;; as aliases avoids maintaining a second, potentially mismatched driver.

(define-module (securityops packages nvidia)
  #:use-module ((nongnu packages nvidia) #:prefix nong:))

(define-public nvidia-driver-new-feature nong:nvidia-driver-new-feature)
(define-public nvidia-firmware-new-feature nong:nvidia-firmware-new-feature)
(define-public nvidia-module-new-feature nong:nvidia-module-new-feature)
(define-public nvda-new-feature nong:nvda-new-feature)
(define-public steam-nvidia-new-feature nong:steam-nvidia-new-feature)
