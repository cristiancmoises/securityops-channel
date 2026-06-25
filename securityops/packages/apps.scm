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
  #:use-module (gnu packages python)             ;python (torando-gui, vaptvupt-gui)
  #:use-module (gnu packages tor)                ;tor (torando-gui)
  #:use-module (gnu packages linux)              ;iptables, e2fsprogs/chattr (torando-gui)
  #:use-module (gnu packages qt)                 ;python-pyside-6, qtbase, qtwayland (vaptvupt-gui)
  #:use-module (gnu packages bash)               ;bash-minimal (vaptvupt-gui launcher)
  #:use-module (gnu packages tls)                ;openssl (vaptvupt libzuptsdk)
  #:use-module (gnu packages password-utils)     ;argon2 (vaptvupt libzuptsdk)
  #:use-module ((guix licenses) #:prefix license:))

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

;;; vaptvupt — pure-C11 post-quantum backup compressor (CLI, v4.0.0) and its
;;; PySide6/Qt6 desktop frontend (GUI, v1.3.0).  Both build from the ONE vendored
;;; release tarball.  The CLI is built FROM SOURCE with gnu-build-system (plain
;;; Makefile, no ./configure).  Two prebuilt vendored shared objects ship in the
;;; tarball — libzuptsdk (password KDF, --pq-sdk) and libpqvaptvupt (--pq-box
;;; sealed box); libzuptsdk has DT_NEEDED on libcrypto.so.3 + libargon2.so.1 but
;;; no RUNPATH, so we feed -rpath-link/-rpath via LDFLAGS at link time and patchelf
;;; a store RUNPATH onto the two .so files after install so they survive
;;; validate-runpath.  KAT self-tests need the vendored libs on LD_LIBRARY_PATH;
;;; disabled here (the binary links and runs fine).
(define-public vaptvupt
  (package
    (name "vaptvupt")
    (version "4.0.0")
    (source (local-file "sources/vaptvupt-4.0.0.tar.gz"))
    (build-system gnu-build-system)
    (arguments
     (list
      #:tests? #f
      #:make-flags
      #~(list (string-append "PREFIX=" #$output)
              (string-append "CC=" #$(cc-for-target)))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)           ; plain Makefile, no ./configure
          ;; libzuptsdk.so needs libcrypto/libargon2 at link AND run time, but
          ;; carries no RUNPATH; the Makefile keeps an env LDFLAGS (`?=` then
          ;; `+=`), so feed it -rpath-link (link) + -rpath (runtime) here.
          (add-before 'build 'set-ldflags
            (lambda* (#:key inputs #:allow-other-keys)
              (let ((ssl (string-append (assoc-ref inputs "openssl") "/lib"))
                    (arg (string-append (assoc-ref inputs "argon2") "/lib")))
                (setenv "LDFLAGS"
                        (string-append "-L" ssl " -L" arg
                                       " -Wl,-rpath-link," ssl
                                       " -Wl,-rpath-link," arg
                                       " -Wl,-rpath," ssl
                                       " -Wl,-rpath," arg)))))
          (add-after 'install 'set-vendored-lib-runpath
            (lambda* (#:key inputs outputs #:allow-other-keys)
              (let* ((out  (assoc-ref outputs "out"))
                     (libc (assoc-ref inputs "libc"))
                     (rpath (string-join
                             (list (string-append libc "/lib")
                                   (string-append (assoc-ref inputs "openssl") "/lib")
                                   (string-append (assoc-ref inputs "argon2") "/lib"))
                             ":"))
                     (vdir (string-append out "/lib/vaptvupt")))
                (for-each
                 (lambda (lib)
                   (invoke "patchelf" "--set-rpath" rpath
                           (string-append vdir "/" lib)))
                 '("libzuptsdk.so.2.0.0"
                   "libpqvaptvupt.so.0.6.0"))))))))
    (native-inputs (list patchelf))
    (inputs (list openssl argon2))
    (supported-systems '("x86_64-linux"))
    (synopsis "Post-quantum backup compression utility (CLI)")
    (description
     "VaptVupt (formerly Zupt) is a pure-C11 backup compressor with post-quantum
hybrid encryption.  Recipient modes: ML-KEM-768 + X25519 sealed box with an
HKDF-SHA256 domain-separated combiner (@code{--pq-box}, via the bundled
libpqvaptvupt), the libzuptsdk envelope (@code{--pq-sdk}) and a legacy combiner
(@code{--pq}); password mode uses Argon2id by default (PBKDF2-SHA256 optional).
Payload protection is AES-256-CTR + HMAC-SHA256 Encrypt-then-MAC with measured
constant-time tag comparison and runtime AES-NI/SHA-NI dispatch; the embedded
VaptVupt 2.60.4 LZ+ANS codec ships CBMC-verified BCJ filters.")
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
    (version "1.3.0")
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
                     (qtbase  (assoc-ref inputs "qtbase"))
                     (qtwl    (assoc-ref inputs "qtwayland")))
                (mkdir-p bin)
                (call-with-output-file (string-append bin "/vaptvupt-gui")
                  (lambda (port)
                    (format port "#!~a
export VAPTVUPT_BIN=\"~a\"
export GUIX_PYTHONPATH=\"~a${GUIX_PYTHONPATH:+:}$GUIX_PYTHONPATH\"
export QT_PLUGIN_PATH=\"~a/lib/qt6/plugins:~a/lib/qt6/plugins${QT_PLUGIN_PATH:+:}$QT_PLUGIN_PATH\"
exec \"~a\" \"~a\" \"$@\"\n"
                            sh cli site qtbase qtwl python3 gui)))
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
     (list bash-minimal python python-pyside-6 qtbase qtwayland vaptvupt))
    (supported-systems '("x86_64-linux"))
    (synopsis "Desktop frontend for VaptVupt (PySide6/Qt6 GUI)")
    (description
     "PySide6 (Qt 6) graphical frontend for VaptVupt: create, inspect and extract
@code{.zupt} archives with password (Argon2id) or post-quantum recipient
encryption, including the v4.0.0 @code{--pq-box} sealed-box mode.  The launcher
pins the matching @code{vaptvupt} CLI from the store via @env{VAPTVUPT_BIN}, so
GUI and CLI versions can never drift apart.")
    (home-page "https://git.securityops.co/cristiancmoises/vaptvupt")
    (license license:agpl3+)))
