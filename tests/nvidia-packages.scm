;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Run with guix repl -L . tests/nvidia-packages.scm.
(define-module (tests nvidia-packages)
  #:use-module (guix packages)
  #:use-module ((securityops packages nvidia) #:prefix channel:)
  #:use-module ((securityops packages games) #:prefix games:)
  #:use-module (srfi srfi-64))

(when (string-suffix? "nvidia-packages.scm" (car (command-line)))
  (test-begin "nvidia-packages")
  (let ((runner (test-runner-current))
        (driver channel:nvidia-driver-new-feature))
    (for-each
     (lambda (package)
       (test-equal (string-append "matched release: " (package-name package))
         "615.78.08" (package-version package)))
     (list driver channel:nvidia-firmware-new-feature
           channel:nvidia-module-new-feature channel:nvda-new-feature))
    (test-assert "the user-facing union uses the refreshed driver"
      (eq? driver
           (lookup-package-input channel:nvda-new-feature
                                 "nvidia-driver-new-feature")))
    (test-equal "driver retains the upstream architecture contract"
      '("x86_64-linux" "i686-linux" "aarch64-linux")
      (package-supported-systems driver))
    (test-equal "Steam retains the channel bootstrap version"
      (package-version games:steam)
      (package-version channel:steam-nvidia-new-feature))
    (test-end "nvidia-packages")
    (exit (if (zero? (test-runner-fail-count runner)) 0 1))))
