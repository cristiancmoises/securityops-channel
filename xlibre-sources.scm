;;; XLibre source pins from guix-xlibre revision 09edbfa3c5c4eaafbbb1947445c219ac53c465a6.
;;; Server pin maintained by SecurityOps; driver pins retained unchanged.

(define-module
  (xlibre-sources)
  #:use-module
  ((guix packages) #:select (origin base32))
  #:use-module
  ((guix git-download)
   #:select
   (git-fetch git-reference git-file-name)))

;; this file was automatically generated

(define-public %xlibre-sources (make-hash-table))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-server"
  (cons "25.2.2"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xserver")
                 (commit "xlibre-xserver-25.2.2")))
          (sha256
            (base32
              "0zc88lvxrlck6vy8a1bl810smjmd1jgya9g9mbznjg75vwz3kpfz"))
          (file-name
            (git-file-name "xlibre-server" "25.2.2")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-input-elographics"
  (cons "25.0.1"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-input-elographics")
                 (commit "xlibre-xf86-input-elographics-25.0.1")))
          (sha256
            (base32
              "1wdibgm534g4brfsivyd4x8pqivyfapqvi2dc9n444mv4ynpmf81"))
          (file-name
            (git-file-name
              "xlibre-input-elographics"
              "25.0.1")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-input-evdev"
  (cons "25.0.0"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-input-evdev")
                 (commit "xlibre-xf86-input-evdev-25.0.0")))
          (sha256
            (base32
              "1hcac307kx9agj2c64k62zhhs9bz84qfj8pzybxnyqmbdvcpdrsr"))
          (file-name
            (git-file-name "xlibre-input-evdev" "25.0.0")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-input-joystick"
  (cons "25.0.0"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-input-joystick")
                 (commit "xlibre-xf86-input-joystick-25.0.0")))
          (sha256
            (base32
              "0rnwr6rg4swv2cannw9j6rj32nf1a069bqvwi7rm842vm59l27iw"))
          (file-name
            (git-file-name "xlibre-input-joystick" "25.0.0")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-input-keyboard"
  (cons "25.0.0"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-input-keyboard")
                 (commit "xlibre-xf86-input-keyboard-25.0.0")))
          (sha256
            (base32
              "0f9avrf5nq0x901m0zij5idkhg2y50nj60065bdjhv1msnlgpwbk"))
          (file-name
            (git-file-name "xlibre-input-keyboard" "25.0.0")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-input-libinput"
  (cons "25.0.1"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-input-libinput")
                 (commit "xlibre-xf86-input-libinput-25.0.1")))
          (sha256
            (base32
              "1q2k7l69ig39h4snmbvpxp1c2y32k5h3qqwzcqlnq2hckyx6fakl"))
          (file-name
            (git-file-name "xlibre-input-libinput" "25.0.1")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-input-mouse"
  (cons "25.0.0"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-input-mouse")
                 (commit "xlibre-xf86-input-mouse-25.0.0")))
          (sha256
            (base32
              "19iy13yl1fahh8mj219srkrzy0a40ssdikkjx07x7v8dx3qrdjpk"))
          (file-name
            (git-file-name "xlibre-input-mouse" "25.0.0")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-input-synaptics"
  (cons "25.0.0"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-input-synaptics")
                 (commit "xlibre-xf86-input-synaptics-25.0.0")))
          (sha256
            (base32
              "00zasb9g4n7vs4drvw3aprfdzrjxkhdl3mgkds6l70hdydmhjm4r"))
          (file-name
            (git-file-name "xlibre-input-synaptics" "25.0.0")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-input-vmmouse"
  (cons "25.0.0"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-input-vmmouse")
                 (commit "xlibre-xf86-input-vmmouse-25.0.0")))
          (sha256
            (base32
              "0jrlvqr5dhpxjdgl09cyik86spg533p09s54484dd0m48zr30ij1"))
          (file-name
            (git-file-name "xlibre-input-vmmouse" "25.0.0")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-input-void"
  (cons "25.0.0"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-input-void")
                 (commit "xlibre-xf86-input-void-25.0.0")))
          (sha256
            (base32
              "1h4fcval1vx9vaj15fjl4nn1zdx5x9ic0dr0y96y5gnrdkc92cxf"))
          (file-name
            (git-file-name "xlibre-input-void" "25.0.0")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-input-wacom"
  (cons "25.0.0"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-input-wacom")
                 (commit "xlibre-xf86-input-wacom-25.0.0")))
          (sha256
            (base32
              "0k4zwvnwf19ly83x2kvn3fjb8mzf9zk4j93p1rmv5qv66vk27428"))
          (file-name
            (git-file-name "xlibre-input-wacom" "25.0.0")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-video-amdgpu"
  (cons "25.1.1"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-video-amdgpu")
                 (commit "xlibre-xf86-video-amdgpu-25.1.1")))
          (sha256
            (base32
              "0b7vn21b8p48qmb9vz5slk7a1b2h00m94ya3qncvrrliw1l0m5y1"))
          (file-name
            (git-file-name "xlibre-video-amdgpu" "25.1.1")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-video-apm"
  (cons "25.0.0"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-video-apm")
                 (commit "xlibre-xf86-video-apm-25.0.0")))
          (sha256
            (base32
              "1w96f6xbzvdbyynk921j530y7x88g0slf7g193pj857vqs7a5r4i"))
          (file-name
            (git-file-name "xlibre-video-apm" "25.0.0")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-video-ark"
  (cons "25.0.0"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-video-ark")
                 (commit "xlibre-xf86-video-ark-25.0.0")))
          (sha256
            (base32
              "1q12p1vi3wlqysg7r7afsbjlvqgkbxkz6cs5zsz7bf7rgk8kzf2i"))
          (file-name
            (git-file-name "xlibre-video-ark" "25.0.0")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-video-ast"
  (cons "25.0.0"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-video-ast")
                 (commit "xlibre-xf86-video-ast-25.0.0")))
          (sha256
            (base32
              "0crgz1lqrqcv78kx1psd62yzc16hjg4ajx2199q91ba65ghr80bc"))
          (file-name
            (git-file-name "xlibre-video-ast" "25.0.0")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-video-ati"
  (cons "25.0.1"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-video-ati")
                 (commit "xlibre-xf86-video-ati-25.0.1")))
          (sha256
            (base32
              "04nybnikr3xkc6fwgiwh95y8xb89z7bnynyssim5x4zz37zg679x"))
          (file-name
            (git-file-name "xlibre-video-ati" "25.0.1")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-video-chips"
  (cons "25.0.0"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-video-chips")
                 (commit "xlibre-xf86-video-chips-25.0.0")))
          (sha256
            (base32
              "0d1aakb1qq93w10aa8zip4z2imbgww5mw0jryr0c4if67w3zmwpm"))
          (file-name
            (git-file-name "xlibre-video-chips" "25.0.0")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-video-cirrus"
  (cons "25.0.0"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-video-cirrus")
                 (commit "xlibre-xf86-video-cirrus-25.0.0")))
          (sha256
            (base32
              "0hxs6kdx899f20v5zsiqdcl8f2m136jwfqbb3zkbi75ap95vx3jf"))
          (file-name
            (git-file-name "xlibre-video-cirrus" "25.0.0")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-video-dummy"
  (cons "25.0.0"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-video-dummy")
                 (commit "xlibre-xf86-video-dummy-25.0.0")))
          (sha256
            (base32
              "02d612hrljdiyi577718lgyvvb90jph2pi4rvxb7hwfzghialdf7"))
          (file-name
            (git-file-name "xlibre-video-dummy" "25.0.0")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-video-fbdev"
  (cons "25.0.0"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-video-fbdev")
                 (commit "xlibre-xf86-video-fbdev-25.0.0")))
          (sha256
            (base32
              "0qafmg0a28sa822xhncg1f5x2w9ya55jix3yyrf3897c820z5z3g"))
          (file-name
            (git-file-name "xlibre-video-fbdev" "25.0.0")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-video-freedreno"
  (cons "25.0.0"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-video-freedreno")
                 (commit "xlibre-xf86-video-freedreno-25.0.0")))
          (sha256
            (base32
              "0kbdzr1vflbp9904y5bx90jmjzf96bilw7l190svp55jq2fqq2f2"))
          (file-name
            (git-file-name "xlibre-video-freedreno" "25.0.0")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-video-geode"
  (cons "25.0.0"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-video-geode")
                 (commit "xlibre-xf86-video-geode-25.0.0")))
          (sha256
            (base32
              "1vmp624qp51lvyby0mbih2fa7llqrw5x4s5z2mxrzllvydy833m3"))
          (file-name
            (git-file-name "xlibre-video-geode" "25.0.0")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-video-i128"
  (cons "25.0.0"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-video-i128")
                 (commit "xlibre-xf86-video-i128-25.0.0")))
          (sha256
            (base32
              "19563k236f401qpp20ckvxnys3qdys3903vnxfjdjwqlbyf0za7j"))
          (file-name
            (git-file-name "xlibre-video-i128" "25.0.0")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-video-i740"
  (cons "25.0.0"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-video-i740")
                 (commit "xlibre-xf86-video-i740-25.0.0")))
          (sha256
            (base32
              "1ldn2qd4a5bp9s417imsggdk1n0r5sfhhyahh8psfamd0k3sc1dp"))
          (file-name
            (git-file-name "xlibre-video-i740" "25.0.0")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-video-intel"
  (cons "25.0.1"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-video-intel")
                 (commit "xlibre-xf86-video-intel-25.0.1")))
          (sha256
            (base32
              "0c14wkqkk611qj3l2hk9kc2l32v3wrlf7lmyndrynzfal9l5bc78"))
          (file-name
            (git-file-name "xlibre-video-intel" "25.0.1")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-video-mach64"
  (cons "25.0.0"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-video-mach64")
                 (commit "xlibre-xf86-video-mach64-25.0.0")))
          (sha256
            (base32
              "1fbsaalqjpyz99faiy5gvysph0b1b3mb3ardnm20vxw4air99w7l"))
          (file-name
            (git-file-name "xlibre-video-mach64" "25.0.0")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-video-mga"
  (cons "25.0.0"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-video-mga")
                 (commit "xlibre-xf86-video-mga-25.0.0")))
          (sha256
            (base32
              "0i2ixi7ly2vj0jwmva82kvr8vncy73ws1rc4qbs62myf22axi1zg"))
          (file-name
            (git-file-name "xlibre-video-mga" "25.0.0")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-video-neomagic"
  (cons "25.0.0"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-video-neomagic")
                 (commit "xlibre-xf86-video-neomagic-25.0.0")))
          (sha256
            (base32
              "04wfa1rx9w4r6gq58kr6gl2vh9bg8ysr50l06za53j2plqb89qb2"))
          (file-name
            (git-file-name "xlibre-video-neomagic" "25.0.0")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-video-nested"
  (cons "25.0.0"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-video-nested")
                 (commit "xlibre-xf86-video-nested-25.0.0")))
          (sha256
            (base32
              "1j3qnpw3inwbdgkgqb19d3rkmai3r6fvwix0bblgqpms871siy8q"))
          (file-name
            (git-file-name "xlibre-video-nested" "25.0.0")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-video-nouveau"
  (cons "25.0.0"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-video-nouveau")
                 (commit "xlibre-xf86-video-nouveau-25.0.0")))
          (sha256
            (base32
              "1gs6wxqprjy91cjz4y569snhfvv58n2744sxnnysn2r5asycnx96"))
          (file-name
            (git-file-name "xlibre-video-nouveau" "25.0.0")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-video-nv"
  (cons "25.0.0"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-video-nv")
                 (commit "xlibre-xf86-video-nv-25.0.0")))
          (sha256
            (base32
              "0ylija24r92jv4sjy9ldrllwrlzymq8z43ral7mdilff95x5cqq3"))
          (file-name
            (git-file-name "xlibre-video-nv" "25.0.0")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-video-omap"
  (cons "25.0.0"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-video-omap")
                 (commit "xlibre-xf86-video-omap-25.0.0")))
          (sha256
            (base32
              "0f8x636dkqh5sqjhczfm86g41hwr7wf0xzy0g70vw1d11fxcr67q"))
          (file-name
            (git-file-name "xlibre-video-omap" "25.0.0")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-video-openchrome"
  (cons "25.0.0"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-video-openchrome")
                 (commit "xlibre-xf86-video-openchrome-25.0.0")))
          (sha256
            (base32
              "04dms0jjdyh3qxzx5gyysgag3abpp8wr0nlsyys4bzgnqlk09xj0"))
          (file-name
            (git-file-name
              "xlibre-video-openchrome"
              "25.0.0")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-video-qxl"
  (cons "25.0.0"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-video-qxl")
                 (commit "xlibre-xf86-video-qxl-25.0.0")))
          (sha256
            (base32
              "07axgwbqddlj9qvaq8raqzcr3acg7djs8y6s09cm5lsjx0wscyh8"))
          (file-name
            (git-file-name "xlibre-video-qxl" "25.0.0")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-video-r128"
  (cons "25.0.0"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-video-r128")
                 (commit "xlibre-xf86-video-r128-25.0.0")))
          (sha256
            (base32
              "0zi7csrzwnx1aqmm7zi8v4kx65p8xdizl2vzaf0gfxnfrmvxz1ab"))
          (file-name
            (git-file-name "xlibre-video-r128" "25.0.0")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-video-rendition"
  (cons "25.0.0"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-video-rendition")
                 (commit "xlibre-xf86-video-rendition-25.0.0")))
          (sha256
            (base32
              "1m3akzqqzbx0jb6ppxsa8wd41f7v7dln4wwhha7f89ra8g28z5bh"))
          (file-name
            (git-file-name "xlibre-video-rendition" "25.0.0")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-video-s3virge"
  (cons "25.0.0"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-video-s3virge")
                 (commit "xlibre-xf86-video-s3virge-25.0.0")))
          (sha256
            (base32
              "1jnkbbc3zsys8pddj63c4bklcl7i5wbjgar2gp38yv0f4pd4as20"))
          (file-name
            (git-file-name "xlibre-video-s3virge" "25.0.0")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-video-savage"
  (cons "25.0.0"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-video-savage")
                 (commit "xlibre-xf86-video-savage-25.0.0")))
          (sha256
            (base32
              "05dphm9s01fi366r79hhqcjzbql4gh2m4n36lc0d1n4wpyxqx2bj"))
          (file-name
            (git-file-name "xlibre-video-savage" "25.0.0")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-video-siliconmotion"
  (cons "25.0.0"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-video-siliconmotion")
                 (commit "xlibre-xf86-video-siliconmotion-25.0.0")))
          (sha256
            (base32
              "1kw5yas828mwn3pqbz5s7b9kccv0z6iz0s5qr24qrbhrqa56b4dz"))
          (file-name
            (git-file-name
              "xlibre-video-siliconmotion"
              "25.0.0")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-video-sis"
  (cons "25.0.0"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-video-sis")
                 (commit "xlibre-xf86-video-sis-25.0.0")))
          (sha256
            (base32
              "12npq9jyxxyncybnpd86wn7af9hggjq781a9ssbmfnl3p19djqqm"))
          (file-name
            (git-file-name "xlibre-video-sis" "25.0.0")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-video-sisusb"
  (cons "25.0.0"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-video-sisusb")
                 (commit "xlibre-xf86-video-sisusb-25.0.0")))
          (sha256
            (base32
              "0svdqkjq77a5rklid94x2p5hhp0mqp54k80hlgk6xz7chx4pyf2f"))
          (file-name
            (git-file-name "xlibre-video-sisusb" "25.0.0")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-video-tdfx"
  (cons "25.0.0"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-video-tdfx")
                 (commit "xlibre-xf86-video-tdfx-25.0.0")))
          (sha256
            (base32
              "0c7lnw084lrnm4q531q3494bjllm0y28g09bdl3n4nhqq7ny6y1q"))
          (file-name
            (git-file-name "xlibre-video-tdfx" "25.0.0")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-video-trident"
  (cons "25.0.0"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-video-trident")
                 (commit "xlibre-xf86-video-trident-25.0.0")))
          (sha256
            (base32
              "1dxfa7vqvaxpkf2sl1kw7xqspyskzqh05dfavd56nbwgbzzc45g7"))
          (file-name
            (git-file-name "xlibre-video-trident" "25.0.0")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-video-v4l"
  (cons "25.0.1"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-video-v4l")
                 (commit "xlibre-xf86-video-v4l-25.0.1")))
          (sha256
            (base32
              "1savyxzmmaq51bbsbf48dgrv1x46vr4hw8k9n97icq9hzy2w56fs"))
          (file-name
            (git-file-name "xlibre-video-v4l" "25.0.1")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-video-vbox"
  (cons "25.0.0"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-video-vbox")
                 (commit "xlibre-xf86-video-vbox-25.0.0")))
          (sha256
            (base32
              "0z38gh0c29q70nv8bgjag8pzc48l9cl5ndxs02zkq9yx0fgx4wc9"))
          (file-name
            (git-file-name "xlibre-video-vbox" "25.0.0")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-video-vesa"
  (cons "25.0.0"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-video-vesa")
                 (commit "xlibre-xf86-video-vesa-25.0.0")))
          (sha256
            (base32
              "0x3f5db1q5pxvml787zkl0ca82aqk2zlss1b4jvyv9qcjsbwf929"))
          (file-name
            (git-file-name "xlibre-video-vesa" "25.0.0")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-video-vmware"
  (cons "25.0.0"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-video-vmware")
                 (commit "xlibre-xf86-video-vmware-25.0.0")))
          (sha256
            (base32
              "1z4vm5nc1h4xm5y7lwfqh2bfrb73n44wb6kir08ln54cbh8dbhml"))
          (file-name
            (git-file-name "xlibre-video-vmware" "25.0.0")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-video-voodoo"
  (cons "25.0.0"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-video-voodoo")
                 (commit "xlibre-xf86-video-voodoo-25.0.0")))
          (sha256
            (base32
              "0cc21b9h89v98sm69wz60izan38pm6b933jkaphw051idzr6lrw6"))
          (file-name
            (git-file-name "xlibre-video-voodoo" "25.0.0")))))

;; this file was automatically generated

(hash-set!
  %xlibre-sources
  "xlibre-video-xgi"
  (cons "25.0.0"
        (origin
          (method git-fetch)
          (uri (git-reference
                 (url "https://github.com/X11Libre/xf86-video-xgi")
                 (commit "xlibre-xf86-video-xgi-25.0.0")))
          (sha256
            (base32
              "0218rp9incivi85p62y7zd91kdhycl85p73lz7prmrkp2ncim055"))
          (file-name
            (git-file-name "xlibre-video-xgi" "25.0.0")))))

;; this file was automatically generated
