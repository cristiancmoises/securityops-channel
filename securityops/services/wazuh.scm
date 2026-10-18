;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>

(define-module (securityops services wazuh)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (gnu services shepherd)
  #:use-module (gnu system file-systems)
  #:use-module (gnu system shadow)
  #:use-module (gnu packages admin)
  #:use-module (guix gexp)
  #:use-module (guix modules)
  #:use-module (guix records)
  #:use-module (ice-9 regex)
  #:use-module (srfi srfi-1)
  #:use-module (securityops packages wazuh)
  #:export (wazuh-agent-configuration wazuh-agent-configuration?
            wazuh-agent-configuration-package
            wazuh-agent-configuration-state-directory
            wazuh-agent-configuration-docker-monitoring?
            wazuh-agent-service-type))

(define-record-type* <wazuh-agent-configuration> wazuh-agent-configuration
                     make-wazuh-agent-configuration
  wazuh-agent-configuration?
  (package
    wazuh-agent-configuration-package
    (default wazuh-agent))
  (state-directory wazuh-agent-configuration-state-directory
                   (default "/var/lib/wazuh-agent"))
  (docker-monitoring? wazuh-agent-configuration-docker-monitoring?
                      (default #f)))

(define (state-directory config)
  (let ((path (wazuh-agent-configuration-state-directory config)))
    (unless (and (string? path)
                 (string-match
                  "^/([A-Za-z0-9_-][A-Za-z0-9_.-]*/)*[A-Za-z0-9_-][A-Za-z0-9_.-]*$"
                  path)
                 (not (or (string=? path "/gnu/store")
                          (string-prefix? "/gnu/store/" path))))
      (error
       "Wazuh state must be an absolute canonical path outside the store" path))
    path))

(define (aux-file name)
  (local-file (canonicalize-path (search-path %load-path
                                              (string-append
                                               "securityops/services/aux-files/"
                                               name)))))

(define (wazuh-agent-file-systems config)
  (list (file-system
          (device "/gnu/store")
          (mount-point (string-append (state-directory config) "/gnu/store"))
          (type "none")
          (flags '(bind-mount read-only))
          (check? #f)
          (create-mount-point? #t))))

(define (wazuh-agent-accounts config)
  (list (user-group
          (name "wazuh")
          (system? #t))
        (user-account
          (name "wazuh")
          (group "wazuh")
          (system? #t)
          (comment "Wazuh privilege-separated endpoint")
          (home-directory (state-directory config))
          (create-home-directory? #f)
          (shell (file-append shadow "/sbin/nologin")))))

(define (wazuh-agent-activation config)
  (let ((state (state-directory config))
        (package
          (wazuh-agent-configuration-package config)))
    (with-imported-modules (source-module-closure
                            '((guix build utils)
                              (securityops services wazuh-activation))
                            ;; The default selector excludes channel modules.
                            #:select? (lambda (module)
                                        (or (guix-module-name? module)
                                            (equal? module
                                                    '(securityops services
                                                      wazuh-activation)))))
                           #~(begin
                               (use-modules (guix build utils)
                                            (securityops services
                                                         wazuh-activation)
                                            (ice-9 ftw))
                               (let* ((state #$state)
                                      (uid (passwd:uid (getpwnam "wazuh")))
                                      (gid (group:gid (getgrnam "wazuh"))))
                                 (define (directory path owner)
                                   (unless (file-exists? path)
                                     (mkdir path #o750)
                                     (chown path owner gid))
                                   (let ((descriptor (open-fdes path
                                                      (logior O_RDONLY
                                                              O_DIRECTORY
                                                              O_NOFOLLOW))))
                                     (dynamic-wind
                                       (lambda () #t)
                                       (lambda ()
                                         (let ((metadata (stat descriptor)))
                                           (unless (and (eq? 'directory
                                                             (stat:type metadata))
                                                        (= owner
                                                           (stat:uid metadata))
                                                        (= gid
                                                           (stat:gid metadata))
                                                        (zero? (logand #x12
                                                                       (stat:perms
                                                                        metadata))))
                                             (error
                                              "Unsafe existing Wazuh directory" path))
                                           ;; mkdir is filtered by the caller's umask.
                                           ;; Also repair only validated existing state.
                                           (chmod descriptor #o750)))
                                       (lambda () (close-fdes descriptor)))))
                                 (define (code-link target path)
                                   (when (file-exists? path)
                                     (let ((metadata (lstat path)))
                                       (unless (and (eq? 'symlink
                                                         (stat:type metadata))
                                                    (zero? (stat:uid metadata))
                                                    (string-prefix?
                                                     "/gnu/store/"
                                                     (readlink path)))
                                         (error
                                          "Refusing to replace non-store Wazuh code"
                                          path)))
                                     (delete-file path))
                                   (symlink target path))
                                 (define (protect-template path)
                                   (let ((metadata (lstat path)))
                                     (chown path 0 gid)
                                     (case (stat:type metadata)
                                       ((directory)
                                        (chmod path #o750)
                                        (for-each (lambda (name)
                                                    (unless (member name
                                                                    '("." ".."))
                                                      (protect-template (string-append
                                                                         path
                                                                         "/"
                                                                         name))))
                                                  (scandir path)))
                                       ((regular)
                                        (chmod path #o640))
                                       (else (error
                                              "Unexpected template file type"
                                              path)))))
                                 ;; Validate existing ancestors before mkdir or file replacement.
                                 (let loop
                                   ((parent (dirname state)))
                                   (let ((metadata (lstat parent)))
                                     (unless (and (eq? 'directory
                                                       (stat:type metadata))
                                                  (zero? (stat:uid metadata))
                                                  (zero? (logand #x12
                                                                 (stat:perms
                                                                  metadata))))
                                       (error "Unsafe Wazuh parent directory"
                                              parent)))
                                   (unless (string=? parent "/")
                                     (loop (dirname parent))))
                                 (directory state 0)
                                 (let* ((etc (string-append state "/etc"))
                                        (fresh? (not (file-exists? etc))))
                                   (when fresh?
                                     (copy-recursively #$(file-append package
                                                          "/share/wazuh/etc")
                                                       etc)
                                     (protect-template etc))
                                   (directory etc 0)
                                   ;; Only shared agent data is writable by the daemon account.
                                   (let ((shared (string-append etc "/shared")))
                                     (when (and (file-exists? shared)
                                                (eq? 'directory
                                                     (stat:type (lstat shared)))
                                                (zero? (stat:uid (lstat shared))))
                                       (chown shared uid gid))
                                     (directory shared uid))
                                   (let ((keys (string-append etc
                                                              "/client.keys")))
                                     (unless (file-exists? keys)
                                       (call-with-output-file keys
                                         (lambda (port)
                                           #t))
                                       (chown keys uid gid)
                                       (chmod keys #o640)))
                                   (let ((options (string-append etc
                                                   "/local_internal_options.conf")))
                                     (when (or fresh?
                                               (not (file-exists? options)))
                                       (call-with-output-file options
                                         (lambda (port)
                                           (display
                                            "agent.remote_conf=0
logcollector.remote_commands=0
wazuh_command.remote_commands=0
sca.remote_commands=0
"
                                            port)))
                                       (chown options 0 gid)
                                       (chmod options #o640))))
                                 (for-each (lambda (relative)
                                             (directory (string-append state
                                                         "/" relative) uid))
                                           '("logs" "logs/alerts"
                                             "logs/archives"
                                             "logs/firewall"
                                             "queue"
                                             "queue/sockets"
                                             "queue/alerts"
                                             "queue/rids"
                                             "queue/fts"
                                             "queue/db"
                                             "queue/tasks"
                                             "queue/agent-info"
                                             "queue/syscollector"
                                             "queue/syscollector/db"
                                             "queue/fim"
                                             "queue/fim/db"
                                             "queue/logcollector"
                                             "queue/diff"
                                             "queue/keystore"
                                             "var"
                                             "var/run"
                                             "var/run/active-response"
                                             "var/active-response"
                                             "var/db"
                                             "var/incoming"
                                             "var/upgrade"
                                             "stats"
                                             "tmp"))
                                 (let ((log (string-append state
                                                           "/logs/ossec.log")))
                                   (unless (file-exists? log)
                                     (call-with-output-file log
                                       (lambda (port)
                                         #t))
                                     (chown log uid gid)
                                     (chmod log #o640)))
                                 (let ((norm (string-append state
                                              "/queue/syscollector/norm_config.json")))
                                   (unless (file-exists? norm)
                                     (copy-file #$(file-append package
                                                   "/share/wazuh/queue/syscollector/norm_config.json")
                                                norm)
                                     (chown norm 0 gid)
                                     (chmod norm #o640)))
                                 (for-each (lambda (relative)
                                             (directory (string-append state
                                                         "/" relative) 0))
                                           '("active-response" "gnu"))
                                 (ensure-wazuh-store-directory (string-append
                                                                state
                                                                "/gnu/store")
                                                               gid)
                                 (code-link #$(file-append package "/bin")
                                            (string-append state "/bin"))
                                 (code-link #$(file-append package "/lib")
                                            (string-append state "/lib"))
                                 (code-link #$(file-append package
                                               "/share/wazuh/ruleset")
                                            (string-append state "/ruleset"))
                                 (code-link #$(file-append package
                                               "/libexec/wazuh/wodles")
                                            (string-append state "/wodles"))
                                 (code-link #$(file-append package
                                               "/libexec/wazuh/active-response/bin")
                                            (string-append state
                                             "/active-response/bin")))))))

(define (wazuh-agent-shepherd-services config)
  (let* ((state (state-directory config))
         (package
           (wazuh-agent-configuration-package config))
         (store-service (string->symbol (string-append "file-system-" state
                                                       "/gnu/store"))))
    (list (shepherd-service (documentation
                             "Run the native Wazuh endpoint; restart reloads all daemon configuration.")
                            (provision '(wazuh-agent))
                            (requirement (list 'networking
                                               'user-processes store-service))
                            (start #~(make-forkexec-constructor (list #$(file-append
                                                                         package
                                                                         "/libexec/wazuh/python/bin/python3")
                                                                      "-I"
                                                                      "-B"
                                                                      #$(aux-file
                                                                         "wazuh-agent-supervisor.py")
                                                                      #$package
                                                                      #$state
                                                                      #$@(if (wazuh-agent-configuration-docker-monitoring?
                                                                              config)
                                                                             (list
                                                                              (aux-file
                                                                               "wazuh-docker-events.py"))
                                                                             '()))
                                                                #:directory #$state
                                                                #:environment-variables
                                                                (list
                                                                 "LC_ALL=C")
                                                                #:log-file #$(string-append
                                                                              state
                                                                              "/logs/shepherd.log")))
                            (stop #~(make-kill-destructor SIGTERM
                                                          #:grace-period 25))
                            (respawn? #t)))))

(define wazuh-agent-service-type
  (service-type (name 'wazuh-agent)
                (extensions (list (service-extension account-service-type
                                                     wazuh-agent-accounts)
                                  (service-extension activation-service-type
                                                     wazuh-agent-activation)
                                  (service-extension file-system-service-type
                                                     wazuh-agent-file-systems)
                                  (service-extension
                                   shepherd-root-service-type
                                   wazuh-agent-shepherd-services)))
                (default-value (wazuh-agent-configuration))
                (description
                 "Supervise a native Wazuh endpoint with private mutable state,
an immutable store bind mount, and optional filtered local Docker events.
Provision ossec.conf, enrollment CA and credentials outside the store before
starting.  Reload configuration with @command{herd restart wazuh-agent}.")))
