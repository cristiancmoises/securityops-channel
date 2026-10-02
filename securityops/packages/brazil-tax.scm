;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>

(define-module (securityops packages brazil-tax)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages python)
  #:use-module (gnu packages xml)
  #:use-module (guix build-system copy)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix packages)
  #:use-module ((guix licenses) #:prefix license:))

(define %esocial-license
  (license:license
   "CC-BY-ND-3.0"
   "https://creativecommons.org/licenses/by-nd/3.0/"
   "Unmodified data redistribution with attribution; not a free software licence."))

(define %esocial-events-url
  (string-append "https://www.gov.br/esocial/pt-br/documentacao-tecnica/manuais/"
                 "2026-07-01_esquemas_xsd_v_s_01_03_00.zip"))

(define %esocial-communication-url
  (string-append "https://www.gov.br/esocial/pt-br/documentacao-tecnica/manuais/"
                 "pacote-de-comunicacao-esocial-v1-6.zip"))

(define (esocial-data-arguments dataset title source-url)
  (list
   #:install-plan
   #~'(("./" #$(string-append "share/esocial/" dataset)
        #:include-regexp ("\\.(xsd|wsdl|xml|txt)$")))
   #:out-of-source? #f
   #:patch-shebangs? #f
   #:strip-binaries? #f
   #:phases
   #~(modify-phases %standard-phases
       (add-before 'unpack 'bound-resources
         (lambda _
           (for-each (lambda (item) (apply setrlimit item))
                     '((as 1073741824 1073741824)
                       (nproc 128 128) (fsize 16777216 16777216)
                       (cpu 120 120) (core 0 0)))
           (setenv "HOME" (getcwd))
           (setenv "XML_CATALOG_FILES" "")))
       (add-after 'install 'preserve-archive-and-attribution
         (lambda* (#:key inputs outputs #:allow-other-keys)
           (let ((directory
                  (string-append (assoc-ref outputs "out")
                                 "/share/esocial/" #$dataset)))
             (copy-file (assoc-ref inputs "source")
                        (string-append directory "/source.zip"))
             (call-with-output-file (string-append directory "/ATTRIBUTION")
               (lambda (port)
                 (display
                  (string-append
                   "eSocial, Governo Federal do Brasil.\nTitle: " #$title
                   "\nOriginal download: " #$source-url
                   "\nOfficial technical documentation:\n"
                   "https://www.gov.br/esocial/pt-br/documentacao-tecnica\n"
                   "Distributed schema bytes and the source archive are unchanged.\n"
                   "Site content licence: Creative Commons Attribution-"
                   "NoDerivatives 3.0 Unported.\n"
                   "https://creativecommons.org/licenses/by-nd/3.0/\n"
                   "The XML Signature schema retains its Internet Society/W3C\n"
                   "copyright and W3C Software License notice in the original XSD.\n"
                   "No government endorsement or warranty is implied.\n")
                  port))))))
       (add-after 'preserve-archive-and-attribution 'check
         (lambda* (#:key tests? outputs #:allow-other-keys)
           (when tests?
             (let ((directory
                    (string-append (assoc-ref outputs "out")
                                   "/share/esocial/" #$dataset)))
               (invoke #$(file-append python-minimal "/bin/python3")
                       #$(local-file "../../tests/esocial-schemas.py")
                       #$dataset directory
                       (string-append directory "/source.zip")
                       #$(file-append libxml2 "/bin/xmllint")))))))))

(define-public esocial-schemas
  (package
    (name "esocial-schemas")
    (version "1.3-20260701")
    (source
     (origin
       (method url-fetch)
       (uri %esocial-events-url)
       (file-name (string-append name "-" version ".zip"))
       (sha256
        (base32 "13mgz5fc80gn4f8xyg9dsf7h4l7l1a211r7w9bs0qiyh6fx5slrj"))))
    (build-system copy-build-system)
    (arguments
     (esocial-data-arguments
      "events" "Esquemas XSD eSocial S-1.3, NT 06/2026, CNPJ alfanumérico"
      %esocial-events-url))
    (native-inputs (list unzip python-minimal libxml2))
    (home-page "https://www.gov.br/esocial/pt-br/documentacao-tecnica")
    (synopsis "Official eSocial S-1.3 event schemas")
    (description
     "This package provides the 52 unmodified eSocial S-1.3 event schemas
through Technical Note 06/2026, effective July 1, 2026, including alphanumeric
CNPJ support.  Data is installed in share/esocial/events with the original
archive and attribution.  XML Schema checks validate document structure only:
they do not verify digital signatures, apply all business rules or submit
events to the government.  The schemas do not modify certificate trust or
activate a service.")
    ;; The government site explicitly licenses its content under CC-BY-ND-3.0.
    ;; Keep all original bytes, including the embedded third-party notice.
    (license (list %esocial-license license:w3c))))

(define-public esocial-communication-schemas
  (package
    (inherit esocial-schemas)
    (name "esocial-communication-schemas")
    (version "1.6")
    (source
     (origin
       (method url-fetch)
       (uri %esocial-communication-url)
       (file-name (string-append name "-" version ".zip"))
       (sha256
        (base32 "15jrzgqx5szfid7d46jg2vm695nq8ca9igc9ni4yg7nzf9sdf7lg"))))
    (arguments
     (esocial-data-arguments "communication" "Pacote de Comunicação eSocial v1.6"
                            %esocial-communication-url))
    (synopsis "Official eSocial communication schemas and WSDL")
    (description
     "This package provides the unmodified eSocial communication package
version 1.6: XML schemas, WSDL files, a response example and the upstream change
log.  Data is installed in share/esocial/communication with the original
archive and attribution.  Its envelope schemas retain their upstream numeric
registration restrictions; alphanumeric CNPJ support in event layout S-1.3
must not be inferred for these envelopes.  The submission envelope deliberately
does not validate its embedded event, which must be validated separately.
Schema validation does not check digital signatures or government business
rules, and this package does not contact or activate a service.")))
