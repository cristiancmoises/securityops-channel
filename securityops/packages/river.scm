;;; SPDX-License-Identifier: BSD-3-Clause
;;; Copyright © 2026 SecurityOps contributors
;;; Adapted from xmonad-wayland's BSD-3-Clause packaging recipes.
;;; See LICENSES/xmonad-wayland-BSD3.txt.

(define-module (securityops packages river)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module (guix build-system zig)
  #:use-module ((guix licenses)
                #:prefix license:)
  #:use-module (gnu packages check)
  #:use-module (gnu packages freedesktop)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages man)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages terminals)
  #:use-module (gnu packages window-management)
  #:use-module (gnu packages xdisorg)
  #:use-module (gnu packages xorg)
  #:use-module (gnu packages zig))

;;; Keep the compositor's direct Wayland dependencies on the same stable ABI.

(define-public wayland-latest
  (package
    (inherit wayland)
    (version "1.26.0")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://gitlab.freedesktop.org/wayland/wayland/-/releases/1.26.0/downloads/"
             "wayland-1.26.0.tar.xz"))
       (file-name "wayland-1.26.0.tar.xz")
       (sha256
        (base32 "18xpc8qv5ll1hfswjfphzlbzrbrihgpyby46w81rk5p48sm6w5v4"))))
    (arguments
     (substitute-keyword-arguments (package-arguments wayland)
       ((#:phases phases)
        #~(modify-phases #$phases
            (add-after 'unpack 'use-source-book
              (lambda _
                ;; The pinned Guix lacks mdbook.  Keep the generated API
                ;; documentation and ship the new manual as Markdown sources.
                (substitute* "doc/meson.build"
                  (("mdbook = find_program\\('mdbook'\\)")
                   "")
                  (("subdir\\('book'\\)")
                   ""))
                (setenv "WAYLAND_BOOK_SOURCE"
                        (string-append (getcwd) "/doc/book"))))
            (add-after 'move-doc 'install-source-book
              (lambda _
                (copy-recursively (getenv "WAYLAND_BOOK_SOURCE")
                                  (string-append #$output:doc
                                   "/share/doc/wayland/book-sources"))))))))))

(define-public wayland-protocols-latest
  (package
    (inherit wayland-protocols)
    (version "1.49")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://gitlab.freedesktop.org/wayland/"
                           "wayland-protocols/-/releases/1.49/downloads/"
                           "wayland-protocols-1.49.tar.xz"))
       (file-name "wayland-protocols-1.49.tar.xz")
       (sha256
        (base32 "050b4jny5pkylx79fpcki9hzzy8f9xvf8k4brrxgyv9djis8yk7c"))))
    (inputs (modify-inputs (package-inputs wayland-protocols)
              (replace "wayland" wayland-latest)))
    (native-inputs (modify-inputs (package-native-inputs wayland-protocols)
                     (replace "wayland" wayland-latest)))))

(define-public libevdev-latest
  (package
    (inherit libevdev)
    (version "1.13.7")
    (source
     (origin
       (method url-fetch)
       (uri
        "https://www.freedesktop.org/software/libevdev/libevdev-1.13.7.tar.xz")
       (file-name "libevdev-1.13.7.tar.xz")
       (sha256
        (base32 "19mzc3h6kq166vv46bg8y4xpv38rmqxl6mnk5axib3qhf54q5bqc"))))
    (native-inputs (modify-inputs (package-native-inputs libevdev)
                     (prepend check)))))

(define-public libinput-minimal-latest
  (package
    (inherit libinput-minimal)
    ;; Upstream stable release 1.32.0, published 2026-09-17.
    (version "1.32.0")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://gitlab.freedesktop.org/libinput/libinput/-/archive/1.32.0/"
             "libinput-1.32.0.tar.gz"))
       (file-name "libinput-1.32.0.tar.gz")
       (sha256
        (base32 "1m68z91fk54yqgz3mgs3raynhkk3vaf67mnc21lfp1jcjv5c3mkx"))))
    (arguments
     (substitute-keyword-arguments (package-arguments libinput-minimal)
       ((#:phases phases)
        #~(modify-phases #$phases
            (add-after 'unpack 'install-license
              (lambda _
                ;; The inherited minimal package's name differs from the
                ;; source directory, so the generic license lookup misses it.
                (install-file "COPYING"
                              (string-append #$output
                                             "/share/doc/libinput-minimal"))))))))
    (inputs (modify-inputs (package-inputs libinput-minimal)
              (replace "libevdev" libevdev-latest)))))

