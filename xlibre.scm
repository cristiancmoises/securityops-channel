;;; XLibre packaging integrated from spacecadet's guix-xlibre,
;;; revision 09edbfa3c5c4eaafbbb1947445c219ac53c465a6.
;;; Original source: https://gitlab.vulnix.sh/spacecadet/guix-xlibre.git
;;; Preserve the (xlibre) API for existing workstation configurations.
;;; SecurityOps maintains the server version and bundled packaging here.

(define-module (xlibre)
  #:use-module ((srfi srfi-1)
                #:select (fold))

  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module (guix packages)
  #:use-module ((guix licenses)
                #:prefix license:)
  #:use-module (gnu packages)

  #:use-module ((guix download)
                #:select (url-fetch))
  #:use-module ((guix git-download)
                #:select (git-fetch
                           git-reference
                           git-version
                           git-file-name))
  #:use-module ((guix build-system meson)
                #:select (meson-build-system))
  #:use-module ((guix build-system gnu)
                #:select (gnu-build-system))
  #:use-module ((gnu packages autotools)
                #:select (autoconf
                           automake
                           libtool))
  #:use-module ((gnu packages base)
                #:select (which))
  #:use-module ((gnu packages compression)
                #:select (zlib))
  #:use-module ((gnu packages freedesktop)
                #:select (libinput-minimal))
  #:use-module ((gnu packages gl)
                #:select (libepoxy
                           mesa))
  #:use-module ((gnu packages glib)
                #:select (dbus))
  #:use-module ((gnu packages gnome)
                #:select (libgudev))
  #:use-module ((gnu packages gnupg)
                #:select (libgcrypt))
  #:use-module ((gnu packages linux)
                #:select (eudev))
  #:use-module ((gnu packages llvm)
                #:select (llvm))
  #:use-module ((gnu packages pkg-config)
                #:select (pkg-config))
  #:use-module ((gnu packages python)
                #:select (python-wrapper))
  #:use-module ((gnu packages spice)
                #:select (spice-protocol))
  #:use-module ((gnu packages xdisorg)
                #:select (pixman
                           mtdev
                           libdrm
                           xf86-input-wacom))
  #:use-module ((gnu packages xorg)
                #:select (xrandr
                           xvinfo
                           xdpyinfo

                           libxfont2
                           libdmx
                           libxau
                           libxaw
                           libxdmcp
                           libxfixes
                           libxcvt
                           libxinerama
                           libxkbfile
                           libxrandr
                           libxrender
                           libxres
                           libxshmfence
                           libxt
                           libxv
                           libevdev
                           libx11
                           libxi
                           libxext
                           libxvmc

                           xkbcomp
                           xkeyboard-config
                           xtrans
                           xcb-util
                           xcb-util-image
                           xcb-util-keysyms
                           xcb-util-renderutil
                           xcb-util-wm
                           libpciaccess
                           xorgproto))

  #:use-module ((gnu services xorg)
                #:select (xorg-configuration
                           xorg-configuration-modules
                           %default-xorg-modules))

  #:use-module ((xlibre-sources)
                #:select (%xlibre-sources))

  #:export (xlibre-configuration
             xf86-module->xlibre))

(define-public xlibre-server
  (let* ((pkgname "xlibre-server")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    ;; XLibre 25.2 includes the former pre-gen4 Intel driver policy.
    (source src)
    (build-system meson-build-system)
    (propagated-inputs
      ;; The following libraries are required by xorg-server.pc.
      (list libpciaccess
            libxcvt
            mesa
            pixman
            xorgproto))
    (inputs
      (list eudev
            dbus
            libdmx
            libepoxy
            libgcrypt
            libxau
            libxaw
            libxdmcp
            libxfixes
            libxfont2
            libxkbfile
            libxrender
            libxres
            libxshmfence
            libxt
            libxv
            xkbcomp
            xkeyboard-config
            xtrans
            zlib
            ;; Inputs for Xephyr
            xcb-util
            xcb-util-image
            xcb-util-keysyms
            xcb-util-renderutil
            xcb-util-wm))
    (native-inputs
      (list python-wrapper
            pkg-config

            ;; for tests
            xrandr
            xvinfo
            xdpyinfo))
    (arguments
     (list
       #:configure-flags
       #~(list
           (string-append "-Dxkb_dir="
                          (assoc-ref %build-inputs "xkeyboard-config")
                          "/share/X11/xkb")
           (string-append "-Dxkb_output_dir="
                          (assoc-ref %outputs "out")
                          "/var/lib/xkb")
           (string-append "-Dxkb_bin_dir="
                          (assoc-ref %build-inputs "xkbcomp")
                          "/bin")
           ;; By default, it ends up with invalid '${prefix}/...', causes:
           ;;   _FontTransOpen: Unable to Parse address ${prefix}/share/...
           ;; It's not used anyway, so set it to empty.
           "-Ddefault_font_path="

           ;; Enable the X security extensions (ssh -X).
           "-Dxcsecurity=true"

           ;; For the log file, etc.
           "-Dlocalstatedir=/var"

           "-Dxephyr=true"
           "-Dxvfb=true"
           "-Dxnest=true"
           "-Dglamor=true"

           "-Dsystemd_logind=true" ;; for GDM
           "-Dsystemd_notify=false")
       #:phases
       #~(modify-phases %standard-phases
           (add-before 'configure 'pre-configure
             (lambda _
               (substitute* (find-files "." "\\.c$")
                 (("/bin/sh") (which "sh"))))))))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "A fork of the Xorg Xserver with code cleanups and enhanced functionality")
    (description
      "This package provides the XLibre X server itself.
The X server accepts requests from client programs to create windows, which
are (normally rectangular) 'virtual screens' that the client program can
draw into.

Windows are then composed on the actual screen by the X server (or by a
separate composite manager) as directed by the window manager, which usually
communicates with the user via graphical controls such as buttons and
draggable titlebars and borders.")
    (license license:x11))))

