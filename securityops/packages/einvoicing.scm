;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>

(define-module (securityops packages einvoicing)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix build-system trivial)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages backup)
  #:use-module (gnu packages guile)
  #:use-module (gnu packages java)
  #:use-module (securityops packages autofirma)
  #:use-module ((guix licenses) #:prefix license:))

(define %java (@@ (securityops packages autofirma) temurin17-runtime))

(define %validator-source
  (origin
    (method url-fetch)
    (uri "https://codeload.github.com/itplr-kosit/validator/tar.gz/v1.6.3")
    (file-name "kosit-validator-1.6.3-source.tar.gz")
    (sha256 (base32 "119f2ziiq4lsyy90jffjr05znjbn1dbxg1zhx6j1pmw8v12qaq3l"))))

(define %saxon-source
  (origin
    (method url-fetch)
    (uri "https://github.com/Saxonica/Saxon-HE/releases/download/SaxonHE12-9/saxon12-9source.zip")
    (sha256 (base32 "1gqcgvnsazfnzmlc8cnxcighihn152ibqdgy9z58zf4gdc7yqyym"))))

(define %saxon-notices
  (origin
    (method url-fetch)
    (uri "https://github.com/Saxonica/Saxon-HE/releases/download/SaxonHE12-9/SaxonHE12-9J.zip")
    (sha256 (base32 "04jxcc3iyz86i078xfvyf70qhvm875yf52qm19jjq4cl6zpmp2gj"))))

(define %xrechnung-source
  (origin
    (method url-fetch)
    (uri (string-append "https://codeload.github.com/itplr-kosit/"
                        "validator-configuration-xrechnung/tar.gz/v2026-08-31"))
    (file-name "xrechnung-2026-08-31-source.tar.gz")
    (sha256 (base32 "1qg97di9gaim5drxr5p1b2lkv4zaqnnwrwvnrwpn26k95hgzba74"))))

;; These dependency JARs omit embedded license files.  Preserve notices from
;; their exact source tags rather than relying on a generic license label.
(define %xmlresolver-source
  (origin
    (method url-fetch)
    (uri "https://codeload.github.com/xmlresolver/xmlresolver/tar.gz/5.3.3")
    (file-name "xmlresolver-5.3.3-source.tar.gz")
    (sha256 (base32 "19ad9xq2zds3fxqwbk42vqymjrkd3b9d3wq2y8pskjhn4dfrxnnk"))))

(define %jansi-source
  (origin
    (method url-fetch)
    (uri "https://codeload.github.com/fusesource/jansi/tar.gz/jansi-2.4.3")
    (file-name "jansi-2.4.3-source.tar.gz")
    (sha256 (base32 "1275a84n1pgajsry77nib0qxdw1k2s3smla7qkbcfyd142vms7ra"))))

(define %istack-source
  (origin
    (method url-fetch)
    (uri "https://codeload.github.com/eclipse-ee4j/jaxb-istack-commons/tar.gz/4.1.2")
    (file-name "istack-4.1.2-source.tar.gz")
    (sha256 (base32 "1h41qdwzdzpwgw2scnrhhzqhxid64hcsvxfi59574d4782mb6qg6"))))

(define %picocli-license
  (origin
    (method url-fetch)
    (uri "https://raw.githubusercontent.com/remkop/picocli/v4.7.7/LICENSE")
    (file-name "picocli-4.7.7-LICENSE")
    (sha256 (base32 "1q9kz1g5b7lvcpspihqn4xr1sr2nl2fvq4kaqj34qx40ryxk02dl"))))

