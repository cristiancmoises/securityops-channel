;;; SPDX-License-Identifier: GPL-3.0-or-later

(define-module (securityops packages reporting)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module (guix build-system pyproject)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages version-control)
  #:use-module (gnu packages check)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-build)
  #:use-module (gnu packages python-check)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages python-web)
  #:use-module (gnu packages python-crypto)
  #:use-module (gnu packages time)
  #:use-module (gnu packages tcl)
  #:use-module (gnu packages xorg)
  #:use-module (gnu packages tls)
  #:use-module (gnu packages xml)
  #:use-module (srfi srfi-1))

(define %bounded-build-environment
  (@@ (securityops packages xml-security) %bounded-build-environment))

(define python-setuptools-for-arelle
  (package
    (inherit python-setuptools)
    (version "84.2.1")
    (source
     (origin
       (inherit (package-source python-setuptools))
       (uri (pypi-uri "setuptools" version))
       (patches
        (append (origin-patches (package-source python-setuptools))
                (list (local-file
                       "patches/setuptools-test-build-meta-spawn.patch"))))
       (sha256
        (base32 "1g6nciflz2d6skj16hqd0w9y113bm1jr6hglc1lsc2ia96sv7y1z"))))
    (native-inputs
     (modify-inputs (package-native-inputs python-setuptools)
       (append python-coverage)))
    (arguments
     (substitute-keyword-arguments (package-arguments python-setuptools)
       ((#:phases phases)
        #~(modify-phases #$phases
            (add-before 'unpack 'bound-build-resources
              #$(%bounded-build-environment))
            (add-after 'configure-tests 'make-upstream-fixtures-visible
              (lambda _
                ;; 84 no longer installs its private test package.
                (setenv "PYTHONPATH"
                        (string-append (getcwd) ":"
                                       (getenv "GUIX_PYTHONPATH")))))
            ;; Setuptools 82 removed pkg_resources entirely.
            (delete 'drop-platformdirs-requirement)))))))

(define python-vcs-versioning-for-arelle
  (package
    (name "python-vcs-versioning")
    (version "2.6.0")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "vcs_versioning" version))
       (sha256
        (base32 "03yn2qjhs5jxdx99w3pnaz0swrlw9k1k2v3gzaibrn72i291bs92"))))
    (build-system pyproject-build-system)
    (native-inputs
     (list python-setuptools-for-arelle python-pytest python-pytest-timeout
           git-minimal))
    (propagated-inputs (list python-packaging))
    (arguments
     (list
      #:test-flags
      #~(list "testing_vcs/test_config.py" "testing_vcs/test_version.py"
              "testing_vcs/test_version_schemes.py")
      #:phases
      #~(modify-phases %standard-phases
          (add-before 'unpack 'bound-build-resources
            #$(%bounded-build-environment))
          (add-before 'check 'configure-tests
            (lambda _
              (setenv "HOME" (getcwd))
              (setenv "PYTHONPATH" (getenv "GUIX_PYTHONPATH")))))))
    (home-page "https://github.com/pypa/setuptools-scm")
    (synopsis "Derive Python package versions from version control metadata")
    (description "Vcs-versioning derives Python package versions from version
control metadata and distribution archives.")
    (license license:expat)))

(define python-setuptools-scm-for-arelle
  (package
    (inherit python-setuptools-scm)
    (version "10.3.4")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "setuptools_scm" version))
       (sha256
        (base32 "1llxlr3p9mvrp7ks9bvkawbb5hipwjm2z4ay420qfq25qazji7x6"))))
    (native-inputs (list python-pytest python-pytest-timeout git-minimal))
    (propagated-inputs
     (list python-packaging python-setuptools-for-arelle
           python-vcs-versioning-for-arelle))
    (arguments
     (list
      #:test-flags
      #~(list "testing_scm/test_basic_api.py" "testing_scm/test_config.py"
              "testing_scm/test_functions.py" "testing_scm/test_cli.py")
      #:phases
      #~(modify-phases %standard-phases
          (add-before 'unpack 'bound-build-resources
            #$(%bounded-build-environment))
          (add-before 'check 'configure-tests
            (lambda _
              (setenv "HOME" (getcwd))
              (setenv "PYTHONPATH" (getenv "GUIX_PYTHONPATH")))))))))

