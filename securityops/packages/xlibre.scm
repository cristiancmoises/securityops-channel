;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; Self-contained XLibre packaging. The compatibility (xlibre) module and
;;; driver definitions are maintained in this same SecurityOps channel.

(define-module (securityops packages xlibre)
  #:use-module (xlibre)
  #:re-export (xlibre-server))