(define-public libxkbcommon-latest
  (package
    (inherit libxkbcommon)
    (version "1.13.2")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://codeload.github.com/xkbcommon/libxkbcommon/tar.gz/refs/tags/"
             "xkbcommon-1.13.2"))
       (file-name "libxkbcommon-1.13.2.tar.gz")
       (sha256
        (base32 "0a2m71rihcm9ka94fbvr8vgcwkp8xnzbvn08ingmzfnbqgvxbi5c"))))
    (inputs (modify-inputs (package-inputs libxkbcommon)
              (replace "wayland" wayland-latest)
              (replace "wayland-protocols" wayland-protocols-latest)))
    (native-inputs (modify-inputs (package-native-inputs libxkbcommon)
                     ;; Generate and run the optional merge-modes regression tests.
                     (prepend python-jinja2)
                     (replace "wayland" wayland-latest)))))

(define-public xwayland-latest
  (package
    (inherit xorg-server-xwayland)
    (home-page "https://www.x.org/")
    (inputs (modify-inputs (package-inputs xorg-server-xwayland)
              (replace "wayland" wayland-latest)
              (replace "wayland-protocols" wayland-protocols-latest)))
    (native-inputs (modify-inputs (package-native-inputs xorg-server-xwayland)
                     (replace "wayland" wayland-latest)
                     (replace "wayland-protocols" wayland-protocols-latest)))))

(define-public wlroots-latest
  (package
    (inherit wlroots-0.20)
    (propagated-inputs (modify-inputs (package-propagated-inputs wlroots-0.20)
                         (replace "wayland" wayland-latest)
                         (replace "wayland-protocols" wayland-protocols-latest)
                         (replace "libinput-minimal" libinput-minimal-latest)
                         (replace "libxkbcommon" libxkbcommon-latest)
                         (replace "xorg-server-xwayland" xwayland-latest)))
    (native-inputs (modify-inputs (package-native-inputs wlroots-0.20)
                     (replace "wayland" wayland-latest)))))

(define-public foot-latest
  (package
    (inherit foot)
    (version "1.28.0")
    (source
     (origin
       (method url-fetch)
       (uri "https://codeberg.org/dnkl/foot/archive/1.28.0.tar.gz")
       (file-name "foot-1.28.0.tar.gz")
       (sha256
        (base32 "0dxhy12p0845nmvap7dcps98z49bp6fyd625ad4x112n5d0bx5j2"))))
    (inputs (modify-inputs (package-inputs foot)
              (replace "wayland" wayland-latest)
              (replace "wayland-protocols" wayland-protocols-latest)
              (replace "libxkbcommon" libxkbcommon-latest)))
    ;; The generated emoji tables incorporate Unicode data.
    (license (list license:expat license:unicode))
    (native-inputs (modify-inputs (package-native-inputs foot)
                     (replace "wayland" wayland-latest)
                     (replace "wayland-protocols" wayland-protocols-latest)))))

(define-public fuzzel-latest
  (package
    (inherit fuzzel)
    (version "1.15.0")
    (source
     (origin
       (method url-fetch)
       (uri "https://codeberg.org/dnkl/fuzzel/archive/1.15.0.tar.gz")
       (file-name "fuzzel-1.15.0.tar.gz")
       (sha256
        (base32 "0fygnnkqsis1as5mz3za86zi3hvw86a1az6lhsspl70zzhic1dlm"))))
    (inputs (modify-inputs (package-inputs fuzzel)
              (replace "wayland" wayland-latest)
              (replace "wayland-protocols" wayland-protocols-latest)
              (replace "libxkbcommon" libxkbcommon-latest)))
    (native-inputs (modify-inputs (package-native-inputs fuzzel)
                     (replace "wayland" wayland-latest)
                     (replace "wayland-protocols" wayland-protocols-latest)))))

(define-public swaybg-latest
  (package
    (inherit swaybg)
    (version "1.2.2")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://codeload.github.com/swaywm/swaybg/tar.gz/refs/tags/v"
             version))
       (file-name (string-append "swaybg-" version ".tar.gz"))
       (sha256
        (base32 "0h6jshdv4qw1sbix82ppv8zkla4wvyf1ychg9darx5jxfrmc1rcl"))))
    (inputs (modify-inputs (package-inputs swaybg)
              (replace "wayland" wayland-latest)
              (replace "wayland-protocols" wayland-protocols-latest)))
    (native-inputs (modify-inputs (package-native-inputs swaybg)
                     (replace "wayland" wayland-latest)
                     (replace "wayland-protocols" wayland-protocols-latest)))
    (home-page "https://github.com/swaywm/swaybg")))

