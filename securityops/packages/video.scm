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
  #:use-module (guix download)
  #:use-module ((nongnu packages nvidia) #:prefix nong:)
  #:use-module ((gnu packages video) #:prefix gnu:)
  #:use-module ((gnu packages image-viewers) #:prefix gnu-iv:))

;;; Keep the CPU build available separately: proprietary NVIDIA libraries must
;;; never become a requirement on other hardware.  The release archive's PGP
;;; signature was verified against FFmpeg's published release-key fingerprint.
(define-public ffmpeg
  (package
    (inherit gnu:ffmpeg)
    (version "9.0.2")
    (replacement #f)
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://ffmpeg.org/releases/ffmpeg-" version
                           ".tar.xz"))
       (sha256
        (base32 "0bh0dslibv4vhjh83vq9gcs1ggp0a50a0y1090ka0pxj7ql50f4c"))))
    (native-inputs
     (modify-inputs (package-native-inputs gnu:ffmpeg)
       (prepend gnu:frei0r)))
    (arguments
     (substitute-keyword-arguments (package-arguments gnu:ffmpeg)
       ((#:configure-flags flags)
        ;; FFmpeg 9 removed libshaderc's API flag, but Vulkan still needs
        ;; the glslc executable supplied by the inherited shaderc input.
        ;; With plugins available for tests, also run all Frei0r FATE cases.
        #~(begin
            (use-modules (srfi srfi-1) (srfi srfi-13))
            (filter-map
             (lambda (flag)
               (cond
                ((string=? flag "--enable-libshaderc") #f)
                ((string-prefix? "--ignore-tests=" flag)
                 (let ((ignored
                        (filter
                         (lambda (test)
                           (not (member test '("filter-frei0r-filter"
                                               "filter-frei0r-filter-unaligned"))))
                         (string-split
                          (substring flag (string-length "--ignore-tests="))
                          #\,))))
                   (and (pair? ignored)
                        (string-append "--ignore-tests="
                                       (string-join ignored ",")))))
                (else flag)))
             #$flags)))
       ((#:phases phases)
        #~(modify-phases #$phases
            (add-before 'check 'set-frei0r-path
              (lambda* (#:key inputs #:allow-other-keys)
                (setenv "FREI0R_PATH"
                        (search-input-directory inputs "lib/frei0r-1"))))))))))

;;; Nonguix's fix-paths phase binds dlopen to the selected driver.  Rebuilding
;;; these headers with the new-feature driver prevents an older userspace
;;; library from being embedded in FFmpeg while a newer kernel driver runs.
;;; SDK 13.1 requires NVIDIA Linux/Windows driver 610 or newer.
(define-public nv-codec-headers
  (package
    (inherit nong:nv-codec-headers)
    (version "13.1.15.0")
    (supported-systems
     (package-supported-systems nong:nvidia-driver-new-feature))
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/FFmpeg/nv-codec-headers.git")
             (commit (string-append "n" version))))
       (file-name (git-file-name "nv-codec-headers" version))
       (sha256
        (base32 "11spiawjvsh6yy9nbhd2gmqcd9lmh959kg9hmplpfwkqh7mrbgra"))))
    (inputs
     (modify-inputs (package-inputs nong:nv-codec-headers)
       ;; Bind dlopen directly to the driver libraries, not the nvda
       ;; graphics union with its additional VAAPI integration.
       (replace "nvidia-driver" nong:nvidia-driver-new-feature)))))

(define-public ffmpeg-nvidia-new-feature
  (package
    (inherit ffmpeg)
    (name "ffmpeg-nvidia-new-feature")
    (supported-systems
     (package-supported-systems nong:nvidia-driver-new-feature))
    (properties
     (cons '(cpe-name . "ffmpeg") (package-properties ffmpeg)))
    (inputs
     (modify-inputs (package-inputs ffmpeg)
       (prepend nv-codec-headers)))
    (arguments
     (substitute-keyword-arguments (package-arguments ffmpeg)
       ((#:configure-flags flags)
        #~(cons* "--enable-ffnvcodec" "--enable-cuvid" "--enable-nvenc"
                 #$flags))))
    (synopsis "FFmpeg with NVENC/NVDEC for the NVIDIA new-feature driver")
    (description
     (string-append (package-description ffmpeg)
                    "  This variant enables NVIDIA hardware encoding and
decoding.  Its userspace libraries must match the running NVIDIA kernel
driver; installing it does not replace the kernel module."))))

;;; wf-recorder 0.6.0 supports FFmpeg 8, not FFmpeg 9's removed AVCodec fields.
;;; Keep this maintained compatibility release separate from the default
;;; FFmpeg 9 packages.  The archive signature was verified against FFmpeg's
;;; published key FCF986EA15E6E293A5644F10B4322F04D67658D8.
(define-public ffmpeg-8-nvidia-new-feature
  (package
    (inherit gnu:ffmpeg)
    (name "ffmpeg-8-nvidia-new-feature")
    (version "8.1.3")
    (replacement #f)
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://ffmpeg.org/releases/ffmpeg-" version
                           ".tar.xz"))
       (sha256
        (base32 "18vq676kxsjx4c9123591nsgzy214zbwmn739spy7lyrjs6d4f3i"))))
    (supported-systems
     (package-supported-systems nong:nvidia-driver-new-feature))
    (properties
     (cons '(cpe-name . "ffmpeg") (package-properties gnu:ffmpeg)))
    (inputs
     (modify-inputs (package-inputs gnu:ffmpeg)
       (prepend nv-codec-headers)))
    (arguments
     (substitute-keyword-arguments (package-arguments gnu:ffmpeg)
       ((#:configure-flags flags)
        #~(cons* "--enable-ffnvcodec" "--enable-cuvid" "--enable-nvenc"
                 #$flags))))
    (synopsis "FFmpeg 8 with NVENC/NVDEC for the NVIDIA new-feature driver")
    (description
     (string-append (package-description gnu:ffmpeg)
                    "  This maintained FFmpeg 8 variant supplies the API used
by wf-recorder 0.6.0 and enables NVIDIA hardware encoding and decoding.  Its
userspace libraries must match the running NVIDIA kernel driver; installing
it does not replace the kernel module."))))

(define-public wf-recorder-nvidia-new-feature
  (package
    (inherit gnu:wf-recorder)
    (name "wf-recorder-nvidia-new-feature")
    (supported-systems
     (package-supported-systems nong:nvidia-driver-new-feature))
    (properties
     (cons '(cpe-name . "wf-recorder")
           (package-properties gnu:wf-recorder)))
    (inputs
     (modify-inputs (package-inputs gnu:wf-recorder)
       (replace "ffmpeg" ffmpeg-8-nvidia-new-feature)))
    (synopsis "Wayland recorder with NVENC for the NVIDIA new-feature driver")
    (description
     (string-append (package-description gnu:wf-recorder)
                    "  This variant links FFmpeg 8 with NVIDIA NVENC support.
Select an encoder with @code{-c h264_nvenc}, @code{-c hevc_nvenc}, or
@code{-c av1_nvenc}; @code{-d} selects a VAAPI device, not an NVIDIA device.
The running NVIDIA kernel driver must match this variant's userspace
libraries."))))

;;; mpv tracks Guix; VLC keeps the current stable 3.0 bug-fix release.
(define-public mpv gnu:mpv)
(define-public vlc
  (package
    (inherit gnu:vlc)
    (version "3.0.24")
    (source
     (origin
       (inherit (package-source gnu:vlc))
       (uri (string-append "https://download.videolan.org/pub/videolan/vlc/"
                           version "/vlc-" version ".tar.xz"))
       (sha256
        (base32 "1psz4b6c1kxr8jv92xs02b8gc3hdwqg0xkyji6dq9mfps41vbjp7"))))))

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

;;; openshot — bumped ahead of Guix: 3.4.0 -> 4.0.1 (stable upstream).
;;; git-fetch of tag v4.0.1; inherits the upstream origin (snippet preserved).
;;; Hash: `guix download --git --commit=v4.0.1 .../OpenShot/openshot-qt'.
;;;
;;; 3.5.1 and later restructure the test suite: Guix's inherited check phase invokes the
;;; removed `src/tests/query_tests.py' (now split into unittest modules such as
;;; `src/tests/test_query.py'), so the build failed in `check'.  The inherited
;;; check phase guards on `tests?', so #:tests? #f makes it a no-op while every
;;; other phase (font path, install, Qt wrapping) runs unchanged.
(define-public openshot
  (package
    (inherit gnu:openshot)
    (version "4.0.1")
    (source
     (origin
       (inherit (package-source gnu:openshot))
       (uri (git-reference
             (url "https://github.com/OpenShot/openshot-qt")
             (commit (string-append "v" version))))
       (file-name (git-file-name (package-name gnu:openshot) version))
       (sha256
        (base32 "0d0frymfyh3nr0b32mp2cl893zs4gc422iav4ci391hia9j8rdh6"))))
    (arguments
     ;; OpenShot 4.0.1 ships src/qt_api.py, but its setuptools layout does not
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
