;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; Compatibility for existing manifests. Keep the original public bindings
;;; so Guix and Toys discover each package once, not one copy per module.

(define-module (securityops packages apps)
  #:use-module (securityops packages applications)
  #:re-export (evelin-bin btp mirim torando-gui zupt zupt-gui
               turborec turborec-nvidia-new-feature moneyprinterturbo guixvis))
