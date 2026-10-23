;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Run: guix repl -L . tests/zen-packages.scm
(define-module (tests zen-packages))
(use-modules (guix packages) (guix base16) (srfi srfi-1) (srfi srfi-64))

(define (run-tests)
  (define package
    (false-if-exception
     (module-ref (resolve-interface '(securityops packages zen))
                 'zen-browser-bin)))
  (test-begin "zen-packages")
  (test-assert "Zen is discoverable as a channel package" (package? package))
  (when (package? package)
    (test-assert "all runtime inputs resolve to packages"
      (every (lambda (entry) (package? (cadr entry))) (package-inputs package)))
    (test-assert "native inputs resolve to packages or pinned origins"
      (every (lambda (entry)
               (or (package? (cadr entry)) (origin? (cadr entry))))
             (package-native-inputs package)))
    (test-assert "PulseAudio client library is an explicit runtime dependency"
      (lookup-package-input package "pulseaudio"))
    (test-equal "official stable release" "1.23.4b" (package-version package))
    (test-equal "only the verified binary architecture" '("x86_64-linux")
      (package-supported-systems package))
    (test-equal "versioned official release archive"
      "https://github.com/zen-browser/desktop/releases/download/1.23.4b/zen.linux-x86_64.tar.xz"
      (origin-uri (package-source package)))
    (test-equal "official archive digest"
      "ba81dd70af70d645f2f0a692f7fa4510f819290abfd8d8e60273d3d5a60d0536"
      (bytevector->base16-string
       (content-hash-value (origin-hash (package-source package))))))
  (let ((runner (test-runner-current)))
    (test-end "zen-packages")
    (exit (if (zero? (test-runner-fail-count runner)) 0 1))))

(when (string=? (basename (car (command-line))) "zen-packages.scm")
  (run-tests))
