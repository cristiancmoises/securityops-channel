;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Run: guix repl -L . tests/ffmpeg-packages.scm
(define-module (tests ffmpeg-packages))
(use-modules (guix packages) (guix gexp) (guix store) (guix monads)
             (srfi srfi-1) (srfi srfi-64)
             ((securityops packages video) #:prefix video:)
             ((gnu packages video) #:prefix gnu-video:)
             ((nongnu packages nvidia) #:prefix nvidia:))

(define (run-tests)
  (test-begin "ffmpeg-packages")
  (test-equal "latest stable FFmpeg" "9.0.2"
    (package-version video:ffmpeg))
  (test-equal "no inherited downgrade graft" #f
    (package-replacement video:ffmpeg))
  (test-equal "latest NVENC headers" "13.1.15.0"
    (package-version video:nv-codec-headers))
  (test-equal "NVIDIA variant tracks FFmpeg" "9.0.2"
    (package-version video:ffmpeg-nvidia-new-feature))
  (test-equal "NVIDIA variant has no downgrade graft" #f
    (package-replacement video:ffmpeg-nvidia-new-feature))
  (test-equal "renamed variant retains FFmpeg vulnerability lookup" "ffmpeg"
    (assoc-ref (package-properties video:ffmpeg-nvidia-new-feature) 'cpe-name))
  (test-equal "same verified FFmpeg source"
    (package-source video:ffmpeg)
    (package-source video:ffmpeg-nvidia-new-feature))
  (test-equal "CPU variant has no direct NVENC headers input" #f
    (assoc-ref (package-inputs video:ffmpeg) "nv-codec-headers"))
  (test-eq "NVIDIA variant uses the updated headers" video:nv-codec-headers
    (lookup-package-input video:ffmpeg-nvidia-new-feature "nv-codec-headers"))
  (test-eq "headers use the new-feature driver recipe"
    nvidia:nvidia-driver-new-feature
    (lookup-package-input video:nv-codec-headers "nvidia-driver"))
  (test-equal "headers restrict targets to the driver recipe"
    (package-supported-systems nvidia:nvidia-driver-new-feature)
    (package-supported-systems video:nv-codec-headers))
  (test-equal "NVIDIA variant restricts targets to the driver recipe"
    (package-supported-systems nvidia:nvidia-driver-new-feature)
    (package-supported-systems video:ffmpeg-nvidia-new-feature))
  (define (configure-flags package)
    (let ((flags (cadr (memq #:configure-flags (package-arguments package)))))
      (with-store store
        (eval (lowered-gexp-sexp
               (run-with-store store
                 (lower-gexp flags #:system "x86_64-linux")))
              (current-module)))))
  (test-equal "removed shaderc option is not passed to FFmpeg 9" #f
    (member "--enable-libshaderc" (configure-flags video:ffmpeg)))
  (test-eq "Frei0r plugins are available for FATE" gnu-video:frei0r
    (lookup-package-native-input video:ffmpeg "frei0r"))
  (test-assert "Frei0r FATE tests are not excluded"
    (not (any (lambda (flag)
                (and (string-prefix? "--ignore-tests=" flag)
                     (string-contains flag "filter-frei0r")))
              (configure-flags video:ffmpeg))))
  (for-each (lambda (flag)
              (test-assert (string-append "NVIDIA configure enables " flag)
                (member flag (configure-flags video:ffmpeg-nvidia-new-feature))))
            '("--enable-ffnvcodec" "--enable-cuvid" "--enable-nvenc"))
  (let ((runner (test-runner-current)))
    (test-end "ffmpeg-packages")
    (exit (if (zero? (test-runner-fail-count runner)) 0 1))))

;; Guix discovers source modules under -L. Importing this test module must
;; neither run tests nor exit the package discovery process.
(when (string=? (basename (car (command-line))) "ffmpeg-packages.scm")
  (run-tests))
