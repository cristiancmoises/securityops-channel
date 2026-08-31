;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; This file is part of the securityops channel.
;;;
;;; XLibre X server release overlay.  The full server packaging remains owned
;;; by the guix-xlibre channel; this module only pins a
;;; newer, authenticated upstream release source.  Consumers must make both
;;; this channel and guix-xlibre visible in GUILE_LOAD_PATH (the system
;;; configuration already does that with its two -L options).

(define-module (securityops packages xlibre)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module ((xlibre) #:prefix guix-xlibre:))

;;; XLibre 25.2 is the current maintained stable series.  Keep the server
;;; source pinned to its latest non-prerelease upstream tag.
(define-public xlibre-server
  (package
    (inherit guix-xlibre:xlibre-server)
    (version "25.2.2")
    (source
     (origin
       ;; The 25.2 series incorporates the Intel-driver policy that the
       ;; inherited pre-gen4 patch used to provide; that old patch no longer
       ;; applies cleanly, so retain the recipe but drop only its patch list.
       (inherit (package-source guix-xlibre:xlibre-server))
       (patches '())
       (uri (git-reference
             (url "https://github.com/X11Libre/xserver")
             (commit "xlibre-xserver-25.2.2")))
       (sha256
        (base32 "0zc88lvxrlck6vy8a1bl810smjmd1jgya9g9mbznjg75vwz3kpfz"))
       (file-name (git-file-name "xlibre-server" version))))))
