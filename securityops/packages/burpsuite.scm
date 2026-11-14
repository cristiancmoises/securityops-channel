;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>

;;; Burp Suite Community Edition, repackaged from the official Linux JAR.
;;; The unmodified JAR lives under libexec/burpsuite and is launched with
;;; OpenJDK 21, preserving the PortSwigger EULA under share/doc/burpsuite.
(define-module (securityops packages burpsuite)
  #:use-module (guix packages)
  #:use-module (guix licenses)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix build-system copy)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages java))

(define burpsuite-license
  (license "PortSwigger End-User License Agreement"
           "https://portswigger.net/burp/eula"
           "Official upstream binary; Community Edition terms apply."))

(define-public burpsuite
  (package
    (name "burpsuite")
    (version "2026.10.1")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://portswigger.net/burp/releases/download"
             "?product=desktop&version=" version "&type=Jar"))
       (file-name (string-append "burpsuite-" version ".jar"))
       (sha256
        (base32 "1if30rjwg7jwgiwq0ln8w2xah21ydhmgrlh9ra8knr5i6xjhiaz8"))))
    (build-system copy-build-system)
    (inputs
     (list bash-minimal
           `(,openjdk21 "jdk")))
    (arguments
     (list
      #:install-plan
      #~'(("burpsuite-2026.10.1.jar" "libexec/burpsuite/burpsuite.jar"))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'strip)
          (delete 'validate-runpath)
          (add-after 'install 'install-notices
            (lambda _
              (use-modules (guix build utils))
              (let ((doc (string-append #$output
                                        "/share/doc/burpsuite")))
                (mkdir-p doc)
                (call-with-output-file (string-append doc "/NOTICE.txt")
                  (lambda (port)
                    (display
                     (string-append
                      "Burp Suite Community Edition 2026.10.1\n"
                      "Official upstream JAR, repacked without modification.\n"
                      "Copyright (c) PortSwigger Ltd.\n"
                      "License: " "https://portswigger.net/burp/eula\n")
                     port))))))
          (add-after 'install-notices 'create-launcher
            (lambda* (#:key inputs #:allow-other-keys)
              (use-modules (guix build utils) (ice-9 format))
              (let* ((out #$output)
                     (java (search-input-file inputs "/bin/java"))
                     (shell (search-input-file inputs "/bin/sh"))
                     (jar (string-append out
                                         "/libexec/burpsuite/"
                                         "burpsuite.jar"))
                     (bin (string-append out "/bin"))
                     (launcher (string-append bin "/burpsuite")))
                (mkdir-p bin)
                (call-with-output-file launcher
                  (lambda (port)
                    (format port
                            (string-append
                             "#!~a~%"
                             "exec \"~a\" "
                             "--add-opens=java.desktop/javax.swing=ALL-UNNAMED "
                             "--add-opens=java.base/java.lang=ALL-UNNAMED "
                             "-jar \"~a\" \"$@\"~%")
                            shell java jar)))
                (chmod launcher #o755)))))))
    (supported-systems '("x86_64-linux"))
    (synopsis "Burp Suite Community Edition web security testing toolkit")
    (description
     "Burp Suite Community Edition is PortSwigger's free web security testing
toolkit, repackaged here from the official Linux JAR and launched with OpenJDK
21.  The PortSwigger EULA is installed under @file{share/doc/burpsuite}.")
    (home-page "https://portswigger.net/burp/communitydownload")
    (license burpsuite-license)))
