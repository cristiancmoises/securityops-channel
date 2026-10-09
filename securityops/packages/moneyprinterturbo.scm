;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>

(define-module (securityops packages moneyprinterturbo)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module (guix build-system copy)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages python)
  #:use-module (gnu packages check)
  #:use-module (gnu packages video)
  #:use-module (gnu packages tor)
  #:use-module (gnu packages version-control)
  #:use-module (gnu packages fonts)
  #:use-module ((guix licenses) #:prefix license:))

;;; moneyprinterturbo — one-click AI short-video generator (harry0703 v1.3.7).
;;; THIRD-PARTY Python app with a huge, partly-unpackaged dependency tree
;;; (streamlit, moviepy, edge-tts, litellm, faster-whisper, the cloud SDKs), so a
;;; full native python-build-system package is infeasible here.  Instead this ships
;;; the (font-pruned) upstream source plus self-contained `moneyprinterturbo' /
;;; `moneyprinterturbo-api' launchers that, on FIRST RUN, copy the app into a
;;; writable per-user dir ($XDG_DATA_HOME/moneyprinterturbo) and pip-install the
;;; pinned requirements.txt into a local venv, fetched over Tor via torsocks.
;;; Documented impurity: that one-time pip step needs network (routed through Tor);
;;; the BUILD itself is fully offline (copy-build-system, no daemon network).
;;;
;;; Tor-only host hardening baked into the launchers:
;;;   * every process runs under torsocks (LD_PRELOAD) so ALL TCP egress (LLM,
;;;     Pexels/Pixabay material, edge-tts) goes through Tor — the app's own [proxy]
;;;     setting only covers material downloads;
;;;   * a shipped torsocks.conf sets `AllowInbound 1' (the local Streamlit/uvicorn
;;;     server accepts the browser) and `AllowOutboundLocalhost 1' (a local Ollama
;;;     LLM at 127.0.0.1:11434 or Redis is reached directly, not via Tor);
;;;   * GRPC_DNS_RESOLVER=native avoids grpc's c-ares UDP DNS (torsocks can't route
;;;     UDP).  NOTE: gemini *voices* and Azure *-V2* voices still bypass Tor and must
;;;     be avoided; gemini as an LLM (forced transport=rest) is fine;
;;;   * IMAGEIO_FFMPEG_EXE pins the store ffmpeg so moviepy never auto-downloads one;
;;;   * HF_HUB_OFFLINE/TRANSFORMERS_OFFLINE default on (keep subtitle_provider=edge;
;;;     whisper would pull a ~3GB model over Tor) and the server binds 127.0.0.1.
;;; The proprietary default subtitle font STHeitiMedium.ttc is dropped and repointed
;;; to bundled WenQuanYi Zen Hei (font-wqy-zenhei, redistributable; covers CJK+Latin)
;;; so the default render works.  Upstream's bundled fonts and sample music are
;;; removed; their redistribution terms are not included in the source archive.
;;; The app is imported
;;; from the writable copy via PYTHONPATH and is never installed into the venv
;;; (pyproject package=false), because root_dir() is __file__-relative.
;;; First-run deps require compatible wheels on PyPI; this copy package does
;;; not build or test the complete Python runtime dependency graph.
(define-public moneyprinterturbo
  (package
    (name "moneyprinterturbo")
    (version "1.3.7")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/harry0703/MoneyPrinterTurbo")
             ;; Commit of the v1.3.7 release tag.
             (commit "cf5a3aedad1741d012152d355aa909d224fc4557")))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1mij12kk7gv30vbzdbpyhk63r30w5978r3ji6zs1vai8g1cafybw"))
       (modules '((guix build utils)))
       (snippet
        #~(begin
            (for-each delete-file-recursively
                      '("resource/fonts" "resource/songs"))
            (mkdir-p "resource/fonts")
            (mkdir-p "resource/songs")))))
    (build-system copy-build-system)
    (native-inputs (list python-pytest))
    (inputs `(("python" ,python)
              ("ffmpeg" ,ffmpeg)
              ("torsocks" ,torsocks)
              ("git-minimal" ,git-minimal)
              ("coreutils-minimal" ,coreutils-minimal)
              ("bash-minimal" ,bash-minimal)
              ("font-wqy-zenhei" ,font-wqy-zenhei)))
    (arguments
     (list
      #:install-plan
      #~'(("app" "share/moneyprinterturbo/app")
          ("webui" "share/moneyprinterturbo/webui")
          ("resource" "share/moneyprinterturbo/resource")
          ("docs/skill" "share/moneyprinterturbo/docs/skill")
          ("cli.py" "share/moneyprinterturbo/")
          ("main.py" "share/moneyprinterturbo/")
          ("config.example.toml" "share/moneyprinterturbo/")
          ("pyproject.toml" "share/moneyprinterturbo/")
          ("requirements.txt" "share/moneyprinterturbo/")
          ("webui.sh" "share/moneyprinterturbo/")
          ("README-en.md" "share/moneyprinterturbo/")
          ("LICENSE" "share/moneyprinterturbo/"))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'strip) ;pure Python + bash, no ELF
          (delete 'validate-runpath)
          ;; The remaining upstream suites import runtime dependencies that
          ;; this wrapper installs only on first use.  These upstream tests
          ;; exercise task-history and CLI helpers using only Python and pytest.
          (add-before 'install 'check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (setenv "PYTHONDONTWRITEBYTECODE" "1")
                (invoke "python3"
                        "-m"
                        "pytest"
                        "-q"
                        "test/services/test_webui_task_history.py"
                        "test/services/test_mpt_agent_skill.py"))))
          (add-after 'install 'patch-defaults
            (lambda* (#:key inputs outputs #:allow-other-keys)
              (let* ((out (assoc-ref outputs "out"))
                     (share (string-append out "/share/moneyprinterturbo"))
                     (fonts (string-append share "/resource/fonts"))
                     (cjk (string-append (assoc-ref inputs "font-wqy-zenhei")
                           "/share/fonts/truetype/wqy-zenhei.ttc")))
                ;; Ship a redistributable CJK font and repoint the proprietary
                ;; default so the out-of-the-box subtitle render does not crash.
                (symlink cjk
                         (string-append fonts "/wqy-zenhei.ttc"))
                (for-each (lambda (f)
                            (substitute* (string-append share "/" f)
                              (("STHeitiMedium\\.ttc")
                               "wqy-zenhei.ttc")
                              (("MicrosoftYaHeiBold\\.ttc")
                               "wqy-zenhei.ttc")))
                          '("app/models/schema.py" "app/services/video.py"
                            "webui/Main.py" "config.example.toml"))
                ;; Never bind the API/UI on all interfaces by default.
                (substitute* (string-append share "/app/config/config.py")
                  (("\"0\\.0\\.0\\.0\"")
                   "\"127.0.0.1\""))
                ;; Defensive: never ship a stray user config into the store.
                (let ((stray (string-append share "/config.toml")))
                  (when (file-exists? stray)
                    (delete-file stray))))))
          (add-after 'patch-defaults 'wrap
            (lambda* (#:key inputs outputs #:allow-other-keys)
              (let* ((out (assoc-ref outputs "out"))
                     (share (string-append out "/share/moneyprinterturbo"))
                     (etc (string-append out "/etc/moneyprinterturbo"))
                     (conf (string-append etc "/torsocks.conf"))
                     (python (string-append (assoc-ref inputs "python")
                                            "/bin/python3"))
                     (ffmpeg (string-append (assoc-ref inputs "ffmpeg")
                                            "/bin/ffmpeg"))
                     (path (string-join (map (lambda (in.sub)
                                               (string-append (assoc-ref
                                                               inputs
                                                               (car in.sub))
                                                              (cdr in.sub)))
                                             '(("python" . "/bin")
                                               ("ffmpeg" . "/bin")
                                               ("torsocks" . "/bin")
                                               ("git-minimal" . "/bin")
                                               ("coreutils-minimal" . "/bin")))
                                        ":")))
                ;; torsocks.conf: route all TCP through Tor (127.0.0.1:9050) but
                ;; allow the local server's inbound socket and direct localhost.
                (mkdir-p etc)
                (call-with-output-file conf
                  (lambda (port)
                    (format port
                     "# Generated by the securityops channel.~%TorAddress 127.0.0.1~%TorPort 9050~%AllowInbound 1~%AllowOutboundLocalhost 1~%")))
                (mkdir-p (string-append out "/bin"))
                (let ((write-launcher (lambda (file exec-tail)
                                        (let ((p (string-append out "/bin/"
                                                                file)))
                                          (call-with-output-file p
                                            (lambda (port)
                                              (format port
                                               "#!/bin/sh
# Generated by the securityops channel: self-contained MoneyPrinterTurbo launcher (Tor-only host).
set -e
export PATH=\"~a${PATH:+:$PATH}\"
STORE_SHARE=\"~a\"
APP_HOME=\"${MPT_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/moneyprinterturbo}\"
VERSION=\"1.3.7\"
export TORSOCKS_ALLOW_INBOUND=1
export TORSOCKS_CONF_FILE=\"~a\"
export GRPC_DNS_RESOLVER=native
export IMAGEIO_FFMPEG_EXE=\"~a\"
export HF_HUB_OFFLINE=\"${HF_HUB_OFFLINE:-1}\"
export TRANSFORMERS_OFFLINE=\"${TRANSFORMERS_OFFLINE:-1}\"
if [ \"$(cat \"$APP_HOME/.version\" 2>/dev/null)\" != \"$VERSION\" ]; then
  echo \">> [moneyprinterturbo] syncing app v$VERSION into $APP_HOME\"
  mkdir -p \"$APP_HOME\"
  cp -a \"$STORE_SHARE/.\" \"$APP_HOME/\"
  chmod -R u+w \"$APP_HOME\"
  mkdir -p \"$APP_HOME/storage\" \"$APP_HOME/models\"
  printf '%s' \"$VERSION\" > \"$APP_HOME/.version\"
  rm -f \"$APP_HOME/.venv/.bootstrap-complete\" 2>/dev/null || true
fi
cd \"$APP_HOME\"
if [ ! -f \"$APP_HOME/.venv/.bootstrap-complete\" ]; then
  echo \">> [moneyprinterturbo] first run: creating venv + installing deps over Tor (one-time, slow)\"
  rm -rf \"$APP_HOME/.venv\"
  ~a -m venv \"$APP_HOME/.venv\"
  PIP_DEFAULT_TIMEOUT=180 PIP_RETRIES=15 PIP_DISABLE_PIP_VERSION_CHECK=1 torsocks \"$APP_HOME/.venv/bin/python\" -m pip install --upgrade pip wheel setuptools
  PIP_DEFAULT_TIMEOUT=180 PIP_RETRIES=15 PIP_DISABLE_PIP_VERSION_CHECK=1 torsocks \"$APP_HOME/.venv/bin/python\" -m pip install -r \"$APP_HOME/requirements.txt\"
  touch \"$APP_HOME/.venv/.bootstrap-complete\"
  echo \">> [moneyprinterturbo] ready — add a Pexels key + pick an LLM in $APP_HOME/config.toml\"
fi
export PYTHONPATH=\"$APP_HOME${PYTHONPATH:+:$PYTHONPATH}\"
~a
"
                                               path
                                               share
                                               conf
                                               ffmpeg
                                               python
                                               exec-tail)))
                                          (chmod p #o755)))))
                  (write-launcher "moneyprinterturbo"
                   "exec torsocks \"$APP_HOME/.venv/bin/python\" -m streamlit run \"$APP_HOME/webui/Main.py\" --server.address=127.0.0.1 --browser.gatherUsageStats=False --server.headless=true \"$@\"")
                  (write-launcher "moneyprinterturbo-api"
                   "exec torsocks \"$APP_HOME/.venv/bin/python\" \"$APP_HOME/main.py\" \"$@\""))))))))
    (supported-systems '("x86_64-linux"))
    (synopsis "One-click AI short-video generator (WebUI + API), Tor-wrapped")
    (description
     "MoneyPrinterTurbo generates short-form videos from a topic: an LLM writes the
script and keywords, stock B-roll is pulled from Pexels/Pixabay, edge-tts adds a
voice-over, subtitles are burned in, and FFmpeg assembles the final clip.  This
package ships the upstream v1.3.7 source (bundled fonts and music removed;
WenQuanYi Zen Hei supplied as the default subtitle font) plus self-contained
@command{moneyprinterturbo} (Streamlit WebUI) and @command{moneyprinterturbo-api}
(FastAPI) launchers.  On first run each launcher copies the app into
@file{$XDG_DATA_HOME/moneyprinterturbo} and pip-installs the pinned
@file{requirements.txt} into a local virtualenv, fetched over Tor via
@command{torsocks}; thereafter all egress (LLM, material, TTS) is routed through
Tor, the local server binds 127.0.0.1, and the store @code{ffmpeg} is pinned so no
binaries are auto-downloaded.  Keep @code{subtitle_provider = \"edge\"} to avoid a
multi-GB Whisper model download.")
    (home-page "https://github.com/harry0703/MoneyPrinterTurbo")
    (license license:expat)))
