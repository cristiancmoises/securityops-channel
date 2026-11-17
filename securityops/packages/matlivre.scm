;;; SPDX-License-Identifier: GPL-3.0-or-later
(define-module (securityops packages matlivre)
  #:use-module (guix packages)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-13)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module (guix build-system copy)
  #:use-module (guix build-system emacs)
  #:use-module ((guix licenses)
                #:prefix license:)
  #:use-module (gnu packages base)
  #:use-module (gnu packages fontutils)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages gl)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages freedesktop)
  #:use-module (gnu packages xdisorg)
  #:use-module (gnu packages xorg))

(define matlivre-glibc
  ;; Private runtime only: the official AppImage imports GLIBC_2.43 libm symbols.
  (package
    (inherit glibc)
    (version "2.43")
    (arguments
     (substitute-keyword-arguments (package-arguments glibc)
       ((#:configure-flags flags)
        `(map (lambda (flag)
                (if (string-prefix? "libc_cv_complocaledir=" flag)
                    "libc_cv_complocaledir=/run/current-system/locale/2.43"
                    flag))
              ,flags))))
    (properties '())
    (supported-systems '("x86_64-linux"))
    (source
     (origin
       (inherit (package-source glibc))
       ;; GNU/Hurd fixes do not apply to this Linux-only private runtime;
       ;; keep all Guix native loader/cache/locale patches intact.
       (patches (remove (lambda (path)
                          (string-contains path "hurd"))
                        (origin-patches (package-source glibc))))
       (uri "https://mirrors.kernel.org/gnu/glibc/glibc-2.43.tar.xz")
       (sha256
        (base32 "0c9qzbaprh779ggvix9c8hcps5y59y2caw42w2il7nxxbmmnrj6r"))))))

(define-public matlivre
  (package
    (name "matlivre")
    (version "0.1.9")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://github.com/campuslivre/matlivre/releases/download/v"
             version "/matlivre.AppImage"))
       (sha256
        (base32 "1apak8k9nsxg101mqaa0xz7nggq3ha6f67drj5h7fdcjs5v4sbc7"))))
    (build-system copy-build-system)
    (arguments
     (list
      #:install-plan
      #~'(("usr/bin/matlivre" "bin/matlivre")
          ("matlivre.png" "share/icons/hicolor/256x256/apps/matlivre.png"))
      #:phases
      #~(modify-phases %standard-phases
          (replace 'unpack
            (lambda* (#:key source #:allow-other-keys)
              ;; Fixed type-2 AppImage squashfs offset for this exact digest.
              ;; Extract data without executing the AppImage runtime or using FUSE.
              (invoke "unsquashfs"
                      "-processors"
                      "1"
                      "-o"
                      "944632"
                      "-d"
                      "appdir"
                      source)
              (chdir "appdir")))
          (add-after 'install 'relocate
            (lambda* (#:key inputs #:allow-other-keys)
              (use-modules (srfi srfi-13)
                           (ice-9 format))
              (let* ((binary (string-append #$output "/bin/matlivre"))
                     (loader (search-input-file inputs
                                                "/lib/ld-linux-x86-64.so.2"))
                     (paths (map (lambda (label)
                                   (string-append (assoc-ref inputs label)
                                                  "/lib"))
                                 '("glibc" "gcc:lib"
                                   "mesa"
                                   "libx11"
                                   "libxcb"
                                   "libxcursor"
                                   "libxi"
                                   "libxrandr"
                                   "libxkbcommon"
                                   "wayland"
                                   "dbus"
                                   "fontconfig")))
                     (doc (string-append #$output "/share/doc/matlivre"))
                     (desktop (string-append #$output
                               "/share/applications/matlivre.desktop")))
                (invoke "patchelf"
                        "--set-interpreter"
                        loader
                                                "--set-rpath"
                        (string-join paths ":")
                        binary)
                ;; RPATH also covers dlopen without leaking the private libc
                ;; into child programs through LD_LIBRARY_PATH.
                (mkdir-p doc)
                (copy-file (assoc-ref inputs "upstream-license")
                           (string-append doc "/LICENSE"))
                (invoke "tar"
                        "xf"
                        (assoc-ref inputs "font-notices")
                        "-C"
                        doc
                        "--strip-components=1"
                        "epaint_default_fonts-0.29.1/fonts")
                (call-with-output-file (string-append doc "/SOURCE.txt")
                  (lambda (port)
                    (display
                     "Official MatLivre v0.1.9 AppImage, extracted and relocated for Guix.
Source: https://github.com/campuslivre/matlivre/tree/efcd31a39ef5b61ab8a2a96a3ab7e8de19e394b9
Bundled updater omitted; updates managed through Guix.
Binary provenance is upstream's release, not a locally reproduced source build.
"
                     port)))
                (mkdir-p (dirname desktop))
                (call-with-output-file desktop
                  (lambda (port)
                    (format port
                     "[Desktop Entry]~%Type=Application~%Name=MatLivre~%Exec=~a/bin/matlivre %f~%Icon=matlivre~%Terminal=false~%Categories=Science;Math;Education;~%"
                     #$output))))))
          (add-after 'relocate 'check-runtime
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (use-modules (ice-9 popen)
                             (ice-9 rdelim)
                             (srfi srfi-13))
                (setenv "XDG_CONFIG_HOME"
                        (getcwd))
                (setenv "APPDATA"
                        (getcwd))
                (let ((port (open-pipe* OPEN_BOTH
                                        "timeout"
                                        "-k"
                                        "5"
                                        "45"
                                        (string-append #$output
                                                       "/bin/matlivre")
                                        "--mcp")))
                  (display
                   "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"run_code\",\"arguments\":{\"code\":\"disp(6*7)\"}}}
"
                   port)
                  (force-output port)
                  (let ((reply (read-line port)))
                    (unless (and (string? reply)
                                 (string-contains reply "42"))
                      (error "MatLivre runtime smoke test failed" reply)))
                  (unless (zero? (close-pipe port))
                    (error "MatLivre exited unsuccessfully")))))))))
    (native-inputs `(("squashfs-tools" ,squashfs-tools)
                     ("patchelf" ,patchelf)
                     ("upstream-license" ,(local-file
                                           "../../etc/matlivre/UPSTREAM-LICENSE"))
                     ("font-notices" ,(origin
                                        (method url-fetch)
                                        (uri (string-append
                                              "https://static.crates.io/crates/"
                                              "epaint_default_fonts/"
                                              "epaint_default_fonts-0.29.1.crate"))
                                        (sha256 (base32
                                                 "1sm3a70hiakp0s65219415smdsfv261z0503l9vwz4vr1gdl0d28"))))))
    (inputs `(("glibc" ,matlivre-glibc)
              ("gcc:lib" ,gcc "lib")
              ("mesa" ,mesa)
              ("libx11" ,libx11)
              ("libxcb" ,libxcb)
              ("libxcursor" ,libxcursor)
              ("libxi" ,libxi)
              ("libxrandr" ,libxrandr)
              ("libxkbcommon" ,libxkbcommon)
              ("wayland" ,wayland)
              ("dbus" ,dbus)
              ("fontconfig" ,fontconfig)))
    (supported-systems '("x86_64-linux"))
    (home-page "https://campuslivre.github.io/matlivre/")
    (synopsis "MATLAB-compatible live scripts and scientific computing")
    (description
     "MatLivre provides a graphical live-script editor and a MATLAB-compatible
runtime.  This package relocates the official Linux binary.  Its stdio interface
also runs code headlessly and returns workspace variables and PNG figures.")
    (license license:expat)))

(define-public emacs-matlibre
  (package
    (name "emacs-matlibre")
    (version "0.1.0")
    (source
     (local-file "../../etc/matlivre" "matlibre-source"
                 #:recursive? #t))
    (build-system emacs-build-system)
    (propagated-inputs (list matlivre))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/cristiancmoises/matlibre")
    (synopsis "MatLibre scientific workspace for graphical and terminal Emacs")
    (description
     "MatLibre runs MatLivre inside Emacs using its local stdio interface.
It supports a persistent workspace, script and region execution, variable inspection,
inline PNG figures in graphical Emacs, and upstream tool discovery.  Documents
can also be opened in MatLivre's graphical editor.  Use M-x matlibre to begin.")
    (license license:gpl3+)))
