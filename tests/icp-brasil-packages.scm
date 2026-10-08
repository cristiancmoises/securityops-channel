;;; SPDX-License-Identifier: GPL-3.0-or-later
(define-module (tests icp-brasil-packages))
(use-modules (guix packages) (guix gexp) (guix licenses)
             (guix build-system trivial) (srfi srfi-64))

(define (run-tests)
  (test-begin "icp-brasil-packages")
  (let* ((interface (false-if-exception
                     (resolve-interface '(securityops packages icp-brasil))))
         (roots (and interface (module-ref interface 'icp-brasil-roots #f))))
    (test-assert "active roots are a real data package" (package? roots))
    (when (package? roots)
      (test-equal "dated official root registry" "2026.10.05"
        (package-version roots))
      (test-assert "original certificate collection is included"
        (local-file? (package-source roots)))
      (test-eq "data-only build" trivial-build-system
        (package-build-system roots))
      (test-equal "installation never registers global trust" '()
        (package-native-search-paths roots))
      (test-equal "no automatic trust environment" '()
        (package-search-paths roots))
      (test-equal "registry redistribution terms retained" "CC-BY-ND 3.0"
        (license-name (package-license roots)))))
  (let ((runner (test-runner-current)))
    (test-end "icp-brasil-packages")
    (exit (if (zero? (test-runner-fail-count runner)) 0 1))))

(when (string=? (basename (car (command-line))) "icp-brasil-packages.scm")
  (run-tests))
