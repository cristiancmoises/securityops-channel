;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>

(define-module (securityops packages belgian-eid)
  #:use-module ((gnu packages security-token) #:prefix upstream:)
  #:use-module (guix git-download)
  #:use-module (guix packages)
  #:use-module (guix utils))

(define-public eid-mw
  (package
    (inherit upstream:eid-mw)
    (version "5.1.31")
    (source
     (origin
       (inherit (package-source upstream:eid-mw))
       (uri (git-reference
             (url "https://github.com/Fedict/eid-mw")
             (commit (string-append "v" version))))
       (file-name (git-file-name "eid-mw" version))
       (sha256
        (base32 "1jkb72ak9mr5qcyzvb8sid3cakbfw4p4qbwjgw1dfwafdpw9x954"))))
    (arguments
     (substitute-keyword-arguments (package-arguments upstream:eid-mw)
       ((#:phases phases)
        `(modify-phases ,phases
           (replace 'bootstrap
             (lambda _
               ;; This release's genver.sh supports a .version file when Git
               ;; metadata is absent.  Its assignments are now indented, so
               ;; the older Guix GITDESC substitution no longer matches.
               (call-with-output-file ".version"
                 (lambda (port) (display ,version port) (newline port)))
               (substitute* "scripts/build-aux/genver.sh"
                 (("/bin/sh") (which "sh")))
               (invoke "sh" "./bootstrap.sh")))))))
    ;; Preserve GTK3 and the upstream --disable-pinentry reader compatibility
    ;; contract, and retain the complete native check phase.
    (inputs
     (modify-inputs (package-inputs upstream:eid-mw)
       (replace "openssl" (@@ (securityops packages tls-security) openssl-security))
       (replace "libxml2" (@@ (securityops packages xml-security) libxml2-security))))))
