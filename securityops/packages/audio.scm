;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Explicit audio packages; importing this module does not enable services.

(define-module (securityops packages audio)
  #:use-module (guix gexp)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (guix utils)
  #:use-module ((gnu packages linux) #:prefix guix:))

(define-public pipewire-latest
  (package
    (inherit guix:pipewire)
    (version "1.6.11")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://gitlab.freedesktop.org/pipewire/pipewire.git")
             ;; Upstream stable tag 1.6.11, released 2026-10-29.
             (commit "4287f31510771fc999f8a58a024c81ca10b8d55f")))
       (file-name (git-file-name "pipewire" version))
       (sha256
        (base32 "0940sbgmpn9c1wa2wkfqs7kx7b0zwn2g6zc37b9zz7zgfgg19la0"))))
    (arguments
     (substitute-keyword-arguments (package-arguments guix:pipewire)
       ((#:configure-flags flags
         #~'())
        #~(append #$flags
                  '("-Dtests=enabled")))))
    ;; Upstream LICENSE identifies the ALSA plugin and JACK server exceptions
    ;; to COPYING's MIT license; meson.build specifies their exact versions.
    (license (list license:expat license:lgpl2.1+ license:gpl2))))

(define-public wireplumber-latest
  (package
    ;; Keep the session manager on the same PipeWire API as pipewire-latest.
    (inherit guix:wireplumber)
    (version "0.5.18")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://gitlab.freedesktop.org/pipewire/wireplumber/-/archive/"
             version "/wireplumber-" version ".tar.gz"))
       (file-name (string-append "wireplumber-" version ".tar.gz"))
       (sha256
        (base32 "18c3sjkr5g5j0ib82690hsx59k70zkqq6g2hq60hcmrabdm352lc"))))
    (arguments
     (substitute-keyword-arguments (package-arguments guix:wireplumber)
       ((#:configure-flags flags
         #~'())
        #~(append #$flags
                  '("-Dtests=true" "-Ddbus-tests=true")))))
    (inputs (modify-inputs (package-inputs guix:wireplumber)
              (replace "pipewire" pipewire-latest)))))
