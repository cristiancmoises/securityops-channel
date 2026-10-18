;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Build only: guix build -L . -f etc/wazuh-agent-service-files.scm
;;; Runtime files for an additive native installation without a system upgrade.
;;; The operator creates the dedicated account and private configuration before
;;; loading these services.  Nothing is activated by building this bundle.
(define-module (etc wazuh-agent-service-files)
  )
(use-modules (gnu services base)
             (gnu services shepherd)
             (guix gexp)
             (securityops services wazuh))

(define config
  (wazuh-agent-configuration (docker-monitoring? #t)))
(define activate
  (program-file "activate-wazuh-agent"
                ((@@ (securityops services wazuh) wazuh-agent-activation)
                 config)))
(define services
  (append (map (@@ (gnu services base) file-system-shepherd-service)
               ((@@ (securityops services wazuh) wazuh-agent-file-systems)
                config))
          ((@@ (securityops services wazuh) wazuh-agent-shepherd-services)
           config)))
(define shepherd-file
  (scheme-file "wazuh-agent-services.scm"
               #~(begin
                   (use-modules (shepherd service))
                   (register-services (list #$@(map (lambda (service)
                                                      #~(primitive-load #$((@@
                                                                            (gnu
                                                                             services
                                                                             shepherd)
                                                                            shepherd-service-file)
                                                                           service)))
                                                    services))))))
(file-union "wazuh-agent-native-service"
            `(("activate" ,activate)
              ("shepherd.scm" ,shepherd-file)))
