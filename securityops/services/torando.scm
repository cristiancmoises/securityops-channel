;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; This file is part of the securityops channel.
;;;
;;; GNU Guix System runs daemons under the GNU Shepherd, not systemd — so the
;;; systemd unit shipped in the torando-gui package is inert on Guix.  This
;;; module provides a native Shepherd service so the Torando Control daemon
;;; (torando-guid) actually starts on `guix system reconfigure' /
;;; `herd start torando-gui'.
;;;
;;; The daemon is root-equivalent (it programs netfilter, pins resolv.conf and
;;; edits torrc), so the service runs it as root in the foreground; it installs
;;; SIGTERM/SIGINT handlers, so the default kill-destructor stops it cleanly.
;;;
;;; Usage in (operating-system ...):
;;;
;;;   (use-modules (securityops services torando))
;;;   (services (cons* (service torando-gui-service-type)
;;;                    ;; ... your other services (incl. tor-service-type) ...
;;;                    %base-services))
;;;
;;; Then visit http://127.0.0.1:8088/ (or run the `torando-gui' launcher, which
;;; opens it for you).  See README → "Run torando-gui as a Shepherd service".

(define-module (securityops services torando)
  #:use-module (gnu services)
  #:use-module (gnu services shepherd)
  #:use-module (guix gexp)
  #:use-module (guix records)
  #:use-module (securityops packages apps)        ;torando-gui
  #:export (torando-gui-configuration
            torando-gui-configuration?
            torando-gui-configuration-package
            torando-gui-configuration-host
            torando-gui-configuration-port
            torando-gui-configuration-config-file
            torando-gui-configuration-extra-options
            torando-gui-service-type))

(define-record-type* <torando-gui-configuration>
  torando-gui-configuration make-torando-gui-configuration
  torando-gui-configuration?
  ;; The package providing bin/torando-guid (defaults to this channel's).
  (package        torando-gui-configuration-package        (default torando-gui))
  ;; Loopback bind address.  The daemon refuses any non-127.0.0.1 host (it is
  ;; root-equivalent), so changing this is only useful with --mock.
  (host           torando-gui-configuration-host           (default "127.0.0.1"))
  (port           torando-gui-configuration-port           (default 8088))
  ;; Optional path or file-like object passed as --config (a config.json).  On
  ;; Guix System /etc/tor/torrc is a read-only store symlink, so point this at a
  ;; config that disables torrc management — see the README example.
  (config-file    torando-gui-configuration-config-file    (default #f))
  ;; Extra command-line arguments appended verbatim (list of strings).
  (extra-options  torando-gui-configuration-extra-options  (default '())))

(define (torando-gui-shepherd-service config)
  (let* ((package     (torando-gui-configuration-package config))
         (host        (torando-gui-configuration-host config))
         (port        (torando-gui-configuration-port config))
         (config-file (torando-gui-configuration-config-file config))
         (extra       (torando-gui-configuration-extra-options config))
         (args        (append (list "--host" host
                                    "--port" (number->string port))
                              (if config-file (list "--config" config-file) '())
                              extra)))
    (list
     (shepherd-service
      (documentation "Torando Control: route a local user's egress through Tor \
(transparent proxy + killswitch).")
      (provision '(torando-gui))
      ;; Needs the network up; it binds loopback and programs netfilter.  Enable
      ;; tor-service-type separately — the daemon talks to Tor over the network.
      (requirement '(networking))
      (start #~(make-forkexec-constructor
                (cons #$(file-append package "/bin/torando-guid")
                      (list #$@args))
                #:log-file "/var/log/torando-gui.log"))
      (stop #~(make-kill-destructor))
      (respawn? #t)))))

(define torando-gui-service-type
  (service-type
   (name 'torando-gui)
   (extensions
    (list (service-extension shepherd-root-service-type
                             torando-gui-shepherd-service)
          ;; Put torando-gui / torando-guid on the global PATH.
          (service-extension profile-service-type
                             (lambda (config)
                               (list (torando-gui-configuration-package config))))))
   (default-value (torando-gui-configuration))
   (description "Run the Torando Control daemon (@command{torando-guid}) under
the Shepherd: a loopback web GUI and root daemon that forces one local user's
egress through Tor's TransPort/DNSPort and drops everything else (a killswitch).
Installs the @code{torando-gui} package into the system profile.")))
