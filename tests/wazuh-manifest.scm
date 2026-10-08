;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Run from the checkout: guix repl -L . tests/wazuh-manifest.scm
(define-module (tests wazuh-manifest))
(use-modules (guix profiles) (srfi srfi-1) (srfi srfi-64))

(define (run-tests)
  (test-begin "wazuh-manifest")
  (let* ((manifest (load (string-append (getcwd) "/etc/wazuh-manifest.scm.in")))
         (entries (manifest-entries manifest)))
    (test-equal "all server stack components" 4 (length entries))
    (test-equal "server stack names"
      '("filebeat" "wazuh-dashboard" "wazuh-indexer" "wazuh-manager")
      (sort (map manifest-entry-name entries) string<?))
    (test-assert "manager and endpoint agent use separate profiles"
      (not (find (lambda (entry)
                   (string=? (manifest-entry-name entry) "wazuh-agent"))
                 entries)))
    (for-each
     (lambda (entry)
       (test-equal "compatible component version"
         (assoc-ref '(("wazuh-manager" . "4.14.8")
                      ("wazuh-indexer" . "4.14.8-1")
                      ("wazuh-dashboard" . "4.14.8-1")
                      ("filebeat" . "7.10.2-2"))
                    (manifest-entry-name entry))
         (manifest-entry-version entry)))
     entries))
  (let ((runner (test-runner-current)))
    (test-end "wazuh-manifest")
    (exit (if (zero? (test-runner-fail-count runner)) 0 1))))

(when (string=? (basename (car (command-line))) "wazuh-manifest.scm")
  (run-tests))
