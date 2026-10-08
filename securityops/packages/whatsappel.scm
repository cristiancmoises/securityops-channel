;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>

(define-module (securityops packages whatsappel)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix build-system emacs)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages guile)
  #:use-module (gnu packages python)
  #:use-module (gnu packages shells)
  #:use-module (gnu packages sqlite)
  #:use-module (gnu packages tls)
  #:use-module (gnu packages version-control)
  #:use-module (gnu packages video))

(define-public whatsappel
  (package
    (name "whatsappel")
    (version "3.3.1")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://git.securityops.co/cristiancmoises/whatsappel/archive/"
             "25e0edd285058842022cec20729ac53fd9eed964.tar.gz"))
       (file-name (string-append name "-" version ".tar.gz"))
       (sha256
        (base32 "1g6akwxjiyi09hqjkx0fa0bd5la0r9pqngrjiwjykz7wp052qzcd"))))
    (build-system emacs-build-system)
    (arguments
     (list
      #:parallel-tests? #f
      ;; pqenv has its own Rust/Cargo build and is an optional component.
      #:test-command #~'("make" "check-client" "check-bridge" "check-python")
      #:include
      #~'("^whatsapp(-org|-profiles|-delivery|-tools)?\\.el$"
          "^whatsappel-(autoloads|pkg)\\.el$"
          "^whatsappel(-profiles|-transport)?\\.scm$"
          "^scripts/(bridge_protocol|read-worker|send-worker|download-worker|media-worker|profile-worker|launch-whatsappel)\\.py$")
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'fix-send-worker-validation
            (lambda _
              ;; Keep validation failures in the worker's existing JSON error
              ;; protocol, before request construction or any network access.
              (let ((matches 0))
                (substitute* "scripts/send-worker.py"
                  (("^    except \\(ValueError, OSError, protocol\\.ProtocolError\\):")
                   (set! matches (+ matches 1))
                   "    except (ValueError, OSError, protocol.ProtocolError, media.WorkerError):"))
                (unless (= matches 1)
                  (error "Expected one send-worker validation handler" matches)))))
          (replace 'ensure-package-description
            (lambda _
              (call-with-output-file "whatsappel-pkg.el"
                (lambda (port)
                  (format port
                          "(define-package \"whatsappel\" \"~a\" \"WhatsApp workspace\" '((emacs \"28.1\")))~%"
                          #$version)))))
          (add-before 'check 'patch-test-interpreters
            (lambda* (#:key inputs #:allow-other-keys)
              ;; Emacs subprocesses use ~/ as their working directory.  The
              ;; default Guix build HOME (/homeless-shelter) does not exist.
              (let ((test-home (string-append (getcwd) "/.test-home")))
                (mkdir-p test-home)
                (setenv "HOME" test-home))
              (substitute* "Makefile"
                (("SHELL := /bin/bash")
                 (string-append "SHELL := "
                                (search-input-file inputs "/bin/bash"))))
              ;; This test creates a real fake verifier executable.  Its
              ;; embedded shebang must also work inside the build sandbox.
              (substitute* "tests/selection-tests.el"
                (("#!/usr/bin/env python3")
                 (string-append "#!"
                                (search-input-file inputs "/bin/python3"))))))
          ;; Keep literal executable names for the upstream regression fixtures;
          ;; pin the installed programs only after those checks have passed.
          (add-before 'install 'pin-runtime-programs
            (lambda* (#:key inputs #:allow-other-keys)
              (let ((python (search-input-file inputs "/bin/python3"))
                    (ffmpeg (search-input-file inputs "/bin/ffmpeg")))
                (substitute* "whatsapp.el"
                  (("(defcustom whatsapp-python-program )\"python3\"" _ prefix)
                   (string-append prefix (object->string python)))
                  (("\"ffmpeg\"") (object->string ffmpeg)))
                (substitute* '("scripts/media-worker.py" "scripts/profile-worker.py")
                  (("shutil.which\\(['\"]ffmpeg['\"]\\)")
                   (string-append "shutil.which(" (object->string ffmpeg) ")"))))))
          (add-after 'install 'install-entry-points
            (lambda* (#:key inputs outputs #:allow-other-keys)
              (let* ((out (assoc-ref outputs "out"))
                     (workspace (elpa-directory out))
                     (bash (search-input-file inputs "/bin/bash"))
                     (python (search-input-file inputs "/bin/python3"))
                     (guile (search-input-file inputs "/bin/guile"))
                     (json (assoc-ref inputs "guile-json"))
                     (tls (assoc-ref inputs "guile-gnutls"))
                     (sqlite (assoc-ref inputs "sqlite")))
                (mkdir-p (string-append out "/bin"))
                (call-with-output-file (string-append out "/bin/whatsappel")
                  (lambda (port)
                    (format port "#!~a~%exec ~s -I ~s \"$@\"~%"
                            bash python
                            (string-append workspace "/scripts/launch-whatsappel.py"))))
                (call-with-output-file (string-append out "/bin/whatsappel-bridge")
                  (lambda (port)
                    (format port "#!~a~%" bash)
                    (format port
                            "export GUILE_LOAD_PATH=\"~a/share/guile/site/3.0:~a/share/guile/site/3.0${GUILE_LOAD_PATH:+:$GUILE_LOAD_PATH}\"~%"
                            json tls)
                    (format port
                            "export GUILE_LOAD_COMPILED_PATH=\"~a/lib/guile/3.0/site-ccache:~a/lib/guile/3.0/site-ccache${GUILE_LOAD_COMPILED_PATH:+:$GUILE_LOAD_COMPILED_PATH}\"~%"
                            json tls)
                    (format port "export PATH=\"~a/bin${PATH:+:$PATH}\"~%" sqlite)
                    (format port "exec ~s --no-auto-compile ~s \"$@\"~%"
                            guile (string-append workspace "/whatsappel.scm"))))
                (chmod (string-append out "/bin/whatsappel") #o555)
                (chmod (string-append out "/bin/whatsappel-bridge") #o555))))
          (add-after 'install 'install-documentation
            (lambda* (#:key outputs #:allow-other-keys)
              (let ((doc (string-append (assoc-ref outputs "out")
                                        "/share/doc/whatsappel")))
                (for-each (lambda (file) (install-file file doc))
                          '("README.md" "README.pt-BR.md" "LICENSE"))
                (for-each (lambda (file)
                            (install-file file (string-append doc "/docs")))
                          '("docs/USAGE.md" "docs/USAGE.pt-BR.md")))))
          (add-after 'build 'check-installed-workspace
            (lambda* (#:key tests? inputs outputs #:allow-other-keys)
              (when tests?
                (let* ((out (assoc-ref outputs "out"))
                       (workspace (elpa-directory out))
                       (python (search-input-file inputs "/bin/python3"))
                       (ffmpeg (search-input-file inputs "/bin/ffmpeg")))
                  (invoke "emacs" "-Q" "--batch" "-L" workspace "--eval"
                          (format #f
                                  "(progn (require 'whatsapp) (unless (and (equal whatsapp-version \"3.3.1\") (equal whatsapp-python-program ~s) (equal (car (whatsapp-voice-command \"/tmp/fixture.ogg\")) ~s)) (error \"Installed runtime programs differ\")))"
                                  python ffmpeg))
                  (invoke (string-append out "/bin/whatsappel") "--help")
                  ;; A missing bridge URL must fail with the same fixed JSON
                  ;; refusal as other invalid input, not an uncaught exception.
                  (invoke python "-I" "-c"
                          "import json, subprocess, sys
result = subprocess.run([sys.executable, '-I', sys.argv[1]],
                        input='{}\\n', capture_output=True, text=True,
                        env={}, timeout=10)
assert result.returncode == 1, result
assert result.stderr == '', result.stderr
assert json.loads(result.stdout) == {'status': None, 'body': {
    'error': 'Invalid request; no message sent.'}}, result.stdout"
                          (string-append workspace "/scripts/send-worker.py"))
                  ;; The fixture loads the installed bridge without starting its
                  ;; HTTP server, using synthetic credentials and no user state.
                  (invoke "env" "-i"
                          "WHATSAPPEL_TOKEN=guix-test-bridge-token-000000"
                          "WUZAPI_TOKEN=guix-test-upstream-token"
                          "WHATSAPPEL_LIDMAP_DB="
                          (string-append out "/bin/whatsappel-bridge")
                          "--check-load"))))))))
    (inputs (list bash-minimal guile-3.0 guile-json-4 guile-gnutls
                  python ffmpeg sqlite))
    (native-inputs (list fish git-minimal))
    (home-page "https://git.securityops.co/cristiancmoises/whatsappel")
    (synopsis "WhatsApp workspace for GNU Emacs with a Guile bridge")
    (description
     "WhatsAppel provides an Emacs conversation workspace, bounded Python
workers and a Guile HTTP bridge to a separately configured wuzapi backend.
The @command{whatsappel} launcher uses the graphical Emacs already selected in
the user's environment.  @command{whatsappel-bridge} starts the bridge using
runtime environment configuration.  Installing this package does not create
credentials or start services.  External media playback needs mpv separately;
the optional Rust pqenv encryption helper is not included.")
    (license license:agpl3)))
