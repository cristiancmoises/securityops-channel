;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>

(define-module (securityops packages wazuh-search)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module (guix build-system trivial)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages gdb)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-xyz)
  #:use-module (securityops packages wazuh))

(define %tools (list bash-minimal coreutils binutils tar gzip xz zstd patchelf))
(define %libraries (list glibc (list gcc "lib") zlib))
(define %launcher
  (local-file (canonicalize-path
               (search-path %load-path
                            "securityops/packages/aux-files/wazuh-search-launch.py"))))
(define %python-site
  (string-append "/lib/python" (version-major+minor (package-version python))
                 "/site-packages"))

;; The compatible 7.10.2 binary's default-deny seccomp filter predates
;; clone3.  Keep that filter unchanged and use glibc's existing legacy-clone
;; pthread implementation only in this private ABI-compatible runtime.
(define glibc-for-wazuh-filebeat
  (package
    (inherit glibc)
    (name "glibc-for-wazuh-filebeat")
    (arguments
     (substitute-keyword-arguments (package-arguments glibc)
       ((#:tests? _ #f) #t)
       ((#:phases phases)
        #~(modify-phases #$phases
            (add-after 'unpack 'use-compatible-pthread-clone
              (lambda _
                (use-modules (ice-9 textual-ports))
                (unless (string-contains
                         (call-with-input-file "nptl/pthread_create.c" get-string-all)
                         "__clone_internal (&args, &start_thread, pd)")
                  (error "Private pthread compatibility patch no longer matches"))
                (substitute* "nptl/pthread_create.c"
                  (("__clone_internal \\(") "__clone_internal_fallback ("))))
            (add-after 'pre-configure 'restore-native-test-unwinder
              (lambda _
                ;; The base bootstrap recipe removes -lgcc_s and disables
                ;; tests.  Its native cancellation/C++ tests require the
                ;; actual compiler unwind runtime; restore test linkage only.
                (substitute* "Makeconfig"
                  (("libgcc_eh := -Wl,--as-needed")
                   "libgcc_eh := -Wl,--as-needed -lgcc_s"))))
            (replace 'check
              (lambda* (#:key inputs make-flags #:allow-other-keys)
                ;; All native NPTL tests, including thread creation/join and
                ;; cancellation, exercise the changed implementation.
                (let ((unwinder (string-append (assoc-ref inputs "gcc-runtime") "/lib"))
                      (previous (getenv "GUIX_LD_WRAPPER_DISABLE_RPATH")))
                  ;; Guix's wrapper otherwise injects GCC RUNPATH into a
                  ;; static-PIE C++ test, which glibc rejects before main.
                  ;; Disable only automatic test-link RPATH; native dynamic
                  ;; tests receive the explicit compiler runtime path below.
                  (dynamic-wind
                    (lambda () (setenv "GUIX_LD_WRAPPER_DISABLE_RPATH" "1"))
                    (lambda ()
                      (catch #t
                        (lambda ()
                          (apply invoke "make" "-j"
                                 (number->string (parallel-job-count))
                                 "check" "subdirs=nptl"
                                 (string-append "sysdep-library-path=" unwinder)
                                 (string-append "sysdep-ld-library-path=" unwinder)
                                 make-flags))
                        (lambda (key . arguments)
                          ;; Native test diagnostics are otherwise lost when
                          ;; the daemon removes a failed temporary directory.
                          (for-each
                           (lambda (result)
                             (when (string-contains
                                    (call-with-input-file result get-string-all) "FAIL:")
                               (let ((log (string-append
                                           (string-drop-right result 12) ".out")))
                                 (when (file-exists? log)
                                   (format #t "Failed native test output: ~a~%" log)
                                   (display (call-with-input-file log get-string-all))))))
                           (find-files "." "\\.test-result$"))
                          (apply throw key arguments))))
                    (lambda ()
                      (if previous
                          (setenv "GUIX_LD_WRAPPER_DISABLE_RPATH" previous)
                          (unsetenv "GUIX_LD_WRAPPER_DISABLE_RPATH")))))))))))
    (native-inputs
     (append (list (list "gcc-runtime" gcc "lib")
                   (list "gdb" gdb) (list "python-pexpect" python-pexpect))
             (package-native-inputs glibc)))
    (synopsis "Private compatible pthread runtime for Wazuh Filebeat")
    (description "This private GNU C Library retains the base Guix source and
patches.  Only pthread creation selects its existing legacy clone fallback,
because compatible Filebeat's unchanged default-deny seccomp filter rejects
clone3.  It is not a global libc replacement.  Native NPTL tests are enabled.")))

(define %relocate-elf
  #~(lambda (directory inputs)
      (let ((loader (search-input-file inputs "/lib/ld-linux-x86-64.so.2"))
            (libraries (map (lambda (name)
                              (string-append (assoc-ref inputs name) "/lib"))
                            '("glibc" "gcc" "zlib"))))
        (for-each
         (lambda (file)
           (when (elf-file? file)
             (let* ((port (open-pipe* OPEN_READ "readelf" "-d" file))
                    (dynamic (get-string-all port)))
               (close-pipe port)
               (when (string-contains dynamic "Dynamic section")
                 (chmod file (logior #o200 (stat:perms (stat file))))
                 (let* ((port (open-pipe* OPEN_READ "patchelf" "--print-rpath" file))
                        (old (string-trim-right (get-string-all port))))
                   (close-pipe port)
                   (invoke "patchelf" "--set-rpath"
                           (string-join
                            (append (list old "$ORIGIN" "$ORIGIN/../lib"
                                          "$ORIGIN/../lib/server" "$ORIGIN/server")
                                    libraries) ":") file))
                 (let* ((port (open-pipe* OPEN_READ "readelf" "-l" file))
                        (program (get-string-all port)))
                   (close-pipe port)
                   (when (string-contains program "Requesting program interpreter")
                     (invoke "patchelf" "--set-interpreter" loader file)))))))
         (find-files directory ".*")))))

(define (wazuh-runtime name version url hash license)
  (package
    (name name)
    (version version)
    (source (origin (method url-fetch) (uri url)
                    (sha256 (base32 hash))))
    (build-system trivial-build-system)
    (arguments
     (list #:modules '((guix build utils))
           #:builder
           #~(begin
               (use-modules (guix build utils) (ice-9 ftw) (ice-9 popen)
                            (ice-9 textual-ports) (srfi srfi-1) (srfi srfi-13))
               (setenv "PATH" (string-join
                               (map (lambda (entry)
                                      (string-append (cdr entry) "/bin"))
                                    %build-inputs) ":"))
               (invoke "tar" "xf" (assoc-ref %build-inputs "source"))
               (let ((root (find file-is-directory?
                                 (scandir "." (lambda (name)
                                                (not (member name '("." ".."))))))))
                 (unless root (error "Runtime archive has no root"))
                 (copy-recursively root #$output)
                 (#$%relocate-elf #$output %build-inputs)))))
    (native-inputs %tools)
    (inputs %libraries)
    (supported-systems '("x86_64-linux"))
    (home-page url)
    (synopsis "Compatible runtime for the Wazuh search distribution")
    (description "This private runtime adapts an official upstream binary
distribution to the Guix loader and runtime libraries.  Its complete upstream
license and notice files are retained; it does not install system services.")
    (license license)))

(define temurin-for-wazuh
  (wazuh-runtime
   "temurin-for-wazuh" "21.0.12.1"
   "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.12.1%2B1/OpenJDK21U-jdk_x64_linux_hotspot_21.0.12.1_1.tar.gz"
   "157fzay6iyd6i3bhc45021fvgd8y5d0nma5swbhqxv872fg8cyff" license:gpl2+))

;; Do not cross the distribution's declared >=14.20.1,<19 Node constraint.
;; 18.20.8 is its latest compatible release, but Node 18 is end-of-life.
(define node-for-wazuh
  (wazuh-runtime
   "node-for-wazuh" "18.20.8"
   "https://nodejs.org/dist/v18.20.8/node-v18.20.8-linux-x64.tar.xz"
   "1j8162cr0ysfl7z6bx6fvcs2gjdcbkxy643adga1255gsrifwrsl" license:expat))

(define (wazuh-search-package name version hash runtime kinds)
  (package
    (name name)
    (version version)
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://packages.wazuh.com/4.x/apt/pool/main/"
                           (if (string=? name "filebeat") "f/" "w/") name "/"
                           name "_" version "_amd64.deb"))
       (sha256 (base32 hash))))
    (build-system trivial-build-system)
    (arguments
     (list #:modules '((guix build utils))
           #:builder
           #~(begin
               (use-modules (guix build utils) (ice-9 popen)
                            (ice-9 textual-ports) (srfi srfi-1) (srfi srfi-13))
               (setenv "PATH" (string-join
                               (map (lambda (entry)
                                      (string-append (cdr entry) "/bin"))
                                    %build-inputs) ":"))
               ;; Stream the payload rather than duplicating an 875 MB archive
               ;; in the daemon's bounded temporary filesystem.
               (invoke "bash" "-o" "pipefail" "-c"
                       "ar p \"$1\" \"$2\" | tar \"$3\" -"
                       "wazuh-unpack" (assoc-ref %build-inputs "source")
                       (if (string=? #$name "wazuh-dashboard")
                           "data.tar.xz" "data.tar.gz")
                       (if (string=? #$name "wazuh-dashboard") "-xJf" "-xzf"))
               (let* ((home (string-append #$output "/share/" #$name))
                      (docs (string-append #$output "/share/doc/" #$name))
                      (python (search-input-file %build-inputs "/bin/python3")))
                 (copy-recursively (string-append "usr/share/" #$name) home)
                 ;; Active configuration/state is never populated with vendor
                 ;; defaults or demonstration credentials by this package.
                 (for-each
                  (lambda (entry)
                    (let ((file (string-append home "/" entry)))
                      (when (or (file-exists? file) (false-if-exception (lstat file)))
                        (if (and (file-is-directory? file)
                                 (not (eq? 'symlink (stat:type (lstat file)))))
                            (delete-file-recursively file) (delete-file file)))))
                  '("config" "data" "logs" "jdk" "node"))
                 (mkdir-p docs)
                 (when (file-exists? (string-append "usr/share/doc/" #$name))
                   (copy-recursively (string-append "usr/share/doc/" #$name) docs))
                 (when (file-exists? (string-append "etc/" #$name))
                   (let ((examples (string-append docs "/config-examples")))
                     (copy-recursively (string-append "etc/" #$name) examples)
                     (let ((users (string-append examples
                                                 "/opensearch-security/internal_users.yml")))
                       (when (file-exists? users) (delete-file users)))
                     (when (string=? #$name "wazuh-indexer")
                       (substitute* (string-append examples "/opensearch.yml")
                         (("enforce_hostname_verification: false")
                          "enforce_hostname_verification: true")
                         (("network.host: \"0.0.0.0\"")
                          "network.host: \"127.0.0.1\"")))))
                 (copy-file
                  #$(plain-file "SOURCE-LINKS"
                     "https://github.com/wazuh/wazuh/tree/v4.14.8\nhttps://github.com/wazuh/wazuh-indexer\nhttps://github.com/wazuh/wazuh-dashboard\nhttps://github.com/wazuh/wazuh-dashboard-plugins/tree/v4.14.8\nhttps://github.com/elastic/beats/tree/v7.10.2\nhttps://github.com/adoptium/jdk21u/releases/tag/jdk-21.0.12.1%2B1\nhttps://nodejs.org/dist/v18.20.8/node-v18.20.8.tar.xz\n")
                  (string-append docs "/SOURCE-LINKS"))
                 (#$%relocate-elf home %build-inputs)
                 (for-each patch-shebang
                           (delete-duplicates
                            (append (find-files home "\\.sh$")
                                    (find-files (string-append home "/bin") ".*"))))
                 (when (string=? #$name "wazuh-dashboard")
                   (substitute* (string-append home "/bin/opensearch-dashboards")
                     (("OSD_PATH_CONF=\"/etc/wazuh-dashboard\"")
                      "OSD_PATH_CONF=\"$OSD_PATH_CONF\""))
                   (let ((client (string-append home
                                  "/plugins/wazuhCore/server/services/server-api-client.js")))
                     (unless (string-contains (call-with-input-file client get-string-all)
                                              "rejectUnauthorized: false")
                       (error "Manager client TLS patch no longer matches upstream"))
                     (substitute* client
                       (("rejectUnauthorized: false") "rejectUnauthorized: true")
                       (("      httpsAgent") "      httpsAgent, maxRedirects: 0"))
                     (unless (string-contains (call-with-input-file client get-string-all)
                                              "httpsAgent, maxRedirects: 0")
                       (error "Manager client redirect patch no longer matches upstream"))
                     (copy-file
                      #$(plain-file "LOCAL-MODIFICATIONS"
                         "The Wazuh manager API client was modified to verify peer certificates and hostnames using an explicit caller-supplied CA, and to prohibit credential-bearing redirects.\n")
                      (string-append docs "/LOCAL-MODIFICATIONS"))))
                 ;; Native helper scripts also locate their compatible runtime
                 ;; beneath the application home.  Add immutable links only
                 ;; after relocation, never traverse and modify an input tree.
                 (when (member #$name '("wazuh-dashboard" "wazuh-indexer"))
                   (symlink #$runtime
                            (string-append home
                              (if (string=? #$name "wazuh-dashboard") "/node" "/jdk"))))
                 (when (string=? #$name "filebeat")
                   (mkdir "wazuh-source")
                   (with-directory-excursion "wazuh-source"
                     (invoke "tar" "xf" (assoc-ref %build-inputs "wazuh-source")
                             "--strip-components=1")
                     (copy-recursively "extensions/filebeat/7.x/wazuh-module"
                                       (string-append home "/module/wazuh"))
                     (copy-file "LICENSE"
                                (string-append docs "/WAZUH-MODULE-LICENSE"))
                     (copy-file "extensions/elasticsearch/7.x/wazuh-template.json"
                                (string-append home "/wazuh-template.json"))))
                 (mkdir-p (string-append #$output "/libexec"))
                 (copy-file #$%launcher
                            (string-append #$output "/libexec/wazuh-search-launch.py"))
                 (mkdir-p (string-append #$output "/bin"))
                 (for-each
                  (lambda (kind)
                    (let* ((command (string-append #$output "/bin/wazuh-"
                                                   (if (string=? kind "securityadmin")
                                                       "indexer-securityadmin" kind)))
                           (script (string-append #$output
                                                  "/libexec/wazuh-search-launch.py")))
                      (call-with-output-file command
                        (lambda (port)
                          (format port "#!~a~%export PATH=~a~%exec ~a -I -c 'import runpy,sys;sys.path.insert(0,~s);sys.argv=sys.argv[1:];runpy.run_path(sys.argv[0],run_name=\"__main__\")' ~a ~a ~a ~a \"$@\"~%"
                                  (which "sh")
                                  (getenv "PATH") python
                                  (string-append (assoc-ref %build-inputs "python-pyyaml")
                                                 #$%python-site)
                                  script kind home #$runtime)))
                      (chmod command #o555))) '#$kinds)))))
    (native-inputs %tools)
    (inputs (append `(("glibc" ,(if (string=? name "filebeat")
                                  glibc-for-wazuh-filebeat glibc))
                      ("gcc" ,gcc "lib") ("zlib" ,zlib)
                      ("python" ,python) ("python-pyyaml" ,python-pyyaml)
                      ("runtime" ,runtime))
                    (if (string=? name "filebeat")
                        `(("wazuh-source" ,wazuh-source)) '())))
    (supported-systems '("x86_64-linux"))
    (home-page "https://wazuh.com/")
    (synopsis "Wazuh search stack component with explicit state")
    (description "This package adapts the official compatible Wazuh
distribution to an immutable Guix runtime.  Its launcher requires existing owned
WAZUH_SEARCH_STATE/config, data and logs directories and explicit TLS and
authentication configuration.  No service, default password, demo trust anchor or
mutable state is installed.  Upstream license and source directions are retained.")
    (license (if (member name '("wazuh-dashboard" "filebeat"))
                 (list license:asl2.0 license:gpl2) license:asl2.0))))

(define-public wazuh-indexer
  (wazuh-search-package "wazuh-indexer" "4.14.8-1"
                        "03r5iv7wmxlh0mf4n3pdn2kaxhfc2cc1ljaib75x90sgmkw295k3"
                        temurin-for-wazuh '("indexer" "securityadmin")))

(define-public wazuh-dashboard
  (wazuh-search-package "wazuh-dashboard" "4.14.8-1"
                        "1m7jhqnmws77bymvxbqv4iyl2x016qm6xgd0rj0yd58jna2k0hgj"
                        node-for-wazuh '("dashboard")))

(define-public wazuh-filebeat
  (wazuh-search-package "filebeat" "7.10.2-2"
                        "0jz1z41d0fdll1v48gd45mpwigx4h3a7kiw6ik8hfw5k60438iyw"
                        python '("filebeat")))
