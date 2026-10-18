;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Run: guix repl -L . tests/wazuh-services.scm
(define-module (tests wazuh-services)
  )
(use-modules (gnu services)
             (gnu services shepherd)
             (gnu system file-systems)
             (guix gexp)
             (srfi srfi-1)
             (srfi srfi-64)
             (securityops services wazuh))

(define (run-tests)
  (test-begin "wazuh-services")
  (test-assert "mount regression module imports without running its fixture"
    (procedure?
     (module-ref (resolve-interface '(tests wazuh-store-activation))
                 'run-tests)))
  (define config
    (wazuh-agent-configuration))
  (define services
    ((@@ (securityops services wazuh) wazuh-agent-shepherd-services)
     config))
  (define (provided name)
    (find (lambda (service)
            (memq name
                  (shepherd-service-provision service))) services))
  (test-equal "private mutable state default" "/var/lib/wazuh-agent"
              (wazuh-agent-configuration-state-directory config))
  (test-equal "Docker monitoring requires opt in" #f
              (wazuh-agent-configuration-docker-monitoring? config))
  (test-equal "one service owns the complete foreground lifecycle" 1
              (length services))
  (test-assert "daemon has executable start and stop"
               (and (gexp? (shepherd-service-start (provided 'wazuh-agent)))
                    (gexp? (shepherd-service-stop (provided 'wazuh-agent)))))
  (test-assert "agent waits for read-only chroot store"
               (memq 'file-system-/var/lib/wazuh-agent/gnu/store
                     (shepherd-service-requirement (provided 'wazuh-agent))))
  (let ((mount (car ((@@ (securityops services wazuh) wazuh-agent-file-systems)
                     config))))
    (test-equal "bind source is immutable store" "/gnu/store"
                (file-system-device mount))
    (test-equal "bind only enters selected state"
                "/var/lib/wazuh-agent/gnu/store"
                (file-system-mount-point mount))
    (test-assert "bind explicitly read only"
                 (and (memq 'bind-mount
                            (file-system-flags mount))
                      (memq 'read-only
                            (file-system-flags mount)))))
  (for-each (lambda (path)
              (test-error "reject unsafe or ambiguous state path" #t
                          ((@@ (securityops services wazuh)
                               wazuh-agent-shepherd-services)
                           (wazuh-agent-configuration (state-directory path)))))
            '("/" "/gnu/store"
              "/gnu/store/state"
              "relative"
              "/var/../tmp/agent"
              "/var/lib/agent/"
              "/var//lib/agent"
              "/var/lib/agent space"))
  (test-equal "Docker opt in shares agent lifecycle" 1
              (length ((@@ (securityops services wazuh)
                           wazuh-agent-shepherd-services)
                       (wazuh-agent-configuration (docker-monitoring? #t)))))
  (let ((runner (test-runner-current)))
    (test-end "wazuh-services")
    (exit (if (zero? (test-runner-fail-count runner)) 0 1))))

(when (string=? (basename (car (command-line))) "wazuh-services.scm")
  (run-tests))
