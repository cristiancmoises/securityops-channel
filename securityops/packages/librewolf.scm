;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2024, 2025 Ian Eure <ian@retrospec.tv>
;;; Copyright © 2025, 2026 Untrusem <mysticmoksh@riseup.net>
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; Reuse Guix's native LibreWolf build and its authenticated source assembly.
;;; This compatibility package preserves the channel graphics-probe libraries
;;; and the NSS/NSPR graph also consumed by AutoFirma.  It does not rebuild or
;;; change the browser engine, its privacy preferences or its sandbox.

(define-module (securityops packages librewolf)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix build-system trivial)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages pciutils)
  #:use-module (gnu packages video)
  #:use-module (gnu packages vulkan)
  #:use-module (gnu packages xdisorg)
  #:use-module ((gnu packages nss) #:prefix nss:)
  #:use-module ((gnu packages librewolf) #:prefix lw:))

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
    (propagated-inputs
     (modify-inputs (package-propagated-inputs nss:nss-rapid)
       (replace "nspr" nspr-4.40)))))

(define %librewolf-source-build lw:librewolf)

(define-public librewolf
  (package
    (inherit lw:librewolf)
    (build-system trivial-build-system)
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      #~(begin
          (use-modules (guix build utils))
          (set-path-environment-variable
           "PATH" '("bin") (list #$bash-minimal #$coreutils))
          (copy-recursively #$%librewolf-source-build #$output)
          (let* ((directory (string-append #$output "/lib/librewolf"))
                 (browser (string-append directory "/librewolf"))
                 (probe (string-append directory "/gfxtest")))
            ;; Do not chmod copied links: some intentionally target immutable
            ;; libraries in the native source-built package's closure.
            (make-file-writable browser)
            (make-file-writable probe)
            ;; Retarget the copied absolute launcher and wrapper; the engine
            ;; remains backed by the matched native source-built closure.
            (delete-file (string-append #$output "/bin/librewolf"))
            (symlink browser (string-append #$output "/bin/librewolf"))
            (substitute* browser
              ((#$%librewolf-source-build) #$output)
              (("^export LD_LIBRARY_PATH=\"")
               (string-append "export LD_LIBRARY_PATH=\""
                              #$nss-rapid-3.129 "/lib/nss:"
                              #$nspr-4.40 "/lib:")))
            ;; Firefox 157's combined probe dlopens these libraries.  Without
            ;; this wrapper the native Guix probe reports "libpci missing".
            (unless (file-exists? probe)
              (error "LibreWolf graphics probe is missing" probe))
            (wrap-program probe
              `("LD_LIBRARY_PATH" prefix
                (,(string-append #$(lookup-package-input lw:librewolf "mesa") "/lib")
                 ,(string-append #$pciutils "/lib")
                 ,(string-append #$libdrm "/lib")
                 ,(string-append #$libva "/lib")
                 ,(string-append #$vulkan-loader "/lib"))))
            (invoke (string-append #$output "/bin/librewolf") "--version")))))
    (native-inputs (list bash-minimal coreutils))
    (inputs
     `(("librewolf-source-build" ,lw:librewolf)
       ("nss-rapid" ,nss-rapid-3.129)
       ("nspr" ,nspr-4.40)
       ("mesa" ,(lookup-package-input lw:librewolf "mesa"))
       ("pciutils" ,pciutils)
       ("libdrm" ,libdrm)
       ("libva" ,libva)
       ("vulkan-loader" ,vulkan-loader)))))
