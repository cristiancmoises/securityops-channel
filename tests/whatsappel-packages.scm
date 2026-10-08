;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Run: guix repl -q -L . tests/whatsappel-packages.scm
(define-module (tests whatsappel-packages))
(use-modules (guix packages) (srfi srfi-64))

(define (run-tests)
  (define interface
    (false-if-exception (resolve-interface '(securityops packages whatsappel))))
  (define binding (and interface (module-variable interface 'whatsappel)))
  (test-begin "whatsappel-packages")
  (test-assert "whatsappel is available as a public channel package"
    (and binding (variable-bound? binding)
         (package? (variable-ref binding))))
  (when (and binding (variable-bound? binding))
    (let ((package (variable-ref binding)))
      (test-equal "Guix users can select the release by its advertised name"
        '("whatsappel" "3.3.1")
        (list (package-name package) (package-version package)))))
  (let ((runner (test-runner-current)))
    (test-end "whatsappel-packages")
    (exit (if (zero? (test-runner-fail-count runner)) 0 1))))

(when (string=? (basename (car (command-line))) "whatsappel-packages.scm")
  (run-tests))
