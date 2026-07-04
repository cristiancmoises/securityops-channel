;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; This file is part of the securityops channel.
;;;
;;; First-party container / sandbox runtimes from
;;; git.securityops.co/cristiancmoises.  As with (securityops packages apps),
;;; the source is VENDORED under packages/sources/ and referenced with
;;; `local-file' (content-addressed at add time, no hash field) so the channel
;;; stays self-contained and buildable by the daemon with no network access.

(define-module (securityops packages containers)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages guile)              ;guile-3.0 (guild compile + search paths)
  #:use-module (gnu packages linux)              ;libseccomp
  #:use-module (gnu packages pkg-config)         ;pkg-config
  #:use-module ((guix licenses) #:prefix license:))

;;; esquema — a rootless, Guile-native Linux container runtime.  A small C core
;;; (libesquema.so, linked against libseccomp) drives the security-critical
;;; sequence — user + mount/pid/uts/ipc/net/cgroup namespaces, rootless uid/gid
;;; maps, pivot_root, full capability drop + securebits + no-new-privs, a
;;; seccomp-BPF allowlist (with a stacked TIOCSTI/TIOCLINUX kill filter) and
;;; cgroup v2 limits — all in async-signal-safe C between fork and execve.  A
;;; Guile layer builds a declarative <container> and calls it, and ships a
;;; native GNU Shepherd service, (esquema esquema-service).
;;;
;;; Built FROM SOURCE with gnu-build-system: the Makefile has no ./configure
;;; and no `install' target, so `configure' is dropped and `install' is
;;; replaced.  `make' (default `all' -> `lib') compiles libesquema.so with the
;;; hardening flags baked into the Makefile (FORTIFY, stack-protector/clash,
;;; full RELRO, NX, CF-protection); Guix's ld-wrapper turns the pkg-config
;;; `-L' onto libseccomp into a RUNPATH so the .so passes validate-runpath.
;;; The Scheme modules install under share/guile/site/3.0 and are byte-compiled
;;; to lib/guile/3.0/site-ccache (except esquema-service.scm, which imports
;;; (guix ...) / (gnu services ...) not present at build time — shipped as
;;; source, compiled in the system-config context where those modules exist).
;;; The FFI's library resolver is repointed at the store copy of libesquema.so,
;;; and native-search-paths export the Guile module dirs so a plain
;;; `(use-modules (esquema runtime))' works once esquema is on the profile.
;;; The in-tree SRFI-64 test suite needs a private user namespace, a static
;;; shell and live /proc games, so it is not run in the build sandbox
;;; (#:tests? #f); it is exercised out-of-band with `make check'.
(define-public esquema
  (package
    (name "esquema")
    (version "0.2.0")
    (source (local-file "sources/esquema-0.2.0-src.tar.gz"))
    (build-system gnu-build-system)
    (native-inputs (list guile-3.0 pkg-config))
    (inputs (list guile-3.0 libseccomp))
    (arguments
     (list
      #:tests? #f                       ;needs userns + static shell + /proc
      #:make-flags #~(list "CC=gcc")
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)           ;plain Makefile, no ./configure
          (replace 'install
            (lambda* (#:key outputs #:allow-other-keys)
              (let* ((out (assoc-ref outputs "out"))
                     (lib (string-append out "/lib"))
                     (scm (string-append out "/share/guile/site/3.0"))
                     (go  (string-append out "/lib/guile/3.0/site-ccache"))
                     (doc (string-append out "/share/doc/esquema-" #$version)))
                ;; 1. the native library
                (install-file "libesquema.so" lib)
                ;; 2. the Guile modules (drop the test tree + the manual smoke)
                (mkdir-p scm)
                (copy-recursively "scheme" scm)
                (when (file-exists? (string-append scm "/esquema/tests"))
                  (delete-file-recursively (string-append scm "/esquema/tests")))
                (when (file-exists? (string-append scm "/esquema/test-ffi.scm"))
                  (delete-file (string-append scm "/esquema/test-ffi.scm")))
                ;; 3. repoint the FFI loader at the store copy of the .so
                (substitute* (string-append scm "/esquema/ffi.scm")
                  (("\"/usr/local/lib\"")
                   (string-append "\"" lib "\" \"/usr/local/lib\"")))
                ;; 4. byte-compile the core modules (esquema-service is left as
                ;;    source: it imports (guix ...) unavailable at build time).
                ;;    ESQUEMA_LIBDIR + the .so already installed let the compiler
                ;;    load (esquema ffi) — pulled in by sandbox/runtime — cleanly.
                (setenv "ESQUEMA_LIBDIR" lib)
                (for-each
                 (lambda (m)
                   (let ((src (string-append scm "/esquema/" m ".scm"))
                         (dst (string-append go "/esquema/" m ".go")))
                     (mkdir-p (dirname dst))
                     (invoke "guild" "compile" "-L" scm "-o" dst src)))
                 '("constants" "ffi" "container" "sandbox" "runtime"))
                ;; 5. docs
                (for-each (lambda (f) (install-file f doc))
                          '("README.md" "LICENSE"))))))))
    (native-search-paths
     (list (search-path-specification
            (variable "GUILE_LOAD_PATH")
            (files '("share/guile/site/3.0")))
           (search-path-specification
            (variable "GUILE_LOAD_COMPILED_PATH")
            (files '("lib/guile/3.0/site-ccache")))))
    (supported-systems '("x86_64-linux"))
    (synopsis "Rootless Guile-native Linux container runtime")
    (description
     "Esquema is a minimal, security-first, rootless container runtime built
natively in Scheme for GNU Guix and the GNU Shepherd — no daemon, no root, no
YAML.  Containers are first-class Scheme objects: a declarative
@code{<container>} is confined behind defence-in-depth by a small C core
(@file{libesquema.so}, seccomp-BPF via libseccomp) that, in async-signal-safe
code between @code{fork} and @code{execve}, unshares user, mount, PID, UTS,
IPC, network and cgroup namespaces, writes rootless uid/gid maps,
@code{pivot_root}s into the rootfs with the host tree detached, drops every
capability (bounding set, ambient, @code{capset}, securebits) and sets
@code{no_new_privs}, applies a syscall allowlist (plus a stacked filter that
kills TIOCSTI/TIOCLINUX terminal injection) and applies best-effort cgroup v2
limits.  It provides the @code{(esquema runtime)}, @code{(esquema container)}
and @code{(esquema sandbox)} modules and a GNU Shepherd service type in
@code{(esquema esquema-service)}.")
    (home-page "https://git.securityops.co/cristiancmoises/esquema")
    (license license:gpl3+)))
