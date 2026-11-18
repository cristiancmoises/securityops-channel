;;; SPDX-License-Identifier: GPL-3.0-or-later

(define-module (securityops packages cargo-crates)
  #:use-module (guix base16)
  #:use-module ((guix build-system cargo) #:select (crate-uri))
  #:use-module (guix download)
  #:use-module (guix packages)
  #:export (crate))

(define (crate name version checksum)
  (let ((id (string-append name "-" version)))
    (list (string-append "crate-" id)
          (origin
            (method url-fetch)
            (uri (crate-uri name version))
            (file-name (string-append id ".crate"))
            (sha256 (base16-string->bytevector checksum))))))
