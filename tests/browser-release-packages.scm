;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Run: guix repl -L . tests/browser-release-packages.scm
(define-module (tests browser-release-packages))
(use-modules (guix packages) (srfi srfi-64)
             ((securityops packages browsers) #:prefix b:)
             ((securityops packages chromium) #:prefix c:)
             ((gnu packages chromium) #:prefix upstream:))

(define (run-tests)
  (test-begin "browser-release-packages")
  (test-equal "Chrome stable release" "155.0.8059.39-1"
    (package-version b:google-chrome-stable))
  (test-equal "Chrome published archive"
    "https://dl.google.com/linux/chrome/deb/pool/main/g/google-chrome-stable/google-chrome-stable_155.0.8059.39-1_amd64.deb"
    (origin-uri (package-source b:google-chrome-stable)))
  (test-equal "portable Chromium stable release" "154.0.8037.97-1"
    (package-version c:ungoogled-chromium-bin))
  (test-equal "portable Chromium published archive"
    "https://github.com/ungoogled-software/ungoogled-chromium-portablelinux/releases/download/154.0.8037.97-1/ungoogled-chromium-154.0.8037.97-1-x86_64_linux.tar.xz"
    (origin-uri (package-source c:ungoogled-chromium-bin)))
  (test-eq "source Chromium retains Guix compiler and patch contract"
    upstream:ungoogled-chromium b:ungoogled-chromium)
  (test-eq "portable browser public alias"
    c:ungoogled-chromium-bin b:ungoogled-chromium-bin)
  (for-each
   (lambda (package)
     (test-equal "portable archive architecture" '("x86_64-linux")
       (package-supported-systems package)))
   (list b:google-chrome-stable c:ungoogled-chromium-bin))
  (let ((runner (test-runner-current)))
    (test-end "browser-release-packages")
    (exit (if (zero? (test-runner-fail-count runner)) 0 1))))

(when (string=? (basename (car (command-line))) "browser-release-packages.scm")
  (run-tests))
