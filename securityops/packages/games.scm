;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; This file is part of the securityops channel.
;;;
;;; Games / game clients.  Depends on the nonguix channel.

(define-module (securityops packages games)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (gnu packages gl)
  #:use-module (nonguix multiarch-container)
  #:use-module ((nongnu packages game-client) #:prefix nong:))

;;; steam — nonguix ships a thin bootstrap (Valve's `steam-launcher' from the
;;; precise archive) that the real client self-updates around.  nonguix pins
;;; that bootstrap at 1.0.0.85; this channel tracks the latest one Valve
;;; publishes, 1.0.0.86 (client timestamp 2026-06-09, scout runtime
;;; 1.0.20260430), by rebuilding nonguix's steam container around a
;;; version-bumped wrap-package.  Everything else (the FHS sandbox, the library
;;; set, the mesa driver) is inherited unchanged from nonguix.
;;;
;;; NOTE: home.scm installs `steam' and transforms it to the NVIDIA variant via
;;; `replace-mesa' (-> steam-nvidia / nvda-580); that transformation is
;;; orthogonal to this bootstrap bump.
(define %steam-container
  ;; nonguix's stock mesa container; its wrap-package is the 1.0.0.85 client.
  (nong:steam-container-for mesa))

(define steam-client/latest
  (let ((client (ngc-wrap-package %steam-container)))
    (package
      (inherit client)
      (version "1.0.0.86")
      (source
       (origin
         (inherit (package-source client))
         (uri "http://repo.steampowered.com/steam/archive/precise/steam_1.0.0.86.tar.gz")
         (file-name "steam-client-1.0.0.86.tar.gz")
         (sha256
          (base32 "0q3mb2fp775b2hqkmixvvnikf2px4c1kwr01qw30qnf3brdf9j9b")))))))

(define-public steam
  (nonguix-container->package
   (nonguix-container
    (inherit %steam-container)
    (version "1.0.0.86")
    (wrap-package steam-client/latest))))
