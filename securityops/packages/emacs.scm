;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; This file is part of the securityops channel.
;;;
;;; Emacs — curated set for the securityops workstation.

(define-module (securityops packages emacs)
  #:use-module ((gnu packages emacs) #:prefix gnu:))

;;; emacs / emacs-pgtk — Guix already ships the latest upstream stable (30.2).
;;; Re-exported so they are installable from this channel and transparently
;;; track Guix; bump here the day Guix lags upstream.  (For the bleeding edge,
;;; Guix also offers `emacs-next' = 31.0.50, intentionally NOT pinned here.)
(define-public emacs gnu:emacs)
(define-public emacs-pgtk gnu:emacs-pgtk)
