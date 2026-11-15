;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Run: guix repl -L . tests/wayland-packages.scm
(define-module (tests wayland-packages))
(use-modules (guix packages) (guix gexp)
             (srfi srfi-1) (srfi srfi-13) (srfi srfi-64)
             ((gnu packages freedesktop) #:prefix gnu:)
             ((securityops packages river) #:prefix river:))

(define (configure-flags package)
  (let ((entry (memq #:configure-flags (package-arguments package))))
    (if entry
        (eval (gexp->approximate-sexp (cadr entry)) (current-module))
        '())))

(define (run-tests)
  (test-begin "wayland-packages")
  (let ((flags (configure-flags river:wayland-latest))
        (arguments (package-arguments river:wayland-latest)))
    ;; Our unpatched upstream source does not provide Guix's added book option.
    (test-assert "upstream Wayland receives no downstream-only book option"
      (not (any (lambda (flag) (string-prefix? "-Dbook=" flag)) flags)))
    (test-equal "all other inherited configure flags survive"
      (filter (lambda (flag) (not (string-prefix? "-Dbook=" flag)))
              (configure-flags gnu:wayland))
      flags)
    (test-assert "Wayland documentation output remains available"
      (member "doc" (package-outputs river:wayland-latest)))
    (test-assert "Wayland documentation remains enabled"
      (not (member "-Ddocumentation=false" flags)))
    (test-assert "Wayland test suite remains enabled"
      (and (not (member "-Dtests=false" flags))
           (let ((tests (memq #:tests? arguments)))
             (or (not tests) (not (eq? #f (cadr tests))))))))
  (let ((runner (test-runner-current)))
    (test-end "wayland-packages")
    (exit (if (zero? (test-runner-fail-count runner)) 0 1))))

(when (string=? (basename (car (command-line))) "wayland-packages.scm")
  (run-tests))