(define python-hatchling-for-arelle
  (package
    (inherit python-hatchling)
    (version "1.33.0")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "hatchling" version))
       (sha256
        (base32 "1vvvc8db7v4mfn7ksmbygzwyjhayz2b9agmpwmfzzz2lspa2nhjc"))))
    (propagated-inputs
     (modify-inputs (package-propagated-inputs python-hatchling)
       (append python-tomlkit)))
    (arguments
     (substitute-keyword-arguments (package-arguments python-hatchling)
       ((#:phases phases #~%standard-phases)
        #~(modify-phases #$phases
            (add-before 'unpack 'bound-build-resources
              #$(%bounded-build-environment))))))))

(define python-hatch-fancy-pypi-readme-for-arelle
  (package
    (name "python-hatch-fancy-pypi-readme")
    (version "25.1.0")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "hatch_fancy_pypi_readme" version))
       (sha256
        (base32 "1y76b7yj67k0amiy3r8za66l2aps5pjnlijnwjnf966cyq8ffabr"))))
    (build-system pyproject-build-system)
    (native-inputs
     (list python-hatchling-for-arelle python-pytest python-pypa-build
           python-wheel))
    (propagated-inputs (list python-hatchling-for-arelle))
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          (add-before 'check 'disable-test-build-isolation
            (lambda _
              (substitute* "tests/test_end_to_end.py"
                (("args = \\[\"-w\"\\]")
                 "args = [\"-w\", \"--no-isolation\"]")))))))
    (home-page "https://github.com/hynek/hatch-fancy-pypi-readme")
    (synopsis "Hatch metadata hook for PyPI readmes")
    (description "Hatch-fancy-pypi-readme composes Python package readmes from
source fragments as a Hatch metadata hook.")
    (license license:expat)))

(define python-filelock-for-arelle
  (package
    (inherit python-filelock-next)
    (version "4.2.10")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "filelock" version))
       (sha256
        (base32 "0pdxjg74vplg7ls5ylf2nf60dbfv2m5w0cg2n0xlnzzyig5w1hzw"))))
    (native-inputs
     (modify-inputs (package-native-inputs python-filelock-next)
       (replace "python-hatchling" python-hatchling-for-arelle)
       (append python-hatch-fancy-pypi-readme-for-arelle)))
    (license license:expat)
    (arguments
     (substitute-keyword-arguments (package-arguments python-filelock-next)
       ((#:phases phases #~%standard-phases)
        #~(modify-phases #$phases
            (add-before 'unpack 'bound-build-resources
              #$(%bounded-build-environment))
            (add-before 'check 'bound-test-allocator
              (lambda _
                ;; The 100-thread contention checks otherwise reserve a
                ;; separate glibc arena per thread beyond the address cap.
                (setenv "MALLOC_ARENA_MAX" "2")))))))))


