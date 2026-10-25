(define-module (securityops packages linux-libre-7-2-11)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base32))

;; Keep the current Guix kernel build phases and configuration while using
;; the already-deblobbed, hash-pinned GNU Linux-libre release tarball.
(define-public linux-libre-7.2.11
  ((@@ (gnu packages linux) make-linux-libre*)
   "7.2.11"
   "gnu"
   (origin
     (method url-fetch)
     (uri
      "https://linux-libre.fsfla.org/pub/linux-libre/releases/7.2.11-gnu/linux-libre-7.2.11-gnu.tar.xz")
     (sha256 (base32 "0pj9vmr5c3yf80lc5zdws3ywa0lynq1kll5brpmqbia9irhqy1ah")))
   '("x86_64-linux")
   #:configuration-file (@@ (gnu packages linux) kernel-config)))

linux-libre-7.2.11
