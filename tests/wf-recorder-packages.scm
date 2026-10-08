;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Run: guix repl -L . tests/wf-recorder-packages.scm
(define-module (tests wf-recorder-packages))
(use-modules (guix packages) (guix gexp) (guix store) (guix monads)
             (srfi srfi-1) (srfi srfi-64)
             ((securityops packages video) #:prefix video:)
             ((gnu packages video) #:prefix gnu:)
             ((securityops packages nvidia) #:prefix nvidia:))

(define (run-tests)
  (define video-module (resolve-interface '(securityops packages video)))
  (define ffmpeg-8
    (module-ref video-module 'ffmpeg-8-nvidia-new-feature #f))
  (define recorder
    (module-ref video-module 'wf-recorder-nvidia-new-feature #f))
  (define (configure-flags package)
    (let ((flags (cadr (memq #:configure-flags (package-arguments package)))))
      (with-store store
        (eval (lowered-gexp-sexp
               (run-with-store store
                 (lower-gexp flags #:system "x86_64-linux")))
              (current-module)))))
  (test-begin "wf-recorder-packages")
  (test-assert "FFmpeg 8 NVIDIA compatibility package is public"
    (package? ffmpeg-8))
  (test-assert "NVIDIA recorder package is public" (package? recorder))
  (when (package? ffmpeg-8)
    (test-equal "maintained FFmpeg 8 security release" "8.1.3"
      (package-version ffmpeg-8))
    (test-equal "compatibility package cannot graft older FFmpeg" #f
      (package-replacement ffmpeg-8))
    (test-equal "FFmpeg vulnerability lookup retained" "ffmpeg"
      (assoc-ref (package-properties ffmpeg-8) 'cpe-name))
    (test-eq "compatibility package reuses secured NVENC headers"
      video:nv-codec-headers
      (lookup-package-input ffmpeg-8 "nv-codec-headers"))
    (test-equal "compatibility package supports only driver architectures"
      (package-supported-systems nvidia:nvidia-driver-new-feature)
      (package-supported-systems ffmpeg-8))
    (test-assert "FFmpeg FATE checks remain enabled"
      (let ((tests (memq #:tests? (package-arguments ffmpeg-8))))
        (or (not tests) (not (eq? #f (cadr tests))))))
    (test-equal "inherited FATE target retained" "fate"
      (cadr (memq #:test-target (package-arguments ffmpeg-8))))
    (for-each
     (lambda (flag)
       (test-assert (string-append "compatibility build enables " flag)
         (member flag (configure-flags ffmpeg-8))))
     '("--enable-ffnvcodec" "--enable-cuvid" "--enable-nvenc"
       "--enable-libshaderc")))
  (when (package? recorder)
    (test-equal "recorder retains supported upstream release" "0.6.0"
      (package-version recorder))
    (test-eq "recorder retains upstream verified source"
      (package-source gnu:wf-recorder) (package-source recorder))
    (test-equal "recorder retains upstream build/check arguments"
      (package-arguments gnu:wf-recorder) (package-arguments recorder))
    (test-equal "recorder vulnerability lookup retained" "wf-recorder"
      (assoc-ref (package-properties recorder) 'cpe-name))
    (test-equal "recorder supports only driver architectures"
      (package-supported-systems nvidia:nvidia-driver-new-feature)
      (package-supported-systems recorder))
    (test-eq "recorder links the FFmpeg 8 NVIDIA build" ffmpeg-8
      (lookup-package-input recorder "ffmpeg")))
  (for-each
   (lambda (package)
     (test-assert (string-append (package-name package)
                                " generic dependency closure remains NVIDIA-free")
       (not (any (lambda (input)
                   (member (package-name (cadr input))
                           '("nvidia-driver" "nvidia-driver-new-feature"
                             "nv-codec-headers")))
                 (package-transitive-inputs package)))))
   (list video:ffmpeg gnu:wf-recorder))
  (let ((runner (test-runner-current)))
    (test-end "wf-recorder-packages")
    (exit (if (zero? (test-runner-fail-count runner)) 0 1))))

;; Importing a test module during Guix discovery must have no side effects.
(when (string=? (basename (car (command-line))) "wf-recorder-packages.scm")
  (run-tests))
