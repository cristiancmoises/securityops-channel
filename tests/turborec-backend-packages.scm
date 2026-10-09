;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Run: guix repl -L . tests/turborec-backend-packages.scm
(define-module (tests turborec-backend-packages))
(use-modules (guix packages) (guix gexp) (guix store) (guix monads)
             (guix build copy-build-system) (guix build utils) (guix build syscalls)
             (ice-9 popen) (ice-9 textual-ports)
             (srfi srfi-1) (srfi srfi-64)
             ((securityops packages turborec) #:prefix apps:)
             ((securityops packages video) #:prefix video:)
             ((securityops packages nvidia) #:prefix nvidia:))

(define (run-tests)
  (define variant
    (module-ref (resolve-interface '(securityops packages turborec))
                'turborec-nvidia-new-feature #f))
  (define (wrapper-output package paired?)
    (let* ((directory (mkdtemp! (string-copy "/tmp/turborec-wrapper-XXXXXX")))
           (out (string-append directory "/out"))
           (tk (string-append directory "/tk"))
           (inputs
            (append
             (list (cons "python" (dirname (dirname (which "python3"))))
                   (cons "bash-minimal" (dirname (dirname (which "bash"))))
                   (cons "python:tk" tk))
             (map (lambda (name) (cons name (string-append "/fixture/" name)))
                  '("ffmpeg" "pulseaudio" "xrandr" "xdpyinfo" "wf-recorder"
                    "wlr-randr" "sway" "wmctrl" "pciutils"))
             (if paired? '(("wf-ffmpeg" . "/fixture/wf-ffmpeg")) '()))))
      (dynamic-wind
        (lambda ()
          (mkdir-p (string-append out "/lib/turborec"))
          (mkdir-p (string-append out "/share/applications"))
          (mkdir-p tk)
          (call-with-output-file (string-append tk "/_tkinter.so")
            (lambda (port) (display "wrapper discovery fixture" port)))
          (call-with-output-file (string-append out "/lib/turborec/turborec.py")
            (lambda (port)
              (display "import os\nfor key in ('TURBOREC_WF_RECORDER', 'TURBOREC_WF_FFMPEG'):\n print(os.environ.get(key, 'unset'))\n" port)))
          (call-with-output-file (string-append out "/lib/turborec/turborecorder")
            (lambda (port)
              (display "printf '%s\\n' \"${TURBOREC_WF_RECORDER-unset}\" \"${TURBOREC_WF_FFMPEG-unset}\"\n" port)))
          (call-with-output-file (string-append out "/share/applications/turborec.desktop")
            (lambda (port) (display "Exec=turborec\nIcon=turborec\n" port))))
        (lambda ()
          ;; Execute the production wrap phase, then run its generated scripts.
          ;; Fixtures supply opaque build-input paths, not a replacement wrapper.
          (let* ((phases-gexp (cadr (memq #:phases (package-arguments package))))
                 (phases
                  (with-store store
                    (eval (lowered-gexp-sexp
                           (run-with-store store
                             (lower-gexp phases-gexp #:system "x86_64-linux")))
                          (current-module)))))
            ((assoc-ref phases 'wrap) #:inputs inputs #:outputs `(("out" . ,out)))
            (map (lambda (launcher)
                   (let* ((port (open-pipe* OPEN_READ
                                           (string-append out "/bin/" launcher)))
                          (output (get-string-all port))
                          (status (close-pipe port)))
                     (unless (zero? status)
                       (error "generated launcher failed" launcher status))
                     output))
                 '("turborec" "turborecorder"))))
        (lambda () (delete-file-recursively directory)))))
  (test-begin "turborec-backend-packages")
  (test-eq "generic app uses current free FFmpeg" video:ffmpeg
    (lookup-package-input apps:turborec "ffmpeg"))
  (test-assert "generic app dependency closure remains NVIDIA-free"
    (not (any (lambda (input)
                (member (package-name (cadr input))
                        '("nvidia-driver" "nvidia-driver-new-feature"
                          "nv-codec-headers")))
              (package-transitive-inputs apps:turborec))))
  (test-assert "optional NVIDIA app is public" (package? variant))
  (test-eq "codec loader uses the channel's matched driver"
    nvidia:nvidia-driver-new-feature
    (lookup-package-input video:nv-codec-headers "nvidia-driver"))
  (for-each
   (lambda (consumer)
     (let* ((backend (if (string=? "wf-recorder-nvidia-new-feature"
                                   (package-name consumer))
                         (lookup-package-input consumer "ffmpeg")
                         consumer))
            (headers (lookup-package-input backend "nv-codec-headers")))
       (test-eq (string-append "matched NVIDIA loader in "
                               (package-name consumer))
         nvidia:nvidia-driver-new-feature
         (lookup-package-input headers "nvidia-driver"))))
   (list video:ffmpeg-nvidia-new-feature video:ffmpeg-8-nvidia-new-feature
         video:wf-recorder-nvidia-new-feature))
  (for-each unsetenv '("TURBOREC_WF_RECORDER" "TURBOREC_WF_FFMPEG"))
  (test-equal "generic launchers do not pin a proprietary backend"
    '("unset\nunset\n" "unset\nunset\n")
    (wrapper-output apps:turborec #f))
  (setenv "TURBOREC_WF_RECORDER" "/untrusted/recorder")
  (setenv "TURBOREC_WF_FFMPEG" "/untrusted/ffmpeg")
  (test-equal "both paired launchers override inherited mismatched paths"
    '("/fixture/wf-recorder/bin/wf-recorder\n/fixture/wf-ffmpeg/bin/ffmpeg\n"
      "/fixture/wf-recorder/bin/wf-recorder\n/fixture/wf-ffmpeg/bin/ffmpeg\n")
    (wrapper-output apps:turborec #t))
  (when (package? variant)
    (test-eq "optional app retains the official app source"
      (package-source apps:turborec) (package-source variant))
    (test-equal "optional app tracks the generic release"
      (package-version apps:turborec) (package-version variant))
    (test-equal "optional app supports only driver architectures"
      (package-supported-systems nvidia:nvidia-driver-new-feature)
      (package-supported-systems variant))
    (test-equal "renamed app retains vulnerability lookup" "turborec"
      (assoc-ref (package-properties variant) 'cpe-name))
    (test-eq "normal pipelines use NVIDIA FFmpeg 9" video:ffmpeg-nvidia-new-feature
      (lookup-package-input variant "ffmpeg"))
    (test-eq "Wayland capture uses NVIDIA wf-recorder"
      video:wf-recorder-nvidia-new-feature
      (lookup-package-input variant "wf-recorder"))
    (test-eq "Wayland probe uses recorder-compatible FFmpeg 8"
      video:ffmpeg-8-nvidia-new-feature
      (lookup-package-input variant "wf-ffmpeg"))
    (test-equal "optional app uses the same paired launcher contract"
      '("/fixture/wf-recorder/bin/wf-recorder\n/fixture/wf-ffmpeg/bin/ffmpeg\n"
        "/fixture/wf-recorder/bin/wf-recorder\n/fixture/wf-ffmpeg/bin/ffmpeg\n")
      (wrapper-output variant #t)))
  (let ((runner (test-runner-current)))
    (test-end "turborec-backend-packages")
    (exit (if (zero? (test-runner-fail-count runner)) 0 1))))

(when (string=? (basename (car (command-line))) "turborec-backend-packages.scm")
  (run-tests))
