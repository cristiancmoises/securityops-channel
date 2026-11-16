;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Run with guix repl -L . tests/librewolf-packages.scm.
(define-module (tests librewolf-packages)
  #:use-module (guix packages)
  #:use-module (guix utils)
  #:use-module (guix gexp)
  #:use-module (guix monads)
  #:use-module (guix store)
  #:use-module (guix derivations)
  #:use-module (guix build utils)
  #:use-module (guix build syscalls)
  #:use-module ((gnu packages librewolf) #:prefix upstream:)
  #:use-module ((securityops packages librewolf) #:prefix channel:)
  #:use-module (ice-9 textual-ports)
  #:use-module (srfi srfi-64))

(define (wrapper-fixture-result)
  (let* ((directory (mkdtemp! (string-copy "/tmp/librewolf-wrapper-XXXXXX")))
         (source (string-append directory "/native"))
         (out (string-append directory "/out"))
         (native-browser (string-append source "/lib/librewolf/librewolf"))
         (browser (string-append out "/lib/librewolf/librewolf"))
         (record (string-append directory "/loader-path"))
         (shell (which "sh")))
    (define (write-script path content)
      (call-with-output-file path
        (lambda (port) (format port "#!~a~%~a" shell content)))
      (chmod path #o755))
    (dynamic-wind
      (lambda ()
        (mkdir-p (string-append source "/bin"))
        (mkdir-p (string-append source "/lib/librewolf"))
        (symlink native-browser (string-append source "/bin/librewolf"))
        (write-script native-browser
          (string-append
           "export LD_LIBRARY_PATH=\"/native/nss:/native/nspr\"\n"
           "exec \"" source "/lib/librewolf/.librewolf-real\" \"$@\"\n"))
        (write-script (string-append source "/lib/librewolf/.librewolf-real")
          (string-append
           "test \"$1\" = --version || exit 1\n"
           "printf '%s\\n' \"$LD_LIBRARY_PATH\" > \"" record "\"\n"
           "printf '%s\\n' \"$0\" > \"" record ".executable\"\n"))
        (write-script (string-append source "/lib/librewolf/gfxtest") "exit 0\n"))
      (lambda ()
        ;; Lower the real builder without realizing its inputs.  Only replace
        ;; the native browser's input path with a small disposable fixture.
        (let* ((builder (cadr (memq #:builder
                                   (package-arguments channel:librewolf))))
               (lowered
                (with-store store
                  (cons
                   (derivation->output-path
                    (package-derivation store upstream:librewolf
                                        "x86_64-linux" #:graft? #f))
                   (lowered-gexp-sexp
                    (run-with-store store
                      (lower-gexp builder #:system "x86_64-linux"
                                  #:graft? #f)))))))
          (define (fixture-paths value)
            (cond ((equal? value (car lowered)) source)
                  ((pair? value)
                   (cons (fixture-paths (car value))
                         (fixture-paths (cdr value))))
                  (else value)))
          (with-environment-variables
              `(("out" ,out) ("PATH" ,(getenv "PATH"))
                ("LD_LIBRARY_PATH" #f))
            (eval (fixture-paths (cdr lowered)) (current-module)))
          (list
           (call-with-input-file record get-string-all)
           (call-with-input-file (string-append record ".executable")
             get-string-all)
           (string-append out "/lib/librewolf/.librewolf-real\n")
           (file-exists? (string-append out "/lib/librewolf/.gfxtest-real"))
           (string=? browser (readlink (string-append out "/bin/librewolf"))))))
      (lambda () (delete-file-recursively directory)))))

(when (string-suffix? "librewolf-packages.scm" (car (command-line)))
  (test-begin "librewolf-packages")
  (let ((runner (test-runner-current)))
    (test-equal "published stable LibreWolf release" "160.0-1"
      (package-version channel:librewolf))
    (test-assert "reuse the authenticated native source build"
      (eq? upstream:librewolf
           (lookup-package-input channel:librewolf "librewolf-source-build")))
    (test-assert "preserve the native package's source assembly and licenses"
      (eq? (package-source upstream:librewolf)
           (package-source channel:librewolf)))
    (test-equal "complete toolchain supports x86_64-linux" '("x86_64-linux")
      (package-transitive-supported-systems channel:librewolf))
    (test-equal "AutoFirma NSS input retains the current rapid release" "3.129"
      (package-version (lookup-package-input channel:librewolf "nss-rapid")))
    (test-equal "AutoFirma NSPR input is not downgraded" "4.40"
      (package-version (lookup-package-propagated-input
                         (lookup-package-input channel:librewolf "nss-rapid")
                         "nspr")))
    (let ((result (wrapper-fixture-result)))
      (test-equal "browser retains its native NSS/NSPR loader paths"
        "/native/nss:/native/nspr\n" (list-ref result 0))
      (test-equal "copied launcher runs the compatibility output's engine"
        (list-ref result 2) (list-ref result 1))
      (test-assert "graphics probe keeps its dependency wrapper"
        (list-ref result 3))
      (test-assert "public launcher points at the compatibility output"
        (list-ref result 4)))
    (test-end "librewolf-packages")
    (exit (if (zero? (test-runner-fail-count runner)) 0 1))))
