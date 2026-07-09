;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; This file is part of the securityops channel.
;;;
;;; ungoogled-chromium — PREBUILT binary, latest available.
;;;
;;; Guix builds ungoogled-chromium from a Chromium "-lite" source tarball hosted
;;; ONLY on Google's commondatastorage GCS bucket, which 403-blocks every Tor
;;; exit node.  guix can build *existing* versions because their source arrives
;;; as a substitute (.tar.zst) from bordeaux.guix.gnu.org — but a brand-new
;;; release has no substitute anywhere, so its base tarball must come straight
;;; from Google, which is unreachable on a Tor-only host.  A from-source bump is
;;; therefore impossible here (and would be a ~30GB-RAM, multi-hour compile on a
;;; 15GB machine regardless).
;;;
;;; The ungoogled-software project publishes official, integrity-hashed PREBUILT
;;; Linux x86_64 binaries on GitHub (Tor-reachable), tracked in the
;;; ungoogled-chromium-binaries metadata repo under linux_portable/64bit.  The
;;; newest prebuilt at packaging time is 150.0.7871.100-1 (published
;;; 2026-07-09).  We wrap that tarball
;;; with nonguix's chromium-binary-build-system (same machinery as google-chrome):
;;; patchelf the 9 bundled ELF objects onto the Guix glibc loader + library set,
;;; install the bundle under share/, and expose bin/chromium.  No bundled
;;; chrome-sandbox => Chromium uses the unprivileged user-namespace sandbox.
;;;
;;; sha256 (base32) verified against the official upstream metadata
;;; (d66edf0ab8e67a9e9be276e67482125ec62a676ebb7e988ab793b9b758c587c1).

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
  #:use-module (gnu packages photo)
  #:use-module (gnu packages qt)
  #:use-module (gnu packages video)
  #:use-module (gnu packages wget)
  #:use-module (gnu packages xiph)
  #:use-module (gnu packages xorg))

(define-public ungoogled-chromium-bin
  (package
    (name "ungoogled-chromium-bin")
    (version "150.0.7871.100-1")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://github.com/ungoogled-software/"
             "ungoogled-chromium-portablelinux/releases/download/"
             version "/ungoogled-chromium-" version "-x86_64_linux.tar.xz"))
       (sha256
        (base32 "1n573n3gkdqjcfwzyqcdyqqz0g7a2ya0sbs3j9b17hy02vsbiv6x"))))
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
      #~'("chrome"
          "chrome_crashpad_handler"
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
              (let ((logo (string-append
                           #$output "/share/ungoogled-chromium/product_logo_48.png"))
                    (target (string-append
                             #$output "/share/icons/hicolor/48x48/apps/chromium.png")))
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
          ;; Expose bin/chromium -> the bundled binary; install-wrapper then
          ;; wraps it with FONTCONFIG_PATH / PATH / LD_LIBRARY_PATH.
          (add-before 'install-wrapper 'install-exe
            (lambda _
              (let ((bin (string-append #$output "/bin"))
                    (chrome (string-append
                             #$output "/share/ungoogled-chromium/chrome")))
                (mkdir-p bin)
                (symlink chrome (string-append bin "/chromium"))))))))
    (inputs
     (list bzip2
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
    (synopsis "Ungoogled Chromium web browser (prebuilt, latest)")
    (description
     "ungoogled-chromium is Google Chromium with the Google-integration and
privacy-affecting code removed.  This package wraps the official upstream
prebuilt Linux x86_64 portable binary (latest available release) for the
@code{securityops} channel; it is the newest ungoogled-chromium obtainable on a
Tor-only host, where the from-source build's Chromium base tarball is
unreachable (Google's GCS 403-blocks Tor exits).")
    (home-page "https://github.com/ungoogled-software/ungoogled-chromium")
    (supported-systems '("x86_64-linux"))
    (license (package-license cr:ungoogled-chromium))))
