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
;;; that bootstrap at 1.0.0.85; this channel tracks Valve's current stable
;;; 1.0.0.87 archive by rebuilding nonguix's steam
;;; container around a version-bumped wrap-package.  Everything else (the FHS
;;; sandbox, the library set, the mesa driver) is inherited unchanged from nonguix.
;;;
;;; NOTE: home.scm installs `steam' and transforms it to the NVIDIA variant via
;;; `replace-mesa' (-> steam-nvidia / nvda-580); that transformation is
;;; orthogonal to this bootstrap bump.
(define %steam-container
  ;; nonguix's stock mesa container; replace its older wrap-package below.
  (nong:steam-container-for mesa))

(define steam-client/latest
  (let ((client (ngc-wrap-package %steam-container)))
    (package
      (inherit client)
      (version "1.0.0.87")
      (source
       (origin
         (inherit (package-source client))
         (uri "http://repo.steampowered.com/steam/archive/precise/steam_1.0.0.87.tar.gz")
         (file-name "steam-client-1.0.0.87.tar.gz")
         (sha256
          (base32 "07xs4wpdiwc671d9qzc92j8ynhc0jw4zzqpkm84q0zrpz797b4v4")))))))

(define-public steam
  (nonguix-container->package
   (nonguix-container
    (inherit %steam-container)
    (version "1.0.0.87")
    (wrap-package steam-client/latest))))
