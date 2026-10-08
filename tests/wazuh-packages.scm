;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Run: guix repl -L . tests/wazuh-packages.scm
(define-module (tests wazuh-packages))
(use-modules (guix packages) (srfi srfi-64)
             ((securityops packages wazuh) #:prefix w:))

(define (run-tests)
  (test-begin "wazuh-packages")
  (for-each
   (lambda (package)
     (test-equal "current stable core release" "4.14.8"
       (package-version package))
     (test-equal "no replacement" #f (package-replacement package))
     (test-assert "core recipe has a real source" (package-source package))
     ;; Package records have lazy fields; exercise dependency expressions too.
     (test-assert "runtime dependencies resolve" (pair? (package-inputs package)))
     (test-assert "native dependencies resolve" (pair? (package-native-inputs package))))
   (list w:wazuh-agent w:wazuh-manager))
  (let ((runtime (assoc-ref (package-inputs w:wazuh-manager) "python-runtime")))
    (test-assert "manager declares its shared pinned Python environment" runtime)
    (test-equal "shared environment follows the component release" "4.14.8"
      (and runtime (package-version (car runtime))))
    (test-assert "agent and manager reuse the exact same Python closure"
      (eq? (car runtime)
           (car (assoc-ref (package-inputs w:wazuh-agent) "python-runtime"))))
    (test-equal "final ABI-compatible CPython security release" "3.10.22"
      (and runtime
           (package-version
            (car (assoc-ref (package-inputs (car runtime)) "native-python"))))))
  (test-assert "bundled runtime license metadata is composite"
    (list? (package-license w:wazuh-manager)))
  (let ((runner (test-runner-current)))
    (test-end "wazuh-packages")
    (exit (if (zero? (test-runner-fail-count runner)) 0 1))))

(when (string=? (basename (car (command-line))) "wazuh-packages.scm")
  (run-tests))
