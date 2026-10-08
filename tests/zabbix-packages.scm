;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Run: guix repl -L . tests/zabbix-packages.scm
(define-module (tests zabbix-packages))
(use-modules (guix packages) (guix download) (srfi srfi-64)
             ((securityops packages zabbix) #:prefix z:))

(define (run-tests)
  (test-begin "zabbix-packages")
  (for-each
   (lambda (package)
     (test-equal (string-append (package-name package) " stable release")
       "7.4.15" (package-version package))
     (test-equal "all components share verified upstream source"
       (origin-hash (package-source z:zabbix-agentd))
       (origin-hash (package-source package)))
     (test-equal "no inherited replacement" #f
       (package-replacement package)))
   (list z:zabbix-agentd z:zabbix-agent2 z:zabbix-server z:zabbix-proxy
         z:zabbix-java-gateway z:zabbix-web-service))
  (for-each
   (lambda (package)
     (test-equal "command package tracks stable agent" "7.4.15"
       (package-version package))
     (test-eq "command package reuses the native agent build"
       z:zabbix-agentd (lookup-package-input package "zabbix-agentd")))
   (list z:zabbix-get z:zabbix-sender))
  (test-equal "server includes frontend and database schema"
    '("out" "front-end" "schema") (package-outputs z:zabbix-server))
  (test-eq "JavaScript command reuses the native server build"
    z:zabbix-server (lookup-package-input z:zabbix-js "zabbix-server"))
  (let ((runner (test-runner-current)))
    (test-end "zabbix-packages")
    (exit (if (zero? (test-runner-fail-count runner)) 0 1))))

(when (string=? (basename (car (command-line))) "zabbix-packages.scm")
  (run-tests))
