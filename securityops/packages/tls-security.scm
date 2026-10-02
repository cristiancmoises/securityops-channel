;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>

(define-module (securityops packages tls-security)
  #:use-module (gnu packages tls)
  #:use-module (guix download)
  #:use-module (guix packages))

(define openssl-security
  (package
    (inherit openssl)
    (version "3.5.9")
    (source
     (origin
       (inherit (package-source openssl))
       (uri (string-append
             "https://github.com/openssl/openssl/releases/download/openssl-"
             version "/openssl-" version ".tar.gz"))
       (sha256
        (base32 "16l5xgqp1ii4vffbr8ap2wqbn8jqrm6x6aflzdvhvw7fw815cgv0"))))))

;; Keep grafting scoped to consumers that explicitly select this package.
(define openssl-with-security-replacement
  (package
    (inherit openssl)
    (replacement openssl-security)))
