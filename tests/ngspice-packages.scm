;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Run: guix repl -L . tests/ngspice-packages.scm
(define-module (tests ngspice-packages))
(use-modules (guix packages) (srfi srfi-64)
             ((securityops packages electronics) #:prefix s:))

(define (run-tests)
  (test-begin "ngspice-packages")
  (for-each
   (lambda (package)
     (test-equal "current stable release" "47" (package-version package))
     (test-eq "same verified release archive"
       (package-source s:libngspice) (package-source package))
     (test-equal "no inherited older replacement" #f
       (package-replacement package)))
   (list s:libngspice s:ngspice))
  (test-eq "CLI uses matching shared library"
    s:libngspice (lookup-package-input s:ngspice "libngspice"))
  (let ((runner (test-runner-current)))
    (test-end "ngspice-packages")
    (exit (if (zero? (test-runner-fail-count runner)) 0 1))))

(when (string=? (basename (car (command-line))) "ngspice-packages.scm")
  (run-tests))
