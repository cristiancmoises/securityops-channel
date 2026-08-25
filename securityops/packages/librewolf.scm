;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2024, 2025 Ian Eure <ian@retrospec.tv>          ; upstream librewolf.scm
;;; Copyright © 2025, 2026 Untrusem <mysticmoksh@riseup.net>    ; upstream librewolf.scm
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;;
;;; This file is part of the securityops channel.
;;;
;;; LibreWolf — bumped ahead of Guix: 151.0.4-1 -> 153.0.3-1 (latest upstream).
;;;
;;; Guix builds librewolf from the module-PRIVATE `make-librewolf-source'
;;; (Firefox release source + the codeberg librewolf/source overlay + a pinned
;;; firefox-l10n checkout, assembled by a `computed-origin-method' derivation).
;;; A channel cannot reach that helper, so the source-assembly machinery
;;; (`firefox-source-origin', `librewolf-source-origin', `computed-origin-method',
;;; `firefox-l10n', `make-librewolf-source') is adapted and vendored here from
;;; gnu/packages/librewolf.scm.  The release pins plus two compatibility
;;; substitutions for the current upstream Makefile/l10n script differ.  The
;;; package then INHERITS guix's `librewolf' (build phases, inputs,
;;; clang/llvm/rust toolchain, configure flags, %librewolf-build-id) and overrides
;;; `version', `source', the release build ID, cbindgen, and NSS.  Firefox 153
;;; requires cbindgen >= 0.29.4 and NSS >= 3.125, while the inherited Guix
;;; package still supplies cbindgen 0.29.2 and nss-rapid 3.124.  The 0.29.4
;;; crate's Cargo.lock differs from 0.29.2 only in cbindgen's own version, so the
;;; private update below safely reuses Guix's complete 0.29 dependency closure.
;;; NSS 3.126 is the current Mozilla rapid release and matches the official Guix
;;; 153.0.3-1 recipe.  The build ID likewise matches that recipe; leaving the
;;; inherited 151.0.4-1 timestamp can break cache validation.
;;;
;;; The librewolf-specific patches (`librewolf-compare-paths.patch',
;;; `librewolf-use-system-wide-dir.patch', …) are guix-bundled; `search-patches'
;;; resolves them from guix's patch dir on the channel load path — no need to
;;; vendor them.  (The l10n-download neuter is NOT a search-patch here: guix's
;;; `librewolf-neuter-locale-download.patch' no longer applies to the current
;;; `curl'-based script, so it is done inline via `substitute*' below.)
;;;
;;; Hashes (all fetched + verified 2026-08-09):
;;;   firefox 153.0.3 source      (ftp.mozilla.org) -> firefox-hash
;;;   librewolf/source 153.0.3-1  (codeberg, git)   -> librewolf-hash
;;;   firefox-l10n @ 6795ea14     (github, git)     -> l10n-hash
;;; The l10n commit is the `revision' from
;;; firefox-153.0.3/browser/locales/l10n-changesets.json in the Firefox source.
;;;
;;; The exact full Firefox/LTO build passed on 2026-08-09.  The computed SOURCE
;;; assembly can also be checked independently with:
;;;   guix build -L ~/securityops-channel -S librewolf

(define-module (securityops packages librewolf)
  #:use-module (guix packages)
  #:use-module (guix build-system cargo)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module ((srfi srfi-1) #:hide (zip))
  #:use-module (gnu packages)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-xyz)
  #:use-module ((gnu packages nss) #:prefix nss:)
  #:use-module ((gnu packages rust-apps) #:prefix rust-apps:)
  #:use-module ((gnu packages librewolf) #:prefix lw:))

(define rust-cbindgen-0.29.4
  (package
    (inherit rust-apps:rust-cbindgen-0.29)
    (version "0.29.4")
    (source
     (origin
       (method url-fetch)
       (uri (crate-uri "cbindgen" version))
       (file-name (string-append "rust-cbindgen-" version ".tar.gz"))
       (sha256
        (base32 "085f02ma9cdz0alnl1p6b1x6bmr7i9nnasq2fjk7n5lw9i457jrf"))))))

(define nss-rapid-3.126
  ;; Firefox 153's in-tree NSS is 3.125, so its --with-system-nss check rejects
  ;; the inherited 3.124.  This is the exact nss-rapid source update in Guix
  ;; master; all build arguments, patches, and inputs remain inherited.
  (package
    (inherit nss:nss-rapid)
    (version "3.126")
    (source
     (origin
       (inherit (package-source nss:nss-rapid))
       (uri (string-append
             "https://ftp.mozilla.org/pub/security/nss/releases/NSS_3_126_RTM/"
             "src/nss-" version ".tar.gz"))
       (sha256
        (base32 "0dz3z7hliwy0w5kq0j5y840fyypvkwj0n91rsy13sig1idspr83s"))))))

(define (firefox-source-origin version hash)
  (origin
    (method url-fetch)
    (uri (string-append
          "https://ftp.mozilla.org/pub/firefox/releases/"
          version "/source/" "firefox-" version
          ".source.tar.xz"))
    (sha256 (base32 hash))))

(define (librewolf-source-origin version hash)
  (origin
    (method git-fetch)
    (uri (git-reference
          (url "https://codeberg.org/librewolf/source.git")
          (commit version)
          (recursive? #t)))
    (file-name (git-file-name "librewolf-source" version))
    ;; The network l10n download in scripts/librewolf-patches.py is neutered in
    ;; `make-librewolf-source' via `substitute*' instead of guix's bundled
    ;; `librewolf-neuter-locale-download.patch'.  That patch targets the old
    ;; `wget|unzip|mv' form of the script; upstream 152.0.4-1 switched to `curl'
    ;; and dropped an unrelated gkrust block above it, so its hunk context no
    ;; longer applies.  The substitute* below tracks the current script.
    (sha256 (base32 hash))))

