;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>

(define-module (securityops packages zupt)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module (guix build-system copy)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages tls)
  #:use-module (gnu packages python)
  #:use-module (gnu packages version-control)
  #:use-module (gnu packages qt)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages xorg)
  #:use-module (gnu packages xdisorg)
  #:use-module (gnu packages linux)
  #:use-module ((gnu packages gl) #:select (mesa))
  #:use-module ((gnu packages fontutils) #:select (fontconfig freetype graphite2))
  #:use-module ((gnu packages freedesktop) #:select (wayland libinput-minimal))
  #:use-module ((gnu packages glib) #:select (glib dbus))
  #:use-module ((gnu packages compression) #:select (zlib zstd brotli))
  #:use-module ((gnu packages image) #:select (libpng libjpeg-turbo))
  #:use-module ((gnu packages xml) #:select (expat libxml2))
  #:use-module ((gnu packages gtk) #:select (harfbuzz))
  #:use-module ((gnu packages icu4c) #:select (icu4c))
  #:use-module ((gnu packages maths) #:select (double-conversion))
  #:use-module ((gnu packages pcre) #:select (pcre2))
  #:use-module ((gnu packages markup) #:select (md4c))
  #:use-module ((gnu packages crypto) #:select (libb2))
  #:use-module ((guix licenses) #:prefix license:))

;; Leaf runtime libraries PySide6's Qt6 (Core/Gui/Widgets) links but does NOT
;; carry in its RUNPATH. The zupt-gui launcher puts these on LD_LIBRARY_PATH;
;; without them `import PySide6.QtWidgets` fails with e.g. "libGL.so.1 /
;; libzstd.so.1: cannot open shared object file" and the GUI wrongly reports
;; "requires PySide6 or PyQt6". NEVER add qtbase/qtwayland here — Qt's own libs
;; resolve via PySide6's RUNPATH; a second copy causes private-API symbol clashes.
(define %zupt-gui-runtime-libs
  (list mesa libxkbcommon fontconfig freetype graphite2 harfbuzz
        icu4c double-conversion pcre2 md4c libb2 brotli
        libpng libjpeg-turbo zlib expat libxml2 pixman glib dbus wayland
        libx11 libxext libxrender libxcb libxrandr libxi libxcursor libxft
        libxfixes libxdamage libxcomposite libxtst libxinerama libsm libice
        libxau libxdmcp xcb-util xcb-util-image xcb-util-keysyms
        xcb-util-renderutil xcb-util-wm xcb-util-cursor
        libinput-minimal mtdev libevdev eudev))

;;; Zupt — pure-C11 post-quantum backup compressor (CLI, v5.2.9) and its
;;; PySide6/Qt6 desktop frontend (GUI, versioned with the CLI).
;;; Both build from the ONE vendored release tarball.  The CLI is built FROM
;;; SOURCE with gnu-build-system (plain Makefile, no ./configure).  It is a
;;; source-only release: the prebuilt vendored shared objects (libzuptsdk /
;;; libpqvaptvupt) were dropped upstream, WITH_SDK defaults to 0 and the binary
;;; links against only -lm -lpthread — so the old LDFLAGS/patchelf RUNPATH
;;; machinery and the openssl/argon2 inputs are gone with them.  --pq-sdk and
;;; --pq-box are now unsupported stubs; native --pq (ML-KEM-768 + X25519)
;;; remains, and password mode defaults to PBKDF2-SHA256.  `make check' passes
;;; on the source-only build, so tests are enabled.
(define-public zupt
  (package
    (name "zupt")
    (version "5.2.9")
    (source (local-file "sources/zupt-5.2.9.tar.gz"))
    (build-system gnu-build-system)
    (arguments
     (list
      #:make-flags
      #~(list (string-append "PREFIX=" #$output)
              (string-append "CC=" #$(cc-for-target)))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure))))        ; plain Makefile, no ./configure
    ;; `make check' (crypto vectors + security-regression scripts) runs in the
    ;; container; tests/test_gui_branding.sh's functional check shells out to
    ;; python3 and tests/test_source_only.sh checks the release's Git metadata,
    ;; so both python and git-minimal are native inputs.
    ;; openssl (3.5+, has ML-KEM-768) lets tests/test_mlkem_fips203.sh run the
    ;; FIPS 203 cross-decapsulation against OpenSSL instead of skipping —
    ;; build-time only, nothing links it.
    (native-inputs (list openssl python git-minimal))
    (supported-systems '("x86_64-linux"))
    (synopsis "Post-quantum backup compression utility (CLI)")
    (description
     "Zupt is a pure-C11 backup compressor with post-quantum
hybrid encryption.  Since 4.1.0 it is a source-only build with no vendored
binary SDKs: recipient modes are the native ML-KEM-768 + X25519 hybrid
(@code{--pq}, recommended) and pure ML-KEM-768 with no classical component
(@code{--pq-only}, for CNSA 2.0-style postures); the SDK-backed
@code{--pq-sdk} and @code{--pq-box} modes are unsupported stubs, and password
mode uses PBKDF2-SHA256.  5.0.0 makes the ML-KEM-768 implementation genuinely
FIPS 203-conformant (earlier releases shipped round-3 CRYSTALS-Kyber under
that label), cross-validated byte-for-byte against OpenSSL 3.5 during this
package's build; BREAKING: @code{--pq}/@code{--pq-only} keys and archives from
4.2.1 or earlier no longer decrypt — regenerate keys and re-encrypt (password
mode and plain compression are unaffected).  4.2.0 fixed a critical AES-CTR
keystream-reuse flaw in @code{--dedup} archives (re-encrypt any written by
4.1.0 or earlier).  Payload protection is
AES-256-CTR + HMAC-SHA256 Encrypt-then-MAC with measured constant-time tag
comparison and runtime AES-NI/SHA-NI dispatch; it embeds the VaptVupt LZ+ANS
codec, which is a codec component rather than a compatibility command.")
    (home-page "https://github.com/cristiancmoises/zupt")
    (license (list license:agpl3+ license:gpl3+))))

