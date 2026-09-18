;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2023 Giacomo Leidi <therewasa@fishinthecalculator.me>
;;; Copyright © 2025 Benjamin Slade <slade@lambda-y.net>
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; This file is part of the securityops channel.
;;;
;;; Mullvad VPN desktop client, bumped to the latest official stable.
;;;
;;; Vendored from small-guix's (small-guix packages mullvad) rather than
;;; inherited because the upstream build phases bake the package `version' into
;;; the .deb unpack step — an `(inherit …)' + version override would break the
;;; real build.  Changes vs. upstream:
;;;   * version 2025.8 -> 2026.5, the current non-prerelease desktop release
;;;     (GitHub release 2026.5, published 2026-09-14; the 2026.5-beta tags are
;;;     ignored).  Check the official stable release before bumping; a newer
;;;     GitHub tag may be a beta.
;;;   * source is the GitHub release asset: since 2026.5 the release again
;;;     carries the desktop .debs (plus detached .asc signatures).  The 2026.4
;;;     note claiming GitHub no longer carried them is outdated, and Mullvad's
;;;     CDN (cdn.mullvad.net) was measured at ~10 KiB/s and failing from this
;;;     host, so the asset URL moved back to GitHub.
;;;   * x86_64-only (this host); add the aarch64 variant + hash if needed.
;;; Hash: `guix hash' on the 115,235,148-byte release asset; its members were
;;; checked against the unpack/wrapper phases (data.tar.xz, control.tar.xz,
;;; the opt/Mullvad VPN/ binaries and the usr/ tree).  The 2026.5 deb ships
;;; icons only up to 512x512 (no 1024x1024), so the desktop icon path below
;;; uses 512x512.
;;; Depends on the nonguix channel for `chromium-binary-build-system'.

(define-module (securityops packages vpn)
  #:use-module (gnu packages base)
  #:use-module (gnu packages gnome)
  #:use-module (gnu packages networking)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix packages)
  #:use-module (nonguix build-system chromium-binary)
  #:use-module ((guix licenses) #:prefix license:))

(define %mullvad-vpn-desktop-version "2026.5")

(define-public mullvad-vpn-desktop
  (package
    (name "mullvad-vpn-desktop")
    (version %mullvad-vpn-desktop-version)
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://github.com/mullvad/mullvadvpn-app/"
                           "releases/download/" version "/MullvadVPN-" version
                           "_amd64.deb"))
       (file-name (string-append name "-" version "-" (%current-system) ".deb"))
       (sha256
        (base32 "1az751s2wmalff8axc019xf2k70yp4mz18lc1vsrg1aqa82d0sxa"))))
    (build-system chromium-binary-build-system)
    (arguments
     (list
      ;; There's no point in substitutes.
      #:substitutable? #f
      #:validate-runpath? #f ; TODO: fails on wrapped binary and included other files
      #:wrapper-plan
      #~(append
         (list "usr/bin/mullvad"
               "usr/bin/mullvad-daemon"
               "usr/bin/mullvad-exclude")
         (map (lambda (file)
                (string-append "opt/Mullvad VPN/" file))
              '("chrome-sandbox"
                "chrome_crashpad_handler"
                "libEGL.so"
                "libffmpeg.so"
                "libGLESv2.so"
                "libvk_swiftshader.so"
                "libvulkan.so.1"
                "mullvad-gui"
                ;; 2026.3 is WireGuard-only: the bundled OpenVPN plugin
                ;; (resources/libtalpid_openvpn_plugin.so) and the openvpn
                ;; binary (resources/openvpn) were dropped from the .deb.
                "resources/mullvad-problem-report"
                "resources/mullvad-setup")))
      #:install-plan
      #~'(("opt/" "/share")
          ("usr/bin/" "/bin")
          ("usr/lib/" "/lib")
          ("usr/local/share/" "/share")
          ("usr/share/" "/share"))
      #:phases
      #~(modify-phases %standard-phases
          (replace 'binary-unpack
            (lambda* (#:key inputs #:allow-other-keys)
              (invoke "ar" "x" #$source)
              ;; The 2026.3 .deb ships control.tar.XZ (older releases used .gz)
              ;; and adds a `_gpgbuilder' signature member; `rm -f' tolerates
              ;; whichever control compression + extras a given release uses.
              (invoke "rm" "-vf" "control.tar.gz" "control.tar.xz" "control.tar.zst"
                      "_gpgbuilder" "debian-binary"
                      (string-append #$name "-" #$version "-" #$(%current-system) ".deb"))
              (invoke "tar" "xvf" "data.tar.xz")
              (invoke "rm" "-vrf" "data.tar.xz" "./usr/bin/mullvad-problem-report")))
          (add-before 'install 'patch-assets
            (lambda _
              (let* ((bin (string-append #$output "/bin"))
                     (icon (string-append #$output "/share/icons/hicolor/512x512/apps/mullvad-vpn.png"))
                     (usr/share "./usr/share")
                     (old-exe "/opt/Mullvad VPN/mullvad-vpn")
                     (exe (string-append bin "/mullvad-vpn")))
                (patch-shebang (string-append (getcwd) old-exe))
                (substitute* (string-append usr/share "/applications/mullvad-vpn.desktop")
                  (("^Icon=mullvad-vpn") (string-append "Icon=" icon))
                  (((string-append "^Exec=" old-exe)) (string-append "Exec=" exe))))))
          (replace 'install-license-files
            ;; The 2026.5 .deb ships its licenses under opt/ and has no
            ;; usr/share/doc/copyright; install them explicitly instead of
            ;; relying on the standard source-directory scan, which cannot
            ;; traverse the build directory's parent in this environment.
            (lambda _
              (let ((doc (string-append #$output "/share/doc/"
                                        #$name "-" #$version)))
                (mkdir-p doc)
                (for-each (lambda (file)
                            (install-file file doc))
                          '("./opt/Mullvad VPN/LICENSE.electron.txt"
                            "./opt/Mullvad VPN/LICENSES.chromium.html")))))
          (add-before 'install-wrapper 'symlink-entrypoint
            (lambda _
              (let* ((bin (string-append #$output "/bin"))
                     (exe (string-append bin "/mullvad-vpn"))
                     (daemon-exe (string-append bin "/mullvad-daemon"))
                     (share (string-append #$output "/share/Mullvad VPN"))
                     (share/resources (string-append share "/resources"))
                     (target (string-append share "/mullvad-vpn")))
                (symlink (string-append share "/resources/mullvad-problem-report")
                         (string-append bin "/mullvad-problem-report"))
                (symlink target exe)
                (wrap-program exe
                  `("MULLVAD_DISABLE_UPDATE_NOTIFICATION" = ("1"))
                  `("LD_LIBRARY_PATH" = (,share)))
                (wrap-program daemon-exe
                  `("MULLVAD_RESOURCE_DIR" = (,share/resources)))))))))
    (native-inputs (list tar))
    (inputs (list iputils libnotify))
    (synopsis "The Mullvad VPN client app for desktop")
    (supported-systems '("x86_64-linux"))
    (description "This is the VPN client software for the Mullvad VPN service.
For more information about the service, please visit Mullvad's website,
mullvad.net (Also accessible via Tor on this onion service).")
    (home-page "https://mullvad.net")
    (license license:gpl3)))