;;;;;; drivers

(define %xlibre-module-common-configure-flags
  (list
    #~(string-append "--with-xorg-module-dir="
                     (assoc-ref %outputs "out")
                     "/lib/xorg/modules")))

(define* (%xlibre-module-common-make-flags module-name #:key video input)
  (let ((module-type
          (cond ((and video input) (error ""))
                (video "video")
                (input "input")
                (else (error "")))))
    (list
      #~(string-append
          #$module-name "_drv_ladir="
          (assoc-ref %outputs "out")
          "/lib/xorg/modules/xlibre-25/drivers/" #$module-type)
      #~(string-append
          "drvmandir="
          (assoc-ref %outputs "out")
          "/share/man/man4"))))

(define %xlibre-module-autogen-fix
  #~(lambda _
      ;; build phase to fix a number of generic issues with module's config.sh
      ;; to be installed before 'bootstrap
      (let ((sh (which "sh")))
        ;; avoid using hard-coded /bin/sh
        (setenv "CONFIG_SHELL" sh)
        (substitute* (list "autogen.sh")
                     ;; "configure" is generated by "autogen.sh"
                     ;; and contains a hard-coded "/bin/sh" shebang
                     (("\\$srcdir/configure")
                      (string-append sh " $srcdir/configure"))
                     ;; remove git config commands
                     ;; only used to configure subjectPrefix for patch emails
                     (("git config.*")
                      "")))))

