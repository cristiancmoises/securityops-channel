;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Run: guix repl -L . tests/rustdesk-packages.scm
(define-module (tests rustdesk-packages))
(use-modules (guix packages) (guix git-download) (srfi srfi-64))

(define (run-tests)
  (test-begin "rustdesk-packages")
  (define interface
    (catch #t
      (lambda () (resolve-interface '(securityops packages remote-desktop)))
      (lambda _ #f)))
  (test-assert "RustDesk package module exists" interface)
  (when interface
    (for-each
     (lambda (spec)
       (let ((package (module-ref interface (car spec) #f)))
         (test-assert "public client/server package" (package? package))
         (when (package? package)
           (test-equal "stable release version" (cdr spec)
             (package-version package))
           (test-equal "binary architecture accurately restricted"
             '("x86_64-linux") (package-supported-systems package))
           (let ((source (lookup-package-native-input package "upstream-source")))
             (test-assert "release source includes submodules"
               (and (origin? source)
                    (git-reference? (origin-uri source))
                    (git-reference-recursive? (origin-uri source))))))))
     '((rustdesk . "1.4.9") (rustdesk-server . "1.1.16"))))
  (let ((runner (test-runner-current)))
    (test-end "rustdesk-packages")
    (exit (if (zero? (test-runner-fail-count runner)) 0 1))))

(when (string=? (basename (car (command-line))) "rustdesk-packages.scm")
  (run-tests))
