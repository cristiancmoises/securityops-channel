;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>

(define-module (securityops services wazuh-activation)
  #:use-module (guix build syscalls)
  #:export (ensure-wazuh-store-directory))

(define (ensure-wazuh-store-directory path gid)
  "Create PATH, or accept only the exact read-only store when it is mounted.
Bind mounts retain the source permission bits: Guix's store can be mode 1775
even on a read-only bind.  Check the effective kernel mount flags and the source
identity instead of weakening the ordinary unmounted-directory checks."
  (unless (file-exists? path)
    (mkdir path #o750)
    (chown path 0 gid))
  (let* ((mounted? (member path (mount-points)))
         (descriptor (and (not mounted?)
                          (open-fdes path
                                     (logior O_RDONLY O_DIRECTORY O_NOFOLLOW)))))
    (dynamic-wind
      (lambda () #t)
      (lambda ()
        (let ((metadata (if descriptor (stat descriptor) (lstat path))))
          (unless (and (eq? 'directory (stat:type metadata))
                       (if mounted?
                           (let ((source (stat "/gnu/store")))
                             (and (= (stat:dev metadata) (stat:dev source))
                                  (= (stat:ino metadata) (stat:ino source))
                                  (not (zero? (logand ST_RDONLY
                                                      (file-system-mount-flags
                                                       (statfs path)))))))
                           (and (zero? (stat:uid metadata))
                                (= gid (stat:gid metadata))
                                (zero? (logand #x12 (stat:perms metadata))))))
            (error "Unsafe Wazuh store destination or mount" path))
          ;; Never chmod the mounted store, whose mode belongs to its source.
          (unless mounted? (chmod descriptor #o750))))
      (lambda () (when descriptor (close-fdes descriptor))))))
