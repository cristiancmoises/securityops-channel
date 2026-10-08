;;; SPDX-License-Identifier: GPL-3.0-or-later

(define-module (securityops packages icp-brasil-chain)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix build-system trivial)
  #:use-module (gnu packages base)
  #:use-module ((guix licenses) #:prefix license:))

(define %openssl
  (@@ (securityops packages tls-security) openssl-security))

(define-public icp-brasil-ca-data
  (package
    (name "icp-brasil-ca-data")
    (version "2026.08.26")
    (source (local-file "aux-files/icp-brasil-chain"
                        "icp-brasil-ca-data-source" #:recursive? #t))
    (build-system trivial-build-system)
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      #~(begin
          (use-modules (guix build utils) (ice-9 popen) (ice-9 rdelim)
                       (srfi srfi-13))
          (let* ((share (string-append #$output "/share/icp-brasil-ca-data"))
                 (openssl (string-append #$%openssl "/bin/openssl"))
                 (sha256sum (string-append #$coreutils "/bin/sha256sum")))
            (with-directory-excursion #$source
              (invoke sha256sum "--strict" "--check" "SHA256SUMS"))
            (copy-recursively #$source share)
            ;; Git byte-preservation metadata is not application data.
            (delete-file (string-append share "/.gitattributes"))
            (let ((certificates (find-files
                                 (string-append share "/certificates") "\\.crt$"))
                  (reference (find-files
                              (string-append share "/reference-ed521") "\\.crt$")))
              (unless (and (= 179 (length certificates))
                           (= 1 (length reference))
                           (string=? (basename (car reference))
                                     "ICP-Brasilv7.crt"))
                (error "Unexpected official CA dataset inventory"))
              (for-each
               (lambda (file)
                 (let* ((port (open-pipe* OPEN_READ openssl "x509" "-in" file
                                         "-noout" "-text"))
                        (details (read-string port))
                        (status (close-pipe port))
                        (reference? (member file reference)))
                   (unless
                       (and (zero? status)
                            (string-contains details "CA:TRUE")
                            (string-contains details "Certificate Sign")
                            (if reference?
                                (string-contains details
                                                 "1.3.6.1.4.1.44588.2.1")
                                (or (string-contains
                                     details
                                     "Public Key Algorithm: rsaEncryption")
                                    (string-contains
                                     details "Public Key Algorithm: ED448"))))
                     (error "Invalid CA data or algorithm separation" file))))
               (append certificates reference)))))))
    (native-inputs (list coreutils %openssl))
    (home-page
     (string-append "https://www.gov.br/iti/pt-br/assuntos/repositorio/"
                    "certificados-das-acs-da-icp-brasil-arquivo-unico-compactado"))
    (synopsis "Opt-in ICP-Brasil certificate authority reference data")
    (description
     "This package preserves all 180 original public CA certificate files in
the ITI Cadeia Vigente archive dated 26 August 2026, including original names,
PEM bytes and newline conventions.  It supplies an inventory with original-file
and DER fingerprints and the official source-archive SHA-512.  The v7 Ed521
certificate is isolated as reference-only because OpenSSL cannot verify that
private algorithm.  The other 179 files are CA data, not selected trust anchors.
Installation provides only an opt-in share directory.  It does not create a
combined trust bundle, register certificates, set CA search paths or modify a
system, browser or Java trust store.  This historical snapshot does not establish
current validity, certificate-chain verification, revocation, permitted purposes
or legal acceptance.  Applications must obtain current issuer and revocation
data and choose an appropriate validation policy.  There are no end-user keys,
signing applications, CRL or OCSP services in this data package.")
    (license
     (license:license "CC-BY-ND 3.0"
                      "https://creativecommons.org/licenses/by-nd/3.0/"
                      "ITI repository terms; original public certificates retained."))))
