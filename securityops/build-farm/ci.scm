;;; Enumerate every exported package, including variants sharing a package name.
;;; Keep this file at the channel module path so Guix can compile it on pull.
(define-module (securityops build-farm ci)
  #:use-module (gnu ci)
  #:use-module (guix discovery)
  #:use-module (guix packages)
  #:use-module (guix store)
  #:use-module (srfi srfi-1)
  #:use-module (ice-9 format)
  #:export (channel-package-rows cuirass-jobs))

(define (channel-module-root)
  (or (find (lambda (path)
              (file-exists? (string-append path "/securityops/packages")))
            %load-path)
      (error "securityops package modules are absent from the evaluated channel")))

(define (channel-package-rows)
  "Return (OWNER SYMBOL NAME VERSION PACKAGE) for every exported recipe."
  (let* ((root (channel-module-root))
         (modules
          (append
           (all-modules
            (list (cons root "securityops/packages"))
            #:warn (lambda (file name args)
                     (error "cannot load channel package module" file name args)))
           (if (file-exists? (string-append root "/xlibre.scm"))
               (list (resolve-interface '(xlibre)))
               '()))))
    (sort
     (fold-module-public-variables*
      (lambda (module symbol binding result)
        (let ((value (variable-ref binding))
              (name (module-name module)))
          (if (package? value)
              (cons (list (if (eq? (car name) 'securityops)
                              (symbol->string (caddr name))
                              "xlibre")
                          (symbol->string symbol)
                          (package-name value)
                          (package-version value)
                          value)
                    result)
              result)))
      '()
      modules)
     (lambda (left right)
       (string<? (string-append (car left) "." (cadr left))
                 (string-append (car right) "." (cadr right)))))))

(define (cuirass-jobs store arguments)
  "Register supported exports with a stable, collision-free job identity."
  (let ((rows (channel-package-rows))
        (systems (arguments->systems arguments)))
    (append-map
     (lambda (system)
       (map
        (lambda (row)
          (let* ((owner (car row))
                 (symbol (cadr row))
                 (package (list-ref row 4))
                 (job-name (string-append owner "." symbol "." system)))
            (catch #t
              (lambda ()
                (parameterize ((%graft? #f))
                  (derivation->job
                   job-name
                   (package-derivation store package system #:graft? #f)
                   #:max-silent-time
                   (or (assoc-ref (package-properties package) 'max-silent-time)
                       3600)
                   #:timeout
                   (or (assoc-ref (package-properties package) 'timeout)
                       72000))))
              (lambda (key . arguments)
                (format (current-error-port)
                        "SECURITYOPS-JOB-ERROR ~a ~a~%" job-name key)
                (apply throw key arguments)))))
        (filter
         (lambda (row)
           (let ((supported (package-supported-systems (list-ref row 4))))
             (if (member system supported)
                 #t
                 (begin
                   (format (current-error-port)
                           "SECURITYOPS-UNSUPPORTED ~a.~a ~a supported=~s~%"
                           (car row) (cadr row) system supported)
                   #f))))
         rows)))
     systems)))
