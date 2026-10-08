;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Run: guix repl -q -L . tests/securityops-tools-packages.scm
(define-module (tests securityops-tools-packages))
(use-modules (guix discovery) (guix packages)
             (srfi srfi-1) (srfi srfi-64))

(define %expected-applications
  '((evelin-bin "evelin-bin" "4.4.0")
    (btp "btp" "0.7")
    (mirim "mirim" "1.1.1")
    (torando-gui "torando-gui" "1.4.1")
    (zupt "zupt" "5.2.9")
    (zupt-gui "zupt-gui" "5.2.9")
    (turborec "turborec" "3.10.4")
    (turborec-nvidia-new-feature "turborec-nvidia-new-feature" "3.10.4")
    (moneyprinterturbo "moneyprinterturbo" "1.3.7")
    (guixvis "guixvis" "0.10.0")
    (whatsappel "whatsappel" "3.3.1")))

(define (run-tests)
  (define root
    (canonicalize-path (string-append (dirname (car (command-line))) "/..")))
  (define canonical-source
    (string-append root "/securityops/packages/applications.scm"))
  (test-begin "securityops-tools-packages")
  ;; Keep the absent-module regression an assertion failure before migration.
  (test-assert "canonical applications module source exists"
    (file-exists? canonical-source))
  (when (file-exists? canonical-source)
    (let ((canonical (resolve-interface '(securityops packages applications)))
          (legacy (resolve-interface '(securityops packages apps))))
      (for-each
       (lambda (entry)
         (let* ((symbol (car entry))
                (label (symbol->string symbol))
                (binding (module-variable canonical symbol))
                (legacy-binding (module-variable legacy symbol)))
           (test-assert (string-append label " is a public canonical package")
             (and binding (variable-bound? binding)
                  (package? (variable-ref binding))))
           (test-eq (string-append label " preserves the legacy variable")
             binding legacy-binding)
           (when (and binding (variable-bound? binding)
                      (package? (variable-ref binding)))
             (let ((package (variable-ref binding)))
               (test-equal (string-append label " preserves its name and release")
                 (cdr entry)
                 (list (package-name package) (package-version package)))
               (test-assert (string-append label " preserves the legacy package")
                 (and legacy-binding (variable-bound? legacy-binding)
                      (eq? package (variable-ref legacy-binding))))))))
       %expected-applications))
    (let* ((load-errors '())
           ;; Use the same discovery helpers as Toys, restricted to this
           ;; channel's package sources; no tests or private directories.
           (modules
            (scheme-modules root "securityops/packages"
                            #:warn (lambda (file module args)
                                     (set! load-errors
                                           (cons (list file module args)
                                                 load-errors)))))
           (names (map cadr %expected-applications))
           (rows
            (fold-module-public-variables*
             (lambda (module symbol variable result)
               (if (and (variable-bound? variable)
                        (package? (variable-ref variable))
                        (member (package-name (variable-ref variable)) names))
                   (let ((package (variable-ref variable)))
                     (cons (list (module-name module) (package-name package)
                                 (package-version package))
                           result))
                   result))
             '() modules)))
      (test-equal "channel package modules load for discovery" '() load-errors)
      (for-each
       (lambda (entry)
         (let* ((name (cadr entry))
                (matches (filter (lambda (row) (string=? name (cadr row))) rows)))
           (test-equal (string-append name " is discovered exactly once")
             1 (length matches))
           (when (pair? matches)
             (test-equal (string-append name " is attributed to applications")
               '(securityops packages applications) (caar matches)))))
       %expected-applications)))
  (let ((runner (test-runner-current)))
    (test-end "securityops-tools-packages")
    (exit (if (zero? (test-runner-fail-count runner)) 0 1))))

(when (string=? (basename (car (command-line))) "securityops-tools-packages.scm")
  (run-tests))
