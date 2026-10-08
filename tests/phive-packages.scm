;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Run: guix repl -L . tests/phive-packages.scm
(define-module (tests phive-packages))
(use-modules (guix packages) (guix build-system trivial) (srfi srfi-1)
             (srfi srfi-64) ((guix licenses) #:prefix license:)
             (securityops packages phive))

(define (run-tests)
  (test-begin "phive-packages")
  (test-equal "stable Java library" "12.2.0" (package-version phive))
  (test-eq "original artifact adaptation" trivial-build-system
    (package-build-system phive))
  (test-equal "test libraries are a separate output" '("out" "tests")
    (package-outputs phive))
  (test-equal "complete runtime including JAXB provider" 50
    (length (@@ (securityops packages phive) %runtime-artifacts)))
  (test-equal "only five extra test libraries" 5
    (length (@@ (securityops packages phive) %test-artifacts)))
  (test-equal "eight PHIVE framework modules" 8
    (count (lambda (entry) (string=? (car entry) "com.helger.phive"))
      (@@ (securityops packages phive) %runtime-artifacts)))
  (test-assert "reference JAXB implementation retained"
    (find (lambda (entry) (string=? (cadr entry) "jaxb-impl"))
      (@@ (securityops packages phive) %runtime-artifacts)))
  (test-assert "classifier artifacts retain the identical shared GAV POM"
    (let ((records (@@ (securityops packages phive) %runtime-artifacts)))
      (every
       (lambda (entry)
         (every (lambda (other)
                  (or (not (equal? (take entry 3) (take other 3)))
                      (string=? (list-ref entry 5) (list-ref other 5))))
                records))
       records)))
  (test-equal "no implicit test/runtime profile propagation" '()
    (package-propagated-inputs phive))
  (test-equal "runtime architecture matches the selected JRE"
    '("x86_64-linux") (package-supported-systems phive))
  (test-assert "exact W3C Software and Document metadata"
    (find (lambda (item)
            (string=? (license:license-name item)
                      "W3C Software and Document License"))
      (package-license phive)))
  (test-assert "Saxon corresponding-source license"
    (memq license:mpl2.0 (package-license phive)))
  (test-assert "JAXB and activation provider license"
    (memq license:edl1.0 (package-license phive)))
  (let ((runner (test-runner-current)))
    (test-end "phive-packages")
    (exit (if (zero? (test-runner-fail-count runner)) 0 1))))

(when (string=? (basename (car (command-line))) "phive-packages.scm")
  (run-tests))
