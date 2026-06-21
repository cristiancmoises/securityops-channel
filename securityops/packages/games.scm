;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; This file is part of the securityops channel.
;;;
;;; Games / game clients.  Depends on the nonguix channel.

(define-module (securityops packages games)
  #:use-module ((nongnu packages game-client) #:prefix nong:))

;;; steam — nonguix's `steam' is a thin bootstrap (1.0.0.85) around the Steam
;;; runtime; the actual client self-updates, so there is no meaningful version
;;; to bump — it is effectively always "latest".  Re-exported for completeness.
;;; NOTE: your home.scm installs `steam' and transforms it to the NVIDIA variant
;;; via `replace-mesa' (-> steam-nvidia / nvda-580); that transformation is
;;; orthogonal to this re-export.
(define-public steam nong:steam)
