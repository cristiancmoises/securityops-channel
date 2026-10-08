;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>

(define-module (securityops packages eid)
  #:use-module (gnu packages cmake)
  #:use-module ((gnu packages crypto) #:prefix guix:)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages samba)
  #:use-module (gnu packages xml)
  #:use-module (guix build-system gnu)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages))

(define minizip-for-libdigidocpp
  (package
    (inherit minizip-ng-compat)
    (inputs
     (modify-inputs (package-inputs minizip-ng-compat)
       (replace "openssl"
         (@@ (securityops packages tls-security) openssl-with-security-replacement))))))

(define xmlsec-for-libdigidocpp
  (package
    (inherit xmlsec-openssl)
    (inputs
     (modify-inputs (package-inputs xmlsec-openssl)
       (replace "openssl" (@@ (securityops packages tls-security) openssl-security))))
    (propagated-inputs
     (modify-inputs (package-propagated-inputs xmlsec-openssl)
       (replace "libxml2" (@@ (securityops packages xml-security) libxml2-security))
       (replace "libxslt" (@@ (securityops packages xml-security) libxslt-security))))))

(define-public libdigidocpp
  (package
    (inherit guix:libdigidocpp)
    (version "4.5.1")
    (source
     (origin
       (inherit (package-source guix:libdigidocpp))
       (uri (git-reference
             (url "https://github.com/open-eid/libdigidocpp")
             (commit (string-append "v" version))))
       (file-name (git-file-name "libdigidocpp" version))
       (sha256
        (base32 "1v5sxk9dcjsgra5q7y0bw8xsf4w6kr2bnvfvzqvyg2g5191qjg9d"))))
    (arguments
     (list
      #:cmake cmake-minimal
      #:test-repeat-until-pass? #f
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'handle-empty-minizip-entries
            (lambda _
              ;; minizip-ng rejects a zero-byte read.  Retain the subsequent
              ;; extra-byte check, so a lying ZIP size is still rejected.
              (substitute* "src/util/ZipSerialize.h"
                (("            t.resize")
                 "            if(!t.empty()) t.resize"))))
          (add-before 'configure 'record-fixture-directory
            (lambda _
              (setenv "LIBDIGIDOCPP_TEST_DATA"
                      (string-append (getcwd) "/test/data"))))
          (replace 'check
            (lambda* (#:key tests? inputs #:allow-other-keys)
              (when tests?
                (let ((path (getenv "PATH"))
                      (environment (environ))
                      (fixtures (getenv "LIBDIGIDOCPP_TEST_DATA"))
                      (scratch (string-append (getcwd) "/test-scratch")))
                  (mkdir-p scratch)
                  ;; Linux uses getpwuid_r rather than HOME.  Map the build
                  ;; user's passwd entry only inside these test processes.
                  (call-with-output-file (string-append scratch "/passwd")
                    (lambda (port)
                      (format port "fixture:x:~a:~a:fixture:~a:/bin/sh~%"
                              (getuid) (getgid) scratch)))
                  (call-with-output-file (string-append scratch "/group")
                    (lambda (port)
                      (format port "fixture:x:~a:~%" (getgid))))
                  (environ (list (string-append "PATH=" path)
                                 (string-append "LD_PRELOAD="
                                   (assoc-ref inputs "nss-wrapper")
                                   "/lib/libnss_wrapper.so")
                                 (string-append "NSS_WRAPPER_PASSWD=" scratch "/passwd")
                                 (string-append "NSS_WRAPPER_GROUP=" scratch "/group")
                                 (string-append "HOME=" scratch)
                                 (string-append "XDG_CACHE_HOME=" scratch)
                                 (string-append "TMPDIR=" scratch)
                                 "LANG=C" "LC_ALL=C"))
                  (setrlimit 'as (* 2 1024 1024 1024) (* 2 1024 1024 1024))
                  (setrlimit 'nproc 256 256)
                  (setrlimit 'fsize (* 64 1024 1024) (* 64 1024 1024))
                  (setrlimit 'cpu 300 300)
                  (setrlimit 'core 0 0)
                  ;; The remaining CTest cases use bundled, signed TSL fixtures.
                  ;; runtest also contains online OCSP/TSA signing operations.
                  (dynamic-wind
                    (lambda () #t)
                    (lambda ()
                      (invoke "ctest" "--output-on-failure" "-E" "^runtest$")
                      (invoke "test/unittests" "--report_level=detailed"
                              "--log_level=test_suite"
                              (string-append
                               "--run_test=LogSuite,SignerSuite,X509CryptoSuite,"
                               "ConfSuite,FileUtilSuite,ASiCETestSuite,"
                               "ASiCSTestSuite,XMLTestSuite")
                              "--" fixtures)
                      (let ((configuration
                             (canonicalize-path
                              (string-append scratch "/.digidocpp/digidocpp.conf"))))
                        (unless (string-prefix? (string-append scratch "/")
                                                configuration)
                          (error "Fixture configuration escaped scratch"))
                        (format #t "Fixture configuration confined to ~a~%"
                                configuration)))
                    (lambda () (environ environment))))))))))
    (native-inputs
     (modify-inputs (package-native-inputs guix:libdigidocpp)
       (prepend nss-wrapper)))
    (inputs
     (modify-inputs (package-inputs guix:libdigidocpp)
       (replace "libxml2" (@@ (securityops packages xml-security) libxml2-security))
       (replace "libxslt" (@@ (securityops packages xml-security) libxslt-security))
       (replace "minizip-ng-compat" minizip-for-libdigidocpp)
       (replace "openssl" (@@ (securityops packages tls-security) openssl-security))
       (replace "xmlsec-openssl" xmlsec-for-libdigidocpp)))))

;; A separate derivation links and runs against the completed installed output.
(define (libdigidocpp-acceptance-for library)
  (package
    (inherit libdigidocpp)
    (name "libdigidocpp-acceptance")
    (source (local-file "../../tests/libdigidocpp-acceptance.cpp"))
    (build-system gnu-build-system)
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          (replace 'unpack
            (lambda* (#:key source #:allow-other-keys)
              (copy-file source "acceptance.cpp")))
          (delete 'configure)
          (replace 'build
            (lambda _
              (invoke "g++" "-std=c++23" "acceptance.cpp" "-o" "acceptance"
                      (string-append "-I" #$library "/include")
                      (string-append "-L" #$library "/lib")
                      (string-append "-Wl,-rpath," #$library "/lib")
                      "-ldigidocpp" "-ldl")))
          (replace 'check
            (lambda* (#:key inputs #:allow-other-keys)
              (let ((scratch (string-append (getcwd) "/scratch"))
                    (environment (environ)))
                (mkdir-p scratch)
                (environ (list (string-append "HOME=" scratch)
                               (string-append "XDG_CACHE_HOME=" scratch)
                               (string-append "TMPDIR=" scratch)
                               "LANG=C" "LC_ALL=C"))
                (setrlimit 'as (* 2 1024 1024 1024) (* 2 1024 1024 1024))
                (setrlimit 'nproc 256 256)
                (setrlimit 'fsize (* 64 1024 1024) (* 64 1024 1024))
                (setrlimit 'cpu 300 300)
                (setrlimit 'core 0 0)
                (dynamic-wind
                  (lambda () #t)
                  (lambda ()
                    (invoke "./acceptance"
                            (string-append (assoc-ref inputs "fixtures") "/test/data")))
                  (lambda () (environ environment))))))
          (replace 'install
            (lambda _
              (mkdir-p #$output)
              (call-with-output-file (string-append #$output "/passed")
                (lambda (port) (display "installed acceptance passed\n" port)))))
          (delete 'strip))))
    (native-inputs (list (list "fixtures" (package-source libdigidocpp))))
    (inputs (list (list "tested-library" library)))
    (license license:gpl3+)
    (properties '((hidden? . #t)))))

(define-public libdigidocpp-acceptance
  (libdigidocpp-acceptance-for libdigidocpp))
