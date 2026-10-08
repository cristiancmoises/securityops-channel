;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>

(define-module (securityops packages ausweisapp)
  #:use-module ((gnu packages security-token) #:prefix upstream:)
  #:use-module ((gnu packages web) #:prefix upstream:)
  #:use-module (gnu packages qt)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix packages)
  #:use-module (guix utils))

(define llhttp-for-ausweisapp
  (package
    (inherit upstream:llhttp)
    (version "9.4.3")
    (source
      (origin
        (method url-fetch)
        ;; This release tag contains the generated C parser; no npm bootstrap.
        (uri "https://codeload.github.com/nodejs/llhttp/tar.gz/refs/tags/release/v9.4.3")
        (file-name "llhttp-9.4.3.tar.gz")
        (sha256
          (base32 "0fbcydlwn0icniwrrqp7ylh6fx00kzbkxkd1jrsahcbv8g3i7f0y"))))))

(define qtbase-for-ausweisapp
  (package
    (inherit qtbase)
    ;; Preserve Qt 6.9's ABI and check policy: dual-stack UDP and the official
    ;; CVE-2026-76151/CVE-2026-78253 backports.
    (source
      (origin
        (inherit (package-source qtbase))
        (patches
          (append (origin-patches (package-source qtbase))
            (list
              (origin
                (method url-fetch)
                (uri "https://github.com/qt/qtbase/commit/daeb703dea77cb20e02f24c5f76daeb0fbda5c68.patch")
                (sha256
                  (base32 "1w9fba3i1x2izb4xsnfq2abbvr0dqhm0n3mbb8g3dwgscn7z69pn")))
              (origin
                (method url-fetch)
                (uri "https://github.com/qt/qtbase/commit/1472386c9595597f156db68c654f0e0e50bbfd33.patch")
                (sha256
                  (base32 "1i4a4i1flwppa6yi0ppkfncl9gn5avrqpzg466xzjsrpvjgrgd2n")))
              (origin
                (method url-fetch)
                (uri "https://github.com/qt/qtbase/commit/6e8dfbad8e5d30b7e53c88365a77b8b7b9a9206b.patch")
                (sha256
                  (base32 "0rqav85wz5l4s6di0dnlcmsjpla79hg3d87dz6gnbqsbw2kl5bda")))
              (origin
                (method url-fetch)
                (uri "https://github.com/qt/qtbase/commit/50cc08f278c6961d00b5b8bae408d4ccc2fbca4d.patch")
                (sha256
                  (base32 "1q7jj34x38hcyws30lmzaf1xz6p56af9alg40b4kp23796ws8069"))))))))))

(define with-broadcast-qt
  ;; The old derivations remain reusable.  Guix rewrites their runtime
  ;; references to the native replacement, including QML and SVG plugins.
  (package-input-rewriting
    (list (cons qtbase
      (package (inherit qtbase) (replacement qtbase-for-ausweisapp))))))

(define qtsvg-for-ausweisapp
  (package
    (inherit qtsvg)
    (source
      (origin
        (inherit (package-source qtsvg))
        (patches
          (append (origin-patches (package-source qtsvg))
            (list
              (origin
                (method url-fetch)
                (uri "https://github.com/qt/qtsvg/commit/ea44b50c6e61104cadd6b7c8ede92a4108634232.patch")
                (sha256 (base32 "1zk6c6fsah6d8a54p8m66s8ybgfagf71fxjin3j9bqqw3qf5ga8g")))
              (origin
                (method url-fetch)
                (uri "https://github.com/qt/qtsvg/commit/6a6273126770006232e805cf1631f93d4919b788.patch")
                (sha256 (base32 "0xvb9pi8682qqm2lcwrcfy35dwbayfxdqm2cqsf2diy03lzvh33l")))
              (origin
                (method url-fetch)
                (uri "https://github.com/qt/qtsvg/commit/5449aacf8e8cccc155525967dc0f88c1de169fc7.patch")
                (sha256 (base32 "0kz2832zysvf8nr99pibfp8qzy68xggyvn1ph29qvmx8iy6rrn9y")))
              (origin
                (method url-fetch)
                (uri "https://download.qt.io/official_releases/qt/6.10/CVE-2026-8168-qtsvg-6.10-0000.diff")
                (sha256 (base32 "1lda79789z9a4di57prc13ddlg8k6qv5wpxgfb9xz9zwydj1b5fq")))
              ;; Official 6.8 paint-server fix; only two 6.9 context lines differ.
              (local-file "patches/qt-svg-6.9-paintservers.patch")
              (origin
                (method url-fetch)
                (uri "https://download.qt.io/official_releases/qt/6.10/CVE-2026-8168-qtsvg-6.10-0002.diff")
                (sha256 (base32 "17i9avlc9nfy4ljadd0q57ylqh15h5l6286iaz7bq51f8x3j6crj")))
              (origin
                (method url-fetch)
                (uri "https://download.qt.io/official_releases/qt/6.10/CVE-2026-8168-qtsvg-6.10-0003.diff")
                (sha256 (base32 "00ibrn3d52hwab85xrkmv6hcqxk5cjnp3w68rhdrvvpriz6v0bcc")))
              (origin
                (method url-fetch)
                (uri "https://download.qt.io/official_releases/qt/6.10/CVE-2026-8168-qtsvg-6.10-0004.diff")
                (sha256 (base32 "170j83m598j7vkk3jva5ydvq2jfcp56sa169scim6nh825bcq50d"))))))))))

(define qtdeclarative-for-ausweisapp
  (package
    (inherit qtdeclarative)
    (source
      (origin
        (inherit (package-source qtdeclarative))
        (patches
          (append (origin-patches (package-source qtdeclarative))
            (list
              (origin
                (method url-fetch)
                (uri "https://github.com/qt/qtdeclarative/commit/cb44be928d5b30da569f48742dc3f2041c736e15.patch")
                (sha256 (base32 "1qf1hvmkgnzmvajwf8l4xijbdfadzyxdi0kagndqh7dykjj980ig")))
              ;; Exact decoded official Gerrit 690033 revision 99d8ef879911a0f85a5729d058e38f895acc8c37.
              (local-file "patches/qt-quick-richtext-allocation.patch")
              (origin
                (method url-fetch)
                (uri "https://github.com/qt/qtdeclarative/commit/855f02c96d3c089ea7c0010ebbe4b29fab9cc1ba.patch")
                (sha256 (base32 "1lg477cyn3syhz5cjnipqia56c8lf7kcbm26z0by0zfmc0z557x1"))))))))
    ;; QuickVectorImage embeds SVG-private state, so compile against new headers.
    (inputs
      (modify-inputs (package-inputs qtdeclarative)
        (replace "qtsvg" qtsvg-for-ausweisapp)))))

(define %use-safe-svg-default
  #~(lambda _
      (let* ((file "src/ui/qml/UiPluginQml.cpp")
             (old "QSvgRenderer::setDefaultOptions(QtSvg::AssumeTrustedSource);")
             (content (call-with-input-file file
                        (@ (ice-9 textual-ports) get-string-all)))
             (position (string-contains content old)))
        (unless (and position
                  (not (string-contains content old (+ position (string-length old)))))
          (error "Unexpected AusweisApp SVG default source" file))
        (substitute* file
          (("QSvgRenderer::setDefaultOptions\\(QtSvg::AssumeTrustedSource\\);")
            "QSvgRenderer::setDefaultOptions(QtSvg::NoOption);")))))

