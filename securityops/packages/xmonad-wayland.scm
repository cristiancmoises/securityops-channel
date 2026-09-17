;;; SPDX-License-Identifier: BSD-3-Clause
;;; Copyright © 2026 SecurityOps contributors
;;; Adapted from xmonad-wayland's BSD-3-Clause packaging recipes.
;;; See LICENSES/xmonad-wayland-BSD3.txt.

(define-module (securityops packages xmonad-wayland)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses)
                #:prefix license:)
  #:use-module (gnu packages haskell)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages python)
  #:use-module (gnu packages freedesktop))

;;; The manager builds from the canonical public repository at the signed
;;; commit below; mirrors carry the same OID.  River itself is not propagated.

(define-public xmonad-wayland
  (package
    (name "xmonad-wayland")
    (version "0.3.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://codeberg.org/berkeley/xmonad-wayland")
             (commit "46968f0544430274ccae0c637a04058a085432c9")))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1jjh42xmx0kigr7yfhw84cywz23xlf2nvi2svcwjgl34vv22hbzg"))))
    (build-system gnu-build-system)
    (arguments
     (list
      ;; Make's built-in CC is not necessarily the compiler for this target.
      #:make-flags
      #~(list (string-append "CC="
                             #$(cc-for-target))
              (string-append "PREFIX="
                             #$output))
      #:test-target "test"
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure))))
    (native-inputs (list ghc-9.2 pkg-config wayland))
    (inputs (list wayland python-minimal))
    (home-page "https://codeberg.org/berkeley/xmonad-wayland")
    (synopsis "XMonad window management for the River Wayland compositor")
    (description
     "XMonad Wayland ports XMonad's StackSet core to Wayland through River.
The manager keeps window order, focus and workspaces while River handles
graphics, input and Wayland/XWayland clients.  River 0.4 or newer is required
and is not propagated; install river-xmonad-runtime from this channel to run
it.  This package does not configure a login session; see the upstream
documentation for a complete River desktop.")
    (license (list license:bsd-3 license:expat))))