(define-public mako-latest
  (package
    (inherit mako)
    (version "1.11.0")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://codeload.github.com/emersion/mako/tar.gz/refs/tags/v"
             version))
       (file-name (string-append "mako-" version ".tar.gz"))
       (sha256
        (base32 "10kjmhqs3bsvvp8xvwhcpr8rfiyfx9szhzqhl2ydz8r0r8zivlbj"))))
    (inputs (modify-inputs (package-inputs mako)
              (replace "wayland" wayland-latest)))
    (native-inputs (modify-inputs (package-native-inputs mako)
                     (replace "wayland-protocols" wayland-protocols-latest)))))

(define-public swaylock-latest
  (package
    (inherit swaylock)
    (version "1.8.6")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://codeload.github.com/swaywm/swaylock/tar.gz/refs/tags/v"
             version))
       (file-name (string-append "swaylock-" version ".tar.gz"))
       (sha256
        (base32 "11m687y8gqwz1b2wrvmyz08hxnbpqqwnaq22s24gizrb07ypchwh"))))
    (inputs (modify-inputs (package-inputs swaylock)
              (replace "wayland" wayland-latest)
              (replace "wayland-protocols" wayland-protocols-latest)
              (replace "libxkbcommon" libxkbcommon-latest)))
    (native-inputs (modify-inputs (package-native-inputs swaylock)
                     (replace "wayland" wayland-latest)
                     (replace "wayland-protocols" wayland-protocols-latest)))))

(define-public wlr-randr-latest
  (package
    (inherit wlr-randr)
    (version "0.5.0")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://gitlab.freedesktop.org/emersion/wlr-randr/-/archive/v0.5.0/"
             "wlr-randr-v0.5.0.tar.gz"))
       (file-name "wlr-randr-0.5.0.tar.gz")
       (sha256
        (base32 "0fi6mka6ix5x9h3n6qrl0l1qfxavmnj1a51zfcf80kxqvm7xjrn5"))))
    (inputs (modify-inputs (package-inputs wlr-randr)
              (replace "wayland" wayland-latest)))
    (native-inputs (modify-inputs (package-native-inputs wlr-randr)
                     (replace "wayland" wayland-latest)
                     (replace "wayland-protocols" wayland-protocols-latest)))
    (home-page "https://gitlab.freedesktop.org/emersion/wlr-randr")))

(define pixman-source
  (origin
    (method url-fetch)
    (uri "https://codeberg.org/ifreund/zig-pixman/archive/v0.3.0.tar.gz")
    (file-name "zig-pixman-0.3.0.tar.gz")
    (sha256 (base32 "17j90nnn2gd4pakg4nqmj8n0v0v0s29yqvn75wn3mfzp6z75f2sb"))))

(define wayland-source
  (origin
    (method url-fetch)
    (uri "https://codeberg.org/ifreund/zig-wayland/archive/v0.6.0.tar.gz")
    (file-name "zig-wayland-0.6.0.tar.gz")
    (sha256 (base32 "09gga9c758vsmwb9la20bpk38bwxlr1lmmyj2bjf0j596qp676km"))))

(define wlroots-source
  (origin
    (method url-fetch)
    (uri "https://codeberg.org/ifreund/zig-wlroots/archive/v0.20.1.tar.gz")
    (file-name "zig-wlroots-0.20.1.tar.gz")
    (sha256 (base32 "0xd18dqc4ydkw0laj4apgh08iav4423kh9pajyl1xa6jiiid3xfl"))))

(define xkbcommon-source
  (origin
    (method url-fetch)
    (uri "https://codeberg.org/ifreund/zig-xkbcommon/archive/v0.4.0.tar.gz")
    (file-name "zig-xkbcommon-0.4.0.tar.gz")
    (sha256 (base32 "1ixmp1sjwq5scy0l2i678xxksgr084bmsam89p6xal3fmlsqh7yc"))))

(define translate-c-source
  (origin
    (method url-fetch)
    (uri
     "https://codeberg.org/ziglang/translate-c/archive/57c559cf581b1fcad90494eda219f98abeb155ce.tar.gz")
    (file-name "zig-translate-c-57c559c.tar.gz")
    (sha256 (base32 "0pn6kp6n1jr800hkahk9kx8qjamb21yami1761dn8iva67rmvamr"))))

