;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Run: guix repl -q -L . tests/securityops-tools-packages.scm
(define-module (tests securityops-tools-packages))
(use-modules (guix discovery) (guix packages) (guix utils)
             (ice-9 match) (srfi srfi-1) (srfi srfi-64))

(define %expected-projects
  '((evelin evelin-bin "evelin-bin" "4.4.0" applications)
    (btp btp "btp" "0.7" applications)
    (mirim mirim "mirim" "1.1.1" applications)
    (torando-gui torando-gui "torando-gui" "1.4.1" applications)
    (zupt zupt "zupt" "5.2.9" applications)
    (zupt zupt-gui "zupt-gui" "5.2.9" applications)
    (turborec turborec "turborec" "3.10.4" applications)
    (turborec turborec-nvidia-new-feature "turborec-nvidia-new-feature" "3.10.4" applications)
    (moneyprinterturbo moneyprinterturbo "moneyprinterturbo" "1.3.7" applications)
    (guixvis guixvis "guixvis" "0.10.0" applications)
    (whatsappel whatsappel "whatsappel" "3.3.1" applications)
    (esquema esquema "esquema" "0.3.0" containers)
    (xmonad-wayland xmonad-wayland "xmonad-wayland" "0.5.0" #f)))

(define (run-tests)
  (define root
    (canonicalize-path (string-append (dirname (car (command-line))) "/..")))
  (test-begin "securityops-tools-packages")
  ;; Resolve projects before compatibility aggregates. Missing modules should
  ;; fail assertions rather than terminate the script with a load exception.
  (for-each
   (lambda (entry)
     (match entry
       ((owner symbol name version compatibility)
        (let* ((source (string-append "securityops/packages/"
                                      (symbol->string owner) ".scm"))
               (exists? (file-exists? (string-append root "/" source)))
               (interface (and exists?
                               (false-if-exception
                                (resolve-interface `(securityops packages ,owner)))))
               (binding (and interface (module-variable interface symbol))))
          (test-assert (string-append name " has its own module source") exists?)
          (test-assert (string-append name " loads directly as a public package")
            (and binding (variable-bound? binding)
                 (package? (variable-ref binding))))
          (when (and binding (variable-bound? binding)
                     (package? (variable-ref binding)))
            (let* ((package (variable-ref binding))
                   (location (package-definition-location package)))
              (test-equal (string-append name " preserves its name and release")
                (list name version)
                (list (package-name package) (package-version package)))
              (test-equal (string-append name " is defined in its project module")
                source (and location (location-file location)))))))))
   %expected-projects)
  (for-each
   (lambda (module-name)
     (test-assert (string-append (symbol->string (caddr module-name))
                                " is not needed to load project modules")
       (not (resolve-module module-name #f #:ensure #f))))
   '((securityops packages applications) (securityops packages apps)))
  (for-each
   (lambda (entry)
     (match entry
       ((owner symbol name version compatibility)
        (when compatibility
          (let* ((interface
                  (false-if-exception
                   (resolve-interface `(securityops packages ,owner))))
                 (binding (and interface (module-variable interface symbol)))
                 (legacy (resolve-interface `(securityops packages ,compatibility)))
                 (legacy-binding (module-variable legacy symbol)))
            (when (and binding (variable-bound? binding))
              (test-eq (string-append name " preserves its compatibility variable")
                binding legacy-binding)
              (test-assert (string-append name " preserves its compatibility package")
                (and legacy-binding (variable-bound? legacy-binding)
                     (eq? (variable-ref binding) (variable-ref legacy-binding))))
              (when (eq? compatibility 'applications)
                (test-eq (string-append name " preserves its original apps variable")
                  binding (module-variable
                           (resolve-interface '(securityops packages apps))
                           symbol)))))))))
   %expected-projects)
  (let* ((load-errors '())
         ;; Use the real Guix/Toys helpers. A compatibility export may be visited
         ;; first, while the package location must still record its own source.
         (modules
          (scheme-modules root "securityops/packages"
                          #:warn (lambda (file module args)
                                   (set! load-errors
                                         (cons (list file module args)
                                               load-errors)))))
         (names (map caddr %expected-projects))
         (rows
          (fold-module-public-variables*
           (lambda (module symbol variable result)
             (if (and (variable-bound? variable)
                      (package? (variable-ref variable))
                      (member (package-name (variable-ref variable)) names))
                 (cons (variable-ref variable) result)
                 result))
           '() modules)))
    (test-equal "channel package modules load for discovery" '() load-errors)
    (for-each
     (lambda (entry)
       (match entry
         ((owner symbol name version compatibility)
          (let ((matches (filter (lambda (package)
                                   (string=? name (package-name package))) rows)))
            (test-equal (string-append name " is discovered exactly once")
              1 (length matches))
            (when (pair? matches)
              (let ((location (package-definition-location (car matches))))
                (test-equal (string-append name " discovery retains its defining source")
                  (string-append "securityops/packages/"
                                 (symbol->string owner) ".scm")
                  (and location (location-file location)))))))))
     %expected-projects))
  (let ((runner (test-runner-current)))
    (test-end "securityops-tools-packages")
    (exit (if (zero? (test-runner-fail-count runner)) 0 1))))

(when (string=? (basename (car (command-line))) "securityops-tools-packages.scm")
  (run-tests))
