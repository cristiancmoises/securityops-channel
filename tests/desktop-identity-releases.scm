;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Run: guix repl -L . tests/desktop-identity-releases.scm
(define-module (tests desktop-identity-releases))
(use-modules (guix packages) (srfi srfi-64)
             ((securityops packages eid) #:prefix e:)
             ((securityops packages river) #:prefix r:))

(define (run-tests)
  (test-begin "desktop-identity-releases")
  (test-equal "libdigidocpp stable" "4.5.1" (package-version e:libdigidocpp))
  (test-equal "libevdev stable" "1.14.0" (package-version r:libevdev-latest))
  (test-equal "Xwayland stable" "24.1.14" (package-version r:xwayland-latest))
  (test-eq "libinput uses the updated event library" r:libevdev-latest
    (lookup-package-input r:libinput-minimal-latest "libevdev"))
  (test-equal "installed acceptance follows the library version"
    (package-version e:libdigidocpp)
    (package-version e:libdigidocpp-acceptance))
  (let ((runner (test-runner-current)))
    (test-end "desktop-identity-releases")
    (exit (if (zero? (test-runner-fail-count runner)) 0 1))))

(when (string=? (basename (car (command-line))) "desktop-identity-releases.scm")
  (run-tests))