(define aro-source
  (origin
    (method url-fetch)
    (uri
     "https://codeload.github.com/Vexu/arocc/tar.gz/5f5a050569a95ecc40a426f0c3666ae7ef987ede")
    (file-name "zig-aro-5f5a050.tar.gz")
    (sha256 (base32 "0zpb3lx3cgdfia97hz2cwhgnjay0iw6sg66pl5dfzs2962hlj2z2"))))

(define river-zig-dependencies
  '(("pixman-source"
     "pixman-0.3.0-LClMnz2VAAAs7QSCGwLimV5VUYx0JFnX5xWU6HwtMuDX")
    ("wayland-source"
     "wayland-0.6.0-lQa1kqz8AQADQmdNJsNhLoNHcnEGEUjrOaPV-dtEnEmX")
    ("wlroots-source"
     "wlroots-0.20.1-jmOlcqNVBAB3uB5oqBTzpRlwu-FmMyyZMVAWCe5kmcSt")
    ("xkbcommon-source"
     "xkbcommon-0.4.0-VDqIe0i2AgDRsok2GpMFYJ8SVhQS10_PI2M_CnHXsJJZ")
    ("translate-c-source"
     "translate_c-0.0.0-Q_BUWlX1BgCD1wo6uo97prlp9VJ4gxAjwN_vZ7nsSjGN")
    ("aro-source" "aro-0.0.0-JSD1Qi7QNgDnfcrdEJf82v3o6MhZySjYVrtdfEf3E4Se")))

