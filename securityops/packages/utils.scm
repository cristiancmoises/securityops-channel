;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; This file is part of the securityops channel.
;;;
;;; Everyday TUI / desktop utilities.  All three are already at the latest
;;; upstream in the pinned Guix, so they are re-exported here (single source of
;;; truth; they track Guix until upstream advances).

(define-module (securityops packages utils)
  #:use-module ((gnu packages password-utils) #:prefix pw:)
  #:use-module ((gnu packages image-viewers) #:prefix iv:)
  #:use-module ((gnu packages disk) #:prefix disk:))

(define-public keepassxc pw:keepassxc)        ; 2.7.12 — latest
(define-public ueberzugpp iv:ueberzugpp)      ; 2.9.10 — latest (ueberzug++)
(define-public lf disk:lf)                     ; 41 — latest (terminal file manager)