(define python-lxml-for-arelle
  (package
    (inherit python-lxml)
    (version "6.1.3")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "lxml" version))
       (sha256
        (base32 "08fxv750ffvh4p5g2xghw169ncxjwgm9sz9g7dpm64fmvna2s8j5"))))
    (native-inputs
     (modify-inputs (package-native-inputs python-lxml)
       (append python-cython)))
    (inputs
     (modify-inputs (package-inputs python-lxml)
       (replace "libxml2"
                (@@ (securityops packages xml-security) libxml2-security))
       (replace "libxslt"
                (@@ (securityops packages xml-security) libxslt-security))))
    (arguments
     (substitute-keyword-arguments (package-arguments python-lxml)
       ((#:phases phases)
        #~(modify-phases #$phases
            (add-before 'unpack 'bound-build-resources
              #$(%bounded-build-environment))))))))

(define python-pillow-for-arelle
  (package
    (inherit python-pillow)
    (version "13.0.0")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "pillow" version))
       (sha256
        (base32 "041mpvk6yajs590bqj2psnjvdsm43flcjw21sxb773qpb2i1pkfd"))))
    (license (license:x11-style
              "https://github.com/python-pillow/Pillow/blob/13.0.0/LICENSE"
              "MIT-CMU License"))
    (arguments
     (substitute-keyword-arguments (package-arguments python-pillow)
       ((#:phases phases)
        #~(modify-phases #$phases
            (add-before 'unpack 'bound-build-resources
              ;; The upstream WebP dimension checks allocate multi-GiB images.
              #$(%bounded-build-environment 4294967296))
            (add-before 'build 'bound-compiler-thread-pools
              (lambda _
                ;; Extension and compiler thread pools are nested upstream.
                (setenv "MAX_CONCURRENCY"
                        (number->string (min 2 (parallel-job-count))))
                (setenv "MALLOC_ARENA_MAX" "2")))))))))

(define %with-security-tls
  (package-input-rewriting
   (list (cons openssl
               (@@ (securityops packages tls-security)
                   openssl-with-security-replacement)))))

(define python-lxml-with-security-replacement
  (package
    (inherit python-lxml)
    ;; Input rewriting does not recurse into a replacement's own closure.
    (replacement (%with-security-tls python-lxml-for-arelle))))

(define libxml2-with-security-replacement
  (package
    (inherit libxml2)
    (replacement
     (%with-security-tls
      (@@ (securityops packages xml-security) libxml2-security)))))

(define tktable-for-arelle
  (package
    (name "tktable")
    (version "2.12.1")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://github.com/bohagan1/TkTable/releases/"
                           "download/tktable-2-12-1/tktable-" version "-src.tar.gz"))
       (sha256
        (base32 "111in6md3zgs4dj1j1i8nagcrcp8l2gg3zdbzlzjq6j7r7fc76vw"))))
    (build-system gnu-build-system)
    (native-inputs (list xorg-server-for-tests))
    (inputs (list tcl tk))
    (arguments
     (list
      #:test-target "test"
      #:make-flags
      #~(list (string-append "TCLSH_ENV=TCL_LIBRARY=" #$tcl "/lib/tcl8.6")
              (string-append "TCLLIBPATH=" (getcwd) " " #$tk "/lib"))
      #:configure-flags
      #~(list (string-append "--libdir=" #$output "/lib")
              (string-append "--with-tcl=" #$tcl "/lib")
              (string-append "--with-tk=" #$tk "/lib"))
      #:phases
      #~(modify-phases %standard-phases
          (add-before 'unpack 'bound-build-resources
            #$(%bounded-build-environment))
          (add-before 'check 'start-test-display
            (lambda* (#:key inputs #:allow-other-keys)
              (setenv "DISPLAY" ":1")
              (let ((pid (primitive-fork)))
                (when (zero? pid)
                  (execl (search-input-file inputs "/bin/Xvfb")
                         "Xvfb" ":1" "-screen" "0" "800x600x24"
                         "-nolisten" "tcp")))
              (let loop ((remaining 50))
                (unless (file-exists? "/tmp/.X11-unix/X1")
                  (when (zero? remaining) (error "Xvfb did not become ready"))
                  (usleep 100000)
                  (loop (- remaining 1))))
              ;; The historical Tcl runner reports failures but does not
              ;; reliably propagate them to make's exit status.
              (substitute* "tests/all.tcl"
                (("::tcltest::cleanupTests 1")
                 (string-append "set failures $::tcltest::numTests(Failed)\n"
                                "::tcltest::cleanupTests 1\n"
                                "exit [expr {$failures != 0}]"))))))))
    (home-page "https://github.com/bohagan1/TkTable")
    (synopsis "Table widget for Tcl/Tk")
    (description "TkTable provides an editable table and matrix widget for
Tcl/Tk applications, including the Arelle graphical interface.")
    (license license:tcl/tk)))

(define %arelle-runtime-packages
  (list python-bottle python-certifi python-filelock-for-arelle python-isodate
        python-jaconv python-jsonschema python-lxml-for-arelle python-numpy
        python-openpyxl python-pillow-for-arelle python-pyparsing python-dateutil
        python-regex python-truststore python-typing-extensions))

(define %arelle-runtime-labels
  (delete-duplicates
   (append '("python:tk")
           (map package-name %arelle-runtime-packages)
           (map car (append-map package-transitive-propagated-inputs
                                %arelle-runtime-packages)))))

(define arelle-base
  (package
    (name "arelle")
    (version "2.47.4")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "arelle_release" version))
       (sha256
        (base32 "053sqf8san3dbd8gh4c8h36g78zfysprqi223sr7as9a6v0l4giz"))))
    (build-system pyproject-build-system)
    (native-inputs
     `(("python-setuptools" ,python-setuptools-for-arelle)
       ("python-setuptools-scm" ,python-setuptools-scm-for-arelle)
       ("python-wheel" ,python-wheel)
       ("python-pytest" ,python-pytest)
       ("upstream-tests" ,(origin
                   (method url-fetch)
                   (uri (string-append "https://github.com/Arelle/Arelle/"
                                       "archive/refs/tags/2.47.4.tar.gz"))
                   (sha256
                    (base32 "0a9pazaksyyj2mz0yz47h2nzpd2cf98x7c3z4j7pa4dp771qvfb1"))))))
    (propagated-inputs
     (cons `("python:tk" ,python "tk")
           (map (lambda (package) (list (package-name package) package))
                %arelle-runtime-packages)))
    (inputs (list tktable-for-arelle))
    (arguments
     (list
      #:sanity-check.py (local-file "../../tests/arelle-sanity.py")
      ;; Exercise XML/XBRL validation, values, XPath functions, model and
      ;; plugin management and the offline web cache.  Live conformance-suite
      ;; downloads and optional third-party plugin integrations are separate.
      #:test-flags
      #~(map (lambda (name)
               (string-append "tests/unit_tests/arelle/test_" name ".py"))
             '("qname" "modelvalue" "xmlvalidate" "xmlvalidateparticles"
               "validatexbrlcalcs" "validatexbrldts" "functionfn" "xmlutil"
               "pluginmanager" "modelmanager" "webcache" "xhtmlinlineutil"))
      #:phases
      #~(modify-phases %standard-phases
          (add-before 'unpack 'bound-build-resources
            #$(%bounded-build-environment))
          (add-after 'unpack 'unpack-upstream-tests
            (lambda* (#:key inputs #:allow-other-keys)
              (invoke "tar" "xf" (assoc-ref inputs "upstream-tests")
                      "--strip-components=1" "Arelle-2.47.4/tests/unit_tests"
                      "Arelle-2.47.4/tests/__init__.py"
                      "Arelle-2.47.4/conftest.py")))
          (add-after 'unpack 'replace-native-tktable-payload
            (lambda* (#:key inputs #:allow-other-keys)
              ;; The sdist's existing SOURCES list otherwise omits new data.
              (substitute* "MANIFEST.in"
                (("^prune docs")
                 (string-append "include arelle/resources/libs/TkTable/"
                                "linux-x86_64/license.txt\nprune docs")))
              ;; Preserve platform selection and Tcl scripts, replacing
              ;; only Linux's bundled binaries with the source-built widget.
              (let ((directory "arelle/resources/libs/TkTable/linux-x86_64"))
                (for-each delete-file (find-files directory "\\.so$"))
                (delete-file (string-append directory "/pkgIndex.tcl"))
                (for-each
                 (lambda (file)
                   (copy-file file (string-append directory "/" (basename file))))
                 (find-files (string-append (assoc-ref inputs "tktable") "/lib")
                             "^(libTktable.*\\.so|pkgIndex\\.tcl|license\\.txt)$")))))
          (add-before 'wrap 'limit-runtime-python-path
            (lambda* (#:key inputs outputs #:allow-other-keys)
              ;; Standard wrapping also captures native build tools.  Keep
              ;; only the application and its transitive runtime dependencies.
              (setenv "ARELLE_BUILD_PYTHONPATH" (getenv "GUIX_PYTHONPATH"))
              (let ((site (string-append "/lib/python"
                                         (python-version (assoc-ref inputs "python"))
                                         "/site-packages")))
                (setenv "GUIX_PYTHONPATH"
                        (string-join
                         (cons (string-append (assoc-ref outputs "out") site)
                               (map (lambda (input)
                                      (string-append (cdr input) site))
                                    (filter
                                     (lambda (input)
                                       (member (car input)
                                               '#$%arelle-runtime-labels))
                                     inputs)))
                         ":")))))
          (add-after 'wrap 'restore-check-python-path
            (lambda _
              ;; Pyproject's check phase follows wrapping and still needs
              ;; pytest-guix and the upstream build/test dependencies.
              (setenv "GUIX_PYTHONPATH" (getenv "ARELLE_BUILD_PYTHONPATH"))
              (unsetenv "ARELLE_BUILD_PYTHONPATH")))
          (add-after 'wrap 'add-cli-alias
            (lambda* (#:key outputs #:allow-other-keys)
              (symlink "arelleCmdLine"
                       (string-append (assoc-ref outputs "out")
                                      "/bin/arelle")))))))
    (home-page "https://arelle.org/")
    (synopsis "XBRL validation and processing platform")
    (description "Arelle validates and processes XBRL reports through a command
line interface, Python library and extensible plugin framework.  It includes
standard taxonomy schemas and supports local offline validation.")
    (license license:asl2.0)))

(define-public arelle
  (%with-security-tls
   ((package-input-rewriting
     ;; Existing runtime dependencies retain native test-tool wrappers
     ;; in their closures.  Replace their dormant old lxml as well.
     (list (cons python-lxml python-lxml-with-security-replacement)
           (cons libxml2 libxml2-with-security-replacement)))
    arelle-base)))
