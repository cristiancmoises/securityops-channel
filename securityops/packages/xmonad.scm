;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; Latest upstream XMonad core and contrib releases; the pinned Guix still
;;; ships xmonad 0.18.0 and xmonad-contrib 0.18.1.

(define-module (securityops packages xmonad)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module ((gnu packages window-management) #:prefix guix:))

(define-public xmonad
  (package
    (inherit guix:xmonad)
    (version "0.18.1")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://hackage.haskell.org/package/xmonad-"
                           version "/xmonad-" version ".tar.gz"))
       (sha256
        (base32 "1w51yza8rxcm97afyfdjvxhndn5fzizfmbs8h83sl0xc0hqmz2wq"))))))

(define-public ghc-xmonad-contrib
  (package
    (inherit guix:ghc-xmonad-contrib)
    (version "0.18.2")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://hackage.haskell.org/package/xmonad-contrib-"
                           version "/xmonad-contrib-" version ".tar.gz"))
       (sha256
        (base32 "0kbaccm8nmx2yxg82yhniv0r87b6yw26qa6w5p83a38i86jfz0rd"))))))
