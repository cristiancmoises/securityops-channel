;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Registry sources from Mirim 1.1.1 Cargo.lock.

(define-module (securityops packages mirim-crates)
  #:use-module (securityops packages cargo-crates)
  #:export (mirim-crates))

(define mirim-crates
  (list
   (crate "aead" "0.5.2"
          "d122413f284cf2d62fb1b7db97e02edb8cda96d769b16e443a4f6195e35662b0")
   (crate "ahash" "0.8.12"
          "5a15f179cd60c4584b8a8c596927aadc462e27f2ca70c04e0071964a73ba7a75")
   (crate "aho-corasick" "1.1.4"
          "ddd31a130427c27518df266943a5308ed92d4b226cc639f5a8f1002816174301")
   (crate "anes" "0.1.6"
          "4b46cbb362ab8752921c97e041f5e366ee6297bd428a31275b9fcf1e380f7299")
   (crate "anstyle" "1.0.14"
          "940b3a0ca603d1eade50a4846a2afffd5ef57a9feac2c0e2ec2e14f9ead76000")
   (crate "anyhow" "1.0.104"
          "330a5ed07fa54e4702c9d6c4174f74427fc0ef6e214bbd677ae50a5099946470")
   (crate "argon2" "0.5.3"
          "3c3610892ee6e0cbce8ae2700349fcf8f98adb0dbfbee85aec3c9179d29cc072")
   (crate "autocfg" "1.5.1"
          "f2032f911046de80f0a198e0901378627c33f59ea0ac00e363d481118bd70a53")
   (crate "base64ct" "1.8.3"
          "2af50177e190e07a26ab74f8b1efbfe2ef87da2116221318cb1c2e82baf7de06")
   (crate "bit-set" "0.8.0"
          "08807e080ed7f9d5433fa9b275196cfc35414f66a0c79d864dc51a0d825231a3")
   (crate "bit-vec" "0.8.0"
          "5e764a1d40d510daf35e07be9eb06e75770908c27d411ee6c92109c9840eaaf7")
   (crate "bitflags" "2.13.0"
          "b4388bee8683e3d04af747c73422af53102d2bd24d9eadb6cbc100baef4b43f8")
   (crate "blake2" "0.10.6"
          "46502ad458c9a52b69d4d4d32775c788b7a1b85e8bc9d482d92250fc0e3f8efe")
   (crate "block-buffer" "0.10.4"
          "3078c7629b62d3f0439517fa394996acacc5cbc91c5a20d8c658e77abd503a71")
   (crate "cast" "0.3.0"
          "37b2a672a2cb129a2e41c10b1224bb368f9f37a2b16b612598138befd7b37eb5")
   (crate "cc" "1.2.64"
          "dad887fd958be91b5098c0248def011f4523ab786cd411be668777e55063501f")
   (crate "cfg-if" "1.0.4"
          "9330f8b2ff13f34540b44e946ef35111825727b38d33286ef986142615121801")
   (crate "chacha20" "0.9.1"
          "c3613f74bd2eac03dad61bd53dbe620703d4371614fe0bc3b9f04dd36fe4e818")
   (crate "chacha20poly1305" "0.10.1"
          "10cd79432192d1c0f4e1a0fef9527696cc039165d729fb41b3f4f4f354c2dc35")
   (crate "ciborium" "0.2.2"
          "42e69ffd6f0917f5c029256a24d0161db17cea3997d185db0d35926308770f0e")
   (crate "ciborium-io" "0.2.2"
          "05afea1e0a06c9be33d539b876f1ce3692f4afea2cb41f740e7743225ed1c757")
   (crate "ciborium-ll" "0.2.2"
          "57663b653d948a338bfb3eeba9bb2fd5fcfaecb9e199e87e1eda4d9e8b240fd9")
   (crate "cipher" "0.4.4"
          "773f3b9af64447d2ce9850330c473515014aa235e6a783b02db81ff39e4a3dad")
   (crate "clap" "4.6.1"
          "1ddb117e43bbf7dacf0a4190fef4d345b9bad68dfc649cb349e7d17d28428e51")
   (crate "clap_builder" "4.6.0"
          "714a53001bf66416adb0e2ef5ac857140e7dc3a0c48fb28b2f10762fc4b5069f")
   (crate "clap_lex" "1.1.0"
          "c8d4a3bb8b1e0c1050499d1815f5ab16d04f0959b233085fb31653fbfc9d98f9")
   (crate "cmov" "0.5.4"
          "0c9ea0ac24bc397ab3c98583a3c9ba74fa56b09a4449bbe172b9b1ddb016027a")
   (crate "const-oid" "0.10.2"
          "a6ef517f0926dd24a1582492c791b6a4818a4d94e789a334894aa15b0d12f55c")
   (crate "cpufeatures" "0.2.17"
          "59ed5838eebb26a2bb2e58f6d5b5316989ae9d08bab10e0e6d103e656d1b0280")
   (crate "cpufeatures" "0.3.0"
          "8b2a41393f66f16b0823bb79094d54ac5fbd34ab292ddafb9a0456ac9f87d201")
   (crate "criterion" "0.5.1"
          "f2b12d017a929603d80db1831cd3a24082f8137ce19c69e6447f54f5fc8d692f")
   (crate "criterion-plot" "0.5.0"
          "6b50826342786a51a89e2da3a28f1c32b06e387201bc2d19791f622c673706b1")
   (crate "crunchy" "0.2.4"
          "460fbee9c2c2f33933d720630a6a0bac33ba7053db5344fac858d4b8952d77d5")
   (crate "crypto-common" "0.1.7"
          "78c8292055d1c1df0cce5d180393dc8cce0abec0a7102adb6c7b1eef6016d60a")
   (crate "crypto-common" "0.2.2"
          "ce6e4c961d6cd6c9a86db418387425e8bdeaf05b3c8bc1411e6dca4c252f1453")
   (crate "ctutils" "0.4.2"
          "7d5515a3834141de9eafb9717ad39eea8247b5674e6066c404e8c4b365d2a29e")
   (crate "der" "0.8.2"
          "a878c850e9e421b20262e9b41f9c860e4785fa07541c266b62ff9d1ef998a80a")
   (crate "digest" "0.10.7"
          "9ed9a281f7bc9b7576e61468ba615a66a5c8cfdff42420a70aa82701a3b1e292")
   (crate "digest" "0.11.3"
          "f1dd6dbb5841937940781866fa1281a1ff7bd3bf827091440879f9994983d5c2")
   (crate "either" "1.16.0"
          "91622ff5e7162018101f2fea40d6ebf4a78bbe5a49736a2020649edf9693679e")
   (crate "equivalent" "1.0.2"
          "877a4ace8713b0bcf2a4e7eec82529c029f1d0619886d18145fea96c3ffe5c0f")
   (crate "errno" "0.3.14"
          "39cab71617ae0d63f51a36d69f866391735b51691dbda63cf6f96d042b63efeb")
   (crate "fallible-iterator" "0.3.0"
          "2acce4a10f12dc2fb14a218589d4f1f62ef011b2d0cc4b3cb1bba8e94da14649")
   (crate "fallible-streaming-iterator" "0.1.9"
          "7360491ce676a36bf9bb3c56c1aa791658183a54d2744120f27285738d90465a")
   (crate "fastrand" "2.4.1"
          "9f1f227452a390804cdb637b74a86990f2a7d7ba4b7d5693aac9b4dd6defd8d6")
   (crate "find-msvc-tools" "0.1.9"
          "5baebc0774151f905a1a2cc41989300b1e6fbb29aff0ceffa1064fdd3088d582")
   (crate "fnv" "1.0.7"
          "3f9eec918d3f24069decb9af1554cad7c880e2da24a9afd88aca000531ab82c1")
   (crate "foldhash" "0.1.5"
          "d9c4f5dac5e15c24eb999c26181a6ca40b39fe946cbe4c263c7209467bc83af2")
   (crate "generic-array" "0.14.7"
          "85649ca51fd72272d7821adaf274ad91c288277713d9c18820d8499a7ff69e9a")
   (crate "getrandom" "0.2.17"
          "ff2abc00be7fca6ebc474524697ae276ad847ad0a6b3faa4bcb027e9a4614ad0")
   (crate "getrandom" "0.3.4"
          "899def5c37c4fd7b2664648c28120ecec138e4d395b459e5ca34f9cce2dd77fd")
   (crate "getrandom" "0.4.2"
          "0de51e6874e94e7bf76d726fc5d13ba782deca734ff60d5bb2fb2607c7406555")
   (crate "half" "2.7.1"
          "6ea2d84b969582b4b1864a92dc5d27cd2b77b622a8d79306834f1be5ba20d84b")
   (crate "hashbrown" "0.14.5"
          "e5274423e17b7c9fc20b6e7e208532f9b19825d82dfd615708b70edd83df41f1")
   (crate "hashbrown" "0.15.5"
          "9229cfe53dfd69f0609a49f65461bd93001ea1ef889cd5529dd176593f5338a1")
   (crate "hashbrown" "0.17.1"
          "ed5909b6e89a2db4456e54cd5f673791d7eca6732202bbf2a9cc504fe2f9b84a")
   (crate "hashlink" "0.9.1"
          "6ba4ff7128dee98c7dc9794b6a411377e1404dba1c97deb8d1a55297bd25d8af")
   (crate "heck" "0.5.0"
          "2304e00983f87ffb38b55b444b5e3b60a884b5d30c0fca7d82fe33449bbe55ea")
   (crate "hermit-abi" "0.5.2"
          "fc0fef456e4baa96da950455cd02c081ca953b141298e41db3fc7e36b1da849c")
   (crate "hkdf" "0.12.4"
          "7b5f8eb2ad728638ea2c7d47a21db23b7b58a72ed6a38256b8a1849f15fbbdf7")
   (crate "hmac" "0.12.1"
          "6c49c37c09c17a53d937dfbb742eb3a961d65a994e6bcdcf37e7399d0cc8ab5e")
   (crate "hybrid-array" "0.2.3"
          "f2d35805454dc9f8662a98d6d61886ffe26bd465f5960e0e55345c70d5c0d2a9")
   (crate "hybrid-array" "0.4.12"
          "9155a582abd142abc056962c29e3ce5ff2ad5469f4246b537ed42c5deba857da")
   (crate "id-arena" "2.3.0"
          "3d3067d79b975e8844ca9eb072e16b31c3c1c36928edf9c6789548c524d0d954")
   (crate "indexmap" "2.14.0"
          "d466e9454f08e4a911e14806c24e16fba1b4c121d1ea474396f396069cf949d9")
   (crate "inout" "0.1.4"
          "879f10e63c20629ecabbb64a8010319738c66a5cd0c29b02d63d272b03751d01")
   (crate "is-terminal" "0.4.17"
          "3640c1c38b8e4e43584d8df18be5fc6b0aa314ce6ebf51b53313d4306cca8e46")
   (crate "itertools" "0.10.5"
          "b0fd2260e829bddf4cb6ea802289de2f86d6a7a690192fbe91b3f46e0f2c8473")
   (crate "itoa" "1.0.18"
          "8f42a60cbdf9a97f5d2305f08a87dc4e09308d1276d28c869c684d7777685682")
   (crate "keccak" "0.1.6"
          "cb26cec98cce3a3d96cbb7bced3c4b16e3d13f27ec56dbd62cbc8f39cfb9d653")
   (crate "keccak" "0.2.0"
          "9e24a010dd405bd7ed803e5253182815b41bf2e6a80cc3bfc066658e03a198aa")
   (crate "kem" "0.3.0-pre.0"
          "2b8645470337db67b01a7f966decf7d0bafedbae74147d33e641c67a91df239f")
   (crate "leb128fmt" "0.1.0"
          "09edd9e8b54e49e587e4f6295a7d29c3ea94d469cb40ab8ca70b288248a81db2")
   (crate "libc" "0.2.186"
          "68ab91017fe16c622486840e4c83c9a37afeff978bd239b5293d61ece587de66")
   (crate "libsqlite3-sys" "0.30.1"
          "2e99fb7a497b1e3339bc746195567ed8d3e24945ecd636e3619d20b9de9e9149")
   (crate "linux-raw-sys" "0.12.1"
          "32a66949e030da00e8c7d4434b251670a91556f4144941d37452769c25d58a53")
   (crate "log" "0.4.32"
          "953f07c43838f8e6f9758cab68bf5bed85465e7587ebe0b823f1bcd81978ad3a")
   (crate "memchr" "2.8.2"
          "88904434abc2901f197fe8cc55f0445e7ded921dba5911dad2e2b39b48e663c4")
   (crate "ml-dsa" "0.1.1"
          "add6b9d92e496f16f4526d68ff29da1483aba4b119baeab8bed3b9e3544a6f3d")
   (crate "ml-kem" "0.2.3"
          "8de49b3df74c35498c0232031bb7e85f9389f913e2796169c8ab47a53993a18f")
   (crate "module-lattice" "0.2.3"
          "0c61b87c9683ab7cb1c6871d261ad5479b6b10ceb52c4352aaca3b5d35a8febe")
   (crate "num-traits" "0.2.19"
          "071dfc062690e90b734c0b2273ce72ad0ffa95f0c74596bc250dcfd960262841")
   (crate "once_cell" "1.21.4"
          "9f7c3e4beb33f85d45ae3e3a1792185706c8e16d043238c593331cc7cd313b50")
   (crate "oorandom" "11.1.5"
          "d6790f58c7ff633d8771f42965289203411a5e5c68388703c06e14f24770b41e")
   (crate "opaque-debug" "0.3.1"
          "c08d65885ee38876c4f86fa503fb49d7b507c2b62552df7c70b2fce627e06381")
   (crate "password-hash" "0.5.0"
          "346f04948ba92c43e8469c1ee6736c7563d71012b17d40745260fe106aac2166")
   (crate "pkcs8" "0.11.0"
          "451913da69c775a56034ea8d9003d27ee8948e12443eae7c038ba100a4f21cb7")
   (crate "pkg-config" "0.3.33"
          "19f132c84eca552bf34cab8ec81f1c1dcc229b811638f9d283dceabe58c5569e")
   (crate "poly1305" "0.8.0"
          "8159bd90725d2df49889a078b54f4f79e87f1f8a8444194cdca81d38f5393abf")
   (crate "ppv-lite86" "0.2.21"
          "85eae3c4ed2f50dcfe72643da4befc30deadb458a9b590d720cde2f2b1e97da9")
   (crate "prettyplease" "0.2.37"
          "479ca8adacdd7ce8f1fb39ce9ecccbfe93a3f1344b3d0d97f20bc0196208f62b")
   (crate "proc-macro2" "1.0.106"
          "8fd00f0bb2e90d81d1044c2b32617f68fcb9fa3bb7640c23e9c748e53fb30934")
   (crate "proptest" "1.11.0"
          "4b45fcc2344c680f5025fe57779faef368840d0bd1f42f216291f0dc4ace4744")
   (crate "quick-error" "1.2.3"
          "a1d01941d82fa2ab50be1e79e6714289dd7cde78eba4c074bc5a4374f650dfe0")
   (crate "quote" "1.0.45"
          "41f2619966050689382d2b44f664f4bc593e129785a36d6ee376ddf37259b924")
   (crate "r-efi" "5.3.0"
          "69cdb34c158ceb288df11e18b4bd39de994f6657d83847bdffdbd7f346754b0f")
   (crate "r-efi" "6.0.0"
          "f8dcc9c7d52a811697d2151c701e0d08956f92b0e24136cf4cf27b57a6a0d9bf")
   (crate "rand" "0.9.4"
          "44c5af06bb1b7d3216d91932aed5265164bf384dc89cd6ba05cf59a35f5f76ea")
   (crate "rand_chacha" "0.9.0"
          "d3022b5f1df60f26e1ffddd6c66e8aa15de382ae63b3a0c1bfc0e4d3e3f325cb")
   (crate "rand_core" "0.6.4"
          "ec0be4795e2f6a28069bec0b5ff3e2ac9bafc99e6a9a7dc3547996c5c816922c")
   (crate "rand_core" "0.9.5"
          "76afc826de14238e6e8c374ddcc1fa19e374fd8dd986b0d2af0d02377261d83c")
   (crate "rand_xorshift" "0.4.0"
          "513962919efc330f829edb2535844d1b912b0fbe2ca165d613e4e8788bb05a5a")
   (crate "regex" "1.12.4"
          "f1292b7759ae1cb9ec195452d1390a074f0cd8541ab7a5a8c31cd6db45d4a6ba")
   (crate "regex-automata" "0.4.14"
          "6e1dd4122fc1595e8162618945476892eefca7b88c52820e74af6262213cae8f")
   (crate "regex-syntax" "0.8.11"
          "d6f6ff9a378485b298a5286656da665ba74413d36db0979633275d2e708145d4")
   (crate "rpassword" "7.5.4"
          "2da316a15f47e3d053de9cb2c439650bd8fa4aaeb9365f2e5f27f492ff73c196")
   (crate "rtoolbox" "0.0.5"
          "50a0e551c1e27e1731aba276dbeaeac73f53c7cd34d1bda485d02bd1e0f36844")
   (crate "rusqlite" "0.32.1"
          "7753b721174eb8ff87a9a0e799e2d7bc3749323e773db92e0984debb00019d6e")
   (crate "rustix" "1.1.4"
          "b6fe4565b9518b83ef4f91bb47ce29620ca828bd32cb7e408f0062e9930ba190")
   (crate "rusty-fork" "0.3.1"
          "cc6bf79ff24e648f6da1f8d1f011e9cac26491b619e6b9280f2b47f1774e6ee2")
   (crate "same-file" "1.0.6"
          "93fc1dc3aaa9bfed95e02e6eadabb4baf7e3078b0bd1b4d7b6b0b68378900502")
   (crate "semver" "1.0.28"
          "8a7852d02fc848982e0c167ef163aaff9cd91dc640ba85e263cb1ce46fae51cd")
   (crate "serde" "1.0.228"
          "9a8e94ea7f378bd32cbbd37198a4a91436180c5bb472411e48b5ec2e2124ae9e")
   (crate "serde_core" "1.0.228"
          "41d385c7d4ca58e59fc732af25c3983b67ac852c1a25000afe1175de458b67ad")
   (crate "serde_derive" "1.0.228"
          "d540f220d3187173da220f885ab66608367b6574e925011a9353e4badda91d79")
   (crate "serde_json" "1.0.150"
          "e8014e44b4736ed0538adeecded0fce2a272f22dc9578a7eb6b2d9993c74cfb9")
   (crate "sha2" "0.10.9"
          "a7507d819769d01a365ab707794a4084392c824f54a7a6a7862f8c3d0892b283")
   (crate "sha3" "0.10.9"
          "77fd7028345d415a4034cf8777cd4f8ab1851274233b45f84e3d955502d93874")
   (crate "shake" "0.1.0"
          "09057cb2149ad4cbd2da1e26b351f9a4c354219421229c69c3063e6f61947c4a")
   (crate "shlex" "2.0.1"
          "f8fadd59c855ef2080decdef8ff161eb6661b86933c9d82e5ba29dc602a55aba")
   (crate "signature" "3.0.0"
          "28d567dcbaf0049cb8ac2608a76cd95ff9e4412e1899d389ee400918ca7537f5")
   (crate "smallvec" "1.15.2"
          "8ed6a63f02c8539c91a8685a86f4099661ba3da017932f6ebbea6de3f0fa7c90")
   (crate "spki" "0.8.0"
          "1d9efca8738c78ee9484207732f728b1ef517bbb1833d6fc0879ca898a522f6f")
   (crate "sponge-cursor" "0.1.0"
          "3a0219bd7d979d58245a4f41f695e1ac9f8befdffadd7f61f1bae9e39abc6620")
   (crate "subtle" "2.6.1"
          "13c2bddecc57b384dee18652358fb23172facb8a2c51ccc10d74c157bdea3292")
   (crate "syn" "2.0.117"
          "e665b8803e7b1d2a727f4023456bbbbe74da67099c585258af0ad9c5013b9b99")
   (crate "tempfile" "3.27.0"
          "32497e9a4c7b38532efcdebeef879707aa9f794296a4f0244f6f69e9bc8574bd")
   (crate "tinytemplate" "1.2.1"
          "be4d6b5f19ff7664e8c98d03e2139cb510db9b0a60b55f8e8709b689d939b6bc")
   (crate "typenum" "1.20.1"
          "b6f5e870be6c3b371b77fe0ee0bafb859fa4964b4404c27de1d380043c4dda20")
   (crate "unarray" "0.1.4"
          "eaea85b334db583fe3274d12b4cd1880032beab409c0d774be044d4480ab9a94")
   (crate "unicode-ident" "1.0.24"
          "e6e4313cd5fcd3dad5cafa179702e2b244f760991f45397d14d4ebf38247da75")
   (crate "unicode-xid" "0.2.6"
          "ebc1c04c71510c7f702b52b7c350734c9ff1295c464a03335b00bb84fc54f853")
   (crate "universal-hash" "0.5.1"
          "fc1de2c688dc15305988b563c3854064043356019f97a4b46276fe734c4f07ea")
   (crate "vcpkg" "0.2.15"
          "accd4ea62f7bb7a82fe23066fb0957d48ef677f6eeb8215f372f52e48bb32426")
   (crate "version_check" "0.9.5"
          "0b928f33d975fc6ad9f86c8f283853ad26bdd5b10b7f1542aa2fa15e2289105a")
   (crate "wait-timeout" "0.2.1"
          "09ac3b126d3914f9849036f826e054cbabdc8519970b8998ddaf3b5bd3c65f11")
   (crate "walkdir" "2.5.0"
          "29790946404f91d9c5d06f9874efddea1dc06c5efe94541a7d6863108e3a5e4b")
   (crate "wasi" "0.11.1+wasi-snapshot-preview1"
          "ccf3ec651a847eb01de73ccad15eb7d99f80485de043efb2f370cd654f4ea44b")
   (crate "wasip2" "1.0.4+wasi-0.2.12"
          "b67efb37e106e55ce722a510d6b5f9c17f083e5fc79afc2badeb12cc313d9487")
   (crate "wasip3" "0.4.0+wasi-0.3.0-rc-2026-01-06"
          "5428f8bf88ea5ddc08faddef2ac4a67e390b88186c703ce6dbd955e1c145aca5")
   (crate "wasm-encoder" "0.244.0"
          "990065f2fe63003fe337b932cfb5e3b80e0b4d0f5ff650e6985b1048f62c8319")
   (crate "wasm-metadata" "0.244.0"
          "bb0e353e6a2fbdc176932bbaab493762eb1255a7900fe0fea1a2f96c296cc909")
   (crate "wasmparser" "0.244.0"
          "47b807c72e1bac69382b3a6fb3dbe8ea4c0ed87ff5629b8685ae6b9a611028fe")
   (crate "winapi-util" "0.1.11"
          "c2a7b1c03c876122aa43f3020e6c3c3ee5c05081c9a00739faf7503aeba10d22")
   (crate "windows-link" "0.2.1"
          "f0805222e57f7521d6a62e36fa9163bc891acd422f971defe97d64e70d0a4fe5")
   (crate "windows-sys" "0.59.0"
          "1e38bc4d79ed67fd075bcc251a1c39b32a1776bbe92e5bef1f0bf1f8c531853b")
   (crate "windows-sys" "0.61.2"
          "ae137229bcbd6cdf0f7b80a31df61766145077ddf49416a728b02cb3921ff3fc")
   (crate "windows-targets" "0.52.6"
          "9b724f72796e036ab90c1021d4780d4d3d648aca59e491e6b98e725b84e99973")
   (crate "windows_aarch64_gnullvm" "0.52.6"
          "32a4622180e7a0ec044bb555404c800bc9fd9ec262ec147edd5989ccd0c02cd3")
   (crate "windows_aarch64_msvc" "0.52.6"
          "09ec2a7bb152e2252b53fa7803150007879548bc709c039df7627cabbd05d469")
   (crate "windows_i686_gnu" "0.52.6"
          "8e9b5ad5ab802e97eb8e295ac6720e509ee4c243f69d781394014ebfe8bbfa0b")
   (crate "windows_i686_gnullvm" "0.52.6"
          "0eee52d38c090b3caa76c563b86c3a4bd71ef1a819287c19d586d7334ae8ed66")
   (crate "windows_i686_msvc" "0.52.6"
          "240948bc05c5e7c6dabba28bf89d89ffce3e303022809e73deaefe4f6ec56c66")
   (crate "windows_x86_64_gnu" "0.52.6"
          "147a5c80aabfbf0c7d901cb5895d1de30ef2907eb21fbbab29ca94c5b08b1a78")
   (crate "windows_x86_64_gnullvm" "0.52.6"
          "24d5b23dc417412679681396f2b49f3de8c1473deb516bd34410872eff51ed0d")
   (crate "windows_x86_64_msvc" "0.52.6"
          "589f6da84c646204747d1270a2a5661ea66ed1cced2631d546fdfb155959f9ec")
   (crate "wit-bindgen" "0.51.0"
          "d7249219f66ced02969388cf2bb044a09756a083d0fab1e566056b04d9fbcaa5")
   (crate "wit-bindgen" "0.57.1"
          "1ebf944e87a7c253233ad6766e082e3cd714b5d03812acc24c318f549614536e")
   (crate "wit-bindgen-core" "0.51.0"
          "ea61de684c3ea68cb082b7a88508a8b27fcc8b797d738bfc99a82facf1d752dc")
   (crate "wit-bindgen-rust" "0.51.0"
          "b7c566e0f4b284dd6561c786d9cb0142da491f46a9fbed79ea69cdad5db17f21")
   (crate "wit-bindgen-rust-macro" "0.51.0"
          "0c0f9bfd77e6a48eccf51359e3ae77140a7f50b1e2ebfe62422d8afdaffab17a")
   (crate "wit-component" "0.244.0"
          "9d66ea20e9553b30172b5e831994e35fbde2d165325bec84fc43dbf6f4eb9cb2")
   (crate "wit-parser" "0.244.0"
          "ecc8ac4bc1dc3381b7f59c34f00b67e18f910c2c0f50015669dde7def656a736")
   (crate "zerocopy" "0.8.52"
          "ce1022995ff5ff5d841ad7d994facc23098cd40152f2c1d11cd607c6f530653f")
   (crate "zerocopy-derive" "0.8.52"
          "1ae7f38b72ec2a254e2b87ef277cf2cd4fb97cbebf944faa6f33354da0867930")
   (crate "zeroize" "1.9.0"
          "e13c156562582aa81c60cb29407084cdb54c4164760106ab78e6c5b0858cf64e")
   (crate "zeroize_derive" "1.5.0"
          "3c50655cbb0fe3fc43170059e702f1ce5e19b84cec58dc87b037a09935c2f328")
   (crate "zmij" "1.0.21"
          "b8848ee67ecc8aedbaf3e4122217aff892639231befc6a1b58d29fff4c2cabaa")))
