;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; This file is part of the securityops channel.
;;;
;;; Official upstream portable build for x86_64 Linux.  Its release schedule
;;; differs from the source release; the version and hash below identify the
;;; exact published binary, without downloading code at runtime.

(define-module (securityops packages chromium)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (nonguix build-system chromium-binary)
  #:use-module ((gnu packages chromium) #:prefix cr:)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages curl)
  #:use-module (gnu packages fonts)
  #:use-module (gnu packages freedesktop)
  #:use-module (gnu packages gl)
  #:use-module (gnu packages gtk)
  #:use-module (gnu packages image)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages pciutils)
  ;; Avoid importing libcamera-minimal twice (networking also exports it).
  #:use-module ((gnu packages photo) #:hide (libcamera-minimal))
  #:use-module (gnu packages qt)
  #:use-module (gnu packages video)
  #:use-module (gnu packages wget)
  #:use-module (gnu packages xiph)
  #:use-module (gnu packages xorg))

(define-public ungoogled-chromium-bin
  (package
    (name "ungoogled-chromium-bin")
    (version "153.0.8010.47-1")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://github.com/ungoogled-software/"
             "ungoogled-chromium-portablelinux/releases/download/"
             version
             "/ungoogled-chromium-"
             version
             "-x86_64_linux.tar.xz"))
       (sha256
        (base32 "1s8mmq65b1xyn0i6k8ng2314phjvnkvbkcwg1rvcf05rrg2w2hf6"))))
    (build-system chromium-binary-build-system)
    (arguments
     (list
      ;; ~140MB prebuilt; nothing to substitute, always wrap locally.
      #:substitutable? #f
      ;; chrome links libnss3.so/libnssutil3.so/libsmime3.so directly, but NSS
      ;; installs those under nss/lib/nss (not nss/lib), so they are out of
      ;; RUNPATH reach.  install-wrapper adds nss/lib/nss to LD_LIBRARY_PATH, so
      ;; they resolve at runtime; the build-time RUNPATH check cannot see that.
      #:validate-runpath? #f
      ;; The 9 ELF objects bundled in the tarball (paths are relative to the
      ;; unpacked top directory, which `unpack' chdirs into).  patchelf sets
      ;; their interpreter to the Guix glibc loader and their RPATH to the
      ;; chromium-binary base inputs plus the extra inputs below.
      #:wrapper-plan
      #~'("chrome" "chrome_crashpad_handler"
          "chromedriver"
          "libEGL.so"
          "libGLESv2.so"
          "libqt5_shim.so"
          "libqt6_shim.so"
          "libvk_swiftshader.so"
          "libvulkan.so.1")
      #:install-plan
      #~'(("." "share/ungoogled-chromium/"))
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'install 'install-icon
            (lambda _
              (let ((logo (string-append #$output
                           "/share/ungoogled-chromium/product_logo_48.png"))
                    (target (string-append #$output
                             "/share/icons/hicolor/48x48/apps/chromium.png")))
                (when (file-exists? logo)
                  (mkdir-p (dirname target))
                  (copy-file logo target)))))
          (add-after 'install 'install-desktop
            (lambda _
              (let ((dir (string-append #$output "/share/applications")))
                (mkdir-p dir)
                (call-with-output-file (string-append dir "/chromium.desktop")
                  (lambda (port)
                    (format port
                     "[Desktop Entry]~%Type=Application~%Name=ungoogled-chromium~%~
GenericName=Web Browser~%Exec=~a/bin/chromium %U~%Icon=chromium~%~
Terminal=false~%Categories=Network;WebBrowser;~%~
MimeType=text/html;x-scheme-handler/http;x-scheme-handler/https;~%~
StartupWMClass=chromium~%"
                     #$output))))))
          ;; Expose both commands so install-wrapper supplies their shared
          ;; FONTCONFIG_PATH / PATH / LD_LIBRARY_PATH, including NSS.
          (add-before 'install-wrapper 'install-exe
            (lambda _
              (let ((bin (string-append #$output "/bin"))
                    (chrome (string-append #$output
                                           "/share/ungoogled-chromium/chrome"))
                    (driver (string-append #$output
                                           "/share/ungoogled-chromium/chromedriver")))
                (mkdir-p bin)
                (symlink chrome
                         (string-append bin "/chromium"))
                (symlink driver
                         (string-append bin "/chromedriver")))))
          (add-after 'install-wrapper 'check-installed-binaries
            (lambda* (#:key (tests? #t) #:allow-other-keys)
              (when tests?
                (invoke (string-append #$output "/bin/chromium") "--version")
                (invoke (string-append #$output "/bin/chromedriver")
                        "--version")))))))
    (inputs (list bzip2
                  curl
                  flac
                  font-liberation
                  gdk-pixbuf
                  gtk
                  harfbuzz
                  libexif
                  libglvnd
                  libpng
                  libva
                  libxscrnsaver
                  opus
                  pciutils
                  pipewire
                  qtbase-5
                  qtbase
                  snappy
                  util-linux
                  xdg-utils
                  wget))
    (synopsis "Ungoogled Chromium web browser (portable upstream build)")
    (description
     "ungoogled-chromium is Google Chromium with the Google-integration and
privacy-affecting code removed.  This package adapts the upstream portable
Linux x86_64 binary to Guix library paths.  The binary release can lag behind
the source release.  Chromium uses its unprivileged user-namespace sandbox;
this package does not install a setuid sandbox helper.")
    (home-page "https://github.com/ungoogled-software/ungoogled-chromium")
    (supported-systems '("x86_64-linux"))
    (license (package-license cr:ungoogled-chromium))))
