;;; SPDX-License-Identifier: GPL-3.0-or-later

(define-module (securityops packages openpace)
  #:use-module (gnu packages autotools)
  #:use-module (gnu packages man)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages popt)
  #:use-module (guix build-system gnu)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages))

(define %openssl
  (@@ (securityops packages tls-security) openssl-security))

(define %openssl-original-source
  ;; Preserve the official archive as well as the effective Guix-patched source.
  ;; This artifact is not a library input and does not replace the native source.
  (origin
    (inherit (package-source %openssl))
    (patches '())
    (snippet #f)))

(define-public openpace
  (package
    (name "openpace")
    (version "1.1.4")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://codeload.github.com/frankmorgner/openpace/tar.gz/refs/tags/"
             version))
       (file-name (string-append name "-" version ".tar.gz"))
       (sha256
        (base32 "022fpqwpxc31jqvq33y9dpavm0c459cimnwn8jxmr5d8kz5zirzs"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:tests? #t
      #:parallel-tests? #f
      #:configure-flags
      #~(list "--disable-python" "--disable-ruby" "--disable-java" "--disable-go"
              (string-append "--enable-cvcdir=" #$output "/share/openpace/trust/cvc")
              (string-append "--enable-x509dir=" #$output "/share/openpace/trust/x509"))
      #:phases
      #~(modify-phases %standard-phases
          (add-before 'unpack 'bound-build-resources
            (lambda _
              (setrlimit 'as 1073741824 1073741824)
              (setrlimit 'nproc 128 128)
              (setrlimit 'fsize 134217728 134217728)
              (setrlimit 'cpu 600 600)
              (setrlimit 'core 0 0)
              (setenv "HOME" (getcwd))
              (setenv "XDG_CACHE_HOME" (getcwd))))
          (replace 'bootstrap
            (lambda _
              ;; Vendor bootstrap also configures, builds and runs eactest.
              ;; Leave those operations to their normal sandboxed phases.
              (invoke "autoreconf" "-vif")))
          (add-after 'install 'separate-example-trust
            (lambda _
              ;; Preserve original examples, without making them default roots.
              (for-each
               (lambda (kind)
                 (let ((defaults (string-append #$output "/share/openpace/trust/" kind))
                       (examples (string-append #$output "/share/openpace/examples/" kind)))
                   (mkdir-p examples)
                   (for-each
                    (lambda (file)
                      (rename-file file (string-append examples "/" (basename file))))
                    (find-files defaults))))
               '("cvc" "x509"))))
          (add-after 'install 'preserve-source-and-permissions
            (lambda _
              (let ((doc (string-append #$output "/share/doc/openpace"))
                    (sources (string-append #$output "/share/openpace/source")))
                (install-file "COPYING" doc)
                ;; This original header includes both section-7 permissions and
                ;; their corresponding-source clauses, without paraphrasing.
                (install-file "src/eac/eac.h" (string-append doc "/license-source"))
                (mkdir-p sources)
                (copy-file #$(package-source this-package)
                           (string-append sources "/openpace-1.1.4.tar.gz"))
                (copy-file #$%openssl-original-source
                           (string-append sources "/openssl-3.5.9.tar.gz"))
                (copy-file #$(package-source %openssl)
                           (string-append sources "/openssl-3.5.9-guix-patched.tar.zst"))))))))
    (native-inputs (list autoconf automake libtool pkg-config gengetopt help2man))
    ;; Public headers and libeac.pc require libcrypto for downstream builds.
    (propagated-inputs (list %openssl))
    (home-page "https://frankmorgner.github.io/openpace/")
    (synopsis "Extended Access Control library and card-verifiable certificate tools")
    (description
     "OpenPACE provides libEAC for PACE, terminal authentication and chip
authentication, together with card-verifiable certificate utilities.  This
package builds the native C library and tools without optional language bindings.
Its compiled default certificate directories are empty and immutable.  Example
certificates are retained separately and are not default trust anchors;
applications must select their own explicit trust configuration.  This package
does not install a card service or claim hardware/provider interoperability.")
    (license
     (list license:gpl3+ license:asl2.0
           (license:license
            "OpenSSL and OpenSC linking permissions"
            "https://github.com/frankmorgner/openpace/blob/1.1.4/src/eac/eac.h"
            "Additional permissions under GPL version 3 section 7; retain the exact source text.")))))
