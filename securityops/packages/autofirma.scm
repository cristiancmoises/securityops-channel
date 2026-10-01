;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>

(define-module (securityops packages autofirma)
  #:use-module (gnu packages backup)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages fontutils)
  #:use-module (gnu packages fonts)
  #:use-module (gnu packages freedesktop)
  #:use-module (gnu packages guile)
  #:use-module (gnu packages java)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages security-token)
  #:use-module (gnu packages sqlite)
  #:use-module (gnu packages tls)
  #:use-module (gnu packages xorg)
  #:use-module ((gnu packages virtualization) #:select (bubblewrap))
  #:use-module (guix build-system gnu)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix packages)
  #:use-module ((securityops packages librewolf) #:prefix channel:)
  #:use-module ((guix licenses) #:prefix license:))

(define temurin17-runtime
  (package
    (name "autofirma-temurin17-runtime")
    (version "17.0.20.1+1")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://github.com/adoptium/temurin17-binaries/releases/download/"
             "jdk-17.0.20.1%2B1/"
             "OpenJDK17U-jre_x64_linux_hotspot_17.0.20.1_1.tar.gz"))
       (sha256
        (base32 "0qjssiacx0a68nniz8mxh80n3d8vv6whmph4qn74rdj660768aqb"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:strip-binaries? #f
      #:modules '((guix build gnu-build-system)
                  (guix build utils)
                  (system vm elf)
                  (rnrs io ports)
                  (srfi srfi-1))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)
          (delete 'build)
          (delete 'check)
          (replace 'install
            (lambda _
              (copy-recursively "." #$output)))
          (add-after 'install 'patch-runtime
            (lambda _
              (let ((interpreter
                     (string-append #$(file-append glibc "/lib")
                                    "/ld-linux-x86-64.so.2"))
                    (rpath
                     (string-join
                      (cons* (string-append #$output "/lib")
                             (string-append #$output "/lib/server")
                             (list #$(file-append glibc "/lib")
                                   #$(file-append alsa-lib "/lib")
                                   #$(file-append fontconfig "/lib")
                                   #$(file-append libx11 "/lib")
                                   #$(file-append libxext "/lib")
                                   #$(file-append libxi "/lib")
                                   #$(file-append libxrender "/lib")
                                   #$(file-append libxtst "/lib")))
                      ":")))
                (for-each
                 (lambda (file)
                   (when (elf-file? file)
                     (let ((elf (call-with-input-file file
                                  (lambda (port)
                                    (parse-elf (get-bytevector-all port))))))
                       ;; Helpers such as lib/jspawnhelper also have an
                       ;; interpreter; shared libraries must not gain one.
                       (when (any (lambda (segment)
                                    (= (elf-segment-type segment) PT_INTERP))
                                  (elf-segments elf))
                         (invoke "patchelf" "--set-interpreter"
                                 interpreter file)))
                     (invoke "patchelf" "--set-rpath" rpath file)))
                 (find-files #$output)))))
          (add-after 'patch-runtime 'check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (invoke (string-append #$output "/bin/java") "-version")
                (invoke "guile" "--no-auto-compile" "-s"
                        #$(local-file "../../tests/autofirma.scm.in")
                        "--runtime" #$output)))))))
    ;; The existing compiler is only used for the ProcessBuilder test fixture;
    ;; no old JDK is retained in the installed runtime or used for signing.
    (native-inputs (list patchelf guile-3.0 (list openjdk17 "jdk")))
    (inputs (list glibc alsa-lib fontconfig libx11 libxext libxi libxrender
                  libxtst))
    (supported-systems '("x86_64-linux"))
    (home-page "https://adoptium.net/temurin/")
    (synopsis "Patched Java 17 runtime for AutoFirma")
    (description
     "This private runtime repacks Eclipse Temurin's official x86-64 Linux JRE
and links its native libraries to Guix dependencies.  AutoFirma 1.9 explicitly
supports Java 17; this runtime includes the current Java 17 security updates
without rebuilding an older JDK bootstrap chain.  The upstream legal notices,
Java security configuration and CA certificates are preserved.")
    ;; OpenJDK's GPL-2 license includes the Classpath exception.  Preserve the
    ;; complete upstream legal/ directory, including third-party notices.
    (license license:gpl2)))

(define %autofirma-nss-package
  (lookup-package-input channel:librewolf "nss-rapid"))

(define %autofirma-nspr-package
  (lookup-package-propagated-input %autofirma-nss-package "nspr"))

(define %autofirma-nss
  (directory-union "autofirma-nss"
                   (list (file-append %autofirma-nss-package "/lib/nss")
                         (file-append %autofirma-nspr-package "/lib")
                         (file-append sqlite-next "/lib"))))

(define %autofirma-fonts
  (mixed-text-file
   "autofirma-fonts.conf"
   "<?xml version=\"1.0\"?><!DOCTYPE fontconfig SYSTEM \"urn:fontconfig:fonts.dtd\">\n"
   "<fontconfig><dir>" (file-append font-dejavu "/share/fonts/truetype")
   "</dir><dir>~/.local/share/fonts</dir><dir>~/.fonts</dir>"
   "<cachedir>~/.cache/fontconfig</cachedir></fontconfig>\n"))

;; Resolve the exact runtime closure at build time, never via runtime Guix.
(define %autofirma-closure
  (computed-file
   "autofirma-runtime-closure"
   #~(call-with-output-file #$output
       (lambda (port)
         (for-each (lambda (path) (display path port) (newline port))
                   (call-with-input-file
                       #$(references-file
                          (file-union
                           "autofirma-runtime-roots"
                           `(("java" ,temurin17-runtime)
                             ("bash" ,bash-minimal)
                             ("xdg" ,xdg-utils)
                             ("pcsc" ,pcsc-lite)
                             ("nss" ,%autofirma-nss)
                             ("fonts" ,%autofirma-fonts))))
                     read))))))

(define-public autofirma
  (package
    (name "autofirma")
    ;; Linux has its own release series: 1.9.1 and 1.9.2 are macOS releases.
    (version "1.9")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://firmaelectronica.gob.es/content/dam/firmaelectronica/"
             "descargas-software/autofirma19/Autofirma_Linux_Debian.zip"))
       (file-name (string-append name "-" version "-linux.zip"))
       (sha256
        (base32 "1637f6pcwrghgx0v0slqclsshdnlvdvjcn7rhzy0vw795qgjb762"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:strip-binaries? #f
      #:phases
      #~(modify-phases %standard-phases
          (replace 'unpack
            (lambda* (#:key source #:allow-other-keys)
              (mkdir "source")
              (chdir "source")
              (invoke "bsdtar" "-xf" source)
              (invoke "bsdtar" "-xf" "autofirma_1_9.deb")
              ;; Extract data only.  Debian maintainer scripts change browser
              ;; and system certificate stores and must never be executed.
              (invoke "bsdtar" "-xf" "data.tar.gz")))
          (delete 'configure)
          (delete 'build)
          (delete 'check)
          (replace 'install
            (lambda _
              (let ((bin (string-append #$output "/bin"))
                    (java #$(file-append temurin17-runtime "/bin/java"))
                    (jar (string-append #$output
                                        "/share/autofirma/autofirma.jar")))
                ;; Preserve upstream's signed, shaded JAR without rewriting it.
                (install-file "usr/lib/Autofirma/autofirma.jar"
                              (dirname jar))
                (mkdir-p bin)
                (for-each (lambda (name)
                            (let ((launcher (if (string=? name
                                                          "autofirma-java")
                                                (string-append #$output
                                                               "/libexec/"
                                                               name)
                                                (string-append bin "/" name))))
                              (mkdir-p (dirname launcher))
                              (call-with-output-file launcher
                                (lambda (port)
                                  (format port
                                          (string-append "#!~a~%"
                                           "export AFIRMA_NSS_HOME_ENV=~a~%"
                                           "export LD_LIBRARY_PATH=\"~a"
                                           "${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}\"~%"
                                           "exec ~a \\\n"
                                           "  -Djdk.tls.maxHandshakeMessageSize=65536 \\
"
                                           "  -Des.gob.afirma.keystores.mozilla."
                                           "UseEnvironmentVariables=true \\\n"
                                           "  -Dsun.security.smartcardio.library=~a \\
"
                                           "  ~a-jar ~a \"$@\"~%")
                                          #$(file-append bash-minimal
                                                         "/bin/bash")
                                          #$%autofirma-nss
                                          #$%autofirma-nss
                                          java
                                          #$(file-append pcsc-lite
                                             "/lib/libpcsclite.so.1")
                                          (if (string=? name "autofirmacl")
                                              "-Dafirma_debug_level=OFF "
                                              "\"-Duser.home=$HOME\" ")
                                          jar)))
                              (chmod launcher #o755)
                              (wrap-program launcher
                                `("PATH" prefix
                                  (,#$(file-append xdg-utils "/bin"))))))
                          '("autofirma-java" "autofirmacl")))
              (let ((launcher (string-append #$output "/bin/autofirma")))
                (copy-file #$(local-file "aux-files/autofirma-gui.sh")
                           launcher)
                (substitute* launcher
                  (("^#!/bin/bash")
                   (string-append "#!"
                                  #$(file-append bash-minimal "/bin/bash")))
                  (("@OUTPUT@")
                   #$output)
                  (("@REALPATH@")
                   #$(file-append coreutils-minimal "/bin/realpath"))
                  (("@CLOSURE@")
                   #$%autofirma-closure)
                  (("@NSS@")
                   #$%autofirma-nss)
                  (("@FONTS@")
                   #$%autofirma-fonts)
                  (("@BWRAP@")
                   #$(file-append bubblewrap "/bin/bwrap")))
                (chmod launcher #o755))
              (install-file "usr/lib/Autofirma/Autofirma.png"
                            (string-append #$output
                             "/share/icons/hicolor/128x128/apps"))
              (install-file "usr/share/Autofirma/Autofirma.svg"
                            (string-append #$output
                             "/share/icons/hicolor/scalable/apps"))
              (install-file "usr/share/applications/afirma.desktop"
                            (string-append #$output "/share/applications"))
              (substitute* (string-append #$output
                            "/share/applications/afirma.desktop")
                (("^Encoding=.*")
                 "")
                (("^Version=.*")
                 "Version=1.0\n")
                (("^Categories=.*")
                 "Categories=Office;Java;\n")
                (("^GenericName=.*")
                 "GenericName=Electronic signature tool\n")
                (("^Comment=.*")
                 "Comment=Sign electronic documents\n")
                (("^Exec=.*")
                 (string-append "Exec="
                                #$output "/bin/autofirma %u\n"))
                (("^Icon=.*")
                 "Icon=Autofirma\n"))
              (copy-recursively "usr/share/doc/Autofirma"
                                (string-append #$output "/share/doc/autofirma"))
              (for-each (lambda (file)
                          (install-file (string-append
                                         "usr/share/common-licenses/" file)
                                        (string-append #$output
                                                       "/share/doc/autofirma")))
                        '("eupl-1.1.txt" "gpl-2.0.txt"))))
          (add-after 'install 'check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (invoke "desktop-file-validate"
                        (string-append #$output
                                       "/share/applications/afirma.desktop"))
                (invoke "guile" "--no-auto-compile" "-s"
                        #$(local-file "../../tests/autofirma.scm.in")
                        #$output)
                (invoke "bash"
                        #$(local-file "../../tests/autofirma-gui.sh")
                        #$output)))))))
    (native-inputs (list libarchive desktop-file-utils guile-3.0 openssl))
    (inputs (list bash-minimal
                  temurin17-runtime
                  %autofirma-nss-package
                  %autofirma-nspr-package
                  sqlite-next
                  pcsc-lite
                  xdg-utils
                  coreutils-minimal
                  bubblewrap
                  font-dejavu))
    (supported-systems '("x86_64-linux"))
    (home-page "https://firmaelectronica.gob.es/descargas")
    (synopsis "Electronic document signing client for Spanish public services")
    (description
     "AutoFirma signs electronic documents from its graphical interface or
command line and provides the @code{afirma://} browser protocol handler.  This
package repacks the official Linux release, retaining its signed JAR and bundled
Java libraries, and uses a private, security-updated Temurin 17 runtime with
Guix's NSS and PC/SC libraries.  A source build would require separately
packaging the upstream Maven dependency graph,
including its snapshot dependencies.  Upstream's certificate configurator,
certificate installation scripts, and Firefox preference overrides are not
installed or executed.  Browser integration requires separately provisioning
and trusting AutoFirma's local-service certificate; installing this package
does not change any certificate store.  Smart-card access requires a running
PC/SC service.  The GUI requires available unprivileged user namespaces and
uses Bubblewrap only to provide compatible NSS paths and a readable
@file{/opt}, not as a security sandbox.  The real user home and selected
display, session-bus and PC/SC sockets remain accessible.  Directories outside
the home can be shared explicitly using the colon-separated
@code{AUTOFIRMA_SHARED_DIRECTORIES} environment variable; broad system roots
are rejected.")
    ;; AutoFirma is GPL-2+ OR EUPL-1.1.  Its signed JAR also includes third-party
    ;; code; retain the bundled notices and include their license families.
    (license (list license:gpl2+
                   license:eupl1.1
                   license:asl2.0
                   license:asl1.1
                   license:expat
                   license:bsd-3
                   license:lgpl2.1+
                   license:mpl1.1
                   license:mpl2.0
                   license:cddl1.0))))
