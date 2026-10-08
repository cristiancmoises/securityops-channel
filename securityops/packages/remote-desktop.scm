;;; SPDX-License-Identifier: GPL-3.0-or-later
(define-module (securityops packages remote-desktop)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix build-system copy)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (nonguix build-system binary)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages curl)
  #:use-module (gnu packages fontutils)
  #:use-module (gnu packages freedesktop)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages gl)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages gstreamer)
  #:use-module (gnu packages gtk)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages pulseaudio)
  #:use-module (gnu packages video)
  #:use-module (gnu packages xdisorg)
  #:use-module (gnu packages xorg))

(define-public rustdesk
  (package
    (name "rustdesk")
    (version "1.4.9")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://github.com/rustdesk/rustdesk/releases/download/"
                           version "/rustdesk-" version "-x86_64.deb"))
       (sha256
        (base32 "18zx2bbg21h4ij6fg62cam3cwm3w8rcydysb0ir4300fqi3vli3j"))))
    (build-system binary-build-system)
    (arguments
     (list
      #:strip-binaries? #f
      #:install-plan
      #~'(("usr/share/rustdesk" "libexec/rustdesk")
          ("usr/share/icons" "share/icons")
          ("usr/share/applications" "share/applications"))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'patchelf)
          (add-after 'install 'relink-flutter-bundle
            (lambda* (#:key inputs #:allow-other-keys)
              (let* ((bundle (string-append #$output "/libexec/rustdesk"))
                     (lib (string-append bundle "/lib"))
                     (runtime-inputs
                      '("glibc" "gcc:lib" "gtk+" "glib" "pango" "cairo"
                        "gdk-pixbuf" "at-spi2-core" "fontconfig-minimal" "libepoxy"
                        "libx11" "libxfixes" "libxtst" "libxcb"
                        "libxkbcommon" "wayland" "dbus" "gstreamer"
                        "gst-plugins-base" "linux-pam" "pulseaudio" "zlib"
                        "libva" "xdotool" "alsa-lib" "mesa"))
                     (runpath
                      (string-join
                       (cons lib
                             (map (lambda (name)
                                    (string-append (assoc-ref inputs name) "/lib"))
                                  runtime-inputs)) ":"))
                     (exe (string-append bundle "/rustdesk")))
                (invoke "patchelf" "--set-interpreter"
                        (search-input-file inputs "/lib/ld-linux-x86-64.so.2") exe)
                (for-each
                 (lambda (file) (invoke "patchelf" "--set-rpath" runpath file))
                 (cons exe (find-files lib "\\.so(\\..*)?$")))
                ;; The Flutter runner locates assets relative to itself.
                (mkdir-p (string-append #$output "/bin"))
                (symlink exe (string-append #$output "/bin/rustdesk"))
                (for-each
                 (lambda (desktop)
                   (substitute* desktop
                     (("Exec=rustdesk")
                      (string-append "Exec=" #$output "/bin/rustdesk"))))
                 (find-files (string-append #$output "/share/applications")
                             "\\.desktop$")))))
          (add-after 'relink-flutter-bundle 'preserve-upstream-source
            (lambda* (#:key inputs #:allow-other-keys)
              (copy-recursively
               (assoc-ref inputs "upstream-source")
               (string-append #$output "/share/doc/rustdesk/source"))))
          (add-after 'preserve-upstream-source 'wrap-runtime-tools
            (lambda* (#:key inputs #:allow-other-keys)
              (wrap-program (string-append #$output "/libexec/rustdesk/rustdesk")
                #:sh (search-input-file inputs "/bin/sh")
                `("PATH" prefix
                  ,(map (lambda (name)
                          (string-append (assoc-ref inputs name) "/bin"))
                        '("curl" "xdotool" "xrandr" "xdg-utils")))
                `("GST_PLUGIN_SYSTEM_PATH" prefix
                  ,(map (lambda (name)
                          (string-append (assoc-ref inputs name)
                                         "/lib/gstreamer-1.0"))
                        '("gstreamer" "gst-plugins-base" "pipewire"))))))
          (add-after 'wrap-runtime-tools 'check-version
            (lambda _
              (invoke (string-append #$output "/bin/rustdesk") "--version")))
          (add-after 'wrap-runtime-tools 'install-packaging-notice
            (lambda _
              (call-with-output-file
                  (string-append #$output "/share/doc/rustdesk/PACKAGING-NOTICE")
                (lambda (port)
                  (display
                   "Guix packaging modifications dated 2026-10-07

This package repackages the official RustDesk 1.4.9 Linux binary release.
It changes the ELF interpreter and executable/shared-library runpaths for
Guix, adjusts desktop launch commands, and adds a scoped shell wrapper for
runtime tools and GStreamer plugins.  It does not rebuild the application.

The matching upstream repository and recursive submodule checkout are
retained in source/ beside this notice, including libs/hbb_common/.
Repository: https://github.com/rustdesk/rustdesk/tree/1.4.9
Commit: 6c578292e8ebbbec708b76986ba8c4bc7c509747
License and Corresponding Source requirements: source/LICENCE (AGPLv3).
Upstream build instructions: https://rustdesk.com/docs/en/dev/build/
Retained build scripts: source/build.py and
source/.github/workflows/flutter-build.yml.
Dependency manifests and lockfiles: source/Cargo.toml, source/Cargo.lock,
source/flutter/pubspec.yaml and source/flutter/pubspec.lock.

The retained repository, submodules and release notices are not a claim
that all transitive dependency sources are vendored or that a complete
legal compliance review has been performed.  Distributors must evaluate
and satisfy the applicable Corresponding Source and notice requirements.
"
                   port))))))))
    (native-inputs
     (list
      (list "bash-minimal" bash-minimal)
      (list "upstream-source"
            (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/rustdesk/rustdesk")
                    (commit "6c578292e8ebbbec708b76986ba8c4bc7c509747")
                    (recursive? #t)))
              (file-name (git-file-name "rustdesk-source" version))
              (sha256
               (base32 "00lmgm04i3a3vfw44wmqgnx33b8zmw8a08p3yawf1g8kxqh1sz02"))))))
    (inputs
     `(("glibc" ,glibc) ("gcc:lib" ,gcc "lib")
       ("gtk+" ,gtk+) ("glib" ,glib) ("pango" ,pango) ("cairo" ,cairo)
       ("gdk-pixbuf" ,gdk-pixbuf) ("at-spi2-core" ,at-spi2-core)
       ("fontconfig-minimal" ,fontconfig) ("libepoxy" ,libepoxy)
       ("libx11" ,libx11) ("libxfixes" ,libxfixes) ("libxtst" ,libxtst)
       ("libxcb" ,libxcb) ("libxkbcommon" ,libxkbcommon) ("wayland" ,wayland)
       ("dbus" ,dbus) ("gstreamer" ,gstreamer)
       ("gst-plugins-base" ,gst-plugins-base) ("linux-pam" ,linux-pam)
       ("pulseaudio" ,pulseaudio) ("zlib" ,zlib) ("libva" ,libva)
       ("xdotool" ,xdotool) ("alsa-lib" ,alsa-lib) ("mesa" ,mesa)
       ("curl" ,curl) ("pipewire" ,pipewire)
       ("xrandr" ,xrandr) ("xdg-utils" ,xdg-utils)))
    (supported-systems '("x86_64-linux"))
    (home-page "https://rustdesk.com")
    (synopsis "Remote desktop client with a Flutter interface")
    (description
     "RustDesk provides a graphical remote desktop client compatible with
self-hosted rendezvous and relay servers.  This package uses the official
Linux release, preserves its Flutter assets and notices, and includes the
matching source checkout with submodules.  Service activation and host
authentication configuration are separate administrative tasks.")
    (license license:agpl3)))

(define-public rustdesk-server
  (package
    (name "rustdesk-server")
    (version "1.1.16")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://github.com/rustdesk/rustdesk-server/releases/download/"
             version "/rustdesk-server-linux-amd64.zip"))
       (sha256
        (base32 "1kyvddghv6mna31gxqzqymj3zgyc4idazpxxn04z9hz6zwdc8r85"))))
    (build-system copy-build-system)
    (arguments
     (list
      #:install-plan #~'(("hbbs" "bin/") ("hbbr" "bin/")
                         ("rustdesk-utils" "bin/"))
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'install 'preserve-upstream-source
            (lambda* (#:key inputs #:allow-other-keys)
              (copy-recursively
               (assoc-ref inputs "upstream-source")
               (string-append #$output "/share/doc/rustdesk-server/source"))))
          (add-after 'preserve-upstream-source 'check-command-interfaces
            (lambda _
              (for-each
               (lambda (name)
                 (invoke (string-append #$output "/bin/" name) "--version")
                 (invoke (string-append #$output "/bin/" name) "--help"))
               '("hbbs" "hbbr"))))
          (add-after 'preserve-upstream-source 'install-packaging-notice
            (lambda _
              (call-with-output-file
                  (string-append #$output
                                 "/share/doc/rustdesk-server/PACKAGING-NOTICE")
                (lambda (port)
                  (display
                   "Guix packaging modifications dated 2026-10-07

This package installs the official RustDesk Server OSS 1.1.16 static Linux
executables in the Guix store and adds this notice and a source checkout.
It does not rebuild the executables, activate services, or configure keys.

The matching upstream repository and recursive submodule checkout are
retained in source/ beside this notice, including libs/hbb_common/.
Repository: https://github.com/rustdesk/rustdesk-server/tree/1.1.16
Commit: 73523b31cfd25d77dee862e6fc9f5e1fb5e485ef
License and Corresponding Source requirements: source/LICENSE (AGPLv3).
Upstream build instructions: source/README.md (How to build manually).
Retained build automation: source/.github/workflows/build.yaml.
Dependency manifest and lockfile: source/Cargo.toml and source/Cargo.lock.

The retained repository, submodules and release notices are not a claim
that all transitive dependency sources are vendored or that a complete
legal compliance review has been performed.  Distributors must evaluate
and satisfy the applicable Corresponding Source and notice requirements.
"
                   port))))))))
    (native-inputs
     (list
      (list "unzip" unzip)
      (list "upstream-source"
            (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/rustdesk/rustdesk-server")
                    (commit "73523b31cfd25d77dee862e6fc9f5e1fb5e485ef")
                    (recursive? #t)))
              (file-name (git-file-name "rustdesk-server-source" version))
              (sha256
               (base32 "1x1ic36zvs8anp59n4r6i19xb10j8ds2px4m3wryb50jwfrxsi85"))))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/rustdesk/rustdesk-server")
    (synopsis "Self-hosted RustDesk rendezvous and relay servers")
    (description
     "RustDesk Server provides hbbs for rendezvous, hbbr for relay, and
rustdesk-utils for administration.  This package uses the official static Linux
executables and includes the matching source checkout with submodules.
Administrators configure endpoints, keys, persistent state and service startup.")
    (license license:agpl3)))
