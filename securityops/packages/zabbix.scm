;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>

(define-module (securityops packages zabbix)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix utils)
  #:use-module (guix gexp)
  #:use-module (guix build-system trivial)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module ((gnu packages monitoring) #:prefix upstream:)
  #:use-module (gnu packages java)
  #:use-module ((securityops packages browsers) #:prefix browsers:)
  #:use-module (gnu packages sqlite))

(define %zabbix-version "7.4.15")
(define %zabbix-report-browser browsers:google-chrome-stable)
(define %zabbix-source
  (origin
    (inherit (package-source upstream:zabbix-agentd))
    (uri (string-append "https://cdn.zabbix.com/zabbix/sources/stable/7.4/"
                        "zabbix-" %zabbix-version ".tar.gz"))
    (sha256
     (base32 "157k4ix8j66xl88sv50k1167ygwvxw0cxn32blfviygb8wvrn7ay"))))

(define-public zabbix-agentd
  (package
    (inherit upstream:zabbix-agentd)
    (version %zabbix-version)
    (source %zabbix-source)
    (replacement #f)))

(define-public zabbix-agent2
  (package
    (inherit upstream:zabbix-agent2)
    (version %zabbix-version)
    (source
     (origin
       (inherit %zabbix-source)
       (patches (origin-patches (package-source upstream:zabbix-agent2)))))
    (replacement #f)))

(define-public zabbix-java-gateway
  (package
    (inherit zabbix-agentd)
    (name "zabbix-java-gateway")
    (arguments
     (list #:configure-flags #~(list "--enable-java")
           #:phases
           #~(modify-phases %standard-phases
               (add-after 'install 'install-foreground-command
                 (lambda* (#:key inputs #:allow-other-keys)
                   (let* ((directory (string-append #$output "/sbin/zabbix_java"))
                          (command (string-append #$output "/bin/zabbix-java-gateway")))
                     (mkdir-p (dirname command))
                     (call-with-output-file command
                       (lambda (port)
                         (format port "#!~a~%exec ~a -Dlogback.configurationFile=~a/lib/logback-console.xml -cp '~a/bin/*:~a/lib/*' com.zabbix.gateway.JavaGateway \"$@\"~%"
                                 (which "sh") (search-input-file inputs "bin/java")
                                 directory directory directory)))
                     (chmod command #o555)))))))
    ;; The pinned official source includes the five required runtime jars.
    ;; Their current logback classes require Java 11 or newer.
    (native-inputs (list (list openjdk "jdk")))
    (inputs (list openjdk))
    ;; Preserve the bundled libraries' licenses; select LGPL-2.1 from
    ;; Logback 1.5.25's EPL-1.0-or-LGPL-2.1 dual license.
    (license (list (package-license zabbix-agentd) license:asl2.0
                   license:expat license:bsd-3 license:lgpl2.1))
    (synopsis "Zabbix Java management gateway")
    (description "Zabbix Java Gateway retrieves JMX values for a Zabbix
server or proxy.  The foreground command logs to the console and uses Java's
standard JAVA_TOOL_OPTIONS mechanism for explicit zabbix.* configuration
properties; the upstream startup scripts and example settings are also included.")))

(define-public zabbix-web-service
  (package
    (inherit zabbix-agent2)
    (name "zabbix-web-service")
    (arguments
     (substitute-keyword-arguments (package-arguments zabbix-agent2)
       ((#:configure-flags flags)
        ;; Configure the agent's C/TLS support too: the bundled full Go test
        ;; suite covers those packages even when only web service is requested.
        #~(cons "--enable-webservice" #$flags))
       ((#:phases phases)
        #~(modify-phases #$phases
            (add-after 'unpack 'preserve-chrome-sandbox
              (lambda _
                ;; chromedp otherwise silently adds --no-sandbox for UID 0.
                ;; Root execution must fail closed, not weaken isolation.
                (invoke "patch" "--batch" "-p1" "-i"
                        #$(plain-file "zabbix-chromedp-sandbox.patch"
"--- a/src/go/vendor/github.com/chromedp/chromedp/allocate.go
+++ b/src/go/vendor/github.com/chromedp/chromedp/allocate.go
@@ -160,6 +160,0 @@
-\tif _, ok := a.initFlags[\"no-sandbox\"]; !ok && os.Getuid() == 0 {
-\t\t// Running as root, for example in a Linux container. Chrome
-\t\t// needs --no-sandbox when running as root, so make that the
-\t\t// default, unless the user set Flag(\"no-sandbox\", false).
-\t\targs = append(args, \"--no-sandbox\")
-\t}
"))))
            (add-after 'install 'wrap-browser
              (lambda _
                (delete-file (string-append #$output "/sbin/zabbix_agent2"))
                (delete-file (string-append #$output "/etc/zabbix_agent2.conf"))
                (delete-file-recursively
                 (string-append #$output "/etc/zabbix_agent2.d"))
                ;; Resolve the supported Chrome implementation from the store,
                ;; not an ambient browser.  Keep its sandbox and TLS checks.
                (wrap-program (string-append #$output "/sbin/zabbix_web_service")
                  `("PATH" =
                    (,(string-append #$%zabbix-report-browser "/bin"))))))))))
    (inputs
     (modify-inputs (package-inputs zabbix-agent2)
       (append browsers:google-chrome-stable)))
    (supported-systems (package-supported-systems %zabbix-report-browser))
    (synopsis "Zabbix scheduled PDF report service")
    (description "Zabbix web service renders scheduled dashboard reports to
PDF using Google Chrome.  It requires explicit configuration and must only be
reachable by the intended Zabbix server.  Run it as a dedicated non-root account
to preserve Chrome's sandbox; this package does not start services.")))

(define-public zabbix-server
  (package
    (inherit upstream:zabbix-server)
    (version %zabbix-version)
    (source %zabbix-source)
    (replacement #f)
    (arguments
     (substitute-keyword-arguments (package-arguments upstream:zabbix-server)
       ((#:phases phases)
        #~(modify-phases #$phases
            (replace 'install-front-end
              (lambda* (#:key outputs #:allow-other-keys)
                (let* ((php (string-append (assoc-ref outputs "front-end")
                                           "/share/zabbix/php"))
                       (conf (string-append php "/conf")))
                  (mkdir-p php)
                  (copy-recursively "ui" php)
                  (rename-file conf (string-append conf "-example"))
                  (mkdir-p conf)
                  ;; Setup also needs this immutable file before a database
                  ;; configuration exists.  Do not redirect the entire conf
                  ;; directory to an uninitialized /etc/zabbix.
                  (symlink "../conf-example/maintenance.inc.php"
                           (string-append conf "/maintenance.inc.php"))
                  (symlink "/etc/zabbix/zabbix.conf.php"
                           (string-append conf "/zabbix.conf.php"))
                  (symlink "/etc/zabbix/certs"
                           (string-append conf "/certs")))))))))))

;; Keep the PostgreSQL server, PHP frontend and schemas provided by Guix.
;; The SQLite proxy is independently configurable and needs no database server.
(define-public zabbix-proxy
  (package
    (inherit zabbix-server)
    (name "zabbix-proxy")
    (outputs '("out" "schema"))
    (arguments
     (substitute-keyword-arguments (package-arguments zabbix-server)
       ((#:configure-flags flags)
        #~(cons* "--enable-proxy" "--with-sqlite3"
                 (delete "--enable-server"
                         (delete "--with-postgresql" #$flags))))
       ((#:phases phases)
        #~(modify-phases #$phases
            (delete 'install-front-end)))))
    (inputs
     (modify-inputs (package-inputs zabbix-server)
       (delete "postgresql")
       (append sqlite)))
    (synopsis "Distributed monitoring solution (SQLite proxy)")
    (description "Zabbix proxy collects monitoring data on behalf of a
Zabbix server and buffers it in a local SQLite database.  This package also
provides the database schemas for explicit initialization.")))

;; The agent build provides both command tools; small outputs reuse its
;; executables without another compilation or installing the daemon command.
(define-public zabbix-get
  (package
    (inherit zabbix-agentd)
    (name "zabbix-get")
    (source #f)
    (build-system trivial-build-system)
    (arguments
     (list #:builder
           #~(begin
               (mkdir #$output)
               (mkdir (string-append #$output "/bin"))
               (symlink #$(file-append zabbix-agentd "/bin/zabbix_get")
                        (string-append #$output "/bin/zabbix_get")))))
    (native-inputs '())
    (inputs (list zabbix-agentd))
    (synopsis "Query values from a Zabbix agent")
    (description "Zabbix get queries a configured agent for a monitoring
item value.  This package exposes the native agent build's query command.")))

(define-public zabbix-sender
  (package
    (inherit zabbix-get)
    (name "zabbix-sender")
    (arguments
     (list #:builder
           #~(begin
               (mkdir #$output)
               (mkdir (string-append #$output "/bin"))
               (symlink #$(file-append zabbix-agentd "/bin/zabbix_sender")
                        (string-append #$output "/bin/zabbix_sender")))))
    (synopsis "Send monitoring data to a Zabbix server")
    (description "Zabbix sender submits monitoring item values to a configured
Zabbix server or proxy.  This package exposes the native sender command.")))

(define-public zabbix-js
  (package
    (inherit zabbix-get)
    (name "zabbix-js")
    (arguments
     (list #:builder
           #~(begin
               (mkdir #$output)
               (mkdir (string-append #$output "/bin"))
               (symlink #$(file-append zabbix-server "/bin/zabbix_js")
                        (string-append #$output "/bin/zabbix_js")))))
    (inputs (list zabbix-server))
    (synopsis "Execute Zabbix JavaScript item scripts")
    (description "Zabbix JavaScript command executes a local script with
an explicit input value using the same engine as the native Zabbix server.")))
