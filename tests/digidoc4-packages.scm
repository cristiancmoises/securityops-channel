;;; SPDX-License-Identifier: GPL-3.0-or-later
(define-module (tests digidoc4-packages))
(use-modules (guix packages) (guix git-download) (srfi srfi-64))

(define (run-tests)
  (test-begin "digidoc4-packages")
  (let* ((interface
          (false-if-exception
            (resolve-interface '(securityops packages digidoc4))))
         (desktop (and interface (module-ref interface 'digidoc4 #f))))
    (test-assert "desktop is a usable package" (package? desktop))
    (when (package? desktop)
      (test-equal "released desktop version" "4.11.1" (package-version desktop))
      (test-assert "source includes the internal libraries"
        (git-reference-recursive? (origin-uri (package-source desktop))))
      (test-equal "desktop uses the channel's tested signature library"
        "4.5.1" (package-version (lookup-package-input desktop "libdigidocpp")))
      (test-equal "desktop and signature library share the current XML ABI"
        "2.15.4" (package-version (lookup-package-input desktop "libxml2")))
      (test-equal "current Mozilla certificate data"
        "3.129" (package-version (lookup-package-input desktop "nss-certs")))
      (test-assert "package cannot graft an older desktop"
        (not (package-replacement desktop)))))
  (let ((runner (test-runner-current)))
    (test-end "digidoc4-packages")
    (exit (if (zero? (test-runner-fail-count runner)) 0 1))))

(when (string=? (basename (car (command-line))) "digidoc4-packages.scm")
  (run-tests))
