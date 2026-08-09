;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2024, 2025 Ian Eure <ian@retrospec.tv>          ; upstream librewolf.scm
;;; Copyright © 2025, 2026 Untrusem <mysticmoksh@riseup.net>    ; upstream librewolf.scm
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; This file is part of the securityops channel.
;;;
;;; LibreWolf — bumped ahead of Guix: 151.0.4-1 -> 153.0.3-1 (latest upstream).
;;;
;;; Guix builds librewolf from the module-PRIVATE `make-librewolf-source'
;;; (Firefox release source + the codeberg librewolf/source overlay + a pinned
;;; firefox-l10n checkout, assembled by a `computed-origin-method' derivation).
;;; A channel cannot reach that helper, so the source-assembly machinery
;;; (`firefox-source-origin', `librewolf-source-origin', `computed-origin-method',
;;; `firefox-l10n', `make-librewolf-source') is adapted and vendored here from
;;; gnu/packages/librewolf.scm.  The release pins plus two compatibility
;;; substitutions for the current upstream Makefile/l10n script differ.  The
;;; package then INHERITS guix's `librewolf' (build phases, inputs,
;;; clang/llvm/rust toolchain, configure flags, %librewolf-build-id) and overrides
;;; `version', `source', the release build ID, cbindgen, and NSS.  Firefox 153
;;; requires cbindgen >= 0.29.4 and NSS >= 3.125, while the inherited Guix
;;; package still supplies cbindgen 0.29.2 and nss-rapid 3.124.  The 0.29.4
;;; crate's Cargo.lock differs from 0.29.2 only in cbindgen's own version, so the
;;; private update below safely reuses Guix's complete 0.29 dependency closure.
;;; NSS 3.126 is the current Mozilla rapid release and matches the official Guix
;;; 153.0.3-1 recipe.  The build ID likewise matches that recipe; leaving the
;;; inherited 151.0.4-1 timestamp can break cache validation.
;;;
;;; The librewolf-specific patches (`librewolf-compare-paths.patch',
;;; `librewolf-use-system-wide-dir.patch', …) are guix-bundled; `search-patches'
;;; resolves them from guix's patch dir on the channel load path — no need to
;;; vendor them.  (The l10n-download neuter is NOT a search-patch here: guix's
;;; `librewolf-neuter-locale-download.patch' no longer applies to the current
;;; `curl'-based script, so it is done inline via `substitute*' below.)
;;;
;;; Hashes (all fetched + verified 2026-08-09):
;;;   firefox 153.0.3 source      (ftp.mozilla.org) -> firefox-hash
;;;   librewolf/source 153.0.3-1  (codeberg, git)   -> librewolf-hash
;;;   firefox-l10n @ 6795ea14     (github, git)     -> l10n-hash
;;; The l10n commit is the `revision' from
;;; firefox-153.0.3/browser/locales/l10n-changesets.json in the Firefox source.
;;;
;;; The exact full Firefox/LTO build passed on 2026-08-09.  The computed SOURCE
;;; assembly can also be checked independently with:
;;;   guix build -L ~/securityops-channel -S librewolf

(define-module (securityops packages librewolf)
  #:use-module (guix packages)
  #:use-module (guix build-system cargo)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module ((srfi srfi-1) #:hide (zip))
  #:use-module (gnu packages)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-xyz)
  #:use-module ((gnu packages nss) #:prefix nss:)
  #:use-module ((gnu packages rust-apps) #:prefix rust-apps:)
  #:use-module ((gnu packages librewolf) #:prefix lw:))

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

(define nss-rapid-3.126
  ;; Firefox 153's in-tree NSS is 3.125, so its --with-system-nss check rejects
  ;; the inherited 3.124.  This is the exact nss-rapid source update in Guix
  ;; master; all build arguments, patches, and inputs remain inherited.
  (package
    (inherit nss:nss-rapid)
    (version "3.126")
    (source
     (origin
       (inherit (package-source nss:nss-rapid))
       (uri (string-append
             "https://ftp.mozilla.org/pub/security/nss/releases/NSS_3_126_RTM/"
             "src/nss-" version ".tar.gz"))
       (sha256
        (base32 "0dz3z7hliwy0w5kq0j5y840fyypvkwj0n91rsy13sig1idspr83s"))))))

(define (firefox-source-origin version hash)
  (origin
    (method url-fetch)
    (uri (string-append
          "https://ftp.mozilla.org/pub/firefox/releases/"
          version "/source/" "firefox-" version
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
    ;; The network l10n download in scripts/librewolf-patches.py is neutered in
    ;; `make-librewolf-source' via `substitute*' instead of guix's bundled
    ;; `librewolf-neuter-locale-download.patch'.  That patch targets the old
    ;; `wget|unzip|mv' form of the script; upstream 152.0.4-1 switched to `curl'
    ;; and dropped an unrelated gkrust block above it, so its hunk context no
    ;; longer applies.  The substitute* below tracks the current script.
    (sha256 (base32 hash))))

(define computed-origin-method (@@ (guix packages) computed-origin-method))