(define ausweisapp-base
  (package
    (inherit upstream:ausweisapp)
    (version "2.6.0")
    (source
      (origin
        (method url-fetch)
        (uri "https://codeload.github.com/Governikus/AusweisApp/tar.gz/refs/tags/2.6.0")
        (file-name "ausweisapp-2.6.0.tar.gz")
        (sha256
          (base32 "1g3phv4fdspi81379hjv4v4pfwmbr6myv1cd5f43ibmvkbnps4mw"))))
    (arguments
      (substitute-keyword-arguments (package-arguments upstream:ausweisapp)
        ((#:configure-flags flags #~'())
          #~(append #$flags
              ;; DVCS.cmake only sets ARTIFACT_VERSION when Git/Hg metadata
              ;; exists.  The pinned release archive has neither.
              (list #$(string-append "-DARTIFACT_VERSION=" version))))
        ((#:phases phases)
          #~(modify-phases #$phases
            (add-after 'unpack 'use-safe-svg-default
              #$%use-safe-svg-default)
            (add-after 'unpack 'include-datetime-explicitly
              (lambda _
                ;; Qt 6.9 meets the desktop minimum, but does not provide
                ;; QDateTime through the incidental includes of Qt 6.11.
                (substitute* "src/settings/GeneralSettings.cpp"
                  (("#include <QCoreApplication>")
                    "#include <QCoreApplication>\n#include <QDateTime>"))))))))
    (inputs
      (modify-inputs (package-inputs upstream:ausweisapp)
        (replace "openssl" (@@ (securityops packages tls-security) openssl-security))
        (replace "qtsvg" qtsvg-for-ausweisapp)
        (replace "qtdeclarative" qtdeclarative-for-ausweisapp)
        (prepend llhttp-for-ausweisapp)))))

(define-public ausweisapp
  (with-broadcast-qt ausweisapp-base))

;; Upstream only generates its Qt/C++ test executables in Debug builds.
;; Keep this acceptance variant separate from the optimized desktop package.
(define ausweisapp-unit-tests
  (with-broadcast-qt
   (package
    (inherit ausweisapp)
    (name "ausweisapp-unit-tests")
    (inputs
      (modify-inputs (package-inputs ausweisapp)
        (append (@ (gnu packages qt) qtconnectivity))))
    (arguments
      (substitute-keyword-arguments (package-arguments ausweisapp)
        ((#:build-type build-type "RelWithDebInfo") "Debug")
        ((#:configure-flags flags #~'())
          ;; Hundreds of test links duplicate the static QML libraries.  Keep
          ;; Debug, -O0 and assertions, but omit debug-symbol duplication.
          #~(append #$flags (list "-DCMAKE_CXX_FLAGS_DEBUG=-O0 -g0")))
        ((#:phases phases)
          #~(modify-phases #$phases
            (add-before 'check 'setup-private-test-environment
              (lambda* (#:key inputs #:allow-other-keys)
                ;; QStandardPaths tests must not write to /homeless-shelter.
                (let ((state (string-append (getcwd) "/test-state")))
                  (for-each
                    (lambda (variable)
                      (let ((directory
                              (string-append state "/"
                                (string-downcase variable))))
                        (mkdir-p directory)
                        (chmod directory #o700)
                        (setenv variable directory)))
                    '("HOME" "XDG_CONFIG_HOME" "XDG_DATA_HOME"
                      "XDG_CACHE_HOME" "XDG_RUNTIME_DIR")))
                ;; Debug tests run before qt-wrap; discover the actual SVG
                ;; decoder and platform plugins used by installed programs.
                (setenv "QT_PLUGIN_PATH"
                  (string-append
                    (assoc-ref inputs "qtsvg") "/lib/qt6/plugins:"
                    (assoc-ref inputs "qtbase") "/lib/qt6/plugins")))))))))))
