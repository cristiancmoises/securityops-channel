;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>

(define-module (securityops packages digidoc4)
  #:use-module (gnu packages nss)
  #:use-module ((gnu packages security-token) #:prefix upstream:)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module (guix packages)
  #:use-module (guix utils)
  #:use-module ((securityops packages eid) #:prefix channel:))

;; The public, signed configuration is serial 212, dated 2026-10-01.  Keep
;; payload, detached signature and trust key pinned together; build offline.
(define (bootstrap-file name url hash)
  (origin
    (method url-fetch)
    (uri url)
    (file-name name)
    (sha256 (base32 hash))))

(define configuration
  (bootstrap-file "digidoc4-config-212.json"
    "https://id.eesti.ee/config.json"
    "1f6b7fwaqg87wjj2rj00adl57cn92hqm89vbmmpgfz80ci4xcaka"))
(define configuration-signature
  (bootstrap-file "digidoc4-config-212.ecc"
    "https://id.eesti.ee/config.ecc"
    "0gjw53dc07svl4yx2y67sszf81sgdh65yw5alm2cvkx4296gdw48"))
(define configuration-key
  (bootstrap-file "digidoc4-config.ecpub"
    "https://id.eesti.ee/config.ecpub"
    "0d4cd8krmqhnzig8y8n1ngrgcgd2j6x6xpdh7yrnkbdc6hnrs116"))
(define european-trust-list
  (bootstrap-file "digidoc4-eu-lotl-20260924.xml"
    "https://ec.europa.eu/tools/lotl/eu-lotl.xml"
    "1046chcyq4iiln7w4fin5486mrw0fx96yxrfc1cn5j1h39801fi8"))

(define digidoc4-certificates
  (package
    (inherit nss-certs)
    (version (package-version nss-rapid))
    (source (package-source nss-rapid))))

(define-public digidoc4
  (package
    (inherit upstream:qdigidoc)
    (name "digidoc4")
    (version "4.11.1")
    (source
      (origin
        (method git-fetch)
        (uri (git-reference
          (url "https://github.com/open-eid/DigiDoc4-Client")
          (commit (string-append "v" version))
          (recursive? #t)))
        (file-name (git-file-name name version))
        (sha256
          (base32 "0y0lr8mdxr0zpy79n6b64sq8gc4wmkhday57546k68bvkwkmm9z9"))))
    (arguments
      (substitute-keyword-arguments (package-arguments upstream:qdigidoc)
        ((#:configure-flags flags #~'())
          ;; Country lists retain their normal, signed runtime update flow;
          ;; never embed Guix's expired 2025 EE/EU bootstrap patches.
          #~(cons* "-DTSL_INCLUDE=" "-DBUILD_DATE=02.09.2026" #$flags))
        ((#:phases phases)
          #~(modify-phases #$phases
            (add-after 'unpack 'provide-signed-bootstrap
              (lambda _
                (copy-file #$configuration "common/config.json")
                (copy-file #$configuration-signature "common/config.ecc")
                (copy-file #$configuration-key "common/config.ecpub")
                (copy-file #$european-trust-list "client/eu-lotl.xml")
                ;; Preserve payload signature and rollback checks as well as
                ;; Qt's default TLS rejection on configuration downloads.
                (substitute* "common/Configuration.cpp"
                  (("reply->ignoreSslErrors\\(errors\\);")
                    "(void)reply; (void)errors;"))))
            (add-before 'configure 'check-bootstrap-signature
              (lambda* (#:key inputs #:allow-other-keys)
                (let ((openssl (search-input-file inputs "bin/openssl")))
                  (invoke openssl "base64" "-d" "-in" "common/config.ecc"
                          "-out" "config-signature.der")
                  (invoke openssl "dgst" "-sha512" "-verify" "common/config.ecpub"
                          "-signature" "config-signature.der" "common/config.json")
                  (call-with-output-file "invalid-config.json"
                    (lambda (port) (display "untrusted configuration\n" port)))
                  (when (zero? (system* openssl "dgst" "-sha512" "-verify"
                    "common/config.ecpub" "-signature" "config-signature.der"
                    "invalid-config.json"))
                    (error "Invalid configuration passed signature validation")))))
            (add-after 'install 'install-bootstrap-evidence
              (lambda _
                (let ((directory (string-append #$output "/share/digidoc4/bootstrap")))
                  (mkdir-p directory)
                  (for-each
                    (lambda (source name)
                      (copy-file source (string-append directory "/" name)))
                    (list #$configuration #$configuration-signature
                          #$configuration-key #$european-trust-list)
                    '("config.json" "config.ecc" "config.ecpub" "eu-lotl.xml")))))
            (add-after 'qt-wrap 'provide-certificate-directory
              (lambda* (#:key inputs outputs #:allow-other-keys)
                (wrap-program
                  (string-append (assoc-ref outputs "out") "/bin/qdigidoc4")
                  `("SSL_CERT_DIR" prefix
                    (,(search-input-directory inputs "/etc/ssl/certs"))))))))))
    (inputs
      (modify-inputs (package-inputs upstream:qdigidoc)
        (replace "libdigidocpp" channel:libdigidocpp)
        (replace "openssl" (@@ (securityops packages tls-security) openssl-security))
        ;; libcdoc finds LibXml2 separately; otherwise CMake can select an
        ;; older transitive input before the signing library's tested ABI.
        (prepend (@@ (securityops packages xml-security) libxml2-security)
                 digidoc4-certificates)))))
