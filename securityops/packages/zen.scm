;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>

(define-module (securityops packages zen)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module (guix gexp)
  #:use-module (guix build-system copy)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages fontutils)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages gl)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages gtk)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages pciutils)
  #:use-module (gnu packages pulseaudio)
  #:use-module (gnu packages video)
  #:use-module (gnu packages vulkan)
  #:use-module (gnu packages xdisorg)
  #:use-module (gnu packages xorg))

(define-public zen-browser-bin
  (package
    (name "zen-browser-bin")
    (version "1.23.4b")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://github.com/zen-browser/desktop/releases/download/"
             version "/zen.linux-x86_64.tar.xz"))
       (sha256
        (base16-string->bytevector
         "ba81dd70af70d645f2f0a692f7fa4510f819290abfd8d8e60273d3d5a60d0536"))))
    (build-system copy-build-system)
    (arguments
     (list
      #:install-plan #~'(("./" "lib/zen-browser/"))
      #:phases
      #~(modify-phases %standard-phases
          ;; Preserve upstream binaries.  Their libraries are resolved by the
          ;; private launcher environment below rather than ELF RUNPATH.
          (delete 'strip)
          (delete 'validate-runpath)
          (add-after 'install 'patch-elf-interpreters
            (lambda* (#:key inputs #:allow-other-keys)
              (let ((loader (search-input-file inputs
                                               "/lib/ld-linux-x86-64.so.2")))
                (for-each
                 (lambda (name)
                   (invoke "patchelf" "--set-interpreter" loader
                           (string-append #$output "/lib/zen-browser/" name)))
                 '("zen" "zen-bin" "gfxtest" "pingsender" "updater")))))
          (add-after 'patch-elf-interpreters 'install-desktop-files
            (lambda* (#:key inputs #:allow-other-keys)
              (use-modules (ice-9 format))
              (let ((doc (string-append #$output "/share/doc/zen-browser"))
                    (icons (string-append #$output
                                          "/share/icons/hicolor/128x128/apps"))
                    (desktop (string-append #$output
                                            "/share/applications/zen-browser.desktop")))
                (mkdir-p doc)
                (copy-file (assoc-ref inputs "zen-license")
                           (string-append doc "/LICENSE"))
                (call-with-output-file (string-append doc "/SOURCE.txt")
                  (lambda (port)
                    (format port
                            (string-append
                             "Official upstream binary, adapted for GNU Guix.~%"
                             "Matching upstream source release:~%"
                             "https://github.com/zen-browser/desktop/releases/tag/~a~%"
                             "Source archive: zen.source.tar.zst~%"
                             "Bundled component notices: about:license~%")
                            #$version)))
                (mkdir-p icons)
                (copy-file
                 (string-append #$output "/lib/zen-browser/browser/chrome/"
                                "icons/default/default128.png")
                 (string-append icons "/zen-browser.png"))
                (mkdir-p (dirname desktop))
                (call-with-output-file desktop
                  (lambda (port)
                    (format port
                            (string-append
                             "[Desktop Entry]~%Type=Application~%"
                             "Name=Zen Browser~%Exec=~a/bin/zen-browser %U~%"
                             "Icon=zen-browser~%Terminal=false~%"
                             "Categories=Network;WebBrowser;~%"
                             "MimeType=text/html;x-scheme-handler/http;"
                             "x-scheme-handler/https;~%")
                            #$output))))))
          (add-after 'install-desktop-files 'manage-updates
            (lambda _
              (let ((policy (string-append
                             #$output "/lib/zen-browser/distribution/"
                             "policies.json")))
                (mkdir-p (dirname policy))
                (call-with-output-file policy
                  (lambda (port)
                    (display
                     (string-append "{\"policies\":{\"DisableAppUpdate\":true,"
                                    "\"DontCheckDefaultBrowser\":true}}\n")
                     port))))))
          (add-after 'manage-updates 'create-launchers
            (lambda* (#:key inputs #:allow-other-keys)
              (use-modules (ice-9 format) (srfi srfi-13))
              (let* ((directory (string-append #$output "/lib/zen-browser"))
                     (shell (search-input-file inputs "/bin/sh"))
                     (library-path
                      (string-join
                       (cons directory
                             (map
                              (lambda (name)
                                (string-append (assoc-ref inputs name) "/lib"))
                              '("glibc" "gcc" "gtk+" "glib" "gdk-pixbuf"
                                "pango" "cairo" "at-spi2-core" "fontconfig-minimal"
                                "freetype" "alsa-lib" "pulseaudio" "dbus"
                                "libglvnd" "mesa"
                                "pciutils" "libdrm" "libva" "vulkan-loader"
                                "libx11" "libxcomposite" "libxdamage" "libxext"
                                "libxfixes" "libxrandr" "libxrender" "libxcursor"
                                "libxi" "libxcb")))
                       ":")))
                (mkdir-p (string-append #$output "/bin"))
                (for-each
                 (lambda (name)
                   (let ((launcher (string-append #$output "/bin/" name)))
                     (call-with-output-file launcher
                       (lambda (port)
                         (format port
                                 (string-append
                                  "#!~a~%LD_LIBRARY_PATH='~a'~%"
                                  "export LD_LIBRARY_PATH~%"
                                  "exec '~a/zen' \"$@\"~%")
                                 shell library-path directory)))
                     (chmod launcher #o755)))
                 '("zen-browser" "zen")))))
          (add-after 'create-launchers 'check-version
            (lambda _
              (use-modules (ice-9 popen) (ice-9 textual-ports))
              (let* ((pipe (open-pipe* OPEN_READ
                                       (string-append #$output
                                                      "/bin/zen-browser")
                                       "--version"))
                     (text (get-string-all pipe))
                     (status (close-pipe pipe)))
                (display text)
                (unless (and (zero? status) (string-contains text #$version))
                  (error "Zen version check failed" status text))))))))
    (native-inputs
     (list (list "patchelf" patchelf)
           (list "zen-license"
                 (origin
                   (method url-fetch)
                   (uri (string-append
                         "https://raw.githubusercontent.com/zen-browser/desktop/"
                         version "/LICENSE"))
                   (sha256
                    (base16-string->bytevector
                     (string-append
                      "c76f740d1521b9bed9ca7a04ad526c31049"
                      "3c62621b1341d623b431736533b30")))))))
    (inputs
     (list glibc `(,gcc "lib") bash-minimal gtk+ glib gdk-pixbuf pango cairo
           at-spi2-core fontconfig freetype alsa-lib pulseaudio dbus libglvnd
           mesa pciutils
           libdrm libva vulkan-loader libx11 libxcomposite libxdamage libxext
           libxfixes libxrandr libxrender libxcursor libxi libxcb))
    (supported-systems '("x86_64-linux"))
    (home-page "https://zen-browser.app/")
    (synopsis "Firefox-based browser with vertical tabs and workspaces")
    (description
     "Zen Browser provides vertical tabs, workspaces and split views.  This
package adapts the official upstream Linux binary to Guix.  Updates are managed
through Guix; the browser's built-in updater is disabled.  Upstream source and
bundled third-party notices are available from the corresponding release and
the browser's about:license page.")
    (license license:mpl2.0)))
