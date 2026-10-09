;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; This file is part of the securityops channel.
;;;
;;; Web browsers.  Depends on the nonguix channel for google-chrome.

(define-module (securityops packages browsers)
  #:use-module (guix gexp)
  #:use-module (guix packages)
  #:use-module (guix utils)
  #:use-module (securityops packages librewolf)
  #:use-module (securityops packages chromium)
  #:use-module ((gnu packages chromium) #:prefix cr:)
  #:use-module ((nongnu packages chrome) #:prefix chrome:)
  #:re-export (librewolf ungoogled-chromium-bin))

;;; The source-built variant follows Guix; the portable upstream build has an
;;; independent release schedule and is maintained in the chromium module.
(define-public ungoogled-chromium cr:ungoogled-chromium)

;;; Stable Linux release verified against Google's version-history service.
;;; Keep the wrapper plan aligned with the ELF files in the downloaded archive.
(define-public google-chrome-stable
  (let ((base chrome:google-chrome-stable))
    (package
      (inherit base)
      (version "155.0.8059.39-1")
      (source
       (origin
         (inherit (package-source base))
         (uri (string-append
               "https://dl.google.com/linux/chrome/deb/pool/main/g/"
               "google-chrome-stable/google-chrome-stable_"
               version "_amd64.deb"))
         (sha256
          (base32 "0f0bxnsn11a9wgz76z1bijgrpai75n42q1hf0ngrq5v6rpra12n5"))))
      (arguments
       (substitute-keyword-arguments (package-arguments base)
         ((#:phases phases)
          #~(modify-phases #$phases
              (replace 'patch-assets
                (lambda _
                  (let ((exe (string-append #$output "/bin/google-chrome")))
                    ;; Keep the portal desktop ID and the legacy default-browser
                    ;; ID.  Rewrite only the executable, preserving %U and the
                    ;; arguments of the new-window and incognito actions.
                    (substitute* '("usr/share/applications/google-chrome.desktop"
                                   "usr/share/applications/com.google.Chrome.desktop")
                      (("^Exec=[^[:space:]]+")
                       (string-append "Exec=" exe)))
                    ;; Retain the remaining adjustments from nonguix's phase.
                    (substitute* "opt/google/chrome/google-chrome"
                      (("CHROME_WRAPPER")
                       "WRAPPER"))
                    (substitute* (string-append
                                  "usr/share/gnome-control-center/"
                                  "default-apps/google-chrome.xml")
                      (("/opt/google/chrome/google-chrome")
                       exe)))))))
         ((#:wrapper-plan _)
          #~(let ((path "opt/google/chrome/"))
              (map (lambda (file)
                     (string-append path file))
                   '("chrome" "chrome-management-service"
                     "chrome-sandbox"
                     "chrome_crashpad_handler"
                     "libLiteRtWebGpuAccelerator.so"
                     "liboptimization_guide_internal.so"
                     "libqt5_shim.so"
                     "libqt6_shim.so"
                     "libvk_swiftshader.so"
                     "libvulkan.so.1"
                     "WidevineCdm/_platform_specific/linux_x64/libwidevinecdm.so")))))))))
