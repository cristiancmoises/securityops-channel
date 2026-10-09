;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>

;;; Compatibility for manifests using the former application collection.
;;; Reexport the original variables so Guix discovers each package once.

(define-module (securityops packages applications)
  #:use-module (securityops packages evelin)
  #:use-module (securityops packages btp)
  #:use-module (securityops packages mirim)
  #:use-module (securityops packages torando-gui)
  #:use-module (securityops packages zupt)
  #:use-module (securityops packages turborec)
  #:use-module (securityops packages moneyprinterturbo)
  #:use-module (securityops packages guixvis)
  #:use-module (securityops packages whatsappel)
  #:re-export (evelin-bin btp mirim torando-gui zupt zupt-gui
               turborec turborec-nvidia-new-feature moneyprinterturbo guixvis
               whatsappel))
