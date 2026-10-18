;; Evaluated by Guix's root-run offload hook on predator-helios-intel.
;; This is a private LAN builder, not the public CT116 substitute server.
(define-module (etc build-farm offload machines-ct126))
(use-modules (guix scripts offload))

(list
 (build-machine
  (name (or (getenv "SECURITYOPS_CT126_HOST") "ct126.invalid"))
  (systems (list "x86_64-linux"))
  (host-key "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKKlL9GeWPmhnbLjNQWTt5b4gKxke2bA5dcAuv6JMGmx root@guix-builder")
  (user "guix-offload")
  (private-key "/root/.ssh/securityops-guix-offload-ct126")
  ;; LXC reports the Proxmox host's load average, not CT126's own workload.
  (overload-threshold #f)
  (parallel-builds 1)))
