;;; SPDX-License-Identifier: GPL-3.0-or-later
(define-module (tests belgian-eid-packages))
(use-modules (guix packages) (guix git-download)
             (srfi srfi-64))

(define (run-tests)
  (test-begin "belgian-eid-packages")
  (let* ((interface (false-if-exception
                     (resolve-interface '(securityops packages belgian-eid))))
         (middleware (and interface (module-ref interface 'eid-mw #f))))
    (test-assert "middleware is a usable package" (package? middleware))
    (when (package? middleware)
      (test-equal "released Linux source" "5.1.31" (package-version middleware))
      (test-equal "official source tag" "v5.1.31"
        (git-reference-commit (origin-uri (package-source middleware))))
      (test-equal "current OpenSSL ABI" "3.5.9"
        (package-version (lookup-package-input middleware "openssl")))
      (test-equal "current XML ABI" "2.15.4"
        (package-version (lookup-package-input middleware "libxml2")))
      (test-assert "native checks remain enabled"
        (let ((setting (memq #:tests? (package-arguments middleware))))
          (or (not setting) (cadr setting))))
      (test-assert "cannot graft an older middleware"
        (not (package-replacement middleware)))))
  (let ((runner (test-runner-current)))
    (test-end "belgian-eid-packages")
    (exit (if (zero? (test-runner-fail-count runner)) 0 1))))

(when (string=? (basename (car (command-line))) "belgian-eid-packages.scm")
  (run-tests))
