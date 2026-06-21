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
;;;   * version 2025.8 -> 2026.2 (Mullvad's published stable desktop release;
;;;     the 2026.3–2026.7 git tags are not promoted to the stable channel).
;;;   * source URL moved off GitHub (no longer carries desktop .debs) to
;;;     Mullvad's official CDN, cdn.mullvad.net.
;;;   * x86_64-only (this host); add the aarch64 variant + hash if needed.
;;; Hash: `guix download .../releases/2026.2/MullvadVPN-2026.2_amd64.deb'.
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

(define %mullvad-vpn-desktop-version "2026.2")

(define-public mullvad-vpn-desktop
  (package
    (name "mullvad-vpn-desktop")
    (version %mullvad-vpn-desktop-version)
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://cdn.mullvad.net/app/desktop/releases/"
                           version "/MullvadVPN-" version "_amd64.deb"))
       (file-name (string-append name "-" version "-" (%current-system) ".deb"))
       (sha256
        (base32 "1yilhzp5s7dplpnn69pyr9s2hd7s37h3f8nbzivv2m5h39gpy0kv"))))
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
                "resources/libtalpid_openvpn_plugin.so"
                "resources/mullvad-problem-report"
                "resources/mullvad-setup"
                "resources/openvpn")))
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
              (invoke "rm" "-v" "control.tar.gz"
                      "debian-binary"
                      (string-append #$name "-" #$version "-" #$(%current-system) ".deb"))
              (invoke "tar" "xvf" "data.tar.xz")
              (invoke "rm" "-vrf" "data.tar.xz" "./usr/bin/mullvad-problem-report")))
          (add-before 'install 'patch-assets
            (lambda _
              (let* ((bin (string-append #$output "/bin"))
                     (icon (string-append #$output "/share/icons/hicolor/1024x1024/apps/mullvad-vpn.png"))
                     (usr/share "./usr/share")
                     (old-exe "/opt/Mullvad VPN/mullvad-vpn")
                     (exe (string-append bin "/mullvad-vpn")))
                (patch-shebang (string-append (getcwd) old-exe))
                (substitute* (string-append usr/share "/applications/mullvad-vpn.desktop")
                  (("^Icon=mullvad-vpn") (string-append "Icon=" icon))
                  (((string-append "^Exec=" old-exe)) (string-append "Exec=" exe))))))
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
