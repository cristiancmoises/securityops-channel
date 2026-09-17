;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2024, 2025 Ian Eure <ian@retrospec.tv>          ; upstream librewolf.scm
;;; Copyright © 2025, 2026 Untrusem <mysticmoksh@riseup.net>    ; upstream librewolf.scm
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; This file is part of the securityops channel.
;;;
;;; LibreWolf source assembly is adapted from Guix.  All three upstream inputs
;;; are pinned: the Firefox release tarball, LibreWolf overlay and the locale
;;; revision listed in Firefox's l10n-changesets.json.  Build phases and tests
;;; follow Guix; dependency overrides meet the release's configure checks.

(define-module (securityops packages librewolf)
  #:use-module (guix packages)
  #:use-module (guix build-system cargo)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module ((srfi srfi-1)
                #:hide (zip))
  #:use-module (gnu packages)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages vulkan)
  #:use-module (gnu packages xdisorg)
  #:use-module ((gnu packages nss)
                #:prefix nss:)
  #:use-module ((gnu packages rust-apps)
                #:prefix rust-apps:)
  #:use-module ((gnu packages librewolf)
                #:prefix lw:))

(define rust-cbindgen-0.29.4
  (package
    (inherit rust-apps:rust-cbindgen-0.29)
    (version "0.29.4")
    (source
     (origin
       (method url-fetch)
       (uri (crate-uri "cbindgen" version))
       (file-name (string-append "rust-cbindgen-" version ".tar.gz"))
       (sha256
        (base32 "085f02ma9cdz0alnl1p6b1x6bmr7i9nnasq2fjk7n5lw9i457jrf"))))))

(define nspr-4.40
  (package
    (inherit nss:nspr)
    (version "4.40")
    (source
     (origin
       (inherit (package-source nss:nspr))
       (uri (string-append "https://ftp.mozilla.org/pub/nspr/releases/v"
                           version "/src/nspr-" version ".tar.gz"))
       (sha256
        (base32 "1p4vq5w0azlya4aisycn6q2b49jjd5633izphfkvfgbzc968ihf0"))))))

(define nss-rapid-3.129
  (package
    (inherit nss:nss-rapid)
    (version "3.129")
    (source
     (origin
       (inherit (package-source nss:nss-rapid))
       (uri (string-append
             "https://ftp.mozilla.org/pub/security/nss/releases/NSS_3_129_RTM/"
             "src/nss-" version ".tar.gz"))
       (sha256
        (base32 "11877m4y0k11kdx1xg8s2nh1jr69afbm8fs78d46fgwal6qa7fiq"))))
    (propagated-inputs (modify-inputs (package-propagated-inputs nss:nss-rapid)
                         (replace "nspr" nspr-4.40)))))

(define (firefox-source-origin version hash)
  (origin
    (method url-fetch)
    (uri (string-append "https://ftp.mozilla.org/pub/firefox/releases/"
                        version
                        "/source/"
                        "firefox-"
                        version
                        ".source.tar.xz"))
    (sha256 (base32 hash))))

(define (librewolf-source-origin version hash)
  (origin
    (method git-fetch)
    (uri (git-reference
          (url "https://codeberg.org/librewolf/source.git")
          (commit version)
          (recursive? #t)))
    (file-name (git-file-name "librewolf-source" version))
    ;; Locale downloads are replaced with the pinned input during assembly.
    (sha256 (base32 hash))))

(define computed-origin-method
  (@@ (guix packages) computed-origin-method))

(define firefox-l10n
  ;; Match this commit to the upstream tarball.  The hash is in
  ;; firefox-NNN/browser/locales/l10n-changesets.json (the "revision" field;
  ;; the same value repeats for every language).  For 156.0 it is f3fd6d5d.
  (let ((commit "f3fd6d5d457d03eb7adea53816ac30c4ff85efca"))
    (origin
      (method git-fetch)
      (uri (git-reference
            (url "https://github.com/mozilla-l10n/firefox-l10n.git")
            (commit commit)))
      (file-name (git-file-name "firefox-l10n" commit))
      (sha256 (base32 "1xibwbr6nakj2vjhajkihb3nzzsq84pi9h6jjslw7xcqk1yg2bg6")))))

(define* (make-librewolf-source #:key version firefox-hash librewolf-hash l10n)
  (let* ((ff-src (firefox-source-origin (car (string-split version #\-))
                                        firefox-hash))
         (lw-src (librewolf-source-origin version librewolf-hash)))

    (origin
      (method computed-origin-method)
      (file-name (string-append "librewolf-" version ".source.tar.gz"))
      (sha256 #f)
      (uri (delay (with-imported-modules '((guix build utils))
                                         #~(begin
                                             (use-modules (guix build utils))
                                             (set-path-environment-variable
                                              "PATH"
                                              '("bin")
                                              (list #+python
                                                    #+(canonical-package bash)
                                                    #+(canonical-package
                                                       gnu-make)
                                                    #+(canonical-package
                                                       coreutils)
                                                    #+(canonical-package
                                                       findutils)
                                                    #+(canonical-package patch)
                                                    #+(canonical-package xz)
                                                    #+(canonical-package sed)
                                                    #+(canonical-package grep)
                                                    #+(canonical-package pigz)
                                                    #+(canonical-package tar)))
                                             (set-path-environment-variable
                                              "PYTHONPATH"
                                              (list #+(format #f
                                                       "lib/python~a/site-packages"
                                                       (version-major+minor (package-version
                                                                             python))))
                                              '#+(cons python-jsonschema
                                                       (map second
                                                            (package-transitive-propagated-inputs
                                                             python-jsonschema))))

                                             ;; Copy LibreWolf source into the build directory and make
                                             ;; everything writable.
                                             (copy-recursively #+lw-src ".")
                                             (for-each make-file-writable
                                                       (find-files "."))

                                             ;; Patch Makefile to use the upstream source instead of
                                             ;; downloading.
                                             (substitute* '("Makefile")
                                               (("^(ff_source_tarball *:= *).*"
                                                 _ var)
                                                (string-append var
                                                               #+ff-src)))

                                             ;; Neuter GPG signing of the tarball.
                                             (substitute* '("Makefile")
                                               (("if [ -f pk.asc ].*")
                                                ""))

                                             ;; Upstream clones an unpinned locale mirror.  Stage the exact
                                             ;; Firefox locale revision instead, keeping its license and
                                             ;; LibreWolf's own locale overlay separate.
                                             (substitute* "scripts/librewolf-patches.py"
                                               (("exec\\(f\"git clone --depth=1 .*l10n\"\\)")
                                                (string-append
                                                 "exec(f\"cp -R "
                                                 #+l10n " {tmpdir}/l10n && "
                                                 "chmod -R u+w {tmpdir}/l10n\")"))
                                               ((" [{]tmpdir[}]/l10n/LICENSE [{]tmpdir[}]/l10n/README")
                                                ""))

                                             ;; Run the build script
                                             (invoke "make" "all")
                                             (copy-file (string-append
                                                         "librewolf-"
                                                         #$version
                                                         ".source.tar.gz")
                                                        #$output)))))
      (patches (search-patches "librewolf-compare-paths.patch"
                               "librewolf-use-system-wide-dir.patch"
                               "librewolf-add-store-to-rdd-allowlist.patch"))
      ;; Slim down the tarball by removing unbundled libraries and 75 Mo (800+
      ;; Mo uncompressed) of unused tests.
      (modules '((guix build utils)))
      (snippet
       #~(for-each delete-file-recursively
                   '("testing/web-platform" "js/src/ctypes/libffi"
                     "ipc/chromium/src/third_party/libevent"
                     "media/libvpx"
                     "docs/nspr"
                     "media/libwebp"
                     "modules/zlib"))))))

(define-public librewolf
  (package
    (inherit lw:librewolf)
    (version "156.0-1")
    (source
     (make-librewolf-source #:version version
      #:firefox-hash "1fda8lhnpncsh78pbknzp4x6s42fcqiq21rzmamhj02i8g06h9qz"
      #:librewolf-hash "11qpsic744q6lkl4yqxjvb592jr0c1gvds6065f9miviajabx65g"
      #:l10n firefox-l10n))
    (arguments
     (substitute-keyword-arguments (package-arguments lw:librewolf)
       ((#:phases phases
         '%standard-phases)
        #~(modify-phases #$phases
            (replace 'set-build-id
              (lambda _
                ;; Fixed channel build ID based on the Firefox release date.
                (setenv "MOZ_BUILD_DATE" "20260915000000")))
            (replace 'wrap-glxtest
              (lambda* (#:key inputs outputs #:allow-other-keys)
                ;; Firefox 156 combines GL, VA-API and Vulkan probes in
                ;; gfxtest.  These libraries are loaded with dlopen().
                (let ((probe (string-append (assoc-ref outputs "out")
                                            "/lib/librewolf/gfxtest"))
                      (libs (map (lambda (name)
                                   (string-append (assoc-ref inputs name)
                                                  "/lib"))
                                 '("mesa" "pciutils" "libdrm" "libva"
                                   "vulkan-loader"))))
                  (unless (file-exists? probe)
                    (error "LibreWolf graphics probe is missing" probe))
                  (wrap-program probe
                    `("LD_LIBRARY_PATH" prefix
                      ,libs)))))))))
    (native-inputs (modify-inputs (package-native-inputs lw:librewolf)
                     (replace "rust-cbindgen" rust-cbindgen-0.29.4)))
    (inputs (modify-inputs (package-inputs lw:librewolf)
              (replace "nspr" nspr-4.40)
              (replace "nss-rapid" nss-rapid-3.129)
              (prepend libdrm vulkan-loader)))))
