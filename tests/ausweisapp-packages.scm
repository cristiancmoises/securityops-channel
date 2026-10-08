;;; SPDX-License-Identifier: GPL-3.0-or-later
(define-module (tests ausweisapp-packages))
(use-modules (guix packages) (guix base32) (guix gexp) (guix hash)
             (guix build utils) (ice-9 textual-ports)
             (srfi srfi-1) (srfi srfi-64))

(define (patch-hash patch)
  (bytevector->nix-base32-string
    (if (origin? patch)
        (content-hash-value (origin-hash patch))
        (file-hash* (local-file-absolute-file-name patch) #:recursive? #f))))

(define (run-tests)
  (test-begin "ausweisapp-packages")
  (let* ((interface
          (false-if-exception
            (resolve-interface '(securityops packages ausweisapp))))
         (desktop (and interface (module-ref interface 'ausweisapp #f))))
    (test-assert "desktop is a usable package" (package? desktop))
    (when (package? desktop)
      (test-equal "released desktop version" "2.6.0" (package-version desktop))
      (test-equal "current HTTP parser" "9.4.3"
        (package-version (lookup-package-input desktop "llhttp")))
      (test-equal "supported OpenSSL runtime" "3.5.9"
        (package-version (lookup-package-input desktop "openssl")))
      (let* ((qt (lookup-package-input desktop "qtbase"))
             (fixed (package-replacement qt))
             (original (@ (gnu packages qt) qtbase)))
        (test-assert "Qt has the native dual-stack broadcast replacement"
          (package? fixed))
        (when (package? fixed)
          (test-equal "backport retains the Qt source version" "6.9.2"
            (package-version fixed))
          (test-equal "all four official Qt corrections are pinned"
            '("https://github.com/qt/qtbase/commit/daeb703dea77cb20e02f24c5f76daeb0fbda5c68.patch"
              "https://github.com/qt/qtbase/commit/1472386c9595597f156db68c654f0e0e50bbfd33.patch"
              "https://github.com/qt/qtbase/commit/6e8dfbad8e5d30b7e53c88365a77b8b7b9a9206b.patch"
              "https://github.com/qt/qtbase/commit/50cc08f278c6961d00b5b8bae408d4ccc2fbca4d.patch")
            (map origin-uri
              (filter origin? (origin-patches (package-source fixed)))))
          (test-equal "official patch content hashes are pinned"
            '("1w9fba3i1x2izb4xsnfq2abbvr0dqhm0n3mbb8g3dwgscn7z69pn"
              "1i4a4i1flwppa6yi0ppkfncl9gn5avrqpzg466xzjsrpvjgrgd2n"
              "0rqav85wz5l4s6di0dnlcmsjpla79hg3d87dz6gnbqsbw2kl5bda"
              "1q7jj34x38hcyws30lmzaf1xz6p56af9alg40b4kp23796ws8069")
            (map (lambda (patch)
                   (bytevector->nix-base32-string
                     (content-hash-value (origin-hash patch))))
              (filter origin? (origin-patches (package-source fixed)))))
          (test-equal "inherited Guix patches remain first and unchanged"
            (origin-patches (package-source original))
            (take (origin-patches (package-source fixed))
              (length (origin-patches (package-source original)))))
          (test-equal "native Qt flags and check policy are unchanged"
            (package-arguments original) (package-arguments fixed))
          (test-equal "native Qt test inputs are unchanged"
            (package-native-inputs original) (package-native-inputs fixed))))
      (for-each
        (lambda (name)
          (test-assert (string-append name " uses the same Qt replacement graph")
            (package?
              (package-replacement
                (lookup-package-input
                  (lookup-package-input desktop name) "qtbase")))))
        '("qtdeclarative" "qtsvg"))
      (let* ((svg (lookup-package-input desktop "qtsvg"))
             (qml (lookup-package-input desktop "qtdeclarative")))
        (for-each
          (lambda (fixed original urls hashes local-name)
            (let ((patches (origin-patches (package-source fixed)))
                  (name (package-name fixed)))
              (test-equal (string-append name " retains inherited source version")
                "6.9.2" (package-version fixed))
              (test-equal (string-append name " official patch URLs are pinned")
                urls (map origin-uri (filter origin? patches)))
              (test-equal (string-append name " local patch identity is pinned")
                (list local-name)
                (map (lambda (patch) (basename (local-file-file patch)))
                  (filter local-file? patches)))
              (test-equal (string-append name " patch content hashes are pinned")
                hashes
                (map patch-hash
                  (filter (lambda (patch) (or (origin? patch) (local-file? patch)))
                    patches)))
              (test-equal (string-append name " inherited patches remain first")
                (origin-patches (package-source original))
                (take patches (length (origin-patches (package-source original)))))
              (test-equal (string-append name " native flags and checks are unchanged")
                (package-arguments original) (package-arguments fixed))
              (test-equal (string-append name " native test inputs are unchanged")
                (map (lambda (input)
                       (list (car input) (package-name (cadr input))
                         (package-version (cadr input))
                         (package-source (cadr input))))
                  (package-native-inputs original))
                (map (lambda (input)
                       (list (car input) (package-name (cadr input))
                         (package-version (cadr input))
                         (package-source (cadr input))))
                  (package-native-inputs fixed)))))
          (list svg qml)
          (list (@ (gnu packages qt) qtsvg) (@ (gnu packages qt) qtdeclarative))
          (list
            '("https://github.com/qt/qtsvg/commit/ea44b50c6e61104cadd6b7c8ede92a4108634232.patch"
              "https://github.com/qt/qtsvg/commit/6a6273126770006232e805cf1631f93d4919b788.patch"
              "https://github.com/qt/qtsvg/commit/5449aacf8e8cccc155525967dc0f88c1de169fc7.patch"
              "https://download.qt.io/official_releases/qt/6.10/CVE-2026-8168-qtsvg-6.10-0000.diff"
              "https://download.qt.io/official_releases/qt/6.10/CVE-2026-8168-qtsvg-6.10-0002.diff"
              "https://download.qt.io/official_releases/qt/6.10/CVE-2026-8168-qtsvg-6.10-0003.diff"
              "https://download.qt.io/official_releases/qt/6.10/CVE-2026-8168-qtsvg-6.10-0004.diff")
            '("https://github.com/qt/qtdeclarative/commit/cb44be928d5b30da569f48742dc3f2041c736e15.patch"
              "https://github.com/qt/qtdeclarative/commit/855f02c96d3c089ea7c0010ebbe4b29fab9cc1ba.patch"))
          (list
            '("1zk6c6fsah6d8a54p8m66s8ybgfagf71fxjin3j9bqqw3qf5ga8g"
              "0xvb9pi8682qqm2lcwrcfy35dwbayfxdqm2cqsf2diy03lzvh33l"
              "0kz2832zysvf8nr99pibfp8qzy68xggyvn1ph29qvmx8iy6rrn9y"
              "1lda79789z9a4di57prc13ddlg8k6qv5wpxgfb9xz9zwydj1b5fq"
              "1iv241zc5p18552fr0vxk05zcjqrlx132sp72rxyn9h77ydm9ggx"
              "17i9avlc9nfy4ljadd0q57ylqh15h5l6286iaz7bq51f8x3j6crj"
              "00ibrn3d52hwab85xrkmv6hcqxk5cjnp3w68rhdrvvpriz6v0bcc"
              "170j83m598j7vkk3jva5ydvq2jfcp56sa169scim6nh825bcq50d")
            '("1qf1hvmkgnzmvajwf8l4xijbdfadzyxdi0kagndqh7dykjj980ig"
              "0jrrdbgwbij3a97x76znaq32ws2q69f9fsryr7spkc4r6g6a50ih"
              "1lg477cyn3syhz5cjnipqia56c8lf7kcbm26z0by0zfmc0z557x1"))
          '("qt-svg-6.9-paintservers.patch" "qt-quick-richtext-allocation.patch"))
        (test-assert "native QML consumes the exact patched SVG source"
          (eq? (package-source svg)
            (package-source (lookup-package-input qml "qtsvg")))))
      (let* ((module (resolve-module '(securityops packages ausweisapp)))
             (phase (module-ref module '%use-safe-svg-default #f)))
        (test-assert "native source contains the fail-closed SVG default phase"
          (gexp? phase))
        (when (gexp? phase)
          (let ((directory
                  (mkdtemp (string-append (or (getenv "TMPDIR") "/tmp")
                            "/ausweisapp-source.XXXXXX")))
                (apply-phase
                  (eval (gexp->approximate-sexp phase)
                    (current-module)))
                (old "QSvgRenderer::setDefaultOptions(QtSvg::AssumeTrustedSource);"))
            (with-directory-excursion directory
              (mkdir-p "src/ui/qml")
              (call-with-output-file "src/ui/qml/UiPluginQml.cpp"
                (lambda (port) (display old port)))
              (apply-phase)
              (test-equal "actual source phase selects normal untrusted SVG defaults"
                "QSvgRenderer::setDefaultOptions(QtSvg::NoOption);"
                (call-with-input-file "src/ui/qml/UiPluginQml.cpp" get-string-all))
              (for-each
                (lambda (content)
                  (call-with-output-file "src/ui/qml/UiPluginQml.cpp"
                    (lambda (port) (display content port)))
                  (test-error "unexpected SVG-option source fails closed" #t
                    (apply-phase))
                  (test-equal "rejected source is not partially rewritten"
                    content
                    (call-with-input-file "src/ui/qml/UiPluginQml.cpp" get-string-all)))
                (list "missing marker" (string-append old "\n" old)))))))
      (test-assert "no older desktop replacement"
        (not (package-replacement desktop)))))
  (let ((runner (test-runner-current)))
    (test-end "ausweisapp-packages")
    (exit (if (zero? (test-runner-fail-count runner)) 0 1))))

(when (string=? (basename (car (command-line))) "ausweisapp-packages.scm")
  (run-tests))
