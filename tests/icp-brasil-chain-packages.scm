;;; SPDX-License-Identifier: GPL-3.0-or-later

(define-module (tests icp-brasil-chain-packages))
(use-modules (guix packages) (guix gexp) (guix licenses)
             (guix build-system trivial) (srfi srfi-64))

(define (run-tests)
  (test-begin "icp-brasil-chain-packages")
  (let* ((interface (false-if-exception
                     (resolve-interface '(securityops packages icp-brasil-chain))))
         (data (and interface (module-ref interface 'icp-brasil-ca-data #f))))
    (test-assert "CA collection is a real opt-in data package" (package? data))
    (when (package? data)
      (test-equal "dated official CA snapshot" "2026.08.26"
        (package-version data))
      (test-assert "original public certificates are immutable channel assets"
        (local-file? (package-source data)))
      (test-eq "data-only build" trivial-build-system
        (package-build-system data))
      (test-equal "no propagated runtime or activation dependency" '()
        (package-propagated-inputs data))
      (test-equal "no automatic CA environment" '()
        (package-search-paths data))
      (test-equal "no native automatic CA environment" '()
        (package-native-search-paths data))
      (test-equal "registry redistribution terms retained" "CC-BY-ND 3.0"
        (license-name (package-license data)))))
  (let ((runner (test-runner-current)))
    (test-end "icp-brasil-chain-packages")
    (exit (if (zero? (test-runner-fail-count runner)) 0 1))))

(when (string=? (basename (car (command-line))) "icp-brasil-chain-packages.scm")
  (run-tests))
