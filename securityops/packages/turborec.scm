;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>

(define-module (securityops packages turborec)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module (guix build-system copy)
  #:use-module (gnu packages python)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages video)
  #:use-module ((securityops packages video) #:prefix sec-video:)
  #:use-module (gnu packages pulseaudio)
  #:use-module (gnu packages xorg)
  #:use-module (gnu packages pciutils)
  #:use-module (gnu packages window-management)
  #:use-module (gnu packages xdisorg)
  #:use-module ((guix licenses) #:prefix license:))

;;; turborec — Turbo Recorder 3.10.4: a hardware-accelerated screen + audio
;;; recorder.  `turborec.py' is a pure-stdlib Python CLI with a Tkinter GUI (the
;;; `gui' subcommand); `turborecorder' is a Linux X11/Wayland bash launcher that
;;; builds a quality-first FFmpeg pipeline (NVENC > VAAPI > x264).  Built FROM
;;; SOURCE with copy-build-system (no compile): the two scripts install under
;;; lib/, and
;;; self-contained shims in bin/ pin the store shell/python3/bash and
;;; prepend the store bins of the tools they exec (ffmpeg, pactl, xrandr,
;;; xdpyinfo, lspci).  The Tkinter GUI gets the python `tk' output (which carries
;;; `_tkinter.so') on PYTHONPATH.  nvidia-smi (optional HW probe) is left to PATH
;;; if present — Auto can fall back to software; an explicit GPU request fails
;;; with an actionable error when its selected encoder cannot start.
(define-public turborec
  (package
    (name "turborec")
    (version "3.10.4")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://codeberg.org/berkeley/turborec.git")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "09hx0bqak1dz8whp1jp1b8i55pawn4l2r5r9bsvjl46sw82fmbib"))))
    (build-system copy-build-system)
    (inputs `(("python" ,python)
              ("python:tk" ,python "tk") ;_tkinter for `turborec gui'
              ("ffmpeg" ,sec-video:ffmpeg)
              ("pulseaudio" ,pulseaudio) ;pactl
              ("xrandr" ,xrandr)
              ("xdpyinfo" ,xdpyinfo)
              ("pciutils" ,pciutils) ;lspci
              ("wf-recorder" ,wf-recorder) ;Wayland (wlroots) screen capture
              ("wlr-randr" ,wlr-randr) ;Wayland output enumeration
              ("sway" ,sway) ;swaymsg
              ("wmctrl" ,wmctrl) ;X11 window capture
              ("bash-minimal" ,bash-minimal)))
    (arguments
     (list
      #:install-plan
      #~'(("turborec.py" "lib/turborec/turborec.py")
          ("turborecorder" "lib/turborec/turborecorder")
          ("packaging/turborec.desktop" "share/applications/turborec.desktop")
          ("packaging/turborec.svg"
           "share/icons/hicolor/scalable/apps/turborec.svg")
          ("README.md" "share/doc/turborec/README.md")
          ("CHANGELOG.md" "share/doc/turborec/CHANGELOG.md")
          ("SECURITY.md" "share/doc/turborec/SECURITY.md")
          ("docs/TUTORIAL.md" "share/doc/turborec/docs/TUTORIAL.md")
          ("docs/README.pt-BR.md" "share/doc/turborec/docs/README.pt-BR.md")
          ("docs/turborec-gui.png" "share/doc/turborec/docs/turborec-gui.png")
          ("LICENSE" "share/doc/turborec/LICENSE"))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'strip) ;pure Python + bash, no ELF
          (delete 'validate-runpath)
          (add-after 'unpack 'check
            (lambda* (#:key inputs tests? #:allow-other-keys)
              (when tests?
                (let ((tkpath (dirname (car (find-files (assoc-ref inputs
                                                         "python:tk")
                                                        "^_tkinter.*\\.so$")))))
                  (setenv "GUIX_PYTHONPATH" tkpath)
                  (invoke "python3" "-m" "py_compile" "turborec.py")
                  (invoke "python3"
                          "-m"
                          "unittest"
                          "discover"
                          "-s"
                          "tests"
                          "-v")
                  (invoke "python3" "-c"
                          "import _tkinter, tkinter; tkinter.Tcl()")
                  (invoke "bash" "-n" "turborecorder")))))
          (add-after 'install 'wrap
            (lambda* (#:key inputs outputs #:allow-other-keys)
              (let* ((out (assoc-ref outputs "out"))
                     (lib (string-append out "/lib/turborec"))
                     (python (string-append (assoc-ref inputs "python")
                                            "/bin/python3"))
                     (bash (string-append (assoc-ref inputs "bash-minimal")
                                          "/bin/bash"))
                     ;; Only the NVIDIA variant supplies this paired probe.
                     ;; The recorder links FFmpeg 8 while other pipelines use 9.
                     (wf-ffmpeg (assoc-ref inputs "wf-ffmpeg"))
                     (wf-environment
                      (if wf-ffmpeg
                          (format #f
                           "export TURBOREC_WF_RECORDER=\"~a/bin/wf-recorder\"\nexport TURBOREC_WF_FFMPEG=\"~a/bin/ffmpeg\"\n"
                           (assoc-ref inputs "wf-recorder") wf-ffmpeg)
                          ""))
                     ;; site-packages dir of the python `tk' output (holds _tkinter.so);
                     ;; derived so it survives a python minor-version bump.
                     (tkpath (dirname (car (find-files (assoc-ref inputs
                                                                  "python:tk")
                                                       "^_tkinter.*\\.so$"))))
                     (path (string-join (map (lambda (in.sub)
                                               (string-append (assoc-ref
                                                               inputs
                                                               (car in.sub))
                                                              (cdr in.sub)))
                                             '(("python" . "/bin")
                                               ("ffmpeg" . "/bin")
                                               ("pulseaudio" . "/bin")
                                               ("xrandr" . "/bin")
                                               ("xdpyinfo" . "/bin")
                                               ("wf-recorder" . "/bin")
                                               ("wlr-randr" . "/bin")
                                               ("sway" . "/bin")
                                               ("wmctrl" . "/bin")
                                               ("pciutils" . "/sbin")
                                               ("pciutils" . "/bin"))) ":")))
                (mkdir-p (string-append out "/bin"))
                (let ((p (string-append out "/bin/turborec")))
                  (call-with-output-file p
                    (lambda (port)
                      (format port
                       "#!/bin/sh
# Generated by the securityops channel: self-contained launcher.
export PATH=\"~a${PATH:+:$PATH}\"
export PYTHONPATH=\"~a${PYTHONPATH:+:$PYTHONPATH}\"
~aexec ~a ~a/turborec.py \"$@\"
"
                       path
                       tkpath
                       wf-environment
                       python
                       lib)))
                  (chmod p #o755)
                  (patch-shebang p))
                (let ((p (string-append out "/bin/turborecorder")))
                  (call-with-output-file p
                    (lambda (port)
                      (format port
                       "#!/bin/sh
# Generated by the securityops channel: self-contained launcher.
export PATH=\"~a${PATH:+:$PATH}\"
~aexec ~a ~a/turborecorder \"$@\"
"
                       path wf-environment bash lib)))
                  (chmod p #o755)
                  (patch-shebang p))
                (substitute* (string-append out
                              "/share/applications/turborec.desktop")
                  (("^Exec=turborec")
                   (string-append "Exec=" out "/bin/turborec"))
                  (("^Icon=turborec")
                   (string-append "Icon=" out
                    "/share/icons/hicolor/scalable/apps/turborec.svg"))))))
          (add-after 'wrap 'check-installed-commands
            (lambda* (#:key outputs tests? #:allow-other-keys)
              (when tests?
                (let ((bin (string-append (assoc-ref outputs "out") "/bin/")))
                  (invoke (string-append bin "turborec") "--version")
                  (invoke (string-append bin "turborec") "--help")
                  (invoke (string-append bin "turborecorder") "-h"))))))))
    (supported-systems '("x86_64-linux"))
    (synopsis "Hardware-accelerated screen and audio recorder")
    (description
     "Turbo Recorder captures the screen and audio into a quality-first FFmpeg
pipeline, auto-detecting the best hardware encoder (NVIDIA NVENC, then Intel/AMD
VAAPI, then software x264), the native screen resolution, and the default
microphone and system-audio sources.  @command{turborec} is a cross-platform
Python CLI with a Tkinter GUI (@command{turborec gui}); @command{turborecorder}
is a Linux X11/Wayland bash launcher.  Built from source and self-contained: the
launchers pin the store @code{python3}/@code{bash} and the tools they call
(@code{ffmpeg}, @code{pactl}, @code{xrandr}, @code{xdpyinfo}, @code{lspci}).")
    (home-page "https://codeberg.org/berkeley/turborec")
    (license license:gpl3)))

;;; This optional variant shares both wrappers and the official application
;;; source with the free package, but explicitly binds the NVIDIA Wayland pair.
(define-public turborec-nvidia-new-feature
  (package
    (inherit turborec)
    (name "turborec-nvidia-new-feature")
    (supported-systems
     (package-supported-systems sec-video:ffmpeg-nvidia-new-feature))
    (properties
     (cons '(cpe-name . "turborec") (package-properties turborec)))
    (inputs
     (cons (list "wf-ffmpeg" sec-video:ffmpeg-8-nvidia-new-feature)
           (modify-inputs (package-inputs turborec)
             (replace "ffmpeg" sec-video:ffmpeg-nvidia-new-feature)
             (replace "wf-recorder" sec-video:wf-recorder-nvidia-new-feature))))
    (synopsis "Screen recorder for the NVIDIA new-feature driver")
    (description
     (string-append (package-description turborec)
                    "  This optional variant pins a matched NVIDIA-enabled
wf-recorder and FFmpeg 8 backend for Wayland capture while retaining FFmpeg 9
for other pipelines.  Its NVIDIA userspace libraries must match the running
kernel driver.  It does not install or replace the kernel module."))))
