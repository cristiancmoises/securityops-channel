;;; SPDX-License-Identifier: GPL-3.0-or-later

(define-module (securityops packages icp-brasil)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix build-system trivial)
  #:use-module (gnu packages tls)
  #:use-module ((guix licenses) #:prefix license:))

(define-public icp-brasil-roots
  (package
    (name "icp-brasil-roots")
    (version "2026.10.05")
    (source (local-file "aux-files/icp-brasil" "icp-brasil-roots-source"
                        #:recursive? #t))
    (build-system trivial-build-system)
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      #~(begin
          (use-modules (guix build utils) (ice-9 rdelim))
          (let* ((share (string-append #$output "/share/icp-brasil"))
                 (roots (string-append share "/roots"))
                 (openssl (string-append #$openssl "/bin/openssl")))
            (copy-recursively #$source roots)
            ;; Ed521 is not supported by OpenSSL. Retain v7 only as reference.
            (let ((reference (string-append share "/reference-ed521")))
              (mkdir-p reference)
              (rename-file (string-append roots "/ICP-Brasilv7.crt")
                           (string-append reference "/ICP-Brasilv7.crt")))
            ;; Check the registry snapshot time, not the builder's wall clock.
            (for-each
             (lambda (version)
               (let ((file (string-append roots "/ICP-Brasilv"
                                          (number->string version) ".crt")))
                 (invoke openssl "verify" "-check_ss_sig" "-no-CApath"
                         "-no-CAstore" "-attime" "1791158400"
                         "-CAfile" file file)))
             '(4 5 6 10 11 12 13))
            ;; Each bundle has an explicit purpose; none becomes system trust.
            (for-each
             (lambda (entry)
               (call-with-output-file
                   (string-append share "/" (car entry) ".pem")
                 (lambda (port)
                   (for-each
                    (lambda (version)
                      (call-with-input-file
                          (string-append roots "/ICP-Brasilv"
                                         (number->string version) ".crt")
                        (lambda (input) (display (read-string input) port))))
                    (cdr entry)))))
             '(("document-signing" 4 5 6 12 13)
               ("tls" 10)
               ("code-signing" 11)))))))
    (native-inputs (list openssl))
    (home-page "https://www.gov.br/iti/pt-br/assuntos/repositorio/repositorio-ac-raiz")
    (synopsis "Explicit-purpose ICP-Brasil root certificate data")
    (description
     "This package preserves the eight active public root certificates in the
ITI registry snapshot of 5 October 2026.  It provides separate document-signing,
TLS and code-signing PEM bundles, original certificate files and attribution.
The v7 Ed521 certificate is reference-only, outside every usable bundle,
because OpenSSL cannot verify its algorithm.  This package does not provide
an Ed521 implementation or claim v7 signature verification.
Expired roots v0, v1 and v2 and revoked roots v3, v8 and v9 are not included.
Installation does not register trust, set a CA environment variable or change
any browser, Java or system certificate store.  These are root certificates,
not the complete intermediate-CA archive or a revocation-checking service.
Applications must select an appropriate policy and obtain current intermediate
certificates and revocation information when validating signatures.")
    (license
     (license:license "CC-BY-ND 3.0"
                      "https://creativecommons.org/licenses/by-nd/3.0/"
                      "ITI registry terms; original public certificates retained."))))