(define firefox-l10n
  ;; Match this commit to the upstream tarball.  The hash is in
  ;; firefox-NNN/browser/locales/l10n-changesets.json (the "revision" field;
  ;; the same value repeats for every language).  For 153.0.3 it is 6795ea14.
  (let ((commit "6795ea14a5bd5ed79a930e6759823c7236476ae4"))
    (origin
      (method git-fetch)
      (uri (git-reference
            (url "https://github.com/mozilla-l10n/firefox-l10n.git")
            (commit commit)))
      (file-name (git-file-name "firefox-l10n" commit))
      (sha256 (base32 "1d47zfrw2gf23c9pa5rzbi5nx9jap2g0icm8dqsar6jb9y7svinc")))))

(define* (make-librewolf-source #:key version firefox-hash librewolf-hash l10n)
  (let* ((ff-src (firefox-source-origin
                  (car (string-split version #\-))
                  firefox-hash))
         (lw-src (librewolf-source-origin
                  version
                  librewolf-hash)))

    (origin
      (method computed-origin-method)
      (file-name (string-append "librewolf-" version ".source.tar.gz"))
      (sha256 #f)
      (uri
       (delay
         (with-imported-modules '((guix build utils))
           #~(begin
               (use-modules (guix build utils))
               (set-path-environment-variable
                "PATH" '("bin")
                (list #+python
                      #+(canonical-package bash)
                      #+(canonical-package gnu-make)
                      #+(canonical-package coreutils)
                      #+(canonical-package findutils)
                      #+(canonical-package patch)
                      #+(canonical-package xz)
                      #+(canonical-package sed)
                      #+(canonical-package grep)
                      #+(canonical-package pigz)
                      #+(canonical-package tar)))
               (set-path-environment-variable
                "PYTHONPATH"
                (list #+(format #f "lib/python~a/site-packages"
                                (version-major+minor
                                 (package-version python))))
                '#+(cons python-jsonschema
                         (map second
                              (package-transitive-propagated-inputs
                               python-jsonschema))))

               ;; Copy LibreWolf source into the build directory and make
               ;; everything writable.
               (copy-recursively #+lw-src ".")
               (for-each make-file-writable (find-files "."))

               ;; Patch Makefile to use the upstream source instead of
               ;; downloading.
               (substitute* '("Makefile")
                 (("^(ff_source_tarball *:= *).*" _ var)
                  (string-append var #+ff-src)))

               ;; Neuter GPG signing of the tarball.
               (substitute* '("Makefile")
                 (("if [ -f pk.asc ].*") ""))

               ;; Stage locales: neuter the network firefox-l10n download (no
               ;; network in the build sandbox) and redirect the locale-apply
               ;; loop at the staged firefox-l10n checkout.
               (begin
                 (substitute* "scripts/librewolf-patches.py"
                   ;; Drop the curl|unzip|mv block that fetches l10n from
                   ;; GitHub; keep the `with TemporaryDirectory()' valid by
                   ;; turning its body into `pass'.
                   (("exec\\(f\"curl -so .*l10n\\.zip.*") "pass")
                   (("exec\\(f\"unzip -qo .*l10n\\.zip.*") "")
                   (("exec\\(f\"mv .*firefox-l10n-main lw/l10n\"\\).*") "")
                   (("l10n_dir = Path(\"..\", \"l10n\")")
                    (string-append
                     "l10n_dir = \"" #+l10n "\""))))

               ;; Run the build script
               (invoke "make" "all")
               (copy-file (string-append "librewolf-" #$version
                                         ".source.tar.gz")
                          #$output)))))
      (patches
       (search-patches
        "librewolf-compare-paths.patch"
        "librewolf-use-system-wide-dir.patch"
        "librewolf-add-store-to-rdd-allowlist.patch"))
      ;; Slim down the tarball by removing unbundled libraries and 75 Mo (800+
      ;; Mo uncompressed) of unused tests.
      (modules '((guix build utils)))
      (snippet
       #~(for-each delete-file-recursively
                   '("testing/web-platform"
                     "gfx/cairo/libpixman"
                     "js/src/ctypes/libffi"
                     "ipc/chromium/src/third_party/libevent"
                     "media/libvpx"
                     "docs/nspr"
                     "media/libwebp"
                     "modules/zlib"))))))

;;; LibreWolf 153.0.3-1 — inherits guix's package and replaces the source plus
;;; the build dependencies whose minimum versions changed in Firefox 153.
;;; The source assembly and inherited Guix build stack use the current
;;; Rust 1.94/Clang 21/LLVM 21/ICU 78/NSS rapid toolchain expected by Firefox
;;; 153; the exact full browser build and runtime metadata were verified on
;;; 2026-08-09.
(define-public librewolf
  (package
    (inherit lw:librewolf)
    (version "153.0.3-1")
    (source
     (make-librewolf-source
      #:version version
      #:firefox-hash "09dwrhl6whin17fmyr1ynzak80q4qr37pxj285rqhl41idj6h527"
      #:librewolf-hash "111pfyyn3ldv7jyid34lsmh8g8alk2vf8zj8bga23v9z5i4h8grl"
      #:l10n firefox-l10n))
    (arguments
     (substitute-keyword-arguments (package-arguments lw:librewolf)
       ((#:phases phases '%standard-phases)
        #~(modify-phases #$phases
            (replace 'set-build-id
              (lambda _
                (setenv "MOZ_BUILD_DATE" "20260804215502")))))))
    (native-inputs
     (modify-inputs (package-native-inputs lw:librewolf)
       (replace "rust-cbindgen" rust-cbindgen-0.29.4)))
    (inputs
     (modify-inputs (package-inputs lw:librewolf)
       (replace "nss-rapid" nss-rapid-3.126)))))
