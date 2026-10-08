;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Run with guix repl -L . tests/librewolf-packages.scm.
(define-module (tests librewolf-packages)
  #:use-module (guix packages)
  #:use-module ((gnu packages librewolf) #:prefix upstream:)
  #:use-module ((securityops packages librewolf) #:prefix channel:)
  #:use-module (srfi srfi-64))

(when (string-suffix? "librewolf-packages.scm" (car (command-line)))
  (test-begin "librewolf-packages")
  (let ((runner (test-runner-current)))
    (test-equal "published stable LibreWolf release" "157.0-1"
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
    (test-end "librewolf-packages")
    (exit (if (zero? (test-runner-fail-count runner)) 0 1))))