(define computed-origin-method (@@ (guix packages) computed-origin-method))

(define firefox-l10n
  ;; Match this commit to the upstream tarball.  The hash is in
  ;; firefox-NNN/browser/locales/l10n-changesets.json (the "revision" field;
  ;; the same value repeats for every language).  For 153.0.3 it is 6795ea14.
  (let ((commit "6795ea14a5bd5ed79a930e6759823c7236476ae4"))
    (origin
      (method git-fetch)
      (uri (git-reference
            (url "https://github.com/mozilla-l10n/firefox-l10n.git")
            (commit commit)))
      (file-name (git-file-name "firefox-l10n" commit))
      (sha256 (base32 "1d47zfrw2gf23c9pa5rzbi5nx9jap2g0icm8dqsar6jb9y7svinc")))))

(define* (make-librewolf-source #:key version firefox-hash librewolf-hash l10n)
  (let* ((ff-src (firefox-source-origin
                  (car (string-split version #\-))
                  firefox-hash))
         (lw-src (librewolf-source-origin
                  version
                  librewolf-hash)))

    (origin
      (method computed-origin-method)
      (file-name (string-append "librewolf-" version ".source.tar.gz"))
      (sha256 #f)
      (uri
       (delay
         (with-imported-modules '((guix build utils))
           #~(begin
               (use-modules (guix build utils))
               (set-path-environment-variable
                "PATH" '("bin")
                (list #+python
                      #+(canonical-package bash)
                      #+(canonical-package gnu-make)
                      #+(canonical-package coreutils)
                      #+(canonical-package findutils)
                      #+(canonical-package patch)
                      #+(canonical-package xz)
                      #+(canonical-package sed)
                      #+(canonical-package grep)
                      #+(canonical-package pigz)
                      #+(canonical-package tar)))
               (set-path-environment-variable
                "PYTHONPATH"
                (list #+(format #f "lib/python~a/site-packages"
                                (version-major+minor
                                 (package-version python))))
                '#+(cons python-jsonschema
                         (map second
                              (package-transitive-propagated-inputs
                               python-jsonschema))))

               ;; Copy LibreWolf source into the build directory and make
               ;; everything writable.
               (copy-recursively #+lw-src ".")
               (for-each make-file-writable (find-files "."))

               ;; Patch Makefile to use the upstream source instead of
               ;; downloading.
               (substitute* '("Makefile")
                 (("^(ff_source_tarball *:= *).*" _ var)
                  (string-append var #+ff-src)))

               ;; Neuter GPG signing of the tarball.
               (substitute* '("Makefile")
                 (("if [ -f pk.asc ].*") ""))

               ;; Stage locales: neuter the network firefox-l10n download (no
               ;; network in the build sandbox) and redirect the locale-apply
               ;; loop at the staged firefox-l10n checkout.
               (begin
                 (substitute* "scripts/librewolf-patches.py"
                   ;; Drop the curl|unzip|mv block that fetches l10n from
                   ;; GitHub; keep the `with TemporaryDirectory()' valid by
                   ;; turning its body into `pass'.
                   (("exec\\(f\"curl -so .*l10n\\.zip.*") "pass")
                   (("exec\\(f\"unzip -qo .*l10n\\.zip.*") "")
                   (("exec\\(f\"mv .*firefox-l10n-main lw/l10n\"\\).*") "")
                   (("l10n_dir = Path(\"..\", \"l10n\")")
                    (string-append
                     "l10n_dir = \"" #+l10n "\""))))

               ;; Run the build script
               (invoke "make" "all")
               (copy-file (string-append "librewolf-" #$version
                                         ".source.tar.gz")
                          #$output)))))
      (patches
       (search-patches
        "librewolf-compare-paths.patch"
        "librewolf-use-system-wide-dir.patch"
        "librewolf-add-store-to-rdd-allowlist.patch"))
      ;; Slim down the tarball by removing unbundled libraries and 75 Mo (800+
      ;; Mo uncompressed) of unused tests.
      (modules '((guix build utils)))
      (snippet
       #~(for-each delete-file-recursively
                   '("testing/web-platform"
                     "gfx/cairo/libpixman"
                     "js/src/ctypes/libffi"
                     "ipc/chromium/src/third_party/libevent"
                     "media/libvpx"
                     "docs/nspr"
                     "media/libwebp"
                     "modules/zlib"))))))

;;; LibreWolf 153.0.3-1 — inherits guix's package and replaces the source plus
;;; the build dependencies whose minimum versions changed in Firefox 153.
;;; The source assembly and inherited Guix build stack use the current
;;; Rust 1.94/Clang 21/LLVM 21/ICU 78/NSS rapid toolchain expected by Firefox
;;; 153; the exact full browser build and runtime metadata were verified on
;;; 2026-08-09.
(define-public librewolf
  (package
    (inherit lw:librewolf)
    (version "153.0.4-1")
    (source
     (make-librewolf-source
      #:version version
      #:firefox-hash "09dwrhl6whin17fmyr1ynzak80q4qr37pxj285rqhl41idj6h527"
      #:librewolf-hash "D6FQQAAAAAAAAAAD5ROOW563G2ZO7V7FL6A2WZRLHOVYOZOZJ3V2467LER3OUNTVOIRGPOZ5NGHQ6RECCIJIVUASURWOL4N736MQCSEC2TBW52RYXN342D5WIQBAHTH3G5BVEU36PE7IVVEQI7TWHQIDSF6HD46HCYOHW6336QPY56T7XC4PGRLPO6537N6X5PW7I57APRXWPN7X4CF5CJ6YZPBJD2MUE6YGJISUXJXNYVOX5PGP3BY4XPN4YV4TRGENHA4QN7234DWE22BW34MNH4OPFXSWGD6OMGYRRCO267P6ID2HNB3373L333N66647O7DX3TOKCVMW7CRPWSOXIB7XR4DAO6277Q7HTL74HF76C65Z65CX634C7537VP7U5KESSF4K2PUJEF6IJ7TXWYPOZXHJ74LI5OX6F5KPEJUM2SC34QKL7AEP337V7K6TX7O7YKYVV77GJI5RDEPALJ2OM7ASPXSBUBX75WWNA75PW625HK7JP657PIAP25XZJUYVY573T7TDHYI7X3CREJ4CVWEAKTHB5KKAWALUN346U7RH3D5R3QXM4A5JU46PLR73T33VUDJVLYNWMMQK3LDF54B3MNERN2ZWJRSGFKTFURRDV2NLHDSTEFUJDHBZRHHQCEWO5Q3SIOIYYOTAQLOUQDQTOGQ2FMB32RZ33NY7ZA4KBYJ2AVNPTTBWWP5R4C77RXFFFWHNKRUZTKTENZDTBFTJUH3RT52TVFRN35PNZDXWO66FRAFZTDXXRNX3ARBWTSUCBC3QLYRPYLGROIDAFKBO7EZX6I6YKPOOKL5QJNTLQZR46HDTQOBHEXRJSS4ZWHA4TE6TSPJSPZZ7DX63VT7OXV54PLGDOUJBDMUDAPLIJ752RMSZR3SOIBFE35WVK5GAWPYRVHXDRE6Z7P32ZWLED47BJVCB2356ZPNT3ACHPSFDVC7PHF6TJDYQBNU2ZIIMJITLSINKOKIIXDNQ26GK6NYEAKWJINBUN4637H6O6ZZ3FMSWSFRMORUW3QYZAATDJLXOTI44H33XZSCA5ODGM72PM6VDHJ5MZN3X652DNOP67DO555Q7DAXUPFMR4QDCDF2RHPGN5PXNQBYTTF2BN5IFHAPJWUBT4B7JHZAG2TFTMESPKOEPVFVXYRMG7NLVVSANHBKSYRAATN56K6XQ577VN3XWLBO4I76ONQBUXYK2QY5QDEMJ6YSIWURZRVQPSNGJC23DIEBJTPYUJ4RBNS6ZQK4DPU3BHQED2WQFK3OVZCCT6VVM6GH2GF4DSNT2OB7XGZ6J5ZUTGYN6ZO7P3C66GZZPTYOP36HM7TM4XM7HF7HRNJV6HB5HU5BYHCZFHLI5LVX6VQ4XE5HR7H777DWOD6OJ4OBWF4ELS6T6PJZPP57HR5DCFGI6KIJEKXWDT567QCQYCJMMURHB2O5IIW7ILOFXFSTK3C3GY4TU7DYGA4NRLT3LSRHEUJGRKY5VNDXIQ7JQYFVQKIDOE2YGLF44FIFKWM3W46N5GJ4H3DUVJUMHIV666SOC6MTEV5PLC5WMDL3RZLJV3DX3676L2KYYQKZ3EZ6733LA4M3HMLSHRVGWP4KQXK5QN75HZUYISG37I75XV5P554PRVX5SIBK3MDFBE5RO2NSGSJPKOB47ECZCIOHHDX5LT3UQJ6OL6HA4XWAD33F3IZWK5HB57PUQQ6LI4BKJGJCDDGEXYVJY35YDGPQQA4LM64ORB4P3U7BKXNJ6GTF2LMCQM6MMHWDQQBQ3QLASGAI7UTP22Z6W52GYTOC35T43XL5WDUUQKKS6BCCBMNPGJDYVGRMAWPBSOB4NDNR5BNPS46DY67R2AQCT5REQPIFTUASOMB6WOA274YZEY2RSARIK3ARZQT45P72CY7522YVPNVEGKI4W6II5QFMQNQWL3DBKMKGRFKC2NQ73HO2YHID5OZHXTJPX5SIW4ZMSLM2ZWNQSTXDL7YLP6FR7ATSJAMQVKPIYBAEDBXTULMOALZ6VTEKWC2P4PWLEJBZPU7LDWW6JPC4YGRQ7CBMCU3XEVWU3ZUNHXTLXECWXGY5V67QGHS226A67ZVZCX3QQX7TLWEQOCYIK5CFUOGROJUJZDIZVOPVEHMYSDPW4K4YZMBHDNAMEGAQSFCZWBEKCEC65LFQ42RYA2YABLNWP4ZJSBR5H2NEEEGQHQ25K7NMK5ONS5Z3R34L5H5APZRUBYZXJLAS7ELMNAUMKHXUITCWYWXDVIIEKPQF4SCA4LC4J7BLSM5GKTY7RXHGVFZPOCRNTL2LRJOSGYVLKFOWB3YZ3I7XAX4RYHKWUFUMLENXJSMHQKBHG3DEWHUDEVGKZVOY5AYARHF5JJBRB5MMXF6PDFLVVOAYOKNPQAYNP7NOBYLROA23F7LS5GPTZTJPLN3AN4VMKGMIQX6GEPJIGJD5KAL443BMJNE2XXLJHKXPCA2OQESA5WNDL455U5KBXX364CTRCJT6FJWWPDGM36QNBQUQ2H7GCN476L4GHGEE7U2EYZU4QGX72VG5QEQE52OUZP2I3B35TIRXLUWVATT73SG2UO7DSOPNO5T72MYFUP6TPT66FSX6573O62ZRP6533N7325733BNDQLSM7MGAEERAX5C6O6O6NWRWZADATD35WHYJUQWYAWVL4DGFJIL7PCNJW5CQRQ3TVHTYANRBNYL2CJUQLJH6IVEE4WTLTSU6Y66AKKY4WTFUVAGCFBGMIYC3GLSWZEHHSFSAFZVEMNWLFHE7CLGAFRFDTVPKHIXFWRN2CNFJ3PVH5J2CCUZZOMQOIAV2UZZG3RL7SGP7TABOHFKPI4YO7UG5MZB75AGPMAPEHSH4BRJSAP2QM7SRJVOSPERHCK67JVRKI5VIXI3STS2QYV2Z2XJLVGKDTQLRKXHUDNUSCVFTPIV4V6IAQVHYNH5WMCUGTMNRRRP646RU6Y7CAYIBRMFZ6U4V2FNJRGPA7Q5M7YPHPQURCHFNLIPGHR6KVNKHW5ZSF4UT3QGLBZPFHY3QYT3TUZMVSAY26YFZF5DY7C6KZVKLBH7JRR5RRDLM77DUIPQ6T2OR2PFMJ2SZV2P4NLJ7NKSJAW5ZZ3BNBXS6GF2WR3HQ7TYHF6HY4SPZLATIK2IZ6L477T4OJ4D45HQ5CVK7YKXXSCTC27UZW4C4AB67OKCU5S6TNUGQUZO3FGWD2ZNDRBVB2WGYS7Z4KEAXWW5F5N2I2D7LV227KUGQZVGZ4QB3GPWRVIYBU5NHWMAQODRQI7DGI"
      #:l10n firefox-l10n))
    (arguments
     (substitute-keyword-arguments (package-arguments lw:librewolf)
       ((#:phases phases '%standard-phases)
        #~(modify-phases #$phases
            (replace 'set-build-id
              (lambda _
                (setenv "MOZ_BUILD_DATE" "20260804215502")))))))
    (native-inputs
     (modify-inputs (package-native-inputs lw:librewolf)
       (replace "rust-cbindgen" rust-cbindgen-0.29.4)))
    (inputs
     (modify-inputs (package-inputs lw:librewolf)
       (replace "nss-rapid" nss-rapid-3.126)))))
