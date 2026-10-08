;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>

(define-module (securityops packages arduino)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix profiles)
  #:use-module (guix search-paths)
  #:use-module (srfi srfi-1)
  #:use-module (guix build-system trivial)
  #:use-module ((guix licenses)
                #:prefix license:)
  #:use-module (nonguix build-system chromium-binary)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages certs)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages gtk)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages libusb)
  #:use-module (gnu packages ncurses)
  #:use-module (gnu packages nss)
  #:use-module (gnu packages package-management))

;; Keep the upstream Electron runtime and compiled native extensions together.
;; Electron 30 is unsupported upstream; see the package description.
(define arduino-ide-bundle
  (package
    (name "arduino-ide-bundle")
    (version "2.3.10")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://github.com/arduino/arduino-ide/releases/download/"
             version "/arduino-ide_" version "_Linux_64bit.zip"))
       (sha256
        (base32 "0xbrb93kzh290z66smdb2kxa12f3r0dhrrqccxmn9m33ww0hp2nc"))))
    (build-system chromium-binary-build-system)
    (arguments
     (list
      ;; NSS lives under lib/nss and is supplied by the runtime wrapper.
      #:validate-runpath? #f
      #:strip-binaries? #f
      #:wrapper-plan
      #~'(("arduino-ide" (("out" "/lib/arduino-ide")))
          "chrome-sandbox"
          "chrome_crashpad_handler"
          "libEGL.so"
          "libGLESv2.so"
          "libffmpeg.so"
          "libvk_swiftshader.so"
          "libvulkan.so.1"
          "resources/app/lib/backend/resources/clangd"
          "resources/app/lib/backend/resources/clang-format"
          "resources/app/lib/backend/resources/arduino-fwuploader"
          "resources/app/lib/backend/resources/arduino-language-server"
          "resources/app/lib/backend/native/drivelist.node"
          "resources/app/lib/backend/native/keymapping.node"
          "resources/app/lib/backend/native/keytar.node"
          "resources/app/lib/backend/native/pty.node"
          "resources/app/lib/backend/native/watcher.node")
      #:install-plan
      #~'(("." "lib/arduino-ide/"))
      #:phases
      #~(modify-phases %standard-phases
          (add-before 'install-wrapper 'install-entrypoints
            (lambda _
              (let ((bin (string-append #$output "/bin")))
                (mkdir-p bin)
                (symlink (string-append #$output
                                        "/lib/arduino-ide/arduino-ide")
                         (string-append bin "/arduino-ide-bundle"))
                (symlink (string-append #$output
                          "/lib/arduino-ide/resources/app/lib/backend/resources/arduino-cli")
                         (string-append bin "/arduino-cli-bundle"))))))))
    (native-inputs (list unzip))
    (inputs (list gdk-pixbuf))
    (supported-systems '("x86_64-linux"))
    (home-page "https://www.arduino.cc/en/software")
    (synopsis "Official Arduino IDE desktop bundle")
    (description
     "Arduino IDE 2 provides an editor, Board and Library Managers, debugging,
and sketch compilation through Arduino CLI.  This package preserves the
official upstream binary bundle, including its Electron 30.1.2 runtime.
Electron 30 no longer receives upstream security support.  A stable Arduino
release does not imply a security-supported Electron runtime.")
    ;; Theia disables the upstream Electron renderer sandbox.  The FHS
    ;; container is not a substitute for renderer isolation.
    (license license:agpl3+)))

;; Board Manager installs foreign compiler binaries after installation.  A
;; fixed FHS profile supplies their loaders without modifying the host system.
(define arduino-ide-runtime
  (profile
   (content
    ;; Do not export host compiler search paths to Board Manager's cross tools.
    (map-manifest-entries
     (lambda (entry)
       (manifest-entry
        (inherit entry)
        (search-paths
         (remove (lambda (path)
                   (member (search-path-specification-variable path)
                           '("CPATH" "C_INCLUDE_PATH" "CPLUS_INCLUDE_PATH"
                             "LIBRARY_PATH")))
                 (manifest-entry-search-paths entry)))))
     (packages->manifest
      (list arduino-ide-bundle (@@ (gnu packages base) glibc-for-fhs)
            (list gcc "lib") zlib ncurses eudev libusb bash-minimal coreutils
            tar gzip bzip2 xz unzip nss-certs))))
   (hooks '())))

(define (arduino-launcher name command)
  (define script
    (scheme-file
     (string-append name ".scm")
     #~(begin
         (use-modules (srfi srfi-1) (ice-9 ftw) (ice-9 regex)
                      (guix scripts environment) (gnu system file-systems))
         (define arduino-home (getenv "HOME"))
         (unless (and arduino-home (string-prefix? "/" arduino-home)
                      (file-exists? arduino-home))
           (error "Arduino IDE needs an existing absolute HOME directory"))
         (define shared
           (delete-duplicates
            (filter (lambda (path) (and path (file-exists? path)))
                    (list arduino-home "/tmp" "/dev/dri" "/dev/bus/usb"
                          "/sys" "/run/udev" "/run/dbus" "/var/run/dbus"
                          (getenv "XDG_RUNTIME_DIR") (getenv "XAUTHORITY")
                          (getenv "XDG_CONFIG_HOME") (getenv "XDG_CACHE_HOME")
                          (getenv "XDG_DATA_HOME")))))
         ;; Serial devices are created dynamically by the host's udev service.
         (define serial
           (filter (lambda (file)
                     (or (string-prefix? "ttyACM" file)
                         (string-prefix? "ttyUSB" file)))
                   (scandir "/dev")))
         ;; The shell CLI rejects --profile with -F after injecting glibc.
         ;; Its exported environment API accepts our complete FHS profile.
         (guix-environment*
          (append
           (list
            (cons 'profile #$(file-append arduino-ide-runtime))
            '(container? . #t) '(emulate-fhs? . #t) '(network? . #t)
            (cons 'exec
                  (cons #$(file-append arduino-ide-bundle
                           (string-append "/bin/" command))
                        (cdr (command-line))))
            (cons 'inherit-regexp
                  (make-regexp
                   (string-append
                    "^(HOME|DISPLAY|WAYLAND_DISPLAY|XAUTHORITY|"
                    "XDG_(RUNTIME_DIR|CONFIG_HOME|CACHE_HOME|DATA_HOME)|"
                    "DBUS_SESSION_BUS_ADDRESS|LANG|LC_.*|TZ|.*_PROXY|"
                    ".*_proxy|ELECTRON_.*|ARDUINO_.*)$"))))
           (map (lambda (path)
                  (cons 'file-system-mapping
                        (file-system-mapping
                         (source path) (target path)
                         (writable? (not (member path '("/sys" "/run/udev")))))))
                (append shared
                        (map (lambda (file) (string-append "/dev/" file))
                             serial)))
           %environment-default-options)))))
  (program-file
   name
   #~(apply execl #$(file-append guix "/bin/guix") "guix"
            "repl" "-q" "--" #$script (cdr (command-line)))))

(define-public arduino-ide
  (package
    (inherit arduino-ide-bundle)
    (name "arduino-ide")
    (build-system trivial-build-system)
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      #~(begin
          (use-modules (guix build utils))
          (let* ((out #$output)
                 (bin (string-append out "/bin"))
                 (doc (string-append out "/share/doc/arduino-ide"))
                 (apps (string-append out "/share/applications"))
                 (icons (string-append out "/share/icons/hicolor/512x512/apps")))
            (mkdir-p bin)
            (symlink #$(arduino-launcher "arduino-ide" "arduino-ide-bundle")
                     (string-append bin "/arduino-ide"))
            (symlink #$(arduino-launcher "arduino-ide-cli"
                                         "arduino-cli-bundle")
                     (string-append bin "/arduino-ide-cli"))
            (mkdir-p icons)
            (symlink #$(file-append arduino-ide-bundle
                        "/lib/arduino-ide/resources/app/resources/icons/512x512.png")
                     (string-append icons "/arduino-ide.png"))
            (mkdir-p apps)
            (make-desktop-entry-file (string-append apps
                                                    "/arduino-ide.desktop")
                                     #:name "Arduino IDE"
                                     #:generic-name "Microcontroller IDE"
                                     #:exec (string-append bin
                                                           "/arduino-ide %F")
                                     #:icon "arduino-ide"
                                     #:type "Application"
                                     #:categories '("Development" "IDE")
                                     #:mime-type '("text/x-arduino")
                                     #:startup-w-m-class "arduino-ide")
            (mkdir-p doc)
            (copy-file
             #$(origin
                 (method url-fetch)
                 (uri (string-append
                       "https://raw.githubusercontent.com/arduino/"
                       "arduino-ide/2.3.10/LICENSE.txt"))
                 (sha256
                  (base32
                   "1c5wk83xn43pma39yf6xm0mr312iinqi7xrh3xplnvddd3zs95hd")))
             (string-append doc "/LICENSE.txt"))
            (call-with-output-file (string-append doc "/SOURCE")
              (lambda (port)
                (display
                 (string-append "Corresponding source: "
                                "https://github.com/arduino/arduino-ide/"
                                "tree/2.3.10\n")
                 port)))))))
    (native-inputs '())
    (inputs '())
    (synopsis "Arduino IDE with an isolated toolchain runtime")
    (description
     (string-append
      (package-description arduino-ide-bundle)
      "\nUpstream Theia disables the Electron renderer sandbox.  The FHS
container is not a substitute for renderer isolation.  The launcher provides
an FHS container for Board Manager toolchains and requires unprivileged user
namespaces and a running Guix daemon.  User files, display sockets and
connected serial devices are shared with the IDE.  arduino-ide-cli runs the
bundled CLI in the same environment."))))
