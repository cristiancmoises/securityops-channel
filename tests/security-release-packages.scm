;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Run: guix repl -L . tests/security-release-packages.scm
(define-module (tests security-release-packages))
(use-modules (guix packages) (srfi srfi-64)
             ((securityops packages ausweisapp) #:prefix a:)
             ((securityops packages security) #:prefix s:)
             ((securityops packages tor) #:prefix t:))

(define (run-tests)
  (test-begin "security-release-packages")
  (test-equal "sdb stable" "2.6.2" (package-version s:sdb))
  (test-equal "radare2 stable" "6.2.6" (package-version s:radare2))
  (test-assert "rizin uses the system BLAKE3 backend"
    (lookup-package-input s:rizin "blake3"))
  (test-equal "AusweisApp uses the matching Qt Language Server ABI"
    "6.9.2"
    (package-version
     (lookup-package-input
      (lookup-package-input a:ausweisapp "qtdeclarative")
      "qtlanguageserver")))
  (test-equal "Tor stable" "0.4.9.16" (package-version t:tor))
  (test-assert "no conflicting regular radare2 dependency"
    (let ((library (lookup-package-input s:radare2 "sdb")))
      (or (not library) (eq? s:sdb library))))
  (test-eq "matching radare2 public dependency" s:sdb
    (lookup-package-propagated-input s:radare2 "sdb"))
  (let ((runner (test-runner-current)))
    (test-end "security-release-packages")
    (exit (if (zero? (test-runner-fail-count runner)) 0 1))))

(when (string=? (basename (car (command-line))) "security-release-packages.scm")
  (run-tests))
