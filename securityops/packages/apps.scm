;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; This file is part of the securityops channel.
;;;
;;; First-party applications from git.securityops.co/cristiancmoises.
;;;
;;; Each app lives in its own repo on the forge.  To keep this channel
;;; self-contained, their sources/release artifacts are VENDORED under
;;; packages/sources/ and referenced with `local-file' (content-addressed by
;;; Guix at add time, so no hash field is needed) rather than fetched with a
;;; git-fetch/url-fetch origin.  This keeps the channel buildable by the daemon
;;; with no network access.

(define-module (securityops packages apps)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix utils)                      ;cc-for-target (vaptvupt)
  #:use-module (guix build-system copy)
  #:use-module (guix build-system gnu)           ;vaptvupt CLI (Makefile)
  #:use-module (gnu packages base)               ;glibc
  #:use-module (gnu packages gcc)                ;gcc:lib (libgcc_s)
  #:use-module (gnu packages elf)                ;patchelf
  #:use-module (gnu packages tls)                ;openssl 3.5 (vaptvupt FIPS 203 check)
  #:use-module (gnu packages python)             ;python (torando-gui, vaptvupt-gui)
  #:use-module (gnu packages tor)                ;tor (torando-gui)
  #:use-module (gnu packages linux)              ;iptables, e2fsprogs/chattr (torando-gui)
  #:use-module (gnu packages qt)                 ;python-pyside-6, qtbase, qtwayland (vaptvupt-gui)
  #:use-module (gnu packages bash)               ;bash-minimal (vaptvupt-gui launcher)
  #:use-module (gnu packages video)              ;ffmpeg (turborec, moneyprinterturbo)
  #:use-module (gnu packages pulseaudio)         ;pulseaudio/pactl (turborec)
  #:use-module (gnu packages xorg)               ;xrandr, xdpyinfo (turborec)
  #:use-module (gnu packages pciutils)           ;lspci (turborec)
  #:use-module (gnu packages wm)                 ;wlr-randr, sway/swaymsg (turborec Wayland)
  #:use-module (gnu packages xdisorg)            ;wmctrl (turborec X11 window capture)
  #:use-module (gnu packages version-control)    ;git-minimal (moneyprinterturbo venv bootstrap)
  #:use-module (gnu packages fonts)              ;font-wqy-zenhei (moneyprinterturbo CJK subtitles)
  ;; vaptvupt-gui: PySide6's Qt6 leaf libraries (NOT in its RUNPATH). #:select
  ;; keeps these from clashing with the many modules imported above. mesa=gl;
  ;; the X11/xcb libs, libxft, libevdev, libxau, libxdmcp come from (gnu packages
  ;; xorg); libxkbcommon/pixman/mtdev from (gnu packages xdisorg); eudev from
  ;; (gnu packages linux); python-shiboken-6/qtbase/qtwayland from (gnu packages
  ;; qt) — all already imported above.
  #:use-module ((gnu packages gl)         #:select (mesa))
  #:use-module ((gnu packages fontutils)  #:select (fontconfig freetype graphite2))
  #:use-module ((gnu packages freedesktop) #:select (wayland libinput-minimal))
  #:use-module ((gnu packages glib)       #:select (glib dbus))
  #:use-module ((gnu packages compression) #:select (zlib zstd brotli))
  #:use-module ((gnu packages image)      #:select (libpng libjpeg-turbo))
  #:use-module ((gnu packages xml)        #:select (expat libxml2))
  #:use-module ((gnu packages gtk)        #:select (harfbuzz))
  #:use-module ((gnu packages icu4c)      #:select (icu4c))
  #:use-module ((gnu packages maths)      #:select (double-conversion))
  #:use-module ((gnu packages pcre)       #:select (pcre2))
  #:use-module ((gnu packages markup)     #:select (md4c))
  #:use-module ((gnu packages crypto)     #:select (libb2))
  #:use-module ((guix licenses) #:prefix license:))

;; Leaf runtime libraries PySide6's Qt6 (Core/Gui/Widgets) links but does NOT
;; carry in its RUNPATH. The vaptvupt-gui launcher puts these on LD_LIBRARY_PATH;
;; without them `import PySide6.QtWidgets` fails with e.g. "libGL.so.1 /
;; libzstd.so.1: cannot open shared object file" and the GUI wrongly reports
;; "requires PySide6 or PyQt6". NEVER add qtbase/qtwayland here — Qt's own libs
;; resolve via PySide6's RUNPATH; a second copy causes private-API symbol clashes.
(define %vaptvupt-gui-runtime-libs
  (list mesa libxkbcommon fontconfig freetype graphite2 harfbuzz
        icu4c double-conversion pcre2 md4c libb2 brotli
        libpng libjpeg-turbo zlib expat libxml2 pixman glib dbus wayland
        libx11 libxext libxrender libxcb libxrandr libxi libxcursor libxft
        libxfixes libxdamage libxcomposite libxtst libxinerama libsm libice
        libxau libxdmcp xcb-util xcb-util-image xcb-util-keysyms
        xcb-util-renderutil xcb-util-wm xcb-util-cursor
        libinput-minimal mtdev libevdev eudev))

;;; evelin — post-quantum transport (ML-KEM-1024 / ML-DSA-87 / ChaCha20-Poly1305).
;;; Packaged from the OFFICIAL upstream static-musl release tarball (v4.1.1),
;;; matching your existing ~/Downloads/evelin.scm.  Fully static (musl,
;;; link-self-contained): no runtime inputs, no patchelf, no grafting.
;;; Ships ev + client/server/agent/keygen/keyscan/multisig-verify, man pages, docs.
(define-public evelin-bin
  (package
    (name "evelin-bin")
    (version "4.1.1")
    (source (local-file "sources/evelin-v4.1.1-linux-x86_64-musl.tar.gz"))
    (build-system copy-build-system)
    (arguments
     (list
      #:install-plan
      #~'(("bin/" "bin/")
          ("share/man/" "share/man/")
          ("share/doc/evelin/" "share/doc/evelin/"))
      #:phases
      #~(modify-phases %standard-phases
          ;; Release binaries are stripped already; static PIE has no runpath.
          (delete 'strip)
          (delete 'validate-runpath))))
    (supported-systems '("x86_64-linux"))
    (synopsis "Evelin post-quantum transport (prebuilt static release binaries)")
    (description
     "Client, server, agent, and key tools from the official Evelin x86_64
musl-static release: ML-KEM-1024 key exchange, ML-DSA-87 authentication,
ChaCha20-Poly1305 AEAD.  Binaries are fully static and carry no runtime
dependencies.")
    (home-page "https://git.securityops.co/cristiancmoises/evelin")
    (license license:agpl3+)))

;;; btp — Built from source (v0.7) on this host with `cargo build --release'
;;; (binaries vendored to keep the channel self-contained / buildable offline).
;;; The two core binaries (btpctl CLI, btpd daemon) are dynamic Rust binaries;
;;; their build-time RUNPATH points at an ephemeral `guix shell' profile, so we
;;; patchelf the interpreter + RPATH onto the declared glibc / gcc:lib inputs.
;;; GUI/Python/JS bindings from the workspace are intentionally excluded.
(define-public btp
  (package
    (name "btp")
    (version "0.7")
    (source (local-file "sources/btp-0.7-bin-x86_64-linux.tar.gz"))
    (build-system copy-build-system)
    (inputs (list glibc `(,gcc "lib")))
    (native-inputs (list patchelf))
    (arguments
     (list
      #:install-plan
      #~'(("bin/" "bin/")
          ("share/man/" "share/man/"))
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'install 'patchelf-binaries
            (lambda* (#:key inputs #:allow-other-keys)
              (let* ((glibc (assoc-ref inputs "glibc"))
                     (gcclib (assoc-ref inputs "gcc"))
                     (ld (string-append glibc "/lib/ld-linux-x86-64.so.2"))
                     (rpath (string-append glibc "/lib:" gcclib "/lib")))
                (for-each
                 (lambda (b)
                   (let ((f (string-append #$output "/bin/" b)))
                     (invoke "patchelf" "--set-interpreter" ld f)
                     (invoke "patchelf" "--set-rpath" rpath f)))
                 '("btpctl" "btpd"))))))))
    (supported-systems '("x86_64-linux"))
    (synopsis "BTP — bundle transparency protocol (CLI + daemon)")
    (description
     "@code{btpctl} (command-line client) and @code{btpd} (daemon) from the BTP
project, built from the v0.7 source release.  Built-from-source dynamic binaries
relinked against Guix's glibc.")
    (home-page "https://git.securityops.co/cristiancmoises/btp")
    (license license:asl2.0)))

;;; mirim — Built from source (v1.0.0) with `cargo build --release --features
;;; cli,sign'.  Builds cleanly under Guix's Rust 1.93 even though the repo pins
;;; 1.96 (the pinned rust-toolchain.toml is bypassed; no 1.96-only features are
;;; used).  Post-quantum secret vault + detached ML-DSA-87 (FIPS 204) signatures.
;;; Same vendor/patchelf approach as btp.
(define-public mirim
  (package
    (name "mirim")
    (version "1.0.0")
    (source (local-file "sources/mirim-1.0.0-bin-x86_64-linux.tar.gz"))
    (build-system copy-build-system)
    (inputs (list glibc `(,gcc "lib")))
    (native-inputs (list patchelf))
    (arguments
     (list
      #:install-plan
      #~'(("bin/" "bin/"))
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'install 'patchelf-binaries
            (lambda* (#:key inputs #:allow-other-keys)
              (let* ((glibc (assoc-ref inputs "glibc"))
                     (gcclib (assoc-ref inputs "gcc"))
                     (ld (string-append glibc "/lib/ld-linux-x86-64.so.2"))
                     (rpath (string-append glibc "/lib:" gcclib "/lib")))
                (for-each
                 (lambda (b)
                   (let ((f (string-append #$output "/bin/" b)))
                     (invoke "patchelf" "--set-interpreter" ld f)
                     (invoke "patchelf" "--set-rpath" rpath f)))
                 '("mirim" "mirim-sign"))))))))
    (supported-systems '("x86_64-linux"))
    (synopsis "mirim — post-quantum secret vault and ML-DSA-87 signing tool")
    (description
     "@code{mirim} (post-quantum encrypted vault: ML-KEM-768 + ChaCha20-Poly1305,
Argon2) and @code{mirim-sign} (detached ML-DSA-87 / FIPS 204 signatures), built
from the v1.0.0 source release.")
    (home-page "https://git.securityops.co/cristiancmoises/mirim")
    (license license:agpl3)))

;;; torando-gui — loopback web GUI + root daemon that routes ONE local user's
;;; egress through Tor (transparent proxy + killswitch), automating the upstream
;;; torando iptables rules plus torrc/resolv.conf management.  Pure-Python
;;; (stdlib only), so it is built FROM SOURCE with copy-build-system — no
;;; compile, no patchelf.  Source is the vendored 1.1.0 release snapshot
;;; (vendored to keep the channel self-contained / buildable offline).  The two FHS shims call a
;;; bare `python3' and assume /usr/lib; the wrap-shims phase rewrites them to the
;;; store python3 and prepends the store bins of the tools the root daemon execs
;;; (iptables, chattr via e2fsprogs, tor), and points the systemd unit at the
;;; store binary — so the Guix package is self-contained (matches packaging/guix.scm
;;; in the upstream repo).  The user-facing `torando-gui' opens a native GTK4 +
;;; WebKitGTK window if that stack is on the user's profile, else falls back to
;;; the browser; the daemon itself needs neither, so they are NOT package inputs
;;; (add `gtk webkitgtk python-pygobject' to your profile for the native window).
(define-public torando-gui
  (package
    (name "torando-gui")
    (version "1.1.0")
    (source (local-file "sources/torando-gui-1.1.0-src.tar.gz"))
    (build-system copy-build-system)
    (inputs (list python tor iptables e2fsprogs))
    (arguments
     (list
      #:install-plan
      #~'(("backend/torando_gui" "lib/torando-gui/torando_gui")
          ("packaging/bin/torando-gui"  "bin/torando-gui")
          ("packaging/bin/torando-guid" "bin/torando-guid")
          ("packaging/systemd/torando-gui.service"
           "lib/systemd/system/torando-gui.service")
          ("packaging/polkit/co.securityops.torando-gui.policy"
           "share/polkit-1/actions/co.securityops.torando-gui.policy")
          ("packaging/polkit/49-torando-gui.rules"
           "share/polkit-1/rules.d/49-torando-gui.rules")
          ("packaging/desktop/torando-gui.desktop"
           "share/applications/torando-gui.desktop")
          ("README.md"       "share/doc/torando-gui/README.md")
          ("THREAT_MODEL.md" "share/doc/torando-gui/THREAT_MODEL.md")
          ("LICENSE"         "share/doc/torando-gui/LICENSE"))
      #:phases
      #~(modify-phases %standard-phases
          ;; No ELF payload (pure Python + /bin/sh shims).
          (delete 'strip)
          (delete 'validate-runpath)
          (add-after 'install 'wrap-shims
            (lambda* (#:key inputs outputs #:allow-other-keys)
              (let* ((out    (assoc-ref outputs "out"))
                     (lib    (string-append out "/lib/torando-gui"))
                     (python (string-append (assoc-ref inputs "python") "/bin/python3"))
                     (path   (string-join
                              (list (string-append (assoc-ref inputs "python") "/bin")
                                    (string-append (assoc-ref inputs "iptables") "/sbin")
                                    (string-append (assoc-ref inputs "iptables") "/bin")
                                    (string-append (assoc-ref inputs "e2fsprogs") "/sbin")
                                    (string-append (assoc-ref inputs "e2fsprogs") "/bin")
                                    (string-append (assoc-ref inputs "tor") "/bin"))
                              ":")))
                (define (write-shim name module)
                  (let ((p (string-append out "/bin/" name)))
                    (call-with-output-file p
                      (lambda (port)
                        (format port "#!/bin/sh
# Generated by the securityops channel: self-contained launcher.
export PYTHONPATH=\"~a${PYTHONPATH:+:$PYTHONPATH}\"
export PATH=\"~a${PATH:+:$PATH}\"
exec ~a -m ~a \"$@\"\n"
                                lib path python module)))
                    (chmod p #o755)))
                (write-shim "torando-gui"  "torando_gui.launcher")
                (write-shim "torando-guid" "torando_gui")
                (substitute* (string-append out "/lib/systemd/system/torando-gui.service")
                  (("/usr/bin/torando-guid")
                   (string-append out "/bin/torando-guid")))))))))
    (synopsis "Route a user's egress through Tor (transparent proxy + killswitch)")
    (description
     "Loopback web GUI that forces one local user's traffic through Tor's
TransPort and DNSPort and drops everything else from that user.  It automates
the upstream torando iptables rules together with torrc and resolv.conf
management, and reports live bootstrap, DNS-leak and exit status.  Built from
source (pure Python); the shims and systemd unit are rewired to the store, so
the package is self-contained.")
    (home-page "https://codeberg.org/cristiancmoises/torando-gui")
    (license license:agpl3)))

;;; vaptvupt — pure-C11 post-quantum backup compressor (CLI, v5.0.0) and its
;;; PySide6/Qt6 desktop frontend (GUI, versioned with the CLI since 4.1.0).
;;; Both build from the ONE vendored release tarball.  The CLI is built FROM
;;; SOURCE with gnu-build-system (plain Makefile, no ./configure).  4.1.0 is a
;;; source-only release: the prebuilt vendored shared objects (libzuptsdk /
;;; libpqvaptvupt) were dropped upstream, WITH_SDK defaults to 0 and the binary
;;; links against only -lm -lpthread — so the old LDFLAGS/patchelf RUNPATH
;;; machinery and the openssl/argon2 inputs are gone with them.  --pq-sdk and
;;; --pq-box are now unsupported stubs; native --pq (ML-KEM-768 + X25519)
;;; remains, and password mode defaults to PBKDF2-SHA256.  `make check' passes
;;; on the source-only build, so tests are enabled.
(define-public vaptvupt
  (package
    (name "vaptvupt")
    (version "5.0.0")
    (source (local-file "sources/vaptvupt-5.0.0.tar.gz"))
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
    ;; python3, so python must be a native-input or that one check fails.
    ;; openssl (3.5+, has ML-KEM-768) lets tests/test_mlkem_fips203.sh run the
    ;; FIPS 203 cross-decapsulation against OpenSSL instead of skipping —
    ;; build-time only, nothing links it.
    (native-inputs (list openssl python))
    (supported-systems '("x86_64-linux"))
    (synopsis "Post-quantum backup compression utility (CLI)")
    (description
     "VaptVupt (formerly Zupt) is a pure-C11 backup compressor with post-quantum
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
comparison and runtime AES-NI/SHA-NI dispatch; the embedded VaptVupt 2.60.4
LZ+ANS codec ships CBMC-verified BCJ filters.")
    (home-page "https://git.securityops.co/cristiancmoises/vaptvupt")
    (license (list license:agpl3+ license:gpl3+))))

;;; vaptvupt-gui — PySide6 (Qt6) frontend, installed from the same tarball with
;;; copy-build-system.  The launcher pins the matching CLI store path via
;;; VAPTVUPT_BIN (the GUI honours it before any PATH lookup), so GUI and CLI can
;;; never drift apart; PySide6 is made importable via GUIX_PYTHONPATH and the Qt
;;; platform plugins (xcb + wayland) via QT_PLUGIN_PATH.
(define-public vaptvupt-gui
  (package
    (name "vaptvupt-gui")
    (version "5.0.0")                    ; upstream versions the GUI with the CLI now
    (source (package-source vaptvupt))   ; same release tarball
    (build-system copy-build-system)
    (arguments
     (list
      #:install-plan
      #~'(("gui/src/zupt_gui.py" "lib/vaptvupt-gui/")
          ("gui/assets/zupt-icon.png"
           "share/icons/hicolor/256x256/apps/vaptvupt-gui.png")
          ("gui/README.md" "share/doc/vaptvupt-gui/")
          ("gui/LICENSE-GUI" "share/doc/vaptvupt-gui/"))
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'install 'make-launcher
            (lambda* (#:key inputs outputs #:allow-other-keys)
              (let* ((out     (assoc-ref outputs "out"))
                     (bin     (string-append out "/bin"))
                     (gui     (string-append
                               out "/lib/vaptvupt-gui/zupt_gui.py"))
                     (sh      (search-input-file inputs "/bin/sh"))
                     (python3 (search-input-file inputs "/bin/python3"))
                     (cli     (search-input-file inputs "/bin/vaptvupt"))
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
                                             %vaptvupt-gui-runtime-libs))
                               (list (string-append zstdlib "/lib")))
                              ":")))
                (mkdir-p bin)
                (call-with-output-file (string-append bin "/vaptvupt-gui")
                  (lambda (port)
                    (format port "#!~a
export VAPTVUPT_BIN=\"~a\"
export GUIX_PYTHONPATH=\"~a:~a${GUIX_PYTHONPATH:+:}$GUIX_PYTHONPATH\"
export QT_PLUGIN_PATH=\"~a/lib/qt6/plugins:~a/lib/qt6/plugins${QT_PLUGIN_PATH:+:}$QT_PLUGIN_PATH\"
export LD_LIBRARY_PATH=\"~a${LD_LIBRARY_PATH:+:}$LD_LIBRARY_PATH\"
exec \"~a\" \"~a\" \"$@\"\n"
                            sh cli site shsite qtbase qtwl ldpath python3 gui)))
                (chmod (string-append bin "/vaptvupt-gui") #o755)
                ;; Legacy name, mirroring the .deb/.rpm packages.
                (symlink "vaptvupt-gui" (string-append bin "/zupt-gui")))))
          (add-after 'make-launcher 'install-desktop-file
            (lambda* (#:key outputs #:allow-other-keys)
              (let* ((out  (assoc-ref outputs "out"))
                     (apps (string-append out "/share/applications")))
                (mkdir-p apps)
                (call-with-output-file
                    (string-append apps "/vaptvupt-gui.desktop")
                  (lambda (port)
                    (format port "[Desktop Entry]
Type=Application
Name=VaptVupt
GenericName=Post-Quantum Backup
Comment=Compress, encrypt and restore .zupt archives
Exec=~a/bin/vaptvupt-gui %F
Icon=vaptvupt-gui
Terminal=false
Categories=Utility;Archiving;Security;
MimeType=application/x-zupt;
Keywords=backup;encryption;post-quantum;compression;zupt;\n"
                            out)))))))))
    (inputs
     (append (list bash-minimal python python-pyside-6 python-shiboken-6
                   qtbase qtwayland vaptvupt
                   (list zstd "lib"))   ; libzstd.so.1 is in zstd's "lib" output
             %vaptvupt-gui-runtime-libs))
    (supported-systems '("x86_64-linux"))
    (synopsis "Desktop frontend for VaptVupt (PySide6/Qt6 GUI)")
    (description
     "PySide6 (Qt 6) graphical frontend for VaptVupt: create, inspect and extract
@code{.zupt} archives with password (PBKDF2-SHA256) or post-quantum recipient
encryption via the native ML-KEM-768 + X25519 hybrid (@code{--pq}).  The
launcher pins the matching @code{vaptvupt} CLI from the store via
@env{VAPTVUPT_BIN}, so GUI and CLI versions can never drift apart.")
    (home-page "https://git.securityops.co/cristiancmoises/vaptvupt")
    (license license:agpl3+)))

;;; turborec — Turbo Recorder 3.1.0: a hardware-accelerated Linux screen + audio
;;; recorder.  `turborec.py' is a pure-stdlib Python CLI with a Tkinter GUI (the
;;; `gui' subcommand); `turborecorder' is an X11 bash launcher that builds a
;;; quality-first FFmpeg pipeline (NVENC > VAAPI > x264).  Built FROM SOURCE with
;;; copy-build-system (no compile): the two scripts install under lib/, and
;;; self-contained `#!/bin/sh' shims in bin/ pin the store python3/bash and
;;; prepend the store bins of the tools they exec (ffmpeg, pactl, xrandr,
;;; xdpyinfo, lspci).  The Tkinter GUI gets the python `tk' output (which carries
;;; `_tkinter.so') on PYTHONPATH.  nvidia-smi (optional HW probe) is left to PATH
;;; if present — turborec degrades gracefully to VAAPI/x264 without it.
(define-public turborec
  (package
    (name "turborec")
    (version "3.1.0")
    (source (local-file "sources/turborec-3.1.0-src.tar.gz"))
    (build-system copy-build-system)
    (inputs
     `(("python" ,python)
       ("python-tk" ,python "tk")             ;_tkinter for `turborec gui'
       ("ffmpeg" ,ffmpeg)
       ("pulseaudio" ,pulseaudio)             ;pactl
       ("xrandr" ,xrandr)
       ("xdpyinfo" ,xdpyinfo)
       ("pciutils" ,pciutils)                 ;lspci
       ("wf-recorder" ,wf-recorder)           ;Wayland (wlroots) screen capture
       ("wlr-randr" ,wlr-randr)               ;Wayland output enumeration
       ("sway" ,sway)                         ;swaymsg
       ("wmctrl" ,wmctrl)                     ;X11 window capture
       ("bash-minimal" ,bash-minimal)))
    (arguments
     (list
      #:install-plan
      #~'(("turborec.py"   "lib/turborec/turborec.py")
          ("turborecorder" "lib/turborec/turborecorder")
          ("packaging/turborec.desktop" "share/applications/turborec.desktop")
          ("packaging/turborec.svg"
           "share/icons/hicolor/scalable/apps/turborec.svg")
          ("README.md"    "share/doc/turborec/README.md")
          ("CHANGELOG.md" "share/doc/turborec/CHANGELOG.md")
          ("LICENSE"      "share/doc/turborec/LICENSE"))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'strip)                       ;pure Python + bash, no ELF
          (delete 'validate-runpath)
          (add-after 'install 'wrap
            (lambda* (#:key inputs outputs #:allow-other-keys)
              (let* ((out    (assoc-ref outputs "out"))
                     (lib    (string-append out "/lib/turborec"))
                     (python (string-append (assoc-ref inputs "python") "/bin/python3"))
                     (bash   (string-append (assoc-ref inputs "bash-minimal") "/bin/bash"))
                     ;; site-packages dir of the python `tk' output (holds _tkinter.so);
                     ;; derived so it survives a python minor-version bump.
                     (tkpath (dirname (car (find-files (assoc-ref inputs "python-tk")
                                                       "^_tkinter.*\\.so$"))))
                     (path   (string-join
                              (map (lambda (in.sub)
                                     (string-append (assoc-ref inputs (car in.sub))
                                                    (cdr in.sub)))
                                   '(("python"      . "/bin")
                                     ("ffmpeg"      . "/bin")
                                     ("pulseaudio"  . "/bin")
                                     ("xrandr"      . "/bin")
                                     ("xdpyinfo"    . "/bin")
                                     ("wf-recorder" . "/bin")
                                     ("wlr-randr"   . "/bin")
                                     ("sway"        . "/bin")
                                     ("wmctrl"      . "/bin")
                                     ("pciutils"    . "/sbin")
                                     ("pciutils"    . "/bin")))
                              ":")))
                (mkdir-p (string-append out "/bin"))
                (let ((p (string-append out "/bin/turborec")))
                  (call-with-output-file p
                    (lambda (port)
                      (format port "#!/bin/sh
# Generated by the securityops channel: self-contained launcher.
export PATH=\"~a${PATH:+:$PATH}\"
export PYTHONPATH=\"~a${PYTHONPATH:+:$PYTHONPATH}\"
exec ~a ~a/turborec.py \"$@\"\n"
                              path tkpath python lib)))
                  (chmod p #o755))
                (let ((p (string-append out "/bin/turborecorder")))
                  (call-with-output-file p
                    (lambda (port)
                      (format port "#!/bin/sh
# Generated by the securityops channel: self-contained launcher.
export PATH=\"~a${PATH:+:$PATH}\"
exec ~a ~a/turborecorder \"$@\"\n"
                              path bash lib)))
                  (chmod p #o755))
                (substitute* (string-append out "/share/applications/turborec.desktop")
                  (("^Exec=turborec")
                   (string-append "Exec=" out "/bin/turborec"))
                  (("^Icon=turborec")
                   (string-append "Icon=" out
                                  "/share/icons/hicolor/scalable/apps/turborec.svg")))))))))
    (supported-systems '("x86_64-linux"))
    (synopsis "Hardware-accelerated Linux screen + audio recorder (FFmpeg, X11)")
    (description
     "Turbo Recorder captures the screen and audio into a quality-first FFmpeg
pipeline, auto-detecting the best hardware encoder (NVIDIA NVENC, then Intel/AMD
VAAPI, then software x264), the native screen resolution, and the default
microphone and system-audio sources.  @command{turborec} is a cross-platform
Python CLI with a Tkinter GUI (@command{turborec gui}); @command{turborecorder}
is an X11 bash launcher.  Built from source and self-contained: the launchers
pin the store @code{python3}/@code{bash} and the tools they call (@code{ffmpeg},
@code{pactl}, @code{xrandr}, @code{xdpyinfo}, @code{lspci}).")
    (home-page "https://git.securityops.co/cristiancmoises/turborec")
    (license license:gpl3)))

;;; moneyprinterturbo — one-click AI short-video generator (harry0703 v1.3.1).
;;; THIRD-PARTY Python app with a huge, partly-unpackaged dependency tree
;;; (streamlit, moviepy, edge-tts, litellm, faster-whisper, the cloud SDKs), so a
;;; full native python-build-system package is infeasible here.  Instead this ships
;;; the (font-pruned) upstream source plus self-contained `moneyprinterturbo' /
;;; `moneyprinterturbo-api' launchers that, on FIRST RUN, copy the app into a
;;; writable per-user dir ($XDG_DATA_HOME/moneyprinterturbo) and pip-install the
;;; pinned requirements.txt into a local venv, fetched over Tor via torsocks.
;;; Documented impurity: that one-time pip step needs network (routed through Tor);
;;; the BUILD itself is fully offline (copy-build-system, no daemon network).
;;;
;;; Tor-only host hardening baked into the launchers:
;;;   * every process runs under torsocks (LD_PRELOAD) so ALL TCP egress (LLM,
;;;     Pexels/Pixabay material, edge-tts) goes through Tor — the app's own [proxy]
;;;     setting only covers material downloads;
;;;   * a shipped torsocks.conf sets `AllowInbound 1' (the local Streamlit/uvicorn
;;;     server accepts the browser) and `AllowOutboundLocalhost 1' (a local Ollama
;;;     LLM at 127.0.0.1:11434 or Redis is reached directly, not via Tor);
;;;   * GRPC_DNS_RESOLVER=native avoids grpc's c-ares UDP DNS (torsocks can't route
;;;     UDP).  NOTE: gemini *voices* and Azure *-V2* voices still bypass Tor and must
;;;     be avoided; gemini as an LLM (forced transport=rest) is fine;
;;;   * IMAGEIO_FFMPEG_EXE pins the store ffmpeg so moviepy never auto-downloads one;
;;;   * HF_HUB_OFFLINE/TRANSFORMERS_OFFLINE default on (keep subtitle_provider=edge;
;;;     whisper would pull a ~3GB model over Tor) and the server binds 127.0.0.1.
;;; The proprietary default subtitle font STHeitiMedium.ttc is dropped and repointed
;;; to bundled WenQuanYi Zen Hei (font-wqy-zenhei, redistributable; covers CJK+Latin)
;;; so the default render works; Charm (OFL) is also shipped.  The app is imported
;;; from the writable copy via PYTHONPATH and is never installed into the venv
;;; (pyproject package=false), because root_dir() is __file__-relative.
;;; First-run deps assume cp3x manylinux wheels exist on PyPI (verified for the
;;; pinned set); if a future pin needs a source build, add a toolchain to the PATH.
(define-public moneyprinterturbo
  (package
    (name "moneyprinterturbo")
    (version "1.3.1")
    (source (local-file "sources/moneyprinterturbo-1.3.1-src.tar.gz"))
    (build-system copy-build-system)
    (inputs
     `(("python" ,python)
       ("ffmpeg" ,ffmpeg)
       ("torsocks" ,torsocks)
       ("git-minimal" ,git-minimal)
       ("coreutils" ,coreutils)
       ("bash-minimal" ,bash-minimal)
       ("font-wqy-zenhei" ,font-wqy-zenhei)))
    (arguments
     (list
      #:install-plan
      #~'(("." "share/moneyprinterturbo"))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'strip)                       ;pure Python + bash, no ELF
          (delete 'validate-runpath)
          (add-after 'install 'patch-defaults
            (lambda* (#:key inputs outputs #:allow-other-keys)
              (let* ((out   (assoc-ref outputs "out"))
                     (share (string-append out "/share/moneyprinterturbo"))
                     (fonts (string-append share "/resource/fonts"))
                     (cjk   (string-append (assoc-ref inputs "font-wqy-zenhei")
                                           "/share/fonts/truetype/wqy-zenhei.ttc")))
                ;; Ship a redistributable CJK font and repoint the proprietary
                ;; default so the out-of-the-box subtitle render does not crash.
                (copy-file cjk (string-append fonts "/wqy-zenhei.ttc"))
                (for-each
                 (lambda (f)
                   (substitute* (string-append share "/" f)
                     (("STHeitiMedium\\.ttc") "wqy-zenhei.ttc")
                     (("MicrosoftYaHeiBold\\.ttc") "wqy-zenhei.ttc")))
                 '("app/models/schema.py" "app/services/video.py" "webui/Main.py"))
                ;; Never bind the API/UI on all interfaces by default.
                (substitute* (string-append share "/app/config/config.py")
                  (("\"0\\.0\\.0\\.0\"") "\"127.0.0.1\""))
                ;; Defensive: never ship a stray user config into the store.
                (let ((stray (string-append share "/config.toml")))
                  (when (file-exists? stray) (delete-file stray))))))
          (add-after 'patch-defaults 'wrap
            (lambda* (#:key inputs outputs #:allow-other-keys)
              (let* ((out    (assoc-ref outputs "out"))
                     (share  (string-append out "/share/moneyprinterturbo"))
                     (etc    (string-append out "/etc/moneyprinterturbo"))
                     (conf   (string-append etc "/torsocks.conf"))
                     (python (string-append (assoc-ref inputs "python") "/bin/python3"))
                     (ffmpeg (string-append (assoc-ref inputs "ffmpeg") "/bin/ffmpeg"))
                     (path   (string-join
                              (map (lambda (in.sub)
                                     (string-append (assoc-ref inputs (car in.sub))
                                                    (cdr in.sub)))
                                   '(("python"      . "/bin")
                                     ("ffmpeg"      . "/bin")
                                     ("torsocks"    . "/bin")
                                     ("git-minimal" . "/bin")
                                     ("coreutils"   . "/bin")))
                              ":")))
                ;; torsocks.conf: route all TCP through Tor (127.0.0.1:9050) but
                ;; allow the local server's inbound socket and direct localhost.
                (mkdir-p etc)
                (call-with-output-file conf
                  (lambda (port)
                    (format port "# Generated by the securityops channel.~%TorAddress 127.0.0.1~%TorPort 9050~%AllowInbound 1~%AllowOutboundLocalhost 1~%")))
                (mkdir-p (string-append out "/bin"))
                (let ((write-launcher
                       (lambda (file exec-tail)
                         (let ((p (string-append out "/bin/" file)))
                           (call-with-output-file p
                             (lambda (port)
                               (format port "#!/bin/sh
# Generated by the securityops channel: self-contained MoneyPrinterTurbo launcher (Tor-only host).
set -e
export PATH=\"~a${PATH:+:$PATH}\"
STORE_SHARE=\"~a\"
APP_HOME=\"${MPT_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/moneyprinterturbo}\"
VERSION=\"1.3.1\"
export TORSOCKS_ALLOW_INBOUND=1
export TORSOCKS_CONF_FILE=\"~a\"
export GRPC_DNS_RESOLVER=native
export IMAGEIO_FFMPEG_EXE=\"~a\"
export HF_HUB_OFFLINE=\"${HF_HUB_OFFLINE:-1}\"
export TRANSFORMERS_OFFLINE=\"${TRANSFORMERS_OFFLINE:-1}\"
if [ \"$(cat \"$APP_HOME/.version\" 2>/dev/null)\" != \"$VERSION\" ]; then
  echo \">> [moneyprinterturbo] syncing app v$VERSION into $APP_HOME\"
  mkdir -p \"$APP_HOME\"
  cp -a \"$STORE_SHARE/.\" \"$APP_HOME/\"
  chmod -R u+w \"$APP_HOME\"
  mkdir -p \"$APP_HOME/storage\" \"$APP_HOME/models\"
  printf '%s' \"$VERSION\" > \"$APP_HOME/.version\"
  rm -f \"$APP_HOME/.venv/.bootstrap-complete\" 2>/dev/null || true
fi
cd \"$APP_HOME\"
if [ ! -f \"$APP_HOME/.venv/.bootstrap-complete\" ]; then
  echo \">> [moneyprinterturbo] first run: creating venv + installing deps over Tor (one-time, slow)\"
  rm -rf \"$APP_HOME/.venv\"
  ~a -m venv \"$APP_HOME/.venv\"
  PIP_DEFAULT_TIMEOUT=180 PIP_RETRIES=15 PIP_DISABLE_PIP_VERSION_CHECK=1 torsocks \"$APP_HOME/.venv/bin/python\" -m pip install --upgrade pip wheel setuptools
  PIP_DEFAULT_TIMEOUT=180 PIP_RETRIES=15 PIP_DISABLE_PIP_VERSION_CHECK=1 torsocks \"$APP_HOME/.venv/bin/python\" -m pip install -r \"$APP_HOME/requirements.txt\"
  touch \"$APP_HOME/.venv/.bootstrap-complete\"
  echo \">> [moneyprinterturbo] ready — add a Pexels key + pick an LLM in $APP_HOME/config.toml\"
fi
export PYTHONPATH=\"$APP_HOME${PYTHONPATH:+:$PYTHONPATH}\"
~a
"
                                       path share conf ffmpeg python exec-tail)))
                           (chmod p #o755)))))
                  (write-launcher
                   "moneyprinterturbo"
                   "exec torsocks \"$APP_HOME/.venv/bin/python\" -m streamlit run \"$APP_HOME/webui/Main.py\" --server.address=127.0.0.1 --browser.gatherUsageStats=False --server.headless=true \"$@\"")
                  (write-launcher
                   "moneyprinterturbo-api"
                   "exec torsocks \"$APP_HOME/.venv/bin/python\" \"$APP_HOME/main.py\" \"$@\""))))))))
    (supported-systems '("x86_64-linux"))
    (synopsis "One-click AI short-video generator (WebUI + API), Tor-wrapped")
    (description
     "MoneyPrinterTurbo generates short-form videos from a topic: an LLM writes the
script and keywords, stock B-roll is pulled from Pexels/Pixabay, edge-tts adds a
voice-over, subtitles are burned in, and FFmpeg assembles the final clip.  This
package ships the upstream v1.3.1 source (proprietary CJK fonts removed; WenQuanYi
Zen Hei bundled as the default subtitle font) plus self-contained
@command{moneyprinterturbo} (Streamlit WebUI) and @command{moneyprinterturbo-api}
(FastAPI) launchers.  On first run each launcher copies the app into
@file{$XDG_DATA_HOME/moneyprinterturbo} and pip-installs the pinned
@file{requirements.txt} into a local virtualenv, fetched over Tor via
@command{torsocks}; thereafter all egress (LLM, material, TTS) is routed through
Tor, the local server binds 127.0.0.1, and the store @code{ffmpeg} is pinned so no
binaries are auto-downloaded.  Keep @code{subtitle_provider = \"edge\"} to avoid a
multi-GB Whisper model download.")
    (home-page "https://github.com/harry0703/MoneyPrinterTurbo")
    (license license:expat)))