(define-public river-xmonad-runtime
  (package
    (name "river-xmonad-runtime")
    (version "0.4.8")
    (source
     (origin
       (method url-fetch)
       (uri
        "https://codeberg.org/river/river/releases/download/v0.4.8/river-0.4.8.tar.gz")
       (file-name "river-0.4.8.tar.gz")
       (sha256
        (base32 "1yh08k9w450k5vir7paksfp87ddcvbbb8rvi6pg40zihdr930h3d"))
       (patches (map (lambda (name)
                       (search-path %load-path
                                    (string-append "securityops/patches/" name)))
                     '("river-xmonad-runtime-preserve-active-keyboard.patch"
                       "river-xmonad-runtime-seat-assignment-log.patch"
                       "river-xmonad-runtime-layer-initial-resize.patch")))))
    (build-system zig-build-system)
    (arguments
     (list
      #:zig zig-0.16
      #:install-source? #f
      #:zig-release-type "safe"
      #:zig-build-flags
      #~(list "-Dpie"
              "-Dxwayland"
              "-Dcpu=baseline"
              "-Dllvm=true"
              "--system"
              "/tmp/zig-cache/p")
      #:zig-test-flags
      #~(list "-Doptimize=ReleaseSafe" "-Dcpu=baseline" "-Dllvm=true"
              "--system" "/tmp/zig-cache/p")
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'configure 'keep-pkg-config-include-paths
            (lambda _
              ;; pkg-config suppresses Guix's C_INCLUDE_PATH entries by default,
              ;; but the separate Aro translate-c tool does not read that variable.
              (setenv "PKG_CONFIG_ALLOW_SYSTEM_CFLAGS" "1")))
          (add-after 'unpack 'use-guix-shell
            (lambda _
              (substitute* '("build.zig" "river/main.zig")
                (("/bin/sh")
                 (which "sh")))))
          ;; Keep upstream dependency names and content hashes intact.
          ;; Seed only the verified archives; --system then prohibits downloads.
          (replace 'unpack-dependencies
            (lambda* (#:key inputs native-inputs #:allow-other-keys)
              (let ((all-inputs (append (or native-inputs
                                            '()) inputs)))
                (for-each (lambda (entry)
                            (let ((archive (assoc-ref all-inputs
                                                      (car entry)))
                                  (expected (cadr entry)))
                              (unless archive
                                (error "missing Zig source archive"
                                       (car entry)))
                              (invoke "zig" "fetch" "--global-cache-dir"
                                      "/tmp/zig-cache" archive)
                              ;; Zig 0.16 caches fetched packages as archives.
                              ;; --system expects hash-named directories.
                              (let ((cached (string-append "/tmp/zig-cache/p/"
                                             expected ".tar.gz")))
                                (unless (file-exists? cached)
                                  (error "upstream Zig content hash mismatch"
                                         (car entry)))
                                (invoke "tar"
                                        "--extract"
                                        "--gzip"
                                        "--no-same-owner"
                                        "--file"
                                        cached
                                        "--directory"
                                        "/tmp/zig-cache/p"))
                              (unless (file-exists? (string-append
                                                     "/tmp/zig-cache/p/"
                                                     expected "/build.zig.zon"))
                                (error "upstream Zig content hash mismatch"
                                       (car entry)))))
                          '#$river-zig-dependencies))))
          (add-after 'install 'fix-installed-protocol-prefix
            (lambda _
              (substitute* (string-append #$output
                            "/share/pkgconfig/river-protocols.pc")
                (("^prefix=.*")
                 (string-append "prefix="
                                #$output "\n")))))
          (add-after 'install 'check-installed-version
            (lambda _
              (invoke (string-append #$output "/bin/river") "-version"))))))
    (inputs (list libevdev-latest
                  libinput-minimal-latest
                  wlroots-latest
                  wayland-latest
                  libxkbcommon-latest
                  pixman))
    (native-inputs (list (list "pkg-config" pkg-config)
                         (list "scdoc" scdoc)
                         (list "wayland" wayland-latest)
                         (list "wayland-protocols" wayland-protocols-latest)
                         (list "pixman-source" pixman-source)
                         (list "wayland-source" wayland-source)
                         (list "wlroots-source" wlroots-source)
                         (list "xkbcommon-source" xkbcommon-source)
                         (list "translate-c-source" translate-c-source)
                         (list "aro-source" aro-source)))
    (home-page "https://isaacfreund.com/software/river/")
    (synopsis "River compositor for the experimental XMonad Wayland manager")
    (description
     "River separates Wayland composition from window-management policy.
This package builds River with Xwayland support and requires a
separate window manager implementing river-window-management-v1.  It is used
by the XMonad Wayland nested test and does not configure a system session.")
    (supported-systems '("x86_64-linux" "aarch64-linux"))
    (license (list license:gpl3 license:expat license:bsd-0
                   license:cc-by-sa4.0))))

(define channel-commit
  "94a3d6c72c7493dd21a3b2ed10f8776bb887b857")

(define channel-wayland-source
  (origin
    (method url-fetch)
    (uri "https://codeberg.org/ifreund/zig-wayland/archive/v0.6.0.tar.gz")
    (file-name "zig-wayland-0.6.0.tar.gz")
    (sha256 (base32 "09gga9c758vsmwb9la20bpk38bwxlr1lmmyj2bjf0j596qp676km"))))

(define channel-tributary-source
  (origin
    (method url-fetch)
    (uri (string-append "https://codeberg.org/Sivecano/libtributary/archive/"
                        "b1e00ffdc1a87f6601b7913a1196c488ff39b27d.tar.gz"))
    (file-name "libtributary-b1e00ff.tar.gz")
    (sha256 (base32 "008br7rmcmv5zhiblmdjycsc9w3h6j5vxm5ch4qdj7hh7p6f7902"))))

(define channel-zig-dependencies
  '(("wayland-source"
     "wayland-0.6.0-lQa1kqz8AQADQmdNJsNhLoNHcnEGEUjrOaPV-dtEnEmX")
    ("tributary-source"
     "tributary-0.4.1-tqCfWzbUAACWcbClrEM-xQIfPNogwri6nGNyWrt123vK")))

(define-public channel-river-input
  (package
    (name "channel-river-input")
    ;; The unreleased manifest says 0.4.2; 0.4.1 is the latest release tag.
    (version (git-version "0.4.1" "1" channel-commit))
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://codeberg.org/Sivecano/channel/archive/"
                           channel-commit ".tar.gz"))
       (file-name (string-append "channel-" channel-commit ".tar.gz"))
       (sha256
        (base32 "1zh69wg2qgmqvmy565w5v09bw07xrzp6367qcn8dpa6i135aimpq"))))
    (build-system zig-build-system)
    (arguments
     (list
      #:zig zig-0.16
      #:install-source? #f
      #:zig-release-type "safe"
      #:zig-build-flags
      #~(list "-Dcpu=baseline" "--system" "/tmp/zig-cache/p")
      #:zig-test-flags
      #~(list "-Doptimize=ReleaseSafe"
              "-Dcpu=baseline"
              "--summary"
              "all"
              "--system"
              "/tmp/zig-cache/p")
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'configure-kernel-header-path
            (lambda _
              (substitute* "build.zig"
                (("    translate_c.linkSystemLibrary")
                 (string-append
                  "    translate_c.addSystemIncludePath(.{ .cwd_relative = \""
                  #$(file-append linux-libre-headers "/include")
                  "\" });\n    translate_c.linkSystemLibrary")))))
          (add-after 'configure 'keep-pkg-config-include-paths
            (lambda _
              ;; Zig's C translator needs explicit system-library include flags.
              (setenv "PKG_CONFIG_ALLOW_SYSTEM_CFLAGS" "1")))
          (replace 'unpack-dependencies
            (lambda* (#:key inputs native-inputs #:allow-other-keys)
              (let ((all-inputs (append (or native-inputs
                                            '()) inputs)))
                (for-each (lambda (entry)
                            (let* ((archive (assoc-ref all-inputs
                                                       (car entry)))
                                   (expected (cadr entry))
                                   (cached (string-append "/tmp/zig-cache/p/"
                                                          expected ".tar.gz")))
                              (invoke "zig" "fetch" "--global-cache-dir"
                                      "/tmp/zig-cache" archive)
                              (unless (file-exists? cached)
                                (error "upstream Zig content hash mismatch"
                                       (car entry)))
                              (invoke "tar"
                                      "--extract"
                                      "--gzip"
                                      "--no-same-owner"
                                      "--file"
                                      cached
                                      "--directory"
                                      "/tmp/zig-cache/p")
                              (unless (file-exists? (string-append
                                                     "/tmp/zig-cache/p/"
                                                     expected "/build.zig.zon"))
                                (error "missing verified Zig package"
                                       (car entry)))))
                          '#$channel-zig-dependencies))))
          (add-after 'unpack-dependencies 'enable-tributary-tests
            (lambda _
              ;; Use the same Wayland module that Channel supplies to tributary.
              ;; Upstream's standalone test target omits that required import.
              (substitute* "build.zig"
                (("    b.installArtifact\\(exe\\);")
                 (string-append
                  "    const tests = b.addTest(.{ .root_module = mod_tributary });
"
                  "    const run_tests = b.addRunArtifact(tests);
"
                  "    b.step(\"test\", \"Run libtributary tests\")"
                  ".dependOn(&run_tests.step);\n"
                  "    b.installArtifact(exe);")))
              ;; Preserve the upstream rectangle test after Vec2 became a struct.
              (substitute* (string-append "/tmp/zig-cache/p/"
                                          (cadr (assoc "tributary-source"
                                                       '#$channel-zig-dependencies))
                                          "/src/utils.zig")
                (("\\.\\{ 0, 0 \\}")
                 ".{ .x = 0, .y = 0 }")
                (("\\.\\{ 20, 20 \\}")
                 ".{ .x = 20, .y = 20 }")
                (("\\.\\{ 25, 25 \\}")
                 ".{ .x = 25, .y = 25 }")
                (("\\.\\{ 100, 100 \\}")
                 ".{ .x = 100, .y = 100 }"))))
          (add-after 'install 'install-documentation
            (lambda* (#:key inputs native-inputs #:allow-other-keys)
              (let ((doc (string-append #$output
                                        "/share/doc/channel-river-input"))
                    (all-inputs (append (or native-inputs
                                            '()) inputs)))
                (install-file "README.asciidoc" doc)
                (install-file "config.rh" doc)
                ;; The tributary Zig manifest excludes its license file.
                (mkdir-p "tributary-license")
                (invoke "tar"
                        "--extract"
                        "--gzip"
                        "--no-same-owner"
                        "--file"
                        (assoc-ref all-inputs "tributary-source")
                        "--strip-components=1"
                        "--directory"
                        "tributary-license"
                        "libtributary/LICENSE")
                (copy-file "tributary-license/LICENSE"
                           (string-append doc "/libtributary-LICENSE"))))))))
    (native-inputs (list (list "pkg-config" pkg-config)
                         (list "linux-libre-headers" linux-libre-headers)
                         (list "river-xmonad-runtime" river-xmonad-runtime)
                         (list "wayland" wayland-latest)
                         (list "wayland-protocols" wayland-protocols-latest)
                         (list "wayland-source" channel-wayland-source)
                         (list "tributary-source" channel-tributary-source)))
    (inputs (list wayland-latest libxkbcommon-latest))
    (home-page "https://codeberg.org/Sivecano/channel")
    (synopsis "Input configuration daemon for River")
    (description
     "Channel configures River input devices through the River input-management,
libinput-configuration and XKB-configuration protocols.  It reads profiles and
matching rules from the River config.rh file, applying settings when devices
appear or the configuration changes.  It runs separately from the window
manager and does not configure the system or start itself automatically.")
    (supported-systems '("x86_64-linux" "aarch64-linux"))
    (license (list license:agpl3 license:expat))))
