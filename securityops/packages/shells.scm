;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; This file is part of the securityops channel.
;;;
;;; Shells — curated set for the securityops workstation.

(define-module (securityops packages shells)
  #:use-module ((gnu packages shells) #:prefix gnu:))

;;; fish — the Rust-rewritten fish 4 line.  Re-exported so it is installable
;;; from this channel and transparently tracks Guix.  Upstream is at 4.8.0 while
;;; Guix lags, but fish 4.x is NOT a version+source bump: Guix builds it from a
;;; pinned `(cargo-inputs 'fish)' crate set (~120 rust-* origins matching that
;;; release's Cargo.lock) plus a corrosion patch, so bumping requires
;;; regenerating the whole crate set for 4.8.0.  Deferred to Guix's own bump
;;; (which brings the matching crate set) rather than fork it here.
(define-public fish gnu:fish)
