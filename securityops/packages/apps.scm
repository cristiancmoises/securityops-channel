;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; This file is part of the securityops channel.
;;;
;;; First-party applications from git.securityops.co/cristiancmoises.
;;;
;;; The forge is SSH-key-only (anonymous HTTP is disabled), so the Guix daemon
;;; cannot fetch these with a normal git-fetch/url-fetch origin.  Sources/release
;;; artifacts are therefore VENDORED into this channel under packages/sources/
;;; and referenced with `local-file' (content-addressed by Guix at add time, so
;;; no hash field is needed).  This keeps the channel self-contained and buildable
;;; by the daemon with no network or SSH access.

(define-module (securityops packages apps)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix build-system copy)
  #:use-module (gnu packages base)               ;glibc
  #:use-module (gnu packages gcc)                ;gcc:lib (libgcc_s)
  #:use-module (gnu packages elf)                ;patchelf
  #:use-module (gnu packages python)             ;python (torando-gui)
  #:use-module (gnu packages tor)                ;tor (torando-gui)
  #:use-module (gnu packages linux)              ;iptables, e2fsprogs/chattr (torando-gui)
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
;;; (the forge is SSH-only, so the daemon can't fetch it; binaries are vendored).
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
;;; compile, no patchelf.  Source is the vendored 1.1.0 release snapshot (the
;;; forge is SSH-only, so the daemon can't fetch it).  The two FHS shims call a
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
