;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; This file is part of the securityops channel.
;;;
;;; Video / media applications.

(define-module (securityops packages video)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module ((gnu packages video) #:prefix gnu:))

;;; mpv / vlc — Guix already ships the latest upstream (mpv 0.41.0, vlc 3.0.23).
;;; Re-exported so they install from this channel and track Guix.
(define-public mpv gnu:mpv)
(define-public vlc gnu:vlc)

;;; openshot — bumped ahead of Guix: 3.4.0 -> 3.5.1 (latest upstream).
;;; git-fetch of tag v3.5.1; inherits the upstream origin (snippet preserved).
;;; Hash: `guix hash -rx' over `git clone -b v3.5.1 .../OpenShot/openshot-qt'.
(define-public openshot
  (package
    (inherit gnu:openshot)
    (version "3.5.1")
    (source
     (origin
       (inherit (package-source gnu:openshot))
       (uri (git-reference
             (url "https://github.com/OpenShot/openshot-qt")
             (commit (string-append "v" version))))
       (file-name (git-file-name (package-name gnu:openshot) version))
       (sha256
        (base32 "0df8sb7k43m580b50c1g430fqbml6vzszaklp9z7767j4gfz1dl8"))))))
