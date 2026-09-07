;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>

(define-module (securityops packages containers)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages guile)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages pkg-config)
  #:use-module ((guix licenses) #:prefix license:))

;; A vendored source snapshot keeps this channel buildable offline.  Namespace
;; integration tests run on the host; the sandbox still checks installation/FFI.
(define-public esquema
  (package
    (name "esquema")
    (version "0.3.0")
    (source (local-file "sources/esquema-0.3.0-src.tar.gz"))
    (build-system gnu-build-system)
    (native-inputs (list guile-3.0 pkg-config))
    (inputs (list guile-3.0 libseccomp))
    (arguments
     (list
      #:make-flags #~(list (string-append "CC=" #$(cc-for-target))
                          (string-append "PREFIX=" #$output))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)
          (replace 'check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (invoke "make" "smoke" "test-install"))))
          (add-after 'install 'compile-guile-modules
            (lambda _
              (let ((scm (string-append #$output "/share/guile/site/3.0"))
                    (go (string-append #$output
                                       "/lib/guile/3.0/site-ccache")))
                ;; The generated library-path module points to the final store
                ;; path; compilation must not depend on the checkout library.
                (unsetenv "ESQUEMA_LIBDIR")
                (for-each
                 (lambda (module)
                   (let ((dst (string-append go "/esquema/" module ".go")))
                     (mkdir-p (dirname dst))
                     (invoke "guild" "compile" "-L" scm "-o" dst
                             (string-append scm "/esquema/" module ".scm"))))
                 '("library-path" "constants" "ffi" "container"
                   "sandbox" "runtime"))))))))
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
     "Esquema provides declarative Scheme containers backed by Linux user,
mount, PID, UTS, IPC, network and cgroup namespaces.  Its C library applies
capability removal, seccomp-BPF, Landlock and descriptor isolation.  Optional
strict policies verify cgroup and open-file limits before payload execution,
and PID-1 supervision provides signal forwarding and bounded teardown.
The package includes Guile modules and a GNU Shepherd service definition.")
    (home-page "https://esquema.securityops.co")
    (license license:agpl3+)))
