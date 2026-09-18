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
  #:use-module ((gnu packages video) #:prefix gnu:)
  #:use-module ((gnu packages image-viewers) #:prefix gnu-iv:))

;;; mpv / vlc — Guix already ships the latest upstream (mpv 0.41.0, vlc 3.0.23).
;;; Re-exported so they install from this channel and track Guix.
(define-public mpv gnu:mpv)
(define-public vlc gnu:vlc)

;;; yt-dlp — bumped ahead of Guix: 2026.07.04 -> 2026.08.19 (latest upstream,
;;; released 2026-08-19).  git-fetch of the release tag; the arguments (test
;;; deselections and the ffmpeg-location phase) are inherited unchanged.  Hash
;;; cross-checked against the definition prepared in the owner's guix fork
;;; checkout.
(define-public yt-dlp
  (package
    (inherit gnu:yt-dlp)
    (version "2026.08.19")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/yt-dlp/yt-dlp/")
             (commit version)))
       (file-name (git-file-name "yt-dlp" version))
       (sha256
        (base32 "1257p5r20cxdr5shsi0zi20wpn0a5qxzz1kyqjssy7p6ciw5kkh4"))))))

;;; ytfzf — Guix ships the latest upstream (2.6.2); re-exported with the
;;; channel's yt-dlp so the terminal frontend downloads with the bumped engine.
(define-public ytfzf
  (package
    (inherit gnu-iv:ytfzf)
    (inputs (modify-inputs (package-inputs gnu-iv:ytfzf)
              (replace "yt-dlp" yt-dlp)))))

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