(define-public kosit-validator
  (package
    (name "kosit-validator")
    (version "1.6.3")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://github.com/itplr-kosit/validator/"
                           "releases/download/v1.6.3/validator-1.6.3.zip"))
       (sha256 (base32 "08kqqf5rlwyl4zx0paar05hm50ww9ahxkvdpvpjxm1jizycs7mcm"))))
    (build-system trivial-build-system)
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      #~(begin
          (use-modules (guix build utils))
          (let ((share (string-append #$output "/share/kosit-validator"))
                (bin (string-append #$output "/bin")))
            (mkdir-p share)
            ;; Official binary distribution, deliberately not a source rebuild.
            ;; Retain every JAR byte and its embedded third-party notices.
            (invoke #$(file-append libarchive "/bin/bsdtar") "-xf"
                    #$source "-C" share)
            (install-file #$%validator-source (string-append share "/source"))
            ;; MPL-2.0 corresponding source for the exact unmodified Saxon JAR.
            (install-file #$%saxon-source (string-append share "/source"))
            (invoke #$(file-append libarchive "/bin/bsdtar") "-xf"
                    #$%saxon-notices "-C" share "notices")
            (mkdir "license-sources")
            (for-each
             (lambda (archive)
               (install-file archive (string-append share "/source"))
               (invoke #$(file-append libarchive "/bin/bsdtar") "-xf"
                       archive "-C" "license-sources"))
             (list #$%xmlresolver-source #$%jansi-source #$%istack-source))
            (for-each
             (lambda (file)
               (install-file file
                 (string-append share "/notices/" (dirname file))))
             (find-files "license-sources"
                         "^([Ll][Ii][Cc][Ee][Nn][Ss][Ee]|NOTICE)([.](md|txt))?$"))
            (copy-recursively "license-sources/xmlresolver-5.3.3/docs/notices"
                              (string-append share "/notices/xmlresolver")
                              #:log (%make-void-port "w"))
            (copy-file #$%picocli-license
                       (string-append share "/notices/picocli-LICENSE"))
            (setrlimit 'as (* 2 1024 1024 1024) (* 2 1024 1024 1024))
            (setrlimit 'nproc 256 256)
            (setrlimit 'fsize (* 64 1024 1024) (* 64 1024 1024))
            (setrlimit 'cpu 300 300)
            (setrlimit 'core 0 0)
            (copy-file #$(local-file "aux-files/KositCli.java") "KositCli.java")
            (copy-file "KositCli.java" (string-append share "/source/KositCli.java"))
            (copy-file (string-append share "/LICENSE")
                       (string-append share "/source/KositCli-LICENSE"))
            (invoke (string-append #$openjdk17:jdk "/bin/javac")
                    "-J-Xmx256m" "-J-XX:+UseSerialGC"
                    "-J-XX:CompressedClassSpaceSize=64m"
                    "-J-XX:ReservedCodeCacheSize=64m" "--release" "17"
                    "-cp" (string-append share "/validator-1.6.3.jar:"
                                         share "/libs/*")
                    "-d" (string-append share "/cli")
                    "KositCli.java")
            (mkdir-p bin)
            (let ((launcher (string-append bin "/kosit-validator")))
              (call-with-output-file launcher
                (lambda (port)
                  (format port
                    (string-append
                     "#!~a~%unset JAVA_TOOL_OPTIONS JDK_JAVA_OPTIONS "
                     "_JAVA_OPTIONS CLASSPATH~%export MALLOC_ARENA_MAX=2~%"
                     "exec ~a -Xmx512m -Xss512k -XX:+UseSerialGC "
                     "-XX:ActiveProcessorCount=4 -XX:CICompilerCount=2 "
                     "-XX:CompressedClassSpaceSize=64m "
                     "-XX:ReservedCodeCacheSize=64m -Djava.awt.headless=true "
                     "-Djavax.xml.accessExternalDTD= "
                     "-Djavax.xml.accessExternalSchema=file "
                     "-Djavax.xml.accessExternalStylesheet=file "
                     "-cp '~a:~a/libs/*:~a/cli' "
                     "de.kosit.validationtool.cmd.KositCli \"$@\"~%")
                    #$(file-append bash-minimal "/bin/bash")
                    #$(file-append %java "/bin/java")
                    (string-append share "/validator-1.6.3.jar") share share)))
              (chmod launcher #o755))))))
    (native-inputs `(("libarchive" ,libarchive)
                     ("openjdk:jdk" ,openjdk17 "jdk")))
    (inputs (list bash-minimal %java %validator-source %saxon-source
                  %saxon-notices %xmlresolver-source %jansi-source
                  %istack-source %picocli-license))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/itplr-kosit/validator")
    (synopsis "KoSIT XML invoice validator")
    (description
     "KoSIT validates XML documents against local scenario configurations,
XML schemas and Schematron rules.  This package repackages the official binary
distribution unchanged, with its individual dependency JARs, license notices,
and corresponding Saxon source.  The launcher uses a pinned Java 17 runtime.
Use xrechnung-validator-configuration for the complete XRechnung rules.  A small
compiled entrypoint preserves the documented error exit for invalid arguments
and adds --version; the upstream JARs are not modified.")
    (license (list license:asl2.0 license:mpl2.0 license:bsd-3 license:expat))))

(define-public xrechnung-validator-configuration
  (package
    (name "xrechnung-validator-configuration")
    (version "2026-08-31")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://github.com/itplr-kosit/validator-configuration-xrechnung/"
             "releases/download/v2026-08-31/"
             "xrechnung-3.0.2-validator-configuration-2026-08-31.zip"))
       (sha256 (base32 "1a112bq0pmw35sw0v0napxd3j439i07w2bj6s32i2ia1gh8csc15"))))
    (build-system trivial-build-system)
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      #~(begin
          (use-modules (guix build utils))
          (let ((share (string-append #$output "/share/xrechnung"))
                (bin (string-append #$output "/bin")))
            (mkdir-p share)
            (invoke #$(file-append libarchive "/bin/bsdtar") "-xf"
                    #$source "-C" share)
            (mkdir "notices")
            (invoke #$(file-append libarchive "/bin/bsdtar") "-xf"
                    #$%xrechnung-source "-C" "notices")
            (for-each
             (lambda (name)
               (install-file
                (string-append
                 "notices/validator-configuration-xrechnung-2026-08-31/" name)
                share)) '("LICENSE" "NOTICE"))
            (install-file #$%xrechnung-source (string-append share "/source"))
            (mkdir-p bin)
            (let ((launcher (string-append bin "/xrechnung-validator")))
              (call-with-output-file launcher
                (lambda (port)
                  (format port "#!~a~%exec ~a -s ~a/scenarios.xml -r ~a \"$@\"~%"
                    #$(file-append bash-minimal "/bin/bash")
                    #$(file-append kosit-validator "/bin/kosit-validator")
                    share share)))
              (chmod launcher #o755))))))
    (native-inputs (list libarchive))
    (inputs (list bash-minimal kosit-validator %xrechnung-source))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/itplr-kosit/validator-configuration-xrechnung")
    (synopsis "Complete offline XRechnung 3.0.2 validation configuration")
    (description
     "This package provides KoSIT's official XRechnung 3.0.2 configuration,
including CEN 1.3.16 Schematron, UBL and CII schemas, local imports and reports.
The xrechnung-validator command uses these pinned rules and KoSIT Validator.
The complete release data is preserved, with Apache notices from its exact
source tag.  No network retrieval is required for validation.")
    (license license:asl2.0)))

;; Acceptance runs against completed, immutable package inputs in the daemon's
;; isolated namespace, separately from their installation derivations.
(define-public kosit-validator-tests
  (computed-file
   "kosit-validator-installed-tests"
   (with-imported-modules '((guix build utils))
     #~(begin
         (use-modules (guix build utils))
         (invoke #$(file-append libarchive "/bin/bsdtar") "-xf"
                 #$%xrechnung-source)
         (mkdir "distribution")
         (invoke #$(file-append libarchive "/bin/bsdtar") "-xf"
                 #$(package-source kosit-validator) "-C" "distribution")
         (for-each
          (lambda (name)
            (copy-recursively #$(file-append xrechnung-validator-configuration "/share/xrechnung")
                              name #:log (%make-void-port "w"))
            (for-each (lambda (file) (chmod file #o644)) (find-files name)))
          '("remote-include" "remote-import" "file-include"))
         (call-with-output-file "external.xsl"
           (lambda (port)
             (display "<xsl:stylesheet version='2.0' xmlns:xsl='http://www.w3.org/1999/XSL/Transform'><xsl:template match='/'><unexpected>UNEXPECTED-ENTITY-CONTENT</unexpected></xsl:template></xsl:stylesheet>" port)))
         (setrlimit 'as (* 2 1024 1024 1024) (* 2 1024 1024 1024))
         (setrlimit 'nproc 256 256)
         (setrlimit 'fsize (* 64 1024 1024) (* 64 1024 1024))
         (setrlimit 'cpu 300 300)
         (setrlimit 'core 0 0)
         (copy-file #$(local-file "../../tests/fixtures/einvoicing/StrictLocalProbe.java")
                    "StrictLocalProbe.java")
         (invoke (string-append #$openjdk17:jdk "/bin/javac")
                 "-J-Xmx256m" "-J-XX:+UseSerialGC"
                 "-J-XX:CompressedClassSpaceSize=64m"
                 "-J-XX:ReservedCodeCacheSize=64m" "--release" "17"
                 "-cp" (string-append #$kosit-validator
                        "/share/kosit-validator/validator-1.6.3.jar:"
                        #$kosit-validator "/share/kosit-validator/libs/*")
                 "-d" "probe" "StrictLocalProbe.java")
         (let ((fixtures "validator-configuration-xrechnung-2026-08-31/src/test/instances/processing-valid"))
           (copy-file #$(local-file "../../tests/fixtures/einvoicing/cii-valid.xml")
                      (string-append fixtures "/cii001.xml"))
           (invoke #$(file-append guile-3.0 "/bin/guile") "--no-auto-compile" "-s"
                   #$(local-file "../../tests/einvoicing.scm.in")
                   #$kosit-validator #$xrechnung-validator-configuration
                   (string-append (getcwd) "/" fixtures) #$output
                   (string-append (getcwd) "/distribution")
                   #$(file-append %java "/bin/java"))
           ;; The child must exit before copying its fully flushed SRFI-64 log.
           (copy-file "einvoicing.log"
                      (string-append #$output "/tests.log")))))))
