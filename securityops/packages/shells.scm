;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; This file is part of the securityops channel.
;;;
;;; Shells — curated set for the securityops workstation.

(define-module (securityops packages shells)
  #:use-module ((gnu packages shells) #:prefix gnu:))

;;; fish — Guix already ships the latest upstream (4.7.1, the Rust-rewritten
;;; fish 4 line).  Re-exported so it is installable from this channel and
;;; transparently tracks Guix; bump here the day Guix lags upstream.
(define-public fish gnu:fish)
