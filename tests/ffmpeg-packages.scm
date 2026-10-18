;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Run: guix repl -L . tests/ffmpeg-packages.scm
(define-module (tests ffmpeg-packages))
(use-modules (guix packages) (guix gexp) (guix store) (guix monads)
             (srfi srfi-1) (srfi srfi-64)
             ((securityops packages video) #:prefix video:)
             ((gnu packages video) #:prefix gnu-video:)
             ((securityops packages nvidia) #:prefix nvidia:))

(define (run-tests)
  (test-begin "ffmpeg-packages")
  (define (sexp-has-symbol? value symbol)
    (cond ((eq? value symbol) #t)
          ((pair? value)
           (or (sexp-has-symbol? (car value) symbol)
               (sexp-has-symbol? (cdr value) symbol)))
          (else #f)))
  (define (phases-expression package)
    (let ((phases (cadr (memq #:phases (package-arguments package)))))
      (with-store store
        (lowered-gexp-sexp
         (run-with-store store
           (lower-gexp phases #:system "x86_64-linux"))))))
  (define video-module (resolve-module '(securityops packages video)))
  (define vvdec (module-ref video-module 'vvdec #f))
  (define ffmpeg-vvdec (module-ref video-module 'ffmpeg-vvdec #f))
  (test-assert "VVdeC decoder package is exported" (package? vvdec))
  (test-assert "FFmpeg VVdeC variant is exported" (package? ffmpeg-vvdec))
  (when (package? vvdec)
    (test-equal "VVdeC includes latest security fixes" "3.2.1"
      (package-version vvdec))
    (test-equal "missing upstream bitstreams do not fail VVdeC CTest" #f
      (cadr (memq #:tests? (package-arguments vvdec))))
    (test-assert "VVdeC has a pinned conformance decode fixture"
      (origin? (lookup-package-native-input vvdec "vvc-conformance-bitstream"))))
  (when (package? ffmpeg-vvdec)
    (test-equal "VVdeC variant tracks channel FFmpeg 9" "9.0.2"
      (package-version ffmpeg-vvdec))
    (test-equal "VVdeC variant retains FFmpeg vulnerability lookup" "ffmpeg"
      (assoc-ref (package-properties ffmpeg-vvdec) 'cpe-name))
    (test-eq "VVdeC variant uses the packaged decoder" vvdec
      (lookup-package-input ffmpeg-vvdec "vvdec"))
    (test-assert "FFmpeg VVdeC carries the conformance bitstream"
      (origin? (lookup-package-native-input ffmpeg-vvdec
                                            "vvc-conformance-bitstream")))
    (test-assert "FFmpeg VVdeC can unpack its conformance bitstream"
      (package? (lookup-package-native-input ffmpeg-vvdec "unzip")))
    (test-assert "FFmpeg VVdeC has a dedicated decoder test phase"
      (sexp-has-symbol? (phases-expression ffmpeg-vvdec)
                        'check-libvvdec-decoder))
    (test-equal "VVdeC variant carries upstream and local hardening patches" 2
      (length (origin-patches (package-source ffmpeg-vvdec)))))
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
  (test-assert "only the observed seek-hls regression is excluded from FATE"
    (any (lambda (flag)
           (and (string-prefix? "--ignore-tests=" flag)
                (member "seek-hls"
                        (string-split
                         (substring flag (string-length "--ignore-tests="))
                         #\,))))
         (configure-flags video:ffmpeg)))
  (define (ignored-tests package)
    (append-map
     (lambda (flag)
       (if (string-prefix? "--ignore-tests=" flag)
           (string-split (substring flag (string-length "--ignore-tests=")) #\,)
           '()))
     (configure-flags package)))
  (test-equal "FFmpeg 9 FATE excludes exactly one additional failing test"
    (sort (delete-duplicates
           (cons "seek-hls"
                 (filter (lambda (name)
                           (not (member name '("filter-frei0r-filter"
                                               "filter-frei0r-filter-unaligned"))))
                         (ignored-tests gnu-video:ffmpeg))))
          string<?)
    (sort (delete-duplicates (ignored-tests video:ffmpeg)) string<?))
  (when (package? ffmpeg-vvdec)
    (test-assert "VVdeC keeps the codec metadata FATE test enabled"
      (not (member "libavcodec-avcodec" (ignored-tests ffmpeg-vvdec))))
    (test-assert "VVdeC configure flag is enabled"
      (member "--enable-libvvdec" (configure-flags ffmpeg-vvdec))))
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
