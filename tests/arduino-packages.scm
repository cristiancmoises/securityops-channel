;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Run: guix repl -L . tests/arduino-packages.scm
(define-module (tests arduino-packages))
(use-modules (guix packages) (srfi srfi-64))

(define (run-tests)
  (test-begin "arduino-packages")
  (define ide
    (false-if-exception
     (module-ref (resolve-interface '(securityops packages arduino))
                 'arduino-ide)))
  (test-assert "Arduino IDE package is public" (package? ide))
  (when (package? ide)
    (test-equal "stable upstream release" "2.3.10" (package-version ide))
    (test-equal "only published Linux architecture" '("x86_64-linux")
      (package-supported-systems ide))
    (test-equal "no downgrade graft" #f (package-replacement ide))
    (test-assert "immutable official release is pinned"
      (origin? (package-source ide))))
  (let ((runner (test-runner-current)))
    (test-end "arduino-packages")
    (exit (if (zero? (test-runner-fail-count runner)) 0 1))))

(when (string=? (basename (car (command-line))) "arduino-packages.scm")
  (run-tests))
