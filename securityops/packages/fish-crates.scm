;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>
;;; Registry sources from the official Fish 4.9.2 Cargo.lock.
(define-module (securityops packages fish-crates)
  #:use-module (guix build-system cargo)
  #:use-module (guix git-download)
  #:use-module (guix gexp)
  #:use-module (guix packages)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages rust-sources)
  #:export (fish-4.9.2-cargo-inputs))

(define fish-registry-inputs
  (list
   (crate-source "aho-corasick" "1.1.4"
                 "00a32wb2h07im3skkikc495jvncf62jl6s96vwc7bhi70h9imlyx")
   (crate-source "allocator-api2" "0.2.21"
                 "08zrzs022xwndihvzdn78yqarv2b9696y67i6h78nla3ww87jgb8")
   (crate-source "anstream" "1.0.0"
                 "13d2bj0xfg012s4rmq44zc8zgy1q8k9yp7yhvfnarscnmwpj2jl2")
   (crate-source "anstyle" "1.0.14"
                 "0030szmgj51fxkic1hpakxxgappxzwm6m154a3gfml83lq63l2wl")
   (crate-source "anstyle-parse" "1.0.0"
                 "03hkv2690s0crssbnmfkr76kw1k7ah2i6s5amdy9yca2n8w7zkjj")
   (crate-source "anstyle-query" "1.1.5"
                 "1p6shfpnbghs6jsa0vnqd8bb8gd7pjd0jr7w0j8jikakzmr8zi20")
   (crate-source "anstyle-wincon" "3.0.11"
                 "0zblannm70sk3xny337mz7c6d8q8i24vhbqi42ld8v7q1wjnl7i9")
   (crate-source "anyhow" "1.0.102"
                 "0b447dra1v12z474c6z4jmicdmc5yxz5bakympdnij44ckw2s83z")
   (crate-source "assert_matches" "1.5.0"
                 "1a9b3p9vy0msylyr2022sk5flid37ini1dxji5l3vwxsvw4xcd4v")
   (crate-source "autocfg" "1.5.1"
                 "0lqasy5i30flcgih1b50kvsk6z32g09r1q4ql7q81pj6228jy0zj")
   (crate-source "bitflags" "2.11.1"
                 "1cvqijg3rvwgis20a66vfdxannjsxfy5fgjqkaq3l13gyfcj4lf4")
   (crate-source "block-buffer" "0.10.4"
                 "0w9sa2ypmrsqqvc20nhwr75wbb5cjr4kkyhpjm1z1lv2kdicfy1h")
   (crate-source "bstr" "1.12.1"
                 "1arc1v7h5l86vd6z76z3xykjzldqd5icldn7j9d3p7z6x0d4w133")
   (crate-source "cc" "1.2.63"
                 "0zy2bqc4nvj6bv2cipx4h4bn65wf1zqf1fw1hsh64mmvg1hh2vjm")
   (crate-source "cfg-if" "1.0.4"
                 "008q28ajc546z5p2hcwdnckmg0hia7rnx52fni04bwqkzyrghc4k")
   (crate-source "cfg_aliases" "0.2.1"
                 "092pxdc1dbgjb6qvh83gk56rkic2n2ybm4yvy76cgynmzi3zwfk1")
   (crate-source "chacha20" "0.10.0"
                 "00bn2rn8l68qvlq93mhq7b4ns4zy9qbjsyjbb9kljgl4hqr9i3bg")
   (crate-source "clap" "4.6.1"
                 "0lcf88l7vlg796rrqr7wipbbmfa5sgsgx4211b7xmxxv8dz13nqx")
   (crate-source "clap_builder" "4.6.0"
                 "17q6np22yxhh5y5v53y4l31ps3hlaz45mvz2n2nicr7n3c056jki")
   (crate-source "clap_complete" "4.6.5"
                 "0wnp1w338vwf20sbaps13cjx452ijw2hybw3b6g1z09mvfzsk9z0")
   (crate-source "clap_derive" "4.6.1"
                 "1acpz49hi00iv9jkapixjzcv7s51x8qkfaqscjm36rqgf428dkpj")
   (crate-source "clap_lex" "1.1.0"
                 "1ycqkpygnlqnndghhcxjb44lzl0nmgsia64x9581030yifxs7m68")
   (crate-source "colorchoice" "1.0.5"
                 "0w75k89hw39p0mnnhlrwr23q50rza1yjki44qvh2mgrnj065a1qx")
   (crate-source "cpufeatures" "0.2.17"
                 "10023dnnaghhdl70xcds12fsx2b966sxbxjq5sxs49mvxqw5ivar")
   (crate-source "cpufeatures" "0.3.0"
                 "00fjhygsqmh4kbxxlb99mcsbspxcai6hjydv4c46pwb67wwl2alb")
   (crate-source "crossbeam-deque" "0.8.6"
                 "0l9f1saqp1gn5qy0rxvkmz4m6n7fc0b3dbm6q1r5pmgpnyvi3lcx")
   (crate-source "crossbeam-epoch" "0.9.18"
                 "03j2np8llwf376m3fxqx859mgp9f83hj1w34153c7a9c7i5ar0jv")
   (crate-source "crossbeam-utils" "0.8.21"
                 "0a3aa2bmc8q35fb67432w16wvi54sfmb69rk9h5bhd18vw0c99fh")
   (crate-source "crypto-common" "0.1.7"
                 "02nn2rhfy7kvdkdjl457q2z0mklcvj9h662xrq6dzhfialh2kj3q")
   (crate-source "digest" "0.10.7"
                 "14p2n6ih29x81akj097lvz7wi9b6b9hvls0lwrv7b6xwyy0s5ncy")
   (crate-source "dirs" "6.0.0"
                 "0knfikii29761g22pwfrb8d0nqpbgw77sni9h2224haisyaams63")
   (crate-source "dirs-sys" "0.5.0"
                 "1aqzpgq6ampza6v012gm2dppx9k35cdycbj54808ksbys9k366p0")
   (crate-source "displaydoc" "0.2.6"
                 "0kyxwfbdmagd8afzb2pzja7wj8dhah7smxdsgw00iq8pa2jhmiqs")
   (crate-source "either" "1.16.0"
                 "17k7jfbdz7k440h6lws9baz8p9zlxgb41sig3w81h80nwzsjyqli")
   (crate-source "equivalent" "1.0.2"
                 "03swzqznragy8n0x31lqc78g2af054jwivp7lkrbrc0khz74lyl7")
   (crate-source "fastrand" "2.4.1"
                 "1mnqxxnxvd69ma9mczabpbbsgwlhd6l78yv3vd681453a9s247wz")
   (crate-source "find-msvc-tools" "0.1.9"
                 "10nmi0qdskq6l7zwxw5g56xny7hb624iki1c39d907qmfh3vrbjv")
   (crate-source "fluent-langneg" "0.13.1"
                 "1c78jl8lpwg5hdg589qbn3m9ls6mzqxnyrvi5llfibhb8mcvxsvy")
   (crate-source "foldhash" "0.1.5"
                 "1wisr1xlc2bj7hk4rgkcjkz3j2x4dhd1h9lwk7mj8p71qpdgbi6r")
   (crate-source "foldhash" "0.2.0"
                 "1nvgylb099s11xpfm1kn2wcsql080nqmnhj1l25bp3r2b35j9kkp")
   (crate-source "generic-array" "0.14.7"
                 "16lyyrzrljfq424c3n8kfwkqihlimmsg5nhshbbp48np3yjrqr45")
   (crate-source "getrandom" "0.2.17"
                 "1l2ac6jfj9xhpjjgmcx6s1x89bbnw9x6j9258yy6xjkzpq0bqapz")
   (crate-source "getrandom" "0.3.4"
                 "1zbpvpicry9lrbjmkd4msgj3ihff1q92i334chk7pzf46xffz7c9")
   (crate-source "getrandom" "0.4.2"
                 "0mb5833hf9pvn9dhvxjgfg5dx0m77g8wavvjdpvpnkp9fil1xr8d")
   (crate-source "globset" "0.4.18"
                 "1qsp3wg0mgxzmshcgymdlpivqlc1bihm6133pl6dx2x4af8w3psj")
   (crate-source "hashbrown" "0.15.5"
                 "189qaczmjxnikm9db748xyhiw04kpmhm9xj9k9hg0sgx7pjwyacj")
   (crate-source "hashbrown" "0.17.1"
                 "0jmqz7i4yl6cm7rbn0i2ffkfrmwi6xkmzkaldr2v8bcsx2v0jngd")
   (crate-source "heck" "0.5.0"
                 "1sjmpsdl8czyh9ywl3qcsfsq9a307dg4ni2vnlwgnzzqhc4y0113")
   (crate-source "id-arena" "2.3.0"
                 "0m6rs0jcaj4mg33gkv98d71w3hridghp5c4yr928hplpkgbnfc1x")
   (crate-source "ignore" "0.4.25"
                 "0jlv2s4fxqj9fsz6y015j5vbz6i475hj80j9q3sy05d0cniq5myk")
   (crate-source "indexmap" "2.14.0"
                 "1na9z6f0d5pkjr1lgsni470v98gv2r7c41j8w48skr089x2yjrnl")
   (crate-source "intl_pluralrules" "7.0.2"
                 "0wprd3h6h8nfj62d8xk71h178q7zfn3srxm787w4sawsqavsg3h7")
   (crate-source "is_executable" "1.0.5"
                 "1i78ss45h94nwabbn6ki64a91djlli8zdwwbh56jj9kvhssbiaxs")
   (crate-source "is_terminal_polyfill" "1.70.2"
                 "15anlc47sbz0jfs9q8fhwf0h3vs2w4imc030shdnq54sny5i7jx6")
   (crate-source "itertools" "0.14.0"
                 "118j6l1vs2mx65dqhwyssbrxpawa90886m3mzafdvyip41w2q69b")
   (crate-source "itoa" "1.0.18"
                 "10jnd1vpfkb8kj38rlkn2a6k02afvj3qmw054dfpzagrpl6achlg")
   (crate-source "jobserver" "0.1.34"
                 "0cwx0fllqzdycqn4d6nb277qx5qwnmjdxdl0lxkkwssx77j3vyws")
   (crate-source "leb128fmt" "0.1.0"
                 "1chxm1484a0bly6anh6bd7a99sn355ymlagnwj3yajafnpldkv89")
   (crate-source "libc" "0.2.186"
                 "0rnyhzjyqq9x56skkllbjzzzwym3r61lq3l4hqj64v71gw0r3av8")
   (crate-source "libredox" "0.1.17"
                 "1ly9hnhiy0f6ccnlg3h8lca9smvv268gj5iwia4gnm10rsxbcaph")
   (crate-source "lock_api" "0.4.14"
                 "0rg9mhx7vdpajfxvdjmgmlyrn20ligzqvn8ifmaz7dc79gkrjhr2")
   (crate-source "log" "0.4.30"
                 "1rd6sw3gv9hb93464w7x3sip99zf8sjagm662r2ckg14b1lcavk1")
   (crate-source "lru" "0.18.0"
                 "1fagimn8n3ivc3diad3jf323lbx86x1cyffjky31dklgjq2hd1la")
   (crate-source "macro_rules_attribute" "0.2.2"
                 "0835cx5bdsj06yffaspqqlids57bn3cwxp0x1g6l10394dwrs135")
   (crate-source "macro_rules_attribute-proc_macro" "0.2.2"
                 "0c1s3lgkrdl5l2zmz6jc5g90zkq5w9islgn19alc86vmi7ddy3v7")
   (crate-source "memchr" "2.8.1"
                 "1n448jx01h5z2xknj6x2dhxgr8s8fb717cf6vfqj5lmhkpj7m53b")
   (crate-source "nix" "0.30.1"
                 "1dixahq9hk191g0c2ydc0h1ppxj0xw536y6rl63vlnp06lx3ylkl")
   (crate-source "nix" "0.31.3"
                 "0gbwnjfny9rq9hl5bz4ry520n9rnfknna4bg88n66f7zx3yx486g")
   (crate-source "num-traits" "0.2.19"
                 "0h984rhdkkqd4ny9cif7y2azl3xdfb7768hb9irhpsch4q3gq787")
   (crate-source "once_cell" "1.21.4"
                 "0l1v676wf71kjg2khch4dphwh1jp3291ffiymr2mvy1kxd5kwz4z")
   (crate-source "once_cell_polyfill" "1.70.2"
                 "1zmla628f0sk3fhjdjqzgxhalr2xrfna958s632z65bjsfv8ljrq")
   (crate-source "option-ext" "0.2.0"
                 "0zbf7cx8ib99frnlanpyikm1bx8qn8x602sw1n7bg6p9x94lyx04")
   (crate-source "parking_lot" "0.12.5"
                 "06jsqh9aqmc94j2rlm8gpccilqm6bskbd67zf6ypfc0f4m9p91ck")
   (crate-source "parking_lot_core" "0.9.12"
                 "1hb4rggy70fwa1w9nb0svbyflzdc69h047482v2z3sx2hmcnh896")
   (crate-source "paste" "1.0.15"
                 "02pxffpdqkapy292harq6asfjvadgp1s005fip9ljfsn9fvxgh2p")
   (crate-source "phf" "0.13.1"
                 "1pzswx5gdglgjgp4azyzwyr4gh031r0kcnpqq6jblga72z3jsmn1")
   (crate-source "phf_codegen" "0.13.1"
                 "1qfnsl2hiny0yg4lwn888xla5iwccszgxnx8dhbwl6s2h2fpzaj9")
   (crate-source "phf_generator" "0.13.1"
                 "0dwpp11l41dy9mag4phkyyvhpf66lwbp79q3ik44wmhyfqxcwnhk")
   (crate-source "phf_shared" "0.13.1"
                 "0rpjchnswm0x5l4mz9xqfpw0j4w68sjvyqrdrv13h7lqqmmyyzz5")
   (crate-source "pkg-config" "0.3.33"
                 "17jnqmcbxsnwhg9gjf0nh6dj5k0x3hgwi3mb9krjnmfa9v435w8r")
   (crate-source "portable-atomic" "1.13.1"
                 "0j8vlar3n5acyigq8q6f4wjx3k3s5yz0rlpqrv76j73gi5qr8fn3")
   (crate-source "prettyplease" "0.2.37"
                 "0azn11i1kh0byabhsgab6kqs74zyrg69xkirzgqyhz6xmjnsi727")
   (crate-source "proc-macro2" "1.0.106"
                 "0d09nczyaj67x4ihqr5p7gxbkz38gxhk4asc0k8q23g9n85hzl4g")
   (crate-source "quote" "1.0.45"
                 "095rb5rg7pbnwdp6v8w5jw93wndwyijgci1b5lw8j1h5cscn3wj1")
   (crate-source "r-efi" "5.3.0"
                 "03sbfm3g7myvzyylff6qaxk4z6fy76yv860yy66jiswc2m6b7kb9")
   (crate-source "r-efi" "6.0.0"
                 "1gyrl2k5fyzj9k7kchg2n296z5881lg7070msabid09asp3wkp7q")
   (crate-source "rand" "0.10.1"
                 "01r22vdpw6z69jzy6khnyr0ljq9im337h4j0mkyz26lnqyyfis6j")
   (crate-source "rand_core" "0.10.1"
                 "0s9wiacxrr100icl7i41308gcj85nlcclrc5jx1jd6p10dhigf33")
   (crate-source "redox_syscall" "0.5.18"
                 "0b9n38zsxylql36vybw18if68yc9jczxmbyzdwyhb9sifmag4azd")
   (crate-source "redox_users" "0.5.2"
                 "1b17q7gf7w8b1vvl53bxna24xl983yn7bd00gfbii74bcg30irm4")
   (crate-source "regex-automata" "0.4.14"
                 "13xf7hhn4qmgfh784llcp2kzrvljd13lb2b1ca0mwnf15w9d87bf")
   (crate-source "regex-syntax" "0.8.10"
                 "02jx311ka0daxxc7v45ikzhcl3iydjbbb0mdrpc1xgg8v7c7v2fw")
   (crate-source "rsconf" "0.3.0"
                 "17qm1ybr16mrf3vgzvaycfkhwv4q14ysqn4906m93j3cx62dkjq6")
   (crate-source "rust-embed" "8.11.0"
                 "09wdk33zavfn2w3id20jidywvf4abfjg1wbfy21psdss6nwkq484")
   (crate-source "rust-embed-impl" "8.11.0"
                 "1ancyg87vx07w5m39538bwvj3hlizk8fd15kk8argsf8qzj042fs")
   (crate-source "rust-embed-utils" "8.11.0"
                 "1cf3wmwdivxqzizav813y42ln9r9jya3q1xi6finyzzywq5yzkav")
   (crate-source "rustc-hash" "2.1.2"
                 "1gjdc5bw9982cj176jvgz9rrqf9xvr1q1ddpzywf5qhs7yzhlc4l")
   (crate-source "rustc_version" "0.4.1"
                 "14lvdsmr5si5qbqzrajgb6vfn69k0sfygrvfvr2mps26xwi3mjyg")
   (crate-source "same-file" "1.0.6"
                 "00h5j1w87dmhnvbv9l8bic3y7xxsnjmssvifw2ayvgx9mb1ivz4k")
   (crate-source "scc" "2.4.0"
                 "1k2nwz3bysf1s3r5g437vq9xfm9i4sadfzn5c0k8xx7ynx3g1rj6")
   (crate-source "scopeguard" "1.2.0"
                 "0jcz9sd47zlsgcnm1hdw0664krxwb5gczlif4qngj2aif8vky54l")
   (crate-source "sdd" "3.0.10"
                 "1jj1brjjasx7r3lf6iyhhrpglx47vzr0z1qi1n0fcszjzv5wy3a9")
   (crate-source "self_cell" "1.2.2"
                 "12cdmh9p2h72rmw923kj841jji4k0vrykihvx19fn059az8pcbmi")
   (crate-source "semver" "1.0.28"
                 "1kaimrpy876bcgi8bfj0qqfxk77zm9iz2zhn1hp9hj685z854y4a")
   (crate-source "serde" "1.0.228"
                 "17mf4hhjxv5m90g42wmlbc61hdhlm6j9hwfkpcnd72rpgzm993ls")
   (crate-source "serde_core" "1.0.228"
                 "1bb7id2xwx8izq50098s5j2sqrrvk31jbbrjqygyan6ask3qbls1")
   (crate-source "serde_derive" "1.0.228"
                 "0y8xm7fvmr2kjcd029g9fijpndh8csv5m20g4bd76w8qschg4h6m")
   (crate-source "serde_json" "1.0.150"
                 "1ffgfhy9kndjnrz8lmy95pr758p2zk8dxv6yi99x0vkkni24w0g8")
   (crate-source "serial_test" "3.4.0"
                 "0bx30wia5a40q849xj7frqwz6s4r7qxilsbvmbrs6w0hpxwxj6wi")
   (crate-source "serial_test_derive" "3.4.0"
                 "1ng66dgrl7dj555b9xja7rmjnchdni4f8ibld3xx5c45kfa92z8a")
   (crate-source "sha2" "0.10.9"
                 "10xjj843v31ghsksd9sl9y12qfc48157j1xpb8v1ml39jy0psl57")
   (crate-source "shellexpand" "3.1.2"
                 "1n3y55yvh2s8cqmqb6bnz4wrlhchjd489fn1dpcc9rhnbsmlz0ij")
   (crate-source "shlex" "1.3.0"
                 "0r1y6bv26c1scpxvhg2cabimrmwgbp4p3wy6syj9n0c4s3q2znhg")
   (crate-source "shlex" "2.0.1"
                 "1fjsll1cd7d2bcpdij9kd6w62rpbc7qqzvydvs021vsmr1cxvypq")
   (crate-source "siphasher" "1.0.3"
                 "0jg6l9xyzca5vy4h6gf8r6p4kk84g98fk95pzig1kq6cr4z8grcf")
   (crate-source "smallvec" "1.15.1"
                 "00xxdxxpgyq5vjnpljvkmy99xij5rxgh913ii1v16kzynnivgcb7")
   (crate-source "strsim" "0.11.1"
                 "0kzvqlw8hxqb7y598w1s0hxlnmi84sg5vsipp3yg5na5d1rvba3x")
   (crate-source "strum_macros" "0.28.0"
                 "0r7n6v5b3x85m52isyc8wq78irmr22g0hmj1xn3pbq8f4yhfx1db")
   (crate-source "syn" "2.0.117"
                 "16cv7c0wbn8amxc54n4w15kxlx5ypdmla8s0gxr2l7bv7s0bhrg6")
   (crate-source "thiserror" "2.0.18"
                 "1i7vcmw9900bvsmay7mww04ahahab7wmr8s925xc083rpjybb222")
   (crate-source "thiserror-impl" "2.0.18"
                 "1mf1vrbbimj1g6dvhdgzjmn6q09yflz2b92zs1j9n3k7cxzyxi7b")
   (crate-source "tinystr" "0.8.3"
                 "0vfr8x285w6zsqhna0a9jyhylwiafb2kc8pj2qaqaahw48236cn8")
   (crate-source "type-map" "0.5.1"
                 "143v32wwgpymxfy4y8s694vyq0wdi7li4s5dmms5w59nj2yxnc6b")
   (crate-source "typenum" "1.20.1"
                 "086s9ly0906kw5yw41249fba97w5zfxf03pyfwdkffvcprqfixdn")
   (crate-source "unic-langid" "0.9.6"
                 "01bx59sqsx2jz4z7ppxq9kldcjq9dzadkmb2dr7iyc85kcnab2x2")
   (crate-source "unic-langid-impl" "0.9.6"
                 "0n66kdan4cz99n8ra18i27f7w136hmppi4wc0aa7ljsd0h4bzqfw")
   (crate-source "unicode-ident" "1.0.24"
                 "0xfs8y1g7syl2iykji8zk5hgfi5jw819f5zsrbaxmlzwsly33r76")
   (crate-source "unicode-segmentation" "1.13.2"
                 "135a26m4a0wj319gcw28j6a5aqvz00jmgwgmcs6szgxjf942facn")
   (crate-source "unicode-width" "0.2.2"
                 "0m7jjzlcccw716dy9423xxh0clys8pfpllc5smvfxrzdf66h9b5l")
   (crate-source "unicode-xid" "0.2.6"
                 "0lzqaky89fq0bcrh6jj6bhlz37scfd8c7dsj5dq7y32if56c1hgb")
   (crate-source "unix_path" "1.0.1"
                 "1bryg19y7q2ma4x2d75kiw25p8v8xq5lvcy9v74c8xxffcc2k3mg")
   (crate-source "unix_str" "1.0.0"
                 "01h9dfad1p5kcqkb7ngjzqja1y37cbakk4kncacrb8nham3hpkia")
   (crate-source "utf8parse" "0.2.2"
                 "088807qwjq46azicqwbhlmzwrbkz7l4hpw43sdkdyyk524vdxaq6")
   (crate-source "version_check" "0.9.5"
                 "0nhhi4i5x89gm911azqbn7avs9mdacw2i3vcz3cnmz3mv4rqz4hb")
   (crate-source "walkdir" "2.5.0"
                 "0jsy7a710qv8gld5957ybrnc07gavppp963gs32xk4ag8130jy99")
   (crate-source "wasi" "0.11.1+wasi-snapshot-preview1"
                 "0jx49r7nbkbhyfrfyhz0bm4817yrnxgd3jiwwwfv0zl439jyrwyc")
   (crate-source "wasip2" "1.0.1+wasi-0.2.4"
                 "1rsqmpspwy0zja82xx7kbkbg9fv34a4a2if3sbd76dy64a244qh5")
   (crate-source "wasip3" "0.4.0+wasi-0.3.0-rc-2026-01-06"
                 "19dc8p0y2mfrvgk3qw3c3240nfbylv22mvyxz84dqpgai2zzha2l")
   (crate-source "wasm-encoder" "0.244.0"
                 "06c35kv4h42vk3k51xjz1x6hn3mqwfswycmr6ziky033zvr6a04r")
   (crate-source "wasm-metadata" "0.244.0"
                 "02f9dhlnryd2l7zf03whlxai5sv26x4spfibjdvc3g9gd8z3a3mv")
   (crate-source "wasmparser" "0.244.0"
                 "1zi821hrlsxfhn39nqpmgzc0wk7ax3dv6vrs5cw6kb0v5v3hgf27")
   (crate-source "widestring" "1.2.1"
                 "0wg4qdbs70xqnlbm8wb0bs4idm2mxk3b6kaqwllsncmb2cqrq1kj")
   (crate-source "winapi-util" "0.1.11"
                 "08hdl7mkll7pz8whg869h58c1r9y7in0w0pk8fm24qc77k0b39y2")
   (crate-source "windows-link" "0.2.1"
                 "1rag186yfr3xx7piv5rg8b6im2dwcf8zldiflvb22xbzwli5507h")
   (crate-source "windows-sys" "0.60.2"
                 "1jrbc615ihqnhjhxplr2kw7rasrskv9wj3lr80hgfd42sbj01xgj")
   (crate-source "windows-sys" "0.61.2"
                 "1z7k3y9b6b5h52kid57lvmvm05362zv1v8w0gc7xyv5xphlp44xf")
   (crate-source "windows-targets" "0.53.5"
                 "1wv9j2gv3l6wj3gkw5j1kr6ymb5q6dfc42yvydjhv3mqa7szjia9")
   (crate-source "windows_aarch64_gnullvm" "0.53.1"
                 "0lqvdm510mka9w26vmga7hbkmrw9glzc90l4gya5qbxlm1pl3n59")
   (crate-source "windows_aarch64_msvc" "0.53.1"
                 "01jh2adlwx043rji888b22whx4bm8alrk3khjpik5xn20kl85mxr")
   (crate-source "windows_i686_gnu" "0.53.1"
                 "18wkcm82ldyg4figcsidzwbg1pqd49jpm98crfz0j7nqd6h6s3ln")
   (crate-source "windows_i686_gnullvm" "0.53.1"
                 "030qaxqc4salz6l4immfb6sykc6gmhyir9wzn2w8mxj8038mjwzs")
   (crate-source "windows_i686_msvc" "0.53.1"
                 "1hi6scw3mn2pbdl30ji5i4y8vvspb9b66l98kkz350pig58wfyhy")
   (crate-source "windows_x86_64_gnu" "0.53.1"
                 "16d4yiysmfdlsrghndr97y57gh3kljkwhfdbcs05m1jasz6l4f4w")
   (crate-source "windows_x86_64_gnullvm" "0.53.1"
                 "1qbspgv4g3q0vygkg8rnql5c6z3caqv38japiynyivh75ng1gyhg")
   (crate-source "windows_x86_64_msvc" "0.53.1"
                 "0l6npq76vlq4ksn4bwsncpr8508mk0gmznm6wnhjg95d19gzzfyn")
   (crate-source "wit-bindgen" "0.46.0"
                 "0ngysw50gp2wrrfxbwgp6dhw1g6sckknsn3wm7l00vaf7n48aypi")
   (crate-source "wit-bindgen" "0.51.0"
                 "19fazgch8sq5cvjv3ynhhfh5d5x08jq2pkw8jfb05vbcyqcr496p")
   (crate-source "wit-bindgen-core" "0.51.0"
                 "1p2jszqsqbx8k7y8nwvxg65wqzxjm048ba5phaq8r9iy9ildwqga")
   (crate-source "wit-bindgen-rust" "0.51.0"
                 "08bzn5fsvkb9x9wyvyx98qglknj2075xk1n7c5jxv15jykh6didp")
   (crate-source "wit-bindgen-rust-macro" "0.51.0"
                 "0ymizapzv2id89igxsz2n587y2hlfypf6n8kyp68x976fzyrn3qc")
   (crate-source "wit-component" "0.244.0"
                 "1clwxgsgdns3zj2fqnrjcp8y5gazwfa1k0sy5cbk0fsmx4hflrlx")
   (crate-source "wit-parser" "0.244.0"
                 "0dm7avvdxryxd5b02l0g5h6933z1cw5z0d4wynvq2cywq55srj7c")
   (crate-source "xterm-color" "1.0.2"
                 "0wx6xfk4v7a6y9dwv9y520q31pnsp36kzxidkdyy99wppbcaj23h")
   (crate-source "zerofrom" "0.1.8"
                 "0wjjdj7gdmd0iq91gzkxl7dlv0nhkk80l4bmdpzh3a1yh48mmh0f")
   (crate-source "zerovec" "0.11.6"
                 "0fdjsy6b31q9i0d73sl7xjd12xadbwi45lkpfgqnmasrqg5i3ych")
   (crate-source "zmij" "1.0.21"
                 "1amb5i6gz7yjb0dnmz5y669674pqmwbj44p4yfxfv2ncgvk8x15q")
   ))

(define fish-fluent-rs-snapshot
  (hidden-package
   (package
     (name "rust-fish-fluent-rs-snapshot")
     (version "0.17.0.cf712bc")
     (source
      (origin
        (method git-fetch)
        (uri
         (git-reference
          (url "https://github.com/danielrainer/fluent-rs")
          (commit "cf712bced280b217b6307edabc2089b3e57204ab")))
        (file-name (git-file-name name version))
        (sha256
         (base32
          "0c3qd6cvldfpf46cbb2j4hkbrycq4q6b206qiq8vch1gadrvdr50"))))
     (build-system cargo-build-system)
     (arguments
      (list
       #:skip-build? #t
       #:install-source? #t
       #:cargo-package-crates
       ''("fluent" "fluent-bundle" "fluent-syntax" "intl-memoizer")
       #:cargo-package-flags
       ''("--no-metadata" "--no-verify" "--exclude-lockfile")))
     (home-page "https://github.com/danielrainer/fluent-rs")
     (synopsis "Fluent crates snapshot for fish")
     (description
      "This hidden source package provides the Fluent workspace crates pinned
by fish's Cargo.lock.")
     (license (list license:asl2.0 license:expat)))))

(define fish-fluent-ftl-tools-snapshot
  (hidden-package
   (package
     (name "rust-fish-fluent-ftl-tools-snapshot")
     (version "0.1.0.5917664")
     (source
      (origin
        (method git-fetch)
        (uri
         (git-reference
          (url "https://codeberg.org/danielrainer/fluent-ftl-tools")
          (commit "5917664c8f2e4928ef1e480ff5c13bbe1e226066")))
        (file-name (git-file-name name version))
        (sha256
         (base32
          "0yivm9rpvjfs98rczndab6zfah5gjmbcxkhxjm0c1p31jqrngzj9"))))
     (build-system cargo-build-system)
     (arguments
      (list
       #:skip-build? #t
       #:install-source? #t
       #:cargo-package-crates
       ''("fluent-ftl-tools" "gettext-po-file-parser")
       #:cargo-package-flags
       ''("--no-metadata" "--no-verify" "--exclude-lockfile")
       #:phases
       #~(modify-phases %standard-phases
           (add-after 'unpack 'use-versioned-fluent-dependencies
             (lambda _
               (substitute* "Cargo.toml"
                 (("git = \"[^\"]+\", rev = \"[^\"]+\"")
                  "version = \"*\"")
                 (("gettext-po-file-parser = \\{ path = \"crates/gettext-po-file-parser\" \\}")
                  "gettext-po-file-parser = { version = \"0.0.0\", path = \"crates/gettext-po-file-parser\" }")))))))
     (home-page "https://codeberg.org/danielrainer/fluent-ftl-tools")
     (synopsis "Fluent FTL tools crates snapshot for fish")
     (description
      "This hidden source package provides the FTL workspace crates pinned by
fish's Cargo.lock.")
     (license (list license:agpl3 license:gpl2)))))

(define fish-4.9.2-cargo-inputs
  (append fish-registry-inputs
          (list fish-fluent-rs-snapshot
                fish-fluent-ftl-tools-snapshot
                rust-pcre2-utf32-0.2)))
