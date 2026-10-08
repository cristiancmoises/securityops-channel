;;; SPDX-License-Identifier: GPL-3.0-or-later
(define-module (securityops packages electronics)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module ((gnu packages electronics) #:prefix upstream:))

(define ngspice-source
  (origin
    (method url-fetch)
    (uri "https://downloads.sourceforge.net/project/ngspice/ng-spice-rework/47/ngspice-47.tar.gz")
    (sha256
     (base32 "0pv7xz6lzniz2y1x456ygvl67ankwwwm8njy14a8m0zia6b68kl9"))))

(define-public libngspice
  (package
    (inherit upstream:libngspice)
    (version "47")
    (source ngspice-source)
    (replacement #f)
    (arguments
     (substitute-keyword-arguments (package-arguments upstream:libngspice)
       ;; Upstream has no shared-library make check target.  Test the installed
       ;; header, linker interface and numerical result after installation.
       ((#:phases phases)
        #~(modify-phases #$phases
            (add-after 'install 'check-installed-library
              (lambda _
                (invoke "gcc" "-std=c11" "-Wall" "-Wextra" "-Werror"
                        #$(local-file "../../tests/ngspice-shared.c")
                        (string-append "-I" #$output "/include")
                        (string-append "-L" #$output "/lib")
                        (string-append "-Wl,-rpath," #$output "/lib")
                        "-lngspice" "-lm" "-o" "ngspice-shared-check")
                (invoke "./ngspice-shared-check")))))))))

(define-public ngspice
  (package
    (inherit upstream:ngspice)
    (version "47")
    (source ngspice-source)
    (replacement #f)
    (inputs
     (modify-inputs (package-inputs upstream:ngspice)
       (replace "libngspice" libngspice)))
    (arguments
     (substitute-keyword-arguments (package-arguments upstream:ngspice)
       ;; The full upstream suite includes graphical cases.  These installed
       ;; headless acceptance checks do not need a display server.
       ((#:phases phases)
        #~(modify-phases #$phases
            (add-after 'install 'check-installed-simulator
              (lambda _
                (use-modules (ice-9 textual-ports) (ice-9 rdelim)
                             (srfi srfi-1) (srfi srfi-13))
                (define (numeric-rows file columns)
                  (call-with-input-file file
                    (lambda (port)
                      (let loop ((rows '()))
                        (let ((line (read-line port)))
                          (if (eof-object? line)
                              (reverse rows)
                              (let ((row (map string->number
                                              (string-tokenize line))))
                                (unless
                                    (and (= (length row) columns)
                                         (every (lambda (x)
                                                  (and (real? x) (= x x)
                                                       (< (abs x) +inf.0)))
                                                row))
                                  (error "Invalid ngspice numerical output" file))
                                (loop (cons row rows)))))))))
                (define (check-circuit file marker)
                  (call-with-output-file "ngspice-acceptance.log"
                    (lambda (port)
                      (parameterize ((current-output-port port)
                                     (current-error-port port))
                        (invoke (string-append #$output "/bin/ngspice")
                                "-b" file))))
                  (let ((log (call-with-input-file "ngspice-acceptance.log"
                               get-string-all)))
                    (display log)
                    (when (or (string-contains-ci log "error:")
                              (string-contains-ci log "error on line"))
                      (throw 'ngspice-interpreter-error file))
                    (unless (string-contains log marker)
                      (error "Missing ngspice acceptance result" marker))))
                (check-circuit
                 #$(local-file "../../tests/fixtures/ngspice/divider.cir")
                 "SECURITYOPS_DIVIDER_PASS")
                (let ((rows (numeric-rows "ngspice-divider.dat" 3)))
                  (unless (= (length rows) 11)
                    (error "Incomplete DC sweep"))
                  (for-each
                   (lambda (row index)
                     (unless (and (< (abs (- (car row) index)) 1e-9)
                                  (< (abs (- (cadr row) index)) 1e-9)
                                  (< (abs (- (caddr row) (/ index 2.0))) 1e-9))
                       (error "Incorrect divider sample" row)))
                   rows (iota 11)))
                (check-circuit
                 #$(local-file "../../tests/fixtures/ngspice/rc.cir")
                 "SECURITYOPS_RC_PASS")
                (let ((rows (numeric-rows "ngspice-rc.dat" 2)))
                  (unless (and (>= (length rows) 5000)
                               (< (abs (- (car (last rows)) 0.005)) 1e-9))
                    (error "Incomplete RC transient"))
                  (for-each
                   (lambda (row)
                     (unless (< (abs (- (cadr row)
                                        (* 5 (- 1 (exp (/ (- (car row)) 0.001))))))
                                1e-4)
                       (error "Incorrect RC transient sample" row)))
                   rows))
                (check-circuit "tests/regression/misc/resume-1.cir"
                               "INFO: success")
                ;; ngspice can exit zero after interpreter errors.  Prove that
                ;; the checker rejects a PASS marker from an invalid analysis.
                (unless
                    (catch 'ngspice-interpreter-error
                      (lambda ()
                        (check-circuit
                         #$(local-file "../../tests/fixtures/ngspice/invalid.cir")
                         "SECURITYOPS_INVALID_PASS")
                        #f)
                      (lambda _ #t))
                  (error "Invalid circuit was accepted"))))))))))
