;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Run: guix repl -L . tests/current-package-releases.scm
(define-module (tests current-package-releases))
(use-modules (guix packages)
             (guix base32)
             (guix utils)
             (srfi srfi-64)
             ((securityops packages audio) #:prefix audio:)
             ((securityops packages browsers) #:prefix browsers:)
             ((securityops packages chromium) #:prefix chromium:)
             ((securityops packages reporting) #:prefix reporting:)
             ((securityops packages river) #:prefix river:)
             ((securityops packages security) #:prefix security:)
             ((securityops packages tor) #:prefix tor:)
             ((securityops packages video) #:prefix video:)
             ((securityops packages zabbix) #:prefix zabbix:)
             ((xlibre) #:prefix xlibre:))

(define (run-tests)
  (test-begin "current-package-releases")
  (test-equal "PipeWire stable" "1.6.11"
    (package-version audio:pipewire-latest))
  (test-equal "Arelle stable" "2.47.4"
    (package-version reporting:arelle))
  (test-equal "Chrome stable" "157.0.8103.78-1"
    (package-version browsers:google-chrome-stable))
  (test-equal "portable Chromium stable" "156.0.8078.79-1"
    (package-version chromium:ungoogled-chromium-bin))
  (test-equal "Xwayland stable, not a release candidate" "24.1.14"
    (package-version river:xwayland-latest))
  (test-equal "sdb stable" "2.6.2"
    (package-version security:sdb))
  (test-equal "Tor stable" "0.4.9.16"
    (package-version tor:tor))
  (test-equal "Tor Browser stable" "16.0.1"
    (package-version tor:torbrowser))
  ;; Tor Browser's pinned source bundles ICU data, but Firefox's configure
  ;; still requires a system ICU whose pkg-config metadata meets its minimum.
  (let ((source (package-source tor:torbrowser)))
    (test-equal "Tor Browser pins the source with bundled ICU 78.3"
      (string-append
       "https://archive.torproject.org/tor-package-archive/torbrowser/"
       "16.0.1/src-firefox-tor-browser-153.7.0esr-16.0-1-build2.tar.xz")
      (origin-uri source))
    (test-equal "Tor Browser source digest pins bundled ICU 78.3"
      "1g1mdqk0nxl2v8pn014ym211fx0l43x4gwrs133aqn8wi5fn91dx"
      (bytevector->nix-base32-string (content-hash-value (origin-hash source))))
    (let ((icu (lookup-package-input tor:torbrowser "icu4c")))
      (test-assert "Tor Browser satisfies the Firefox 153 ICU minimum"
        (and icu (version>=? (package-version icu) "78.1")))))
  (test-equal "Tor Browser assets match" "16.0.1"
    (package-version tor:torbrowser-assets))
  (test-equal "yt-dlp stable" "2026.10.26"
    (package-version video:yt-dlp))
  (test-equal "OpenShot stable" "4.1.1"
    (package-version video:openshot))
  (let ((renderer (lookup-package-propagated-input video:mpv "libplacebo")))
    (test-assert "mpv renderer satisfies its upstream minimum"
      (version>=? (package-version renderer) "7.387.0"))
    (test-assert "renderer declares its native Jinja generator"
      (member "python-jinja2"
              (map (lambda (input) (package-name (cadr input)))
                   (package-native-inputs renderer)))))
  (test-equal "XLibre stable" "25.2.3"
    (package-version xlibre:xlibre-server))
  (test-equal "Zabbix stable" "7.4.16"
    (package-version zabbix:zabbix-agentd))
  (let ((runner (test-runner-current)))
    (test-end "current-package-releases")
    (exit (if (zero? (test-runner-fail-count runner)) 0 1))))

(when (string=? (basename (car (command-line))) "current-package-releases.scm")
  (run-tests))
