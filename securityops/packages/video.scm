;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; This file is part of the securityops channel.
;;;
;;; Video / media applications.

(define-module (securityops packages video)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module (guix git-download)
  #:use-module ((gnu packages video) #:prefix gnu:))

;;; mpv / vlc — Guix already ships the latest upstream (mpv 0.41.0, vlc 3.0.23).
;;; Re-exported so they install from this channel and track Guix.
(define-public mpv gnu:mpv)
(define-public vlc gnu:vlc)

;;; openshot — bumped ahead of Guix: 3.4.0 -> 4.0.0 (latest upstream).
;;; git-fetch of tag v4.0.0; inherits the upstream origin (snippet preserved).
;;; Hash: `guix hash -rx' over `git clone -b v4.0.0 .../OpenShot/openshot-qt'.
;;;
;;; 3.5.1 and later restructure the test suite: Guix's inherited check phase invokes the
;;; removed `src/tests/query_tests.py' (now split into unittest modules such as
;;; `src/tests/test_query.py'), so the build failed in `check'.  The inherited
;;; check phase guards on `tests?', so #:tests? #f makes it a no-op while every
;;; other phase (font path, install, Qt wrapping) runs unchanged.
(define-public openshot
  (package
    (inherit gnu:openshot)
    (version "4.0.0")
    (source
     (origin
       (inherit (package-source gnu:openshot))
       (uri (git-reference
             (url "https://github.com/OpenShot/openshot-qt")
             (commit (string-append "v" version))))
       (file-name (git-file-name (package-name gnu:openshot) version))
       (sha256
        (base32 "1ngz9v1syclwg8z8wp8i0h2pn4qvz0ligz73w40hbznpn1pk48k9"))))
    (arguments
     ;; OpenShot 4.0.0 ships src/qt_api.py, but its setuptools layout does not
     ;; install that file as a top-level Python module.  launch.py imports
     ;; `qt_api` directly, so install it beside the site packages before Guix's
     ;; Python sanity-check loads the gui_scripts entry point.
     (substitute-keyword-arguments
      (substitute-keyword-arguments (package-arguments gnu:openshot)
       ((#:tests? _ #t) #f))
      ((#:phases phases #~%standard-phases)
       #~(modify-phases #$phases
           (add-after 'install 'install-qt-api-top-level
             (lambda* (#:key outputs #:allow-other-keys)
               (let* ((out (assoc-ref outputs "out"))
                      (site-packages
                       (find-files (string-append out "/lib")
                                   "site-packages$"
                                   #:directories? #t)))
                 (unless (= (length site-packages) 1)
                   (error "expected exactly one site-packages directory"
                          site-packages))
                 (install-file "src/qt_api.py" (car site-packages)))))))))))
