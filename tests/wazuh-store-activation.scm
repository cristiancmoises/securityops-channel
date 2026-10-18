;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Run: unshare --user --map-root-user --mount --fork \
;;;        guix repl -L . tests/wazuh-store-activation.scm "$(readlink /proc/self/ns/mnt)"
;;; Uses only private namespace mounts; never activates Wazuh or mounts on host.
(define-module (tests wazuh-store-activation)
  #:export (run-tests))

(use-modules (guix build syscalls)
             (guix build utils)
             (ice-9 ftw)
             (securityops services wazuh-activation)
             (srfi srfi-64))

(define (run-tests)
  (unless (and (zero? (getuid))
               (= 2
                  (length (command-line)))
               (not (zero? (stat:uid (stat "/gnu/store"))))
               (not (equal? (readlink "/proc/self/ns/mnt")
                            (cadr (command-line)))))
    (error "Run only inside a private user and mount namespace"))

  (define temporary
    (mkdtemp "/tmp/wazuh-store-activation-XXXXXX"))
  (define destination
    (string-append temporary "/store"))
  (define other
    (string-append temporary "/other"))
  (define mounted?
    #f)
  (define source-covered?
    #f)
  (define result
    1)
  (define (bind source read-only?)
    (mount source destination "none" MS_BIND)
    (set! mounted? #t)
    (when read-only?
      (mount source destination "none"
             (logior MS_BIND MS_REMOUNT MS_RDONLY
                     (statfs-flags->mount-flags (file-system-mount-flags (statfs
                                                                          destination)))))))
  (define (unmount)
    (when mounted?
      (umount destination)
      (set! mounted? #f)))

  (dynamic-wind (lambda ()
                  (mount #f "/" #f
			 (logior MS_REC MS_PRIVATE))
                  (mkdir other #o750))
      (lambda ()
        (test-begin "wazuh-store-activation")
        (umask #o077)
        (test-assert "create safe unmounted destination"
                     (begin
                       (ensure-wazuh-store-directory destination 0)
                       (= 488
                          (stat:perms (stat destination)))))
        (test-assert "repeat unmounted activation"
                     (begin
                       (ensure-wazuh-store-directory destination 0) #t))
        (chmod destination #o700)
        (test-assert "repair restrictive unmounted directory"
                     (begin
                       (ensure-wazuh-store-directory destination 0)
                       (= #o750 (stat:perms (stat destination)))))
        (chmod destination #o700)
        (test-error "reject mismatched group before changing permissions" #t
                    (ensure-wazuh-store-directory destination 1))
        (test-equal "mismatched group leaves permissions unchanged" #o700
                    (stat:perms (stat destination)))
        (chmod destination #o1775)
        (test-error "reject writable unmounted directory" #t
                    (ensure-wazuh-store-directory destination 0))
        (chmod destination #o750)
        (bind "/gnu/store" #t)
        (test-equal
         "actual store bind preserves source permission bits"
         (stat:perms (stat "/gnu/store"))
         (stat:perms (stat destination)))
        (test-assert "reactivate with actual read-only store bind"
                     (begin
                       (ensure-wazuh-store-directory destination 0) #t))
        (test-assert "read-only store reactivation is repeatable"
                     (begin
                       (ensure-wazuh-store-directory destination 0) #t))
        (unmount)
        (bind other #t)
        (test-error
         "reject wrong read-only bind with safe permission bits" #t
         (ensure-wazuh-store-directory destination 0))
        (unmount)
        (bind other #f)
        (test-error
         "reject wrong writable bind with safe permission bits" #t
         (ensure-wazuh-store-directory destination 0))
        (unmount)
        ;; An inherited read-only host store cannot be made writable in a user
        ;; namespace.  Cover only this namespace's source with a private writable
        ;; fixture, testing matching device/inode with the real kernel RW flag.
        (mount other "/gnu/store" "none" MS_BIND)
        (set! source-covered? #t)
        (bind "/gnu/store" #f)
        (test-error "reject writable matching store bind" #t
                    (ensure-wazuh-store-directory destination 0))
        (unmount)
        (umount "/gnu/store")
        (set! source-covered? #f)
        (rmdir destination)
        (symlink "/gnu/store" destination)
        (test-error "reject symlink to actual store" #t
                    (ensure-wazuh-store-directory destination 0))
        (delete-file destination)
        (let ((runner (test-runner-current)))
          (test-end "wazuh-store-activation")
          (set! result
                (if (zero? (test-runner-fail-count runner)) 0 1))))
      (lambda ()
        (unmount)
        (when source-covered?
          (umount "/gnu/store"))
        (delete-file-recursively temporary)))
  (exit result))

;; Guix imports channel modules while compiling them.  Loading this module must
;; never execute the privileged fixture; explicit invocation still checks both
;; namespaces before allocating temporary state or attempting any mount.
(when (string=? (basename (car (command-line))) "wazuh-store-activation.scm")
  (run-tests))
