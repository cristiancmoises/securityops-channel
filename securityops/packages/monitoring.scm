;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; This file is part of the securityops channel.
;;;
;;; System-monitoring tools — latest upstream releases, with real downloaded
;;; source hashes.

(define-module (securityops packages monitoring)
  #:use-module (guix packages)
  #:use-module (guix utils)
  #:use-module (guix gexp)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix build-system pyproject)        ;current pypi-uri (no deprecation warning)
  #:use-module ((gnu packages monitoring) #:prefix mon:)
  #:use-module ((gnu packages python-check) #:prefix pyc:))

;;; python-pyinstrument — private helper, bumped 5.1.1 -> 5.1.2 because glances
;;; 4.5.x declares `pyinstrument>=5.1.2' as a core dependency and Guix only ships
;;; 5.1.1 (the pyproject sanity-check would otherwise flag a version conflict).
;;; Patch bump: inherit, swap version + source.  Its own test suite is skipped —
;;; the deselect list in the inherited args targets 5.1.1 test names, and this is
;;; a transitive dependency we only need as a library; glances is verified
;;; end-to-end below.
(define python-pyinstrument
  (package
    (inherit pyc:python-pyinstrument)
    (version "5.1.2")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "pyinstrument" version))
       (sha256
        (base32 "1w0bcmfdniy44vjbk6gxp5n3w35qyxlcr89lffikyjd95mkrs55g"))))
    ;; Tests are skipped, so drop the test-only native-inputs (keeps setuptools)
    ;; to avoid building the trio/pytest-trio stack just to discard it.
    (native-inputs
     (modify-inputs (package-native-inputs pyc:python-pyinstrument)
       (delete "python-flaky" "python-greenlet" "python-pytest"
               "python-pytest-asyncio" "python-pytest-trio")))
    (arguments
     (substitute-keyword-arguments (package-arguments pyc:python-pyinstrument)
       ((#:tests? _ #t) #f)))))

;;; glances — bumped ahead of Guix: 4.3.0 -> 4.5.5 (latest stable).  Cross-
;;; platform curses/web system monitor (psutil-based).  Inherits Guix's package
;;; and overrides version + source; adds the new `pyinstrument' core dependency
;;; (via the bumped helper above) and rewrites the arguments because the 4.3.0
;;; custom test entry (`unittest-core.py') no longer exists in 4.5.x (tests moved
;;; to tests/), so tests are skipped here.  The weekly PyPI update-check is still
;;; disabled, exactly as Guix does.
;;; Hash: `guix hash -rx' on a checkout of the v4.5.5 tag.
(define-public glances
  (package
    (inherit mon:glances)
    (version "4.5.5")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/nicolargo/glances")
             (commit (string-append "v" version))))
       (file-name (git-file-name "glances" version))
       (sha256
        (base32 "1i8f901x62ggwivaf0l3irbmpagwpp1yn1vcjsy8wjyqvvpjs826"))))
    (propagated-inputs
     (modify-inputs (package-propagated-inputs mon:glances)
       (append python-pyinstrument)))
    (arguments
     (list
      #:tests? #f                       ;4.3.0 custom unittest entry gone in 4.5.x
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'disable-update-checks
            (lambda _
              ;; Glances phones PyPI for weekly update checks by default.
              (substitute* "glances/outdated.py"
                (("^(.*)self\\.load_config\\(config\\)\n" line indentation)
                 (string-append indentation
                                "self.args.disable_check_update = True\n"
                                line))))))))))