(define-public xlibre-input-elographics
  (let* ((pkgname "xlibre-input-elographics")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (arguments
      (list
        #:configure-flags
        #~(list
            (string-append "--with-sdkdir="
                           (assoc-ref %outputs "out")
                           "/include/xorg")
            (string-append "--with-xorg-conf-dir="
                           (assoc-ref %outputs "out")
                           "/share/X11/xorg.conf.d")
            #$@%xlibre-module-common-configure-flags)))
    (inputs (list libx11 xlibre-server libxfont2))
    (native-inputs (list pkg-config autoconf automake libtool))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "Elographics input driver for X server")
    (description
     "xf86-input-elographics is a touchscreen input driver for the Xorg X server.")
    (license license:x11))))

(define-public xlibre-input-evdev
  (let* ((pkgname "xlibre-input-evdev")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (inputs
      (list
        eudev
        libevdev
        mtdev
        xlibre-server
        libxfont2))
    (native-inputs (list pkg-config autoconf automake libtool))
    (arguments
      (list
        #:configure-flags
        #~(list (string-append "--with-sdkdir="
                               (assoc-ref %outputs "out")
                               "/include/xorg")
                #$@%xlibre-module-common-configure-flags)))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "Generic input driver for X server")
    (description
     "xf86-input-evdev is a generic input driver for the Xorg X server.
This driver supports all input devices that the kernel knows about,
including most mice, keyboards, tablets and touchscreens.")
    (license license:x11))))

(define-public xlibre-input-joystick
  (let* ((pkgname "xlibre-input-joystick")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (inputs (list xlibre-server libxfont2))
    (native-inputs (list pkg-config autoconf automake libtool))
    (arguments
     (list
       #:configure-flags
       #~(list (string-append "--with-sdkdir="
                              (assoc-ref %outputs "out")
                              "/include/xorg")
               #$@%xlibre-module-common-configure-flags)))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "Joystick input driver for X server")
    (description
     "xf86-input-joystick is a joystick input driver for the Xorg X server.
It is used to control the pointer with a joystick device.")
    (license license:x11))))

;;;; TODO: check cross-build on hurd
(define-public xlibre-input-keyboard
  (let* ((pkgname "xlibre-input-keyboard")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (arguments
      (list
        #:configure-flags
        #~(list
            #$@%xlibre-module-common-configure-flags)))
    (inputs (list xlibre-server libxfont2))
    (native-inputs (list pkg-config autoconf automake libtool))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "Keyboard input driver for X server")
    (description
     "xf86-input-keyboard is a keyboard input driver for the Xorg X server.")
    (license license:x11))))

(define-public xlibre-input-libinput
  (let* ((pkgname "xlibre-input-libinput")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (arguments
     (list
       #:configure-flags
       #~(list (string-append "--with-sdkdir="
                              %output "/include/xorg")
               #$@%xlibre-module-common-configure-flags)))
    (native-inputs
     (list pkg-config autoconf automake libtool))
    (inputs
     (list
       libinput-minimal
       xlibre-server
       libxfont2))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "Input driver for X server based on libinput")
    (description
     "xf86-input-libinput is an input driver for the Xorg X server based
on libinput.  It is a thin wrapper around libinput, so while it does
provide all features that libinput supports it does little beyond.")
    (license (list license:x11          ; only install-sh
                   license:expat)))))    ; everything else

;;;; TODO: check cross-build on hurd
(define-public xlibre-input-mouse
  (let* ((pkgname "xlibre-input-mouse")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (arguments
     (list
       #:configure-flags
       #~(list
           (string-append "--with-sdkdir="
                          (assoc-ref %outputs "out")
                          "/include/xorg")
           #$@%xlibre-module-common-configure-flags)))
    (inputs (list xlibre-server libxfont2))
    (native-inputs (list pkg-config autoconf automake libtool))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "Mouse input driver for X server")
    (description
     "xf86-input-mouse is a mouse input driver for the Xorg X server.
This driver supports four classes of mice: serial, bus and PS/2 mice,
and additional mouse types supported by specific operating systems, such
as USB mice.")
    (license license:x11))))

(define-public xlibre-input-synaptics
  (let* ((pkgname "xlibre-input-synaptics")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (inputs (list libx11 libxi libevdev mtdev xlibre-server libxfont2))
    (native-inputs (list pkg-config autoconf automake libtool))
    (arguments
      (list
        #:configure-flags
        #~(list (string-append "--with-sdkdir="
                               (assoc-ref %outputs "out")
                               "/include/xorg")
                (string-append "--with-xorg-conf-dir="
                               (assoc-ref %outputs "out")
                            "/share/X11/xorg.conf.d")
                #$@%xlibre-module-common-configure-flags)))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "Touchpad input driver for X server")
    (description
     "xf86-input-synaptics is a touchpad driver for the Xorg X server.")
    (license license:x11))))

(define-public xlibre-input-vmmouse
  (let* ((pkgname "xlibre-input-vmmouse")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (arguments
      (list
        #:configure-flags
        #~(list
            (string-append "--with-sdkdir="
                           (assoc-ref %outputs "out")
                           "/include/xorg")
            (string-append "--with-xorg-conf-dir="
                           (assoc-ref %outputs "out")
                           "/share/X11/xorg.conf.d")
            #$@%xlibre-module-common-configure-flags)))
    (inputs (list libx11 libgudev xlibre-server libxfont2))
    (native-inputs (list pkg-config autoconf automake libtool))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "VMware mouse input driver for X server")
    (description
     "xf86-input-vmmouse is a mouse driver for the Xorg X server.")
    (license license:x11))))

(define-public xlibre-input-void
  (let* ((pkgname "xlibre-input-void")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (arguments
      (list
        #:configure-flags
        #~(list
            #$@%xlibre-module-common-configure-flags)))
    (inputs (list xlibre-server libxfont2))
    (native-inputs (list pkg-config autoconf automake libtool))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "Void (null) input driver for X server")
    (description
     "xf86-input-void is a null input driver for the Xorg X server.")
    (license license:x11))))

(define-public xlibre-input-wacom
  (let* ((pkgname "xlibre-input-wacom")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (arguments
      (list #:configure-flags
            #~(list (string-append "--with-sdkdir=" #$output "/include/xorg")
                    (string-append "--with-xorg-conf-dir=" #$output
                                   "/share/X11/xorg.conf.d")
                    #$@%xlibre-module-common-configure-flags)
            #:phases
            #~(modify-phases %standard-phases
                (add-before 'bootstrap 'pre-bootstrap
                  #$%xlibre-module-autogen-fix))))
    (build-system gnu-build-system)
    (native-inputs (list pkg-config autoconf automake libtool))
    (inputs (list xlibre-server libxfont2 libxrandr libxinerama libxi eudev))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "Wacom input driver for X")
    (description "The xf86-input-wacom driver is the wacom-specific X11 input
driver for the X.Org X Server version 1.7 and later (X11R7.5 or later).")
    (license license:x11))))

(define-public xlibre-video-amdgpu
  (let* ((pkgname "xlibre-video-amdgpu")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (arguments
      (list
        #:configure-flags
        #~(list
            #$@%xlibre-module-common-configure-flags)
        #:make-flags
        #~(list
            #$@(%xlibre-module-common-make-flags "amdgpu" #:video #t))))
    (inputs (list xlibre-server libxfont2))
    (native-inputs (list pkg-config autoconf automake libtool))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "AMD Radeon video driver for X server")
    (description
     "xf86-video-amdgpu is an AMD Radeon video driver for the Xorg
X server.")
    (license license:x11))))

(define-public xlibre-video-apm
  (let* ((pkgname "xlibre-video-apm")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (arguments
      (list
        #:configure-flags
        #~(list
            #$@%xlibre-module-common-configure-flags)
        #:phases
        #~(modify-phases %standard-phases
            (add-before 'bootstrap 'pre-bootstrap
                        #$%xlibre-module-autogen-fix))))
    (inputs (list xlibre-server libxfont2))
    (native-inputs (list pkg-config autoconf automake libtool))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "Alliance Promotion graphics chipsets video driver for X server")
    (description
      "xf86-video-apm is an Alliance Promotion video driver for the Xorg X server.")
    (license license:expat))))

(define-public xlibre-video-ark
  (let* ((pkgname "xlibre-video-ark")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (arguments
      (list
        #:phases
        #~(modify-phases %standard-phases
            (add-before 'bootstrap 'pre-bootstrap
                        #$%xlibre-module-autogen-fix))
        #:configure-flags
        #~(list
            #$@%xlibre-module-common-configure-flags)))
    (inputs (list xlibre-server libxfont2))
    (native-inputs (list pkg-config autoconf automake libtool))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "Ark Logic video driver for X server")
    (description
     "xf86-video-ark is an Ark Logic video driver for the Xorg X server.")
    (license license:x11))))

;;;; xlibre-video-armada-novena

(define-public xlibre-video-ast
  (let* ((pkgname "xlibre-video-ast")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (home-page "https://github.com/X11Libre/xserver")
    (source src)
    (build-system gnu-build-system)
    (arguments
      (list
        #:configure-flags
        #~(list
            #$@%xlibre-module-common-configure-flags)))
    (inputs (list xlibre-server libxfont2))
    (native-inputs (list pkg-config autoconf automake libtool))
    (synopsis "ASpeed Technologies video driver for X server")
    (description
     "xf86-video-ast is an ASpeed Technologies video driver for the Xorg
X server.")
    (license license:x11))))

(define-public xlibre-video-ati
  (let* ((pkgname "xlibre-video-ati")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (arguments
      (list
        #:configure-flags
        #~(list
            #$@%xlibre-module-common-configure-flags)))
    (inputs (list mesa xorgproto xlibre-server libxfont2))
    (native-inputs
     (list pkg-config autoconf automake libtool autoconf automake libtool))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "ATI Radeon video driver for X server")
    (description
     "xf86-video-ati is an ATI Radeon video driver for the Xorg
X server.")
    (license license:x11))))

(define-public xlibre-video-chips
  (let* ((pkgname "xlibre-video-chips")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (arguments
      (list
        #:configure-flags
        #~(list
            #$@%xlibre-module-common-configure-flags)))
    (inputs (list mesa xorgproto xlibre-server libxfont2))
    (native-inputs
     (list pkg-config autoconf automake libtool autoconf automake libtool))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "Chips and Technologies video driver for X server")
    (description
      "xf86-video-chips is a video driver for the Xorg X server.")
    (license license:x11))))

(define-public xlibre-video-cirrus
  (let* ((pkgname "xlibre-video-cirrus")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (arguments
      (list
        #:configure-flags
        #~(list
            #$@%xlibre-module-common-configure-flags)))
    (inputs (list xlibre-server libxfont2))
    (native-inputs (list pkg-config autoconf automake libtool))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "Cirrus Logic video driver for X server")
    (description
     "xf86-video-cirrus is a Cirrus Logic video driver for the Xorg
X server.")
    (license license:x11))))

(define-public xlibre-video-dummy
  (let* ((pkgname "xlibre-video-dummy")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (arguments
      (list
        #:configure-flags
        #~(list
            #$@%xlibre-module-common-configure-flags)))
    (inputs (list xlibre-server libxfont2))
    (native-inputs (list pkg-config autoconf automake libtool))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "Dummy video driver for X server")
    (description
     "Virtual/offscreen frame buffer driver for the Xorg X server.")
    ;; per https://lists.freedesktop.org/archives/xorg/2020-June/060316.html
    (license license:x11))))

(define-public xlibre-video-fbdev
  (let* ((pkgname "xlibre-video-fbdev")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (arguments
      (list
        #:configure-flags
        #~(list
            #$@%xlibre-module-common-configure-flags)))
    (inputs (list xlibre-server libxfont2))
    (native-inputs (list pkg-config autoconf automake libtool))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "Framebuffer device video driver for X server")
    (description
     "xf86-video-fbdev is a video driver for the Xorg X server for
framebuffer device.")
    (license license:x11))))

;; TODO: fix build, build on arm
(define-public xlibre-video-freedreno
  (let* ((pkgname "xlibre-video-freedreno")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (inputs
     (list
       libdrm
       mesa
       eudev
       xlibre-server
       zlib
       libxfont2))
    (native-inputs
     (list pkg-config autoconf automake libtool))
     ;; This driver is only supported on ARM systems.
    (supported-systems '("armhf-linux" "aarch64-linux"))
    (arguments
     `(#:configure-flags
       (list (string-append "--with-xorg-conf-dir="
                            (assoc-ref %outputs "out")
                            "/share/X11/xorg.conf.d"))
       #:phases
       (modify-phases %standard-phases
         (replace 'bootstrap
           (lambda _
             ;; autogen.sh calls configure unconditionally.
             (invoke "autoreconf" "-vfi"))))))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "Adreno video driver for X server")
    (description
     "xf86-video-freedreno is a 2D graphics driver for the Xorg X server.
It supports a variety of Adreno graphics chipsets.")
    (license license:x11))))

(define-public xlibre-video-geode
  (let* ((pkgname "xlibre-video-geode")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (arguments
      (list
        #:configure-flags
        #~(list
            #$@%xlibre-module-common-configure-flags)))
    (inputs (list xlibre-server libxfont2))
    (native-inputs (list pkg-config autoconf automake libtool))
    (supported-systems
     ;; This driver is only supported on i686 systems.
     (filter (lambda (system) (string-prefix? "i686-" system))
             %supported-systems))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "AMD Geode GX/LX video driver for X server")
    (description
     "xf86-video-geode is an Xorg X server video driver for the AMD
Geode GX and LX processors.  The GX component supports both XAA and EXA
for graphics acceleration.  The LX component supports EXA, including
compositing.  Both support Xv overlay and dynamic rotation with XRandR.")
    (license license:x11))))

(define-public xlibre-video-i128
  (let* ((pkgname "xlibre-video-i128")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (arguments
      (list
        #:configure-flags
        #~(list
            #$@%xlibre-module-common-configure-flags)
        #:phases
        #~(modify-phases %standard-phases
            (add-before 'bootstrap 'pre-bootstrap
                        #$%xlibre-module-autogen-fix))))
    (inputs (list xlibre-server libxfont2))
    (native-inputs (list pkg-config autoconf automake libtool))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "I128 video driver for X server")
    (description
     "xf86-video-i128 is an I128 (Imagine 128) video driver for the Xorg
X server.")
    (license license:x11))))

(define-public xlibre-video-i740
  (let* ((pkgname "xlibre-video-i740")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (arguments
      (list
        #:configure-flags
        #~(list
            #$@%xlibre-module-common-configure-flags)))
    (inputs (list xlibre-server libxfont2))
    (native-inputs (list pkg-config autoconf automake libtool))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "I740 video driver for X server")
    (description
     "Intel 740 video driver for the X server.")
    (license license:x11))))

(define-public xlibre-video-intel
  (let* ((pkgname "xlibre-video-intel")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (inputs
      (list mesa
            eudev
            libx11
            libxfont2
            xlibre-server))
    (native-inputs
     (list pkg-config autoconf automake libtool))
    (supported-systems
     ;; This driver is only supported on Intel systems.
     (filter (lambda (system) (or (string-prefix? "i686-" system)
                                  (string-prefix? "x86_64-" system)))
             %supported-systems))
    (arguments
      ;; https://github.com/X11Libre/xserver/issues/401
      ;; Issue is fixed by removing -fno-plt from CFLAGS and adding -Wl,-z,lazy to LDFLAGS
      (list
        #:configure-flags
        #~(list
            "--with-default-accel=sna"
            #$@%xlibre-module-common-configure-flags)
        #:make-flags
        #~(list
            #$@(%xlibre-module-common-make-flags "intel" #:video #t))))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "Intel video driver for X server")
    (description
     "xf86-video-intel is a 2D graphics driver for the Xorg X server.
It supports a variety of Intel graphics chipsets.")
    (license license:x11))))

(define-public xlibre-video-mach64
  (let* ((pkgname "xlibre-video-mach64")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (arguments
      (list
        #:configure-flags
        #~(list
            #$@%xlibre-module-common-configure-flags)))
    (inputs (list mesa xorgproto xlibre-server libxfont2))
    (native-inputs
      (list pkg-config autoconf automake libtool))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "Mach64 video driver for X server")
    (description
     "xf86-video-mach64 is a video driver for the Xorg X server.
This driver is intended for all ATI video adapters based on the Mach64
series or older chipsets, providing maximum video function within
hardware limitations.  The driver is also intended to optionally provide
the same level of support for generic VGA or 8514/A adapters.")
    (license license:x11))))

(define-public xlibre-video-mga
  (let* ((pkgname "xlibre-video-mga")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (arguments
      (list
        #:configure-flags
        #~(list
            #$@%xlibre-module-common-configure-flags)))
    (inputs (list mesa xorgproto xlibre-server libxfont2))
    (native-inputs (list pkg-config autoconf automake libtool))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "Matrox video driver for X server")
    (description
     "xf86-video-mga is a Matrox video driver for the Xorg X server.")
    (license license:x11))))

(define-public xlibre-video-neomagic
  (let* ((pkgname "xlibre-video-neomagic")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (arguments
      (list
        #:configure-flags
        #~(list
            #$@%xlibre-module-common-configure-flags)))
    (inputs (list xorgproto xlibre-server libxfont2))
    (native-inputs (list pkg-config autoconf automake libtool))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "NeoMagic video driver for X server")
    (description
     "xf86-video-neomagic is a NeoMagic video driver for the Xorg X server.")
    (license license:x11))))

(define-public xlibre-video-nested
  (let* ((pkgname "xlibre-video-nested")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (arguments
      (list
        #:configure-flags
        #~(list
            #$@%xlibre-module-common-configure-flags)))
    (inputs (list xlibre-server libxfont2))
    (native-inputs (list pkg-config autoconf automake libtool))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "nested video driver for X server")
    (description
     "Driver to run Xorg on top of Xorg or something else.")
    (license license:x11))))

(define-public xlibre-video-nv
  (let* ((pkgname "xlibre-video-nv")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (arguments
      (list
        #:configure-flags
        #~(list
            #$@%xlibre-module-common-configure-flags)))
    (inputs (list xlibre-server libxfont2))
    (native-inputs (list pkg-config autoconf automake libtool))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "NVIDIA video driver for X server")
    (description
     "This package contains Xorg support for the NVIDIA GeForce 8 series of
graphics processors.

There are a few caveats of which to be aware: the XVideo extension is not
supported, and the RENDER extension is not accelerated by this driver.")
    (license license:x11))))

(define-public xlibre-video-nouveau
  (let* ((pkgname "xlibre-video-nouveau")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (arguments
      (list
        #:configure-flags
        #~(list
            "CFLAGS=-g -O2 -Wno-error=implicit-function-declaration"
            #$@%xlibre-module-common-configure-flags)))
    (inputs (list xlibre-server libxfont2))
    (native-inputs (list pkg-config autoconf automake libtool))
    (home-page "https://nouveau.freedesktop.org")
    (synopsis "NVIDIA video driver for X server")
    (description
     "This package provides modern, high-quality Xorg drivers for NVIDIA
graphics cards.")
    (license license:x11))))

(define xlibre-video-omap
  (let* ((pkgname "xlibre-video-omap")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (arguments
      (list
        #:configure-flags
        #~(list
            #$@%xlibre-module-common-configure-flags)))
    (inputs (list xlibre-server libxfont2 libdrm))
    (native-inputs (list pkg-config autoconf automake libtool which))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "TI OMAP video driver for X server")
    (description
      "TI OMAP video driver for the X server.")
    (license license:x11))))

(define xlibre-video-openchrome
  (let* ((pkgname "xlibre-video-openchrome")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (arguments
      (list
        #:configure-flags
        #~(list
            #$@%xlibre-module-common-configure-flags)
        #:phases
        #~(modify-phases %standard-phases
            (add-before 'bootstrap 'pre-bootstrap
                        #$%xlibre-module-autogen-fix))))
    (inputs (list xlibre-server libxfont2 libxvmc))
    (native-inputs (list pkg-config autoconf automake libtool))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "OpenChrome DDX video driver for X server")
    (description
     "OpenChrome DDX is an open source implementation of X.Org Server
DDX (Device Dependent X) graphics device driver for VIA Technologies
UniChrome and Chrome9 IGPs.")
    (license license:x11))))

(define-public xlibre-video-qxl
  (let* ((pkgname "xlibre-video-qxl")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (arguments
      (list
        #:phases
        #~(modify-phases %standard-phases
            (add-before 'bootstrap 'pre-bootstrap
                        #$%xlibre-module-autogen-fix))
        #:configure-flags
        #~(list
            #$@%xlibre-module-common-configure-flags)))
    (inputs
      (list libxfont2 spice-protocol xlibre-server xorgproto))
    (native-inputs
      (list pkg-config autoconf automake libtool))
    (synopsis "Qxl video driver for X server")
    (description "xf86-video-qxl is a video driver for the Xorg X server.
This driver is intended for the spice qxl virtio device.")
    (home-page "https://www.spice-space.org")
    (license license:x11))))

(define-public xlibre-video-r128
  (let* ((pkgname "xlibre-video-r128")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (arguments
      (list
        #:configure-flags
        #~(list
            #$@%xlibre-module-common-configure-flags)))
    (inputs (list mesa xorgproto xlibre-server libxfont2))
    (native-inputs
     (list pkg-config autoconf automake libtool))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "ATI Rage 128 video driver for X server")
    (description
     "xf86-video-r128 is a video driver for the Xorg X server.
This driver is intended for ATI Rage 128 based cards.")
    (license license:x11))))

(define-public xlibre-video-rendition
  (let* ((pkgname "xlibre-video-rendition")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (arguments
      (list
        #:configure-flags
        #~(list
            #$@%xlibre-module-common-configure-flags)))
    (inputs (list xlibre-server libxfont2))
    (native-inputs (list pkg-config autoconf automake libtool))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "Rendition video driver for X server")
    (description
     "Rendition video driver for the X server.")
    (license license:x11))))

(define-public xlibre-video-s3virge
  (let* ((pkgname "xlibre-video-s3virge")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (arguments
      (list
        #:configure-flags
        #~(list
            #$@%xlibre-module-common-configure-flags)))
    (inputs (list xlibre-server libxfont2))
    (native-inputs (list pkg-config autoconf automake libtool))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "S3 ViRGE video driver for X server")
    (description
     "The s3virge driver for Xorg supports the S3 ViRGE, ViRGE DX, GX,
GX2, MX, MX+, and VX chipsets. It also supports Trio3D and Trio3D/2x
chips.")
    (license license:x11))))

(define-public xlibre-video-savage
  (let* ((pkgname "xlibre-video-savage")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (arguments
      (list
        #:configure-flags
        #~(list
            #$@%xlibre-module-common-configure-flags)))
    (inputs (list mesa xorgproto xlibre-server libxfont2))
    (native-inputs (list pkg-config autoconf automake libtool))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "Savage video driver for X server")
    (description
     "xf86-video-savage is an S3 Savage video driver for the Xorg X server.")
    (license license:x11))))

(define-public xlibre-video-siliconmotion
  (let* ((pkgname "xlibre-video-siliconmotion")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source
      (origin
        (inherit src)
        #;(patches (search-patches "xf86-video-siliconmotion-fix-ftbfs.patch")))) ;; TODO:
    (build-system gnu-build-system)
    (arguments
      (list
        #:configure-flags
        #~(list
            #$@%xlibre-module-common-configure-flags)))
    (inputs (list xlibre-server libxfont2))
    (native-inputs (list pkg-config autoconf automake libtool))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "Silicon Motion video driver for X server")
    (description
     "xf86-video-siliconmotion is a Silicon Motion video driver for the
Xorg X server.")
    (license license:x11))))

(define-public xlibre-video-sis
  (let* ((pkgname "xlibre-video-sis")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (arguments
      (list
        #:configure-flags
        #~(list
            #$@%xlibre-module-common-configure-flags)))
    (inputs (list mesa xorgproto xlibre-server libxfont2))
    (native-inputs
     (list pkg-config autoconf automake libtool))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "Sis video driver for X server")
    (description
     "xf86-video-SiS is a SiS video driver for the Xorg X server.
This driver supports SiS chipsets of 300/315/330/340 series.")
    (license license:bsd-3))))

(define-public xlibre-video-sisusb
  (let* ((pkgname "xlibre-video-sisusb")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (arguments
      (list
        #:configure-flags
        #~(list
            #$@%xlibre-module-common-configure-flags)))
    (inputs (list mesa xorgproto xlibre-server libxfont2))
    (native-inputs (list pkg-config autoconf automake libtool))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "SiS Net2280-based USB video driver for the Xorg X server")
    (description
      "xf86-video-sisusb is a SiS Net2280-based USB video driver for the Xorg
X server.")
    (license license:bsd-3))))

(define-public xlibre-video-tdfx
  (let* ((pkgname "xlibre-video-tdfx")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (arguments
      (list
        #:configure-flags
        #~(list
            #$@%xlibre-module-common-configure-flags)))
    (inputs (list mesa xorgproto xlibre-server libxfont2))
    (native-inputs (list pkg-config autoconf automake libtool))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "3Dfx video driver for X server")
    (description
     "xf86-video-tdfx is a 3Dfx video driver for the Xorg X server.")
    (license license:x11))))

(define-public xlibre-video-trident
  (let* ((pkgname "xlibre-video-trident")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (arguments
      (list
        #:configure-flags
        #~(list
            #$@%xlibre-module-common-configure-flags)))
    (inputs (list xlibre-server libxfont2))
    (native-inputs (list pkg-config autoconf automake libtool))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "Trident video driver for X server")
    (description
     "Trident video driver for the X server.")
    (license license:x11))))

;;;; LICENSE:
;; the xf86-video-v4l source and some other xf86 drivers use a stub license,
;; wherein the licensing is bunted to the individual files:
;; the videodev2.h header file is GPLv2
;; the makefile is expat
;;
;; the v4l.c file is unlicensed, but has a copyright attribution to Mauro Carvalho Chehab -
;; on the grounds of the current file being a "major rewrite" -
;; the original source file was committed by Kaleb Keithley -
;; and is stated as being "based on Michael Schimek's permedia 2 driver" -
;; but I can't find definitive heratige to any specific code from the permedia 2 driver (xf86-video-glint) -
;; which is X11 licensed.
;;
;; I emailed Mauro for clarification.
;;
;; TODO: If not resolved, upstream this to nonguix instead of guix
(define-public xlibre-video-v4l
  (let* ((pkgname "xlibre-video-v4l")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (arguments
      (list
        #:configure-flags
        #~(list
            #$@%xlibre-module-common-configure-flags)
        #:make-flags
        #~(list
            #$@(%xlibre-module-common-make-flags "v4l" #:video #t))
        #:phases
        #~(modify-phases %standard-phases
            (add-before 'bootstrap 'pre-bootstrap
                        #$%xlibre-module-autogen-fix))))
    (inputs (list mesa xorgproto xlibre-server libxfont2))
    (native-inputs (list pkg-config autoconf automake libtool))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "Video 4 Linux adapter driver")
    (description
     "This chipset driver does not provide a graphics adaptor driver, but instead
registers a number of generic Xv adaptors which can be used with any graphics
chipset driver.")
    (license (list
               license:expat ;; formerly misidentified as x11?
               license:gpl2+)))))

(define-public xlibre-video-vbox
  (let* ((pkgname "xlibre-video-vbox")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (arguments
      (list
        #:configure-flags
        #~(list
            #$@%xlibre-module-common-configure-flags)))
    (inputs (list xlibre-server libxfont2))
    (native-inputs (list pkg-config autoconf automake libtool))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "VirtualBox video driver for X server")
    (description
     "This driver is only for use in VirtualBox guests without the vboxvideo
kernel modesetting driver in the guest kernel, and which are configured to
use the VBoxVGA device instead of a VMWare-compatible video device emulation.")
    (license license:x11))))

(define-public xlibre-video-vesa
  (let* ((pkgname "xlibre-video-vesa")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (arguments
      (list
        #:configure-flags
        #~(list
            #$@%xlibre-module-common-configure-flags)))
    (inputs (list xlibre-server libxfont2))
    (native-inputs (list pkg-config autoconf automake libtool))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "VESA video driver for X server")
    (description
     "xf86-video-vesa is a generic VESA video driver for the Xorg
X server.")
    (license license:x11))))

(define-public xlibre-video-vmware
  (let* ((pkgname "xlibre-video-vmware")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (arguments
      (list
        #:configure-flags
        #~(list
            #$@%xlibre-module-common-configure-flags)))
    (inputs
     (list libx11
           libxext
           llvm
           mesa ; for xatracker
           xlibre-server
           libxfont2))
    (native-inputs
     (list eudev pkg-config autoconf automake libtool))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "VMware SVGA video driver for X server")
    (description
     "xf86-video-vmware is a VMware SVGA video driver for the Xorg X server.")
    ;; This package only makes sense on some architectures.
    (supported-systems (list "x86_64-linux" "i686-linux"))
    (license license:x11))))

(define-public xlibre-video-voodoo
  (let* ((pkgname "xlibre-video-voodoo")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (arguments
      (list
        #:configure-flags
        #~(list
            #$@%xlibre-module-common-configure-flags)))
    (inputs (list xorgproto xlibre-server libxfont2))
    (native-inputs (list pkg-config autoconf automake libtool))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "Voodoo/Voodoo2 video driver for X server")
    (description
     "xf86-video-voodoo is a Voodoo video driver for the Xorg X server.")
    (license license:x11))))

(define xlibre-video-xgi
  (let* ((pkgname "xlibre-video-xgi")
         (source-info (hash-ref %xlibre-sources pkgname))
         (vers (car source-info))
         (src (cdr source-info)))
  (package
    (name pkgname)
    (version vers)
    (source src)
    (build-system gnu-build-system)
    (arguments
      (list
        #:configure-flags
        #~(list
            #$@%xlibre-module-common-configure-flags)
        #:phases
        #~(modify-phases %standard-phases
            (add-before 'bootstrap 'pre-bootstrap
                        #$%xlibre-module-autogen-fix))))
    (inputs (list xlibre-server libxfont2))
    (native-inputs (list pkg-config autoconf automake libtool which))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis " video driver for X server")
    (description
     " video driver for the X server.")
    (license license:x11))))

(define-public xlibre-video-ps3
  (package
    (name "xlibre-video-ps3")
    (version "1.2.6.1")
    (source
      (origin
        (method git-fetch)
        (uri (git-reference
               (url "https://github.com/rxrbln/xf86-video-ps3")
               (commit "e49048d9b81adc487e5a9a275264c1fd72ea284f")))
        (sha256
          (base32
            "0w48z04yj2y8sl148fzz5cf9mywnfiaq5rfrpm585kgv0l11h7qn"))))
    (build-system gnu-build-system)
    (supported-systems '("powerpc-linux" "powerpc64le-linux"))
    (arguments
      (list
        #:phases
        #~(modify-phases %standard-phases
            (add-before 'bootstrap 'pre-bootstrap
                        #$%xlibre-module-autogen-fix))))
    (inputs (list xorgproto xlibre-server libxfont2))
    (native-inputs (list pkg-config autoconf automake libtool))
    (home-page "https://github.com/rxrbln/xf86-video-ps3")
    (synopsis "PS3 Driver for XLibre X server")
    (description
     "xf86-video-ps3 is a PS3 video driver for the Xorg X server.")
    (license license:x11)))

;;;;;; helpers

(define-public replace-xorg-server
  "Replace xorg-server with xlibre-server."
  (package-input-rewriting/spec
    (list
      (cons "xorg-server" (lambda _ xlibre-server)))
    #:deep? #t #:replace-hidden? #t))

(define (xf86-module->xlibre module . extra-packages)
  "Takes a package (an xf86 X11 module) and replaces the xorg-server package with xlibre-server.
Also adds lixfont2 package as input, dependency for xlibre.
Extra arguments are other packages to add to inputs, for convenience."
  (let ((new-packages (cons* libxfont2 extra-packages)))
    (replace-xorg-server
      (package
        (inherit module)
        (name (string-append (package-name module) "-xlibre"))
        (inputs
          (fold
            (lambda (pkg inputs)
              (modify-inputs inputs (append pkg)))
            (package-inputs module)
            new-packages))))))

(define %all-xlibre-modules '())

(define-syntax define-xlibre-module
  (lambda (x)
    (syntax-case x ()
      ((_ new-package old-package . pkgs)
         #'(begin
             (define-public new-package
               (xf86-module->xlibre old-package . pkgs))
             (set! %all-xlibre-modules
               (cons (cons (package-name old-package) (lambda _ new-package)) %all-xlibre-modules))))
      (rest #'(warn "bad syntax" 'rest)))))

;;;;;; modules derived from xorg variant

(define-public xf86-input-keyboard-xlibre
  (deprecated-package "xf86-input-keyboard-xlibre" xlibre-input-keyboard))
(define-public xf86-input-mouse-xlibre
  (deprecated-package "xf86-input-mouse-xlibre" xlibre-input-mouse))
(define-public xf86-video-ark-xlibre
  (deprecated-package "xf86-video-ark-xlibre" xlibre-video-ark))
(define-public xf86-video-i128-xlibre
  (deprecated-package "xf86-video-i128-xlibre" xlibre-video-i128))
(define-public xf86-video-qxl-xlibre
  (deprecated-package "xf86-video-qxl-xlibre" xlibre-video-qxl))

#;(define-xlibre-module xf86-video-glide-xlibre           xf86-video-glide)
#;(define-xlibre-module xf86-video-newport-xlibre         xf86-video-newport)
#;(define-xlibre-module xf86-video-wsfb-xlibre            xf86-video-wsfb)

;; wacomlinux is still maintaining the wacom xorg driver
;; there are differing commits between them, but currently xlibre only works
;; with the xlibre fork
(define-public xf86-input-wacom-xlibre
  (replace-xorg-server
    (package
      (inherit xf86-input-wacom)
      (name "xf86-input-wacom-xlibre")
      (version "1.2.3")
      (source
        (origin
          (method url-fetch)
          (uri (string-append
                 "https://github.com/linuxwacom/xf86-input-wacom/releases/download/"
                 "xf86-input-wacom-" version "/"
                 "xf86-input-wacom-" version ".tar.bz2"))
          (sha256
            (base32 "0imi3iraarralyw1w4c6qxw5wdrciw28zawgv60wqn6aqck5hdkh"))))
      (inputs
        (modify-inputs
          (package-inputs xf86-input-wacom)
            (append libxfont2)))
      (arguments
        (substitute-keyword-arguments (package-arguments xf86-input-wacom)
          ((#:configure-flags flags '())
           #~(#$@flags
              "CFLAGS=-g -O2 -Wno-error=implicit-function-declaration"
              #$@%xlibre-module-common-configure-flags)))))))

;;;;;; configuration helpers

(define-public replace-xorg-modules
  "Replace xorg modules with xlibre modules."
  (package-input-rewriting/spec
    %all-xlibre-modules
    #:deep? #t #:replace-hidden? #t))

(define-public replace-xorg
  "Thorough package-input-rewriting procedure for xorg -> xlibre."
  (package-input-rewriting/spec
    (cons
      (cons "xorg-server" (lambda _ xlibre-server))
      %all-xlibre-modules)
    #:deep? #t #:replace-hidden? #t))

(define-public %default-xlibre-modules
  (list xlibre-video-vesa
        xlibre-video-fbdev
        xlibre-video-amdgpu
        xlibre-video-ati
        xlibre-video-cirrus
        xlibre-video-intel
        xlibre-video-mach64
        xlibre-video-nouveau
        xlibre-video-nv
        xlibre-video-sis

        xlibre-input-libinput
        xlibre-input-evdev
        xlibre-input-mouse))

(define-syntax xlibre-configuration
  (lambda (x)
    "Like xorg-configuration, but returns a record with xlibre server and modules."
    (syntax-case x ()
      ((_ . rest)
       (with-syntax
         ((args
            (datum->syntax x
              (fold
                (lambda (f conf) (f conf))
                (syntax->datum #'rest)
                (let ((cond-add (lambda (name opt)
                                  (lambda (config)
                                    (if (assq name config)
                                      config
                                      (cons
                                        (list name opt)
                                        config))))))
                  (list (cond-add 'server 'xlibre-server)
                        (cond-add 'modules '%default-xlibre-modules)))))))
         #'(xorg-configuration . args))))))

(define-public (xorg-configuration->xlibre-configuration config)
  "Takes an xorg-configuration record and returns an xorg-configuration record for xlibre.
Server is replaced with xlibre-server, and modules are transformed to support xlibre."
  (xorg-configuration
    (inherit config)
    (server xlibre-server)
    (modules
      (map
        xf86-module->xlibre
        (xorg-configuration-modules config)))))

xlibre-server