;;; zupt-gui — PySide6 (Qt6) frontend, installed from the same tarball with
;;; copy-build-system.  The launcher pins the matching CLI store path via
;;; ZUPT_BIN, so GUI and CLI can never drift apart; PySide6 is made importable
;;; via GUIX_PYTHONPATH and the Qt
;;; platform plugins (xcb + wayland) via QT_PLUGIN_PATH.
(define-public zupt-gui
  (package
    (name "zupt-gui")
    (version "5.2.9")                    ; upstream versions the GUI with the CLI
    (source (package-source zupt))        ; same release tarball
    (build-system copy-build-system)
    (arguments
     (list
      #:install-plan
      #~'(("gui/src/zupt_gui.py" "lib/zupt-gui/")
          ("gui/assets/zupt-icon.png"
           "share/icons/hicolor/256x256/apps/zupt-gui.png")
          ("gui/README.md" "share/doc/zupt-gui/")
          ("gui/LICENSE-GUI" "share/doc/zupt-gui/"))
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'install 'make-launcher
            (lambda* (#:key inputs outputs #:allow-other-keys)
              (let* ((out     (assoc-ref outputs "out"))
                     (bin     (string-append out "/bin"))
                     (gui     (string-append
                               out "/lib/zupt-gui/zupt_gui.py"))
                     (sh      (search-input-file inputs "/bin/sh"))
                     (python3 (search-input-file inputs "/bin/python3"))
                     (cli     (search-input-file inputs "/bin/zupt"))
                     (pyside  (assoc-ref inputs "python-pyside-6"))
                     (site    (car (find-files pyside "^site-packages$"
                                               #:directories? #t)))
                     ;; Shiboken6 is a SEPARATE package PySide6 imports at
                     ;; runtime; its site-packages must be on GUIX_PYTHONPATH too
                     ;; or "import PySide6" fails with "Unable to import Shiboken".
                     (shiboken (assoc-ref inputs "python-shiboken-6"))
                     (shsite  (car (find-files shiboken "^site-packages$"
                                               #:directories? #t)))
                     (qtbase  (assoc-ref inputs "qtbase"))
                     (qtwl    (assoc-ref inputs "qtwayland"))
                     ;; Leaf-library search path (libGL, libxkbcommon, X11/xcb,
                     ;; fontconfig, wayland, glib, dbus, ...). Qt's own libraries
                     ;; are intentionally excluded — they resolve via PySide6's
                     ;; RUNPATH; adding qtbase here causes private-API clashes.
                     ;; zstd ships libzstd.so.1 in its separate "lib" output.
                     (zstdlib (assoc-ref inputs "zstd"))
                     (ldpath (string-join
                              (append
                               (list #$@(map (lambda (p) (file-append p "/lib"))
                                             %zupt-gui-runtime-libs))
                               (list (string-append zstdlib "/lib")))
                              ":")))
                (mkdir-p bin)
                (call-with-output-file (string-append bin "/zupt-gui")
                  (lambda (port)
                    (format port "#!~a
export ZUPT_BIN=\"~a\"
export GUIX_PYTHONPATH=\"~a:~a${GUIX_PYTHONPATH:+:}$GUIX_PYTHONPATH\"
export QT_PLUGIN_PATH=\"~a/lib/qt6/plugins:~a/lib/qt6/plugins${QT_PLUGIN_PATH:+:}$QT_PLUGIN_PATH\"
export LD_LIBRARY_PATH=\"~a${LD_LIBRARY_PATH:+:}$LD_LIBRARY_PATH\"
exec \"~a\" \"~a\" \"$@\"\n"
                            sh cli site shsite qtbase qtwl ldpath python3 gui)))
                (chmod (string-append bin "/zupt-gui") #o755))))
          (add-after 'make-launcher 'install-desktop-file
            (lambda* (#:key outputs #:allow-other-keys)
              (let* ((out  (assoc-ref outputs "out"))
                     (apps (string-append out "/share/applications")))
                (mkdir-p apps)
                (call-with-output-file
                    (string-append apps "/zupt-gui.desktop")
                  (lambda (port)
                    (format port "[Desktop Entry]
Type=Application
Name=Zupt
GenericName=Post-Quantum Backup
Comment=Compress, encrypt and restore .zupt archives
Exec=~a/bin/zupt-gui %F
Icon=zupt-gui
Terminal=false
Categories=Utility;Archiving;Security;
MimeType=application/x-zupt;
Keywords=backup;encryption;post-quantum;compression;zupt;\n"
                            out)))))))))
    (inputs
     (append (list bash-minimal python python-pyside-6 python-shiboken-6
                   qtbase qtwayland zupt
                   (list zstd "lib"))   ; libzstd.so.1 is in zstd's "lib" output
             %zupt-gui-runtime-libs))
    (supported-systems '("x86_64-linux"))
    (synopsis "Desktop frontend for Zupt (PySide6/Qt6 GUI)")
    (description
     "PySide6 (Qt 6) graphical frontend for Zupt: create, inspect and extract
@code{.zupt} archives with password (PBKDF2-SHA256) or post-quantum recipient
encryption via the native ML-KEM-768 + X25519 hybrid (@code{--pq}).  The
launcher pins the matching @code{zupt} CLI from the store via @env{ZUPT_BIN},
so GUI and CLI versions can never drift apart.")
    (home-page "https://github.com/cristiancmoises/zupt")
    (license license:agpl3+)))
