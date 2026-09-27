;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; This file is part of the securityops channel.

(define-module (securityops packages webpki)
  #:use-module (gnu packages backup)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages fontutils)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages gl)
  #:use-module (gnu packages gtk)
  #:use-module (gnu packages icu4c)
  #:use-module (gnu packages tls)
  #:use-module (gnu packages vulkan)
  #:use-module (gnu packages web)
  #:use-module (gnu packages xdisorg)
  #:use-module (gnu packages xorg)
  #:use-module (guix build-system gnu)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix packages)
  #:use-module ((guix licenses) #:prefix license:))

(define-public lacuna-webpki
  (package
    (name "lacuna-webpki")
    (version "2.16.0")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://get.webpkiplugin.com/Downloads/" version
                           "/setup-rpm-64"))
       (file-name (string-append name "-" version ".rpm"))
       (sha256
        (base32 "1rp1p46wrczmnid32mlc4zhjvdfvn2phbkpglpcjc1sx9sjfp720"))))
    (build-system gnu-build-system)
    (arguments
     (list
      ;; The RPM contains an already linked, self-extracting .NET executable.
      #:strip-binaries? #f
      #:phases
      #~(modify-phases %standard-phases
          (replace 'unpack
            (lambda* (#:key source #:allow-other-keys)
              (mkdir "source")
              (chdir "source")
              (invoke "bsdtar" "-xf" source)
              (unless (file-exists? "opt/lacuna-webpki/webpki")
                (error "Web PKI executable missing from RPM"))))
          (delete 'configure)
          (delete 'build)
          (replace 'check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (for-each (lambda (file)
                            (invoke "jq" "-e"
                                    (string-append
                                     ".name == \"com.lacunasoftware.webpki\""
                                     " and .type == \"stdio\"")
                                    (string-append "opt/lacuna-webpki/" file)))
                          '("manifest-firefox.json" "manifest.json"
                            "manifest-edge.json")))))
          (replace 'install
            (lambda* (#:key inputs #:allow-other-keys)
              (let* ((bin (string-append #$output "/bin"))
                     (host (string-append bin "/lacuna-webpki"))
                     (lib-dirs (map (lambda (name)
                                      (string-append (assoc-ref inputs name)
                                                     "/lib"))
                                    '("glibc" "gcc:lib"
                                      "zlib"
                                      "openssl"
                                      "icu4c"
                                      "libx11"
                                      "fontconfig-minimal"
                                      "libice"
                                      "libsm"
                                      "libxext"
                                      "libxrender"
                                      "libxi"
                                      "libxrandr"
                                      "libxcursor"
                                      "libxkbcommon"
                                      "mesa"
                                      "freetype"
                                      "gtk+"
                                      "vulkan-loader"))))
                (mkdir-p bin)
                (copy-file "opt/lacuna-webpki/webpki" host)
                (chmod host #o755)
                (invoke "patchelf"
                        "--set-interpreter"
                        (string-append (assoc-ref inputs "glibc")
                                       "/lib/ld-linux-x86-64.so.2")
                        "--set-rpath"
                        (string-append "$ORIGIN/netcoredeps:"
                                       (string-join lib-dirs ":"))
                        host)
                (wrap-program host
                  `("LD_LIBRARY_PATH" prefix
                    ,lib-dirs)
                  `("XDG_DATA_DIRS" prefix
                    (,(string-append (assoc-ref inputs "gtk+") "/share")))))))
          (add-after 'install 'install-native-manifests
            (lambda _
              (let* ((directory (string-append #$output
                                 "/share/lacuna-webpki/native-messaging-hosts"))
                     (host (string-append #$output "/bin/lacuna-webpki")))
                (mkdir-p directory)
                (for-each (lambda (source-file destination-file)
                            (let ((destination (string-append directory "/"
                                                destination-file)))
                              (copy-file (string-append "opt/lacuna-webpki/"
                                                        source-file)
                                         destination)
                              (substitute* destination
                                (("/opt/lacuna-webpki/webpki")
                                 host))
                              (invoke "jq"
                                      "-e"
                                      "--arg"
                                      "host"
                                      host
                                      ".path == $host"
                                      destination)))
                          '("manifest-firefox.json" "manifest.json"
                            "manifest-edge.json")
                          '("firefox.json" "chromium.json" "edge.json"))))))))
    (native-inputs (list libarchive patchelf jq))
    (inputs (list (list "gcc:lib" gcc "lib")
                  (list "bash-minimal" bash-minimal)
                  (list "glibc" glibc)
                  (list "zlib" zlib)
                  (list "openssl" openssl)
                  (list "icu4c" icu4c-78)
                  (list "libx11" libx11)
                  (list "fontconfig-minimal" fontconfig)
                  (list "libice" libice)
                  (list "libsm" libsm)
                  (list "libxext" libxext)
                  (list "libxrender" libxrender)
                  (list "libxi" libxi)
                  (list "libxrandr" libxrandr)
                  (list "libxcursor" libxcursor)
                  (list "libxkbcommon" libxkbcommon)
                  (list "mesa" mesa)
                  (list "freetype" freetype)
                  (list "gtk+" gtk+)
                  (list "vulkan-loader" vulkan-loader)))
    (supported-systems '("x86_64-linux"))
    (home-page "https://docs.lacunasoftware.com/en-us/articles/web-pki")
    (synopsis "Native host for the Lacuna Web PKI browser extension")
    (description
     "This package adapts Lacuna Web PKI's x86_64 Linux RPM to Guix and
provides the native messaging host and manifests for Firefox-compatible,
Chromium-compatible, and Edge browsers.  The browser extension must be
installed separately, and the relevant manifest must be linked into the
browser's native messaging directory.  Upstream has discontinued Linux
support for this component.")
    (license license:expat)))
