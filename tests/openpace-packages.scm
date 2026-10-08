;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Run: guix repl -L . tests/openpace-packages.scm
(define-module (tests openpace-packages))
(use-modules (guix packages) (guix download) (guix build-system gnu)
             (guix base32) ((guix licenses) #:prefix license:)
             (srfi srfi-1) (srfi srfi-64))

(define (run-tests)
  (test-begin "openpace-packages")
  (let ((interface
         (false-if-exception
          (resolve-interface '(securityops packages openpace)))))
    (test-assert "independent OpenPACE package is available" interface)
    (when interface
      (let* ((pkg (module-ref interface 'openpace))
             (source (package-source pkg))
             (crypto (lookup-package-propagated-input pkg "openssl")))
        (test-equal "pinned library release" "1.1.4" (package-version pkg))
        (test-eq "native GNU build" gnu-build-system (package-build-system pkg))
        (test-equal "library and tools share one output" '("out")
          (package-outputs pkg))
        (test-eq "original source download" url-fetch (origin-method source))
        (test-equal "fixed official source URL"
          "https://codeload.github.com/frankmorgner/openpace/tar.gz/refs/tags/1.1.4"
          (origin-uri source))
        (test-equal "exact source digest"
          "022fpqwpxc31jqvq33y9dpavm0c459cimnwn8jxmr5d8kz5zirzs"
          (bytevector->nix-base32-string (content-hash-value (origin-hash source))))
        (test-equal "no source patch or crypto policy substitution" '()
          (origin-patches source))
        (test-assert "original source snippet is not rewritten"
          (not (origin-snippet source)))
        (test-equal "explicit patched crypto dependency" "3.5.9"
          (package-version crypto))
        (test-equal "only crypto development dependency is propagated" '("openssl")
          (map car (package-propagated-inputs pkg)))
        (test-eq "propagated crypto is the exact private security package"
          (@@ (securityops packages tls-security) openssl-security)
          (let ((entry (assoc-ref (package-propagated-inputs pkg) "openssl")))
            (and entry (car entry))))
        (test-equal "crypto is not duplicated as a local input" '()
          (package-inputs pkg))
        (let ((original
               (@@ (securityops packages openpace) %openssl-original-source))
              (effective (package-source crypto)))
          (test-equal "preserved raw crypto origin keeps the production URL"
            (origin-uri effective) (origin-uri original))
          (test-equal "preserved raw crypto origin keeps the production digest"
            (content-hash-value (origin-hash effective))
            (content-hash-value (origin-hash original)))
          (test-equal "raw preservation alone omits the source patch" '()
            (origin-patches original))
          (test-assert "raw preservation alone omits source transformation"
            (not (origin-snippet original)))
          (test-assert "actual crypto input still retains its Guix patch"
            (pair? (origin-patches effective))))
        (test-assert "GPL3+ license retained"
          (memq license:gpl3+ (package-license pkg)))
        (test-assert "included crypto corresponding source license retained"
          (memq license:asl2.0 (package-license pkg)))
        (test-assert "both section-7 linking permissions described"
          (find (lambda (item)
                  (string=? (license:license-name item)
                            "OpenSSL and OpenSC linking permissions"))
            (package-license pkg))))))
  (let ((runner (test-runner-current)))
    (test-end "openpace-packages")
    (exit (if (zero? (test-runner-fail-count runner)) 0 1))))

(when (string=? (basename (car (command-line))) "openpace-packages.scm")
  (run-tests))
