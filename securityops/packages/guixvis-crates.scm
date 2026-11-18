;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Registry sources from GuixVis 0.10.0 Cargo.lock.

(define-module (securityops packages guixvis-crates)
  #:use-module (securityops packages cargo-crates)
  #:export (guixvis-crates))

(define guixvis-crates
  (list
   (crate "adler2" "2.0.1"
          "320119579fcad9c21884f5c4861d16174d0e06250625266f50fe6898340abefa")
   (crate "aho-corasick" "1.1.5"
          "c982642fa9e8606056828ee9a8505737230110bb1099153c79efe865c59d12ba")
   (crate "allocator-api2" "0.2.21"
          "683d7910e743518b0e34f1186f92494becacb047c7b6bf616c96772180fef923")
   (crate "anstream" "1.0.0"
          "824a212faf96e9acacdbd09febd34438f8f711fb84e09a8916013cd7815ca28d")
   (crate "anstyle" "1.0.14"
          "940b3a0ca603d1eade50a4846a2afffd5ef57a9feac2c0e2ec2e14f9ead76000")
   (crate "anstyle-parse" "1.0.0"
          "52ce7f38b242319f7cabaa6813055467063ecdc9d355bbb4ce0c68908cd8130e")
   (crate "anstyle-query" "1.1.5"
          "40c48f72fd53cd289104fc64099abca73db4166ad86ea0b4341abe65af83dadc")
   (crate "anstyle-wincon" "3.0.11"
          "291e6a250ff86cd4a820112fb8898808a366d8f9f58ce16d1f538353ad55747d")
   (crate "anyhow" "1.0.104"
          "330a5ed07fa54e4702c9d6c4174f74427fc0ef6e214bbd677ae50a5099946470")
   (crate "approx" "0.5.1"
          "cab112f0a86d568ea0e627cc1d6be74a1e9cd55214684db5561995f6dad897c6")
   (crate "atomic" "0.6.1"
          "a89cbf775b137e9b968e67227ef7f775587cde3fd31b0d8599dbd0f598a48340")
   (crate "atomic-waker" "1.1.2"
          "1505bd5d3d116872e7271a6d4e16d81d0c8570876c8de68093a09ac269d8aac0")
   (crate "autocfg" "1.5.1"
          "f2032f911046de80f0a198e0901378627c33f59ea0ac00e363d481118bd70a53")
   (crate "axum" "0.8.9"
          "31b698c5f9a010f6573133b09e0de5408834d0c82f8d7475a89fc1867a71cd90")
   (crate "axum-core" "0.5.6"
          "08c78f31d7b1291f7ee735c1c6780ccde7785daae9a9206026862dab7d8792d1")
   (crate "base64" "0.22.1"
          "72b3254f16251a8381aa12e40e3c4d2f0199f8c6508fbecb9d91f575e0fbb8c6")
   (crate "bit-set" "0.5.3"
          "0700ddab506f33b20a03b13996eccd309a48e5ff77d0d95926aa0210fb4e95f1")
   (crate "bit-vec" "0.6.3"
          "349f9b6a179ed607305526ca489b34ad0a41aed5f7980fa90eb03160b69598fb")
   (crate "bitflags" "1.3.2"
          "bef38d45163c2f1dde094a7dfd33ccf595c92905c8f8f4fdc18d06fb1037718a")
   (crate "bitflags" "2.13.2"
          "3ded4057c258ba199e2d26386d3af3780957ecaee6c4ef4041c6b4b8b97c0b06")
   (crate "block-buffer" "0.10.4"
          "3078c7629b62d3f0439517fa394996acacc5cbc91c5a20d8c658e77abd503a71")
   (crate "bumpalo" "3.20.3"
          "72f5acc6cb2ba439de613abc23857ec3d78374d8ed5ac84e9d11336e87da8649")
   (crate "by_address" "1.2.1"
          "64fa3c856b712db6612c019f14756e64e4bcea13337a6b33b696333a9eaa2d06")
   (crate "bytemuck" "1.25.2"
          "95832e849adfb21180ccb6826a99da14e5d266ae5c2e668e1602cf234f153797")
   (crate "bytes" "1.12.1"
          "fc652a48c352aef3ea3aed32080501cf3ef6ed5da78602a020c991775b0aff04")
   (crate "castaway" "0.2.4"
          "dec551ab6e7578819132c713a93c022a05d60159dc86e7a7050223577484c55a")
   (crate "cfg-if" "1.0.5"
          "4e7648175b45a9a48536d676f68d918270699102aa8dab5496df06904c914600")
   (crate "cfg_aliases" "0.2.2"
          "f079e83a288787bcd14a6aea84cee5c87a67c5a3e660c30f557a3d24761b3527")
   (crate "clap" "4.6.7"
          "aa8876b300ab35ba921adea3dfd70157a46249b33f95c9084ae5709785478946")
   (crate "clap_builder" "4.6.7"
          "ec0797fb7aeb1406c84efac526901f7ec3ead2124f946b494e72879d4b54704d")
   (crate "clap_derive" "4.6.7"
          "f9c751b79415d4e559e3d1fcf128e09e720eb673a06d26cf6f392d37d75b66e0")
   (crate "clap_lex" "1.1.1"
          "1c133bc6a41be0d194c306b5506d15e6feeea7b1d6604bd3f8310dfb2ca96486")
   (crate "colorchoice" "1.0.5"
          "1d07550c9036bf2ae0c684c4297d503f838287c83c53686d05370d0e139ae570")
   (crate "compact_str" "0.9.1"
          "9dfdd1c2274d9aa354115b09dc9a901d6c5576818cdf70d14cae2bdb47df00ab")
   (crate "convert_case" "0.10.0"
          "633458d4ef8c78b72454de2d54fd6ab2e60f9e02be22f3c6104cdc8a4e0fceb9")
   (crate "cpufeatures" "0.2.17"
          "59ed5838eebb26a2bb2e58f6d5b5316989ae9d08bab10e0e6d103e656d1b0280")
   (crate "crc32fast" "1.5.2"
          "01a7799fd6b852db0e61728dde9a204c423b44d689dbd432522543614b490e78")
   (crate "critical-section" "1.2.0"
          "790eea4361631c5e7d22598ecd5723ff611904e3344ce8720784c93e3d83d40b")
   (crate "crossterm" "0.29.0"
          "d8b9f2e4c67f833b660cdb0a3523065869fb35570177239812ed4c905aeff87b")
   (crate "crossterm_winapi" "0.9.1"
          "acdd7c62a3665c7f6830a51635d9ac9b23ed385797f70a83bb8bafe9c572ab2b")
   (crate "crypto-common" "0.1.7"
          "78c8292055d1c1df0cce5d180393dc8cce0abec0a7102adb6c7b1eef6016d60a")
   (crate "csscolorparser" "0.6.2"
          "eb2a7d3066da2de787b7f032c736763eb7ae5d355f81a68bab2675a96008b0bf")
   (crate "darling" "0.24.1"
          "ed17f5901b6630b993ca003def43f2f8ef4014fc13b047b57aad617ff32bc2ec")
   (crate "darling_core" "0.24.1"
          "6837e2cf7485aaae18f86181d2f0e9a7ed297a025e220aeabf63fdebd3a2ddff")
   (crate "darling_macro" "0.24.1"
          "2ac7135c3ef02b2f7833bbeb1be5ba7f966dcde8a87c6b87f65a778d71a02785")
   (crate "deltae" "0.3.2"
          "5729f5117e208430e437df2f4843f5e5952997175992d1414f94c57d61e270b4")
   (crate "deranged" "0.5.8"
          "7cd812cc2bc1d69d4764bd80df88b4317eaef9e773c75226407d9bc0876b211c")
   (crate "derive_more" "2.1.1"
          "d751e9e49156b02b44f9c1815bcb94b984cdcc4396ecc32521c739452808b134")
   (crate "derive_more-impl" "2.1.1"
          "799a97264921d8623a957f6c3b9011f3b5492f557bbb7a5a19b7fa6d06ba8dcb")
   (crate "digest" "0.10.7"
          "9ed9a281f7bc9b7576e61468ba615a66a5c8cfdff42420a70aa82701a3b1e292")
   (crate "dirs" "7.0.0"
          "8d57d423b3c82e89b9a24ca3091fee61f456a26edbd28d26c65906f4bc1dcd8f")
   (crate "dirs-sys" "0.5.0"
          "e01a3366d27ee9890022452ee61b2b63a67e6f13f58900b651ff5665f0bb1fab")
   (crate "document-features" "0.2.12"
          "d4b8a88685455ed29a21542a33abd9cb6510b6b129abadabdcef0f4c55bc8f61")
   (crate "either" "1.18.0"
          "252afb9ae5eaa683babdc6a068b3f5726eb19e05070c731f9b2a23a7c3e8ed34")
   (crate "equivalent" "1.0.2"
          "877a4ace8713b0bcf2a4e7eec82529c029f1d0619886d18145fea96c3ffe5c0f")
   (crate "errno" "0.3.14"
          "39cab71617ae0d63f51a36d69f866391735b51691dbda63cf6f96d042b63efeb")
   (crate "euclid" "0.22.14"
          "f1a05365e3b1c6d1650318537c7460c6923f1abdd272ad6842baa2b509957a06")
   (crate "fancy-regex" "0.11.0"
          "b95f7c0680e4142284cf8b22c14a476e87d61b004a3a0861872b32ef7ead40a2")
   (crate "filedescriptor" "0.8.3"
          "e40758ed24c9b2eeb76c35fb0aebc66c626084edd827e07e1552279814c6682d")
   (crate "finl_unicode" "1.4.0"
          "9844ddc3a6e533d62bba727eb6c28b5d360921d5175e9ff0f1e621a5c590a4d5")
   (crate "fixedbitset" "0.4.2"
          "0ce7134b9999ecaf8bcd65542e436736ef32ddca1b3e06094cb6ec5755203b80")
   (crate "flate2" "1.1.10"
          "6e634e2e0ebac1ee034020da1ca582e17ffe4e0f5e985823721e168928136dcb")
   (crate "fnv" "1.0.7"
          "3f9eec918d3f24069decb9af1554cad7c880e2da24a9afd88aca000531ab82c1")
   (crate "foldhash" "0.2.0"
          "77ce24cb58228fbb8aa041425bb1050850ac19177686ea6e0f41a70416f56fdb")
   (crate "form_urlencoded" "1.2.2"
          "cb4cb245038516f5f85277875cdaa4f7d2c9a0fa0468de06ed190163b1581fcf")
   (crate "futures-channel" "0.3.34"
          "b1f9e3d69d39e4862ffed03ed071a76f9a13ba1d9109d355b0f0aa6b15e393c4")
   (crate "futures-core" "0.3.34"
          "92d699e522242e69e3003b94ecc1f960f3a5e015aa7c5d7486e65ad01dd94f5e")
   (crate "futures-task" "0.3.34"
          "cd417de3d1d015fc3bfd2b1ea46dfc7bab72ef86f1cc7cc9c78e728b34a6d1fd")
   (crate "futures-util" "0.3.34"
          "0d50a92467f8ba5dd6e3ee5d4bd04d73ab2e4e1c44474a0674821dfce14b79bc")
   (crate "generic-array" "0.14.7"
          "85649ca51fd72272d7821adaf274ad91c288277713d9c18820d8499a7ff69e9a")
   (crate "getrandom" "0.3.4"
          "899def5c37c4fd7b2664648c28120ecec138e4d395b459e5ca34f9cce2dd77fd")
   (crate "getrandom" "0.4.3"
          "300e883d756b2e4ec94e02791f39b04b522276138852cfc41d9fb7e904106099")
   (crate "hashbrown" "0.16.1"
          "841d1cc9bed7f9236f321df977030373f4a4163ae1a7dbfe1a51a2c1a51d9100")
   (crate "hashbrown" "0.17.1"
          "ed5909b6e89a2db4456e54cd5f673791d7eca6732202bbf2a9cc504fe2f9b84a")
   (crate "heck" "0.5.0"
          "2304e00983f87ffb38b55b444b5e3b60a884b5d30c0fca7d82fe33449bbe55ea")
   (crate "hex" "0.4.3"
          "7f24254aa9a54b5c858eaee2f5bccdb46aaf0e486a595ed5fd8f86ba55232a70")
   (crate "http" "1.5.0"
          "918d3568bebf352712bc2ef3d46a8bcf1a75b373be6539de198e9105cbbf9ce0")
   (crate "http-body" "1.1.0"
          "ca2a8f2913ee65f60facd6a5905613afaa448497a0230cc41ce022d93290bc2c")
   (crate "http-body-util" "0.1.5"
          "23169fe34a5fbcdd3f3862e78fb9b6fccd5f02a6dc6f732547005d45631ce71c")
   (crate "httparse" "1.10.1"
          "6dbf3de79e51f3d586ab4cb9d5c3e2c14aa28ed23d180cf89b4df0454a69cc87")
   (crate "httpdate" "1.0.3"
          "df3b46402a9d5adb4c86a0cf463f42e19994e3ee891101b1841f30a545cb49a9")
   (crate "hyper" "1.11.1"
          "27b501faa50e7a26c3d3560ca625132f4078a17771f4810baf70475ae48cbe43")
   (crate "hyper-util" "0.1.20"
          "96547c2556ec9d12fb1578c4eaf448b04993e7fb79cbaad930a656880a6bdfa0")
   (crate "ident_case" "1.0.1"
          "b9e0384b61958566e926dc50660321d12159025e767c18e043daf26b70104c39")
   (crate "indoc" "2.0.7"
          "79cf5c93f93228cf8efb3ba362535fb11199ac548a09ce117c9b1adc3030d706")
   (crate "instability" "0.3.13"
          "2bf84e73fa6f27f299dec58e13223cf70db80da872eb921d4f6138342a0eabc8")
   (crate "is_terminal_polyfill" "1.70.2"
          "a6cb138bb79a146c1bd460005623e142ef0181e3d0219cb493e02f7d08a35695")
   (crate "itertools" "0.14.0"
          "2b192c782037fadd9cfa75548310488aabdbf3d2da73885b31bd0abd03351285")
   (crate "itoa" "1.0.18"
          "8f42a60cbdf9a97f5d2305f08a87dc4e09308d1276d28c869c684d7777685682")
   (crate "js-sys" "0.3.105"
          "ce57d20d1ea864ce2ac172ab472d409214f4fd359f0b2a2775abdf522e2af99e")
   (crate "kasuari" "0.4.12"
          "bde5057d6143cc94e861d90f591b9303d6716c6b9602309150bd068853c10899")
   (crate "lab" "0.11.0"
          "bf36173d4167ed999940f804952e6b08197cae5ad5d572eb4db150ce8ad5d58f")
   (crate "lazy_static" "1.5.0"
          "bbd2bcb4c963f2ddae06a2efc7e9f3591312473c50c6685e1f298068316e66fe")
   (crate "libc" "0.2.189"
          "3eaf3ede3fee6db1a4c2ee091bf8a8b4dccdc6d17f656fb07896ee72867612f2")
   (crate "libm" "0.2.16"
          "b6d2cec3eae94f9f509c767b45932f1ada8350c4bdb85af2fcab4a3c14807981")
   (crate "libredox" "0.1.24"
          "6480ccc157a1389bb2e4891b24751b0f798ba640d22386f23143fbcc89da195a")
   (crate "line-clipping" "0.3.8"
          "e752191d037c44ad111a8caa762921926658402f01cc1253f7bef2020ece4f5e")
   (crate "linux-raw-sys" "0.12.1"
          "32a66949e030da00e8c7d4434b251670a91556f4144941d37452769c25d58a53")
   (crate "litrs" "1.0.0"
          "11d3d7f243d5c5a8b9bb5d6dd2b1602c0cb0b9db1621bafc7ed66e35ff9fe092")
   (crate "lock_api" "0.4.14"
          "224399e74b87b5f3557511d98dff8b14089b3dadafcab6bb93eab67d3aace965")
   (crate "log" "0.4.34"
          "f9f8bd3e56ce4dfc153cf470fffbfa98c7620958b312ca5c3a4b8d5181fd13c6")
   (crate "lru" "0.18.4"
          "ff9840bcc50b71349309900da0ce7279aa336ae71d73250b07998932c7d97c25")
   (crate "mac_address" "1.1.8"
          "c0aeb26bf5e836cc1c341c8106051b573f1766dfa05aa87f0b98be5e51b02303")
   (crate "matchit" "0.8.4"
          "47e1ffaa40ddd1f3ed91f717a33c8c0ee23fff369e3aa8772b9605cc1d22f4c3")
   (crate "memchr" "2.8.3"
          "cf8baf1c55e62ffcace7a9f06f4bd9cd3f0c4beb022d3b367256b91b87513d98")
   (crate "memmem" "0.1.1"
          "a64a92489e2744ce060c349162be1c5f33c6969234104dbd99ddb5feb08b8c15")
   (crate "memoffset" "0.9.1"
          "488016bfae457b036d996092f6cb448677611ce4449e970ceaf42695203f218a")
   (crate "mime" "0.3.17"
          "6877bb514081ee2a7ff5ef9de3281f14a4dd4bceac4c09388074a6b5df8a139a")
   (crate "minimal-lexical" "0.2.1"
          "68354c5c6bd36d73ff3feceb05efa59b6acb7626617f4962be322a825e61f79a")
   (crate "miniz_oxide" "0.9.1"
          "b63fbc4a50860e98e7b2aa7804ded1db5cbc3aff9193adaff57a6931bf7c4b4c")
   (crate "mio" "1.2.3"
          "4b18443e9c262bfe8fa82f51666e2642c53393f7e5c27b3e1aeab922cff5b9d8")
   (crate "nix" "0.29.0"
          "71e2746dc3a24dd78b3cfcb7be93368c6de9963d30f43a6a73998a9cf4b17b46")
   (crate "nom" "7.1.3"
          "d273983c5a657a70a3e8f2a01329822f3b8c8172b73826411a55751e404a0a4a")
   (crate "nucleo-matcher" "0.3.1"
          "bf33f538733d1a5a3494b836ba913207f14d9d4a1d3cd67030c5061bdd2cac85")
   (crate "num-conv" "0.2.2"
          "521739c6d2bac4aa25192232afe6841231376b2b26d4d9fae5ecf8ca5772e441")
   (crate "num-derive" "0.4.2"
          "ed3955f1a9c7c0c15e092f9c887db08b1fc683305fdf6eb6684f22555355e202")
   (crate "num-traits" "0.2.19"
          "071dfc062690e90b734c0b2273ce72ad0ffa95f0c74596bc250dcfd960262841")
   (crate "num_threads" "0.1.7"
          "5c7398b9c8b70908f6371f47ed36737907c87c52af34c268fed0bf0ceb92ead9")
   (crate "once_cell" "1.21.4"
          "9f7c3e4beb33f85d45ae3e3a1792185706c8e16d043238c593331cc7cd313b50")
   (crate "once_cell_polyfill" "1.70.2"
          "384b8ab6d37215f3c5301a95a4accb5d64aa607f1fcb26a11b5303878451b4fe")
   (crate "option-ext" "0.2.0"
          "04744f49eae99ab78e0d5c0b603ab218f515ea8cfe5a456d7629ad883a3b6e7d")
   (crate "ordered-float" "4.6.0"
          "7bb71e1b3fa6ca1c61f383464aaf2bb0e2f8e772a1f01d486832464de363b951")
   (crate "palette" "0.7.7"
          "ddeed8580d347d2abf3dcf06a5f0b3dc020258338526b277847cd4248a70fc64")
   (crate "palette_derive" "0.7.7"
          "88537020289b719d81be994ccf1bbf4990f477e2f69ee52fe3e45f43a02e56be")
   (crate "palette_math" "0.7.7"
          "6e6eb142958d64335fb0e345c5b9ead2ecd6fc438c307e9d7d3c4fd428dbaf12")
   (crate "parking_lot" "0.12.5"
          "93857453250e3077bd71ff98b6a65ea6621a19bb0f559a85248955ac12c45a1a")
   (crate "parking_lot_core" "0.9.12"
          "2621685985a2ebf1c516881c026032ac7deafcda1a2c9b7850dc81e3dfcb64c1")
   (crate "percent-encoding" "2.3.2"
          "9b4f627cb1b25917193a259e49bdad08f671f8d9708acfd5fe0a8c1455d87220")
   (crate "pest" "2.9.1"
          "6d45aeb61b4bf818e12d4205f2466f8c4748f85f4fce0146d1c03d69d753f0ad")
   (crate "pest_derive" "2.9.1"
          "89cc5a242e25ed4e7704d0be240f2cfbe20a8c27e7e252d94835be93d92dc39f")
   (crate "pest_generator" "2.9.1"
          "7abf21475cc3820fe4b2ca2dc2142902f67a02189f3b5b3a229f4febc01a43e5")
   (crate "pest_meta" "2.9.1"
          "adba4db388f687393c18c51348d44a41d870ca9df71a2c98172ea3035dc6936e")
   (crate "phf" "0.11.3"
          "1fd6780a80ae0c52cc120a26a1a42c1ae51b247a253e4e06113d23d2c2edd078")
   (crate "phf_codegen" "0.11.3"
          "aef8048c789fa5e851558d709946d6d79a8ff88c0440c587967f8e94bfb1216a")
   (crate "phf_generator" "0.11.3"
          "3c80231409c20246a13fddb31776fb942c38553c51e871f8cbd687a4cfb5843d")
   (crate "phf_macros" "0.11.3"
          "f84ac04429c13a7ff43785d75ad27569f2951ce0ffd30a3321230db2fc727216")
   (crate "phf_shared" "0.11.3"
          "67eabc2ef2a60eb7faa00097bd1ffdb5bd28e62bf39990626a582201b7a754e5")
   (crate "pin-project-lite" "0.2.17"
          "a89322df9ebe1c1578d689c92318e070967d1042b512afbe49518723f4e6d5cd")
   (crate "portable-atomic" "1.15.0"
          "05c8b63e8d9609db387f0324918f81d68fe27748f084ef092fb35954d0539a85")
   (crate "powerfmt" "0.2.0"
          "439ee305def115ba05938db6eb1644ff94165c5ab5e9420d1c1bcedbba909391")
   (crate "proc-macro2" "1.0.107"
          "985e7ec9bb745e6ce6535b544d84d6cd6f7ad8bd711c398938ae983b91a766d9")
   (crate "quote" "1.0.47"
          "1fbf4db142a473a8d80c26bbf18454ed458bf8d26c8219c331daecfdbd079001")
   (crate "r-efi" "5.3.0"
          "69cdb34c158ceb288df11e18b4bd39de994f6657d83847bdffdbd7f346754b0f")
   (crate "r-efi" "6.0.0"
          "f8dcc9c7d52a811697d2151c701e0d08956f92b0e24136cf4cf27b57a6a0d9bf")
   (crate "rand" "0.8.8"
          "e058c7de0b26af77780c769414d6257830bb240f3c38477dbc2c16e5f54d6d4c")
   (crate "rand_core" "0.6.4"
          "ec0be4795e2f6a28069bec0b5ff3e2ac9bafc99e6a9a7dc3547996c5c816922c")
   (crate "ratatui" "0.30.2"
          "3274ba0a2c5e1bcad2a2005d20f4dc59dad26b2eb0940fb094500dba4099d57d")
   (crate "ratatui-core" "0.1.2"
          "cbb175c433c8e28a809d1f5773a2ae96e68c0ce40db865cbab1020bf33ae479c")
   (crate "ratatui-crossterm" "0.1.2"
          "567584a3b0e6a8203c23de40b4861497266725eb5363dbfd18a1edd603cca9f0")
   (crate "ratatui-macros" "0.7.2"
          "ed7dc68daa7498a43e4d68e0eb078427e10c38fbcfbb1e42d955f1fa2140d814")
   (crate "ratatui-termina" "0.1.0"
          "c0bf912d9e66f057a759d92e386a280ea886b352ab757d6ac4d653c7ed2c43c2")
   (crate "ratatui-termwiz" "0.1.2"
          "faf03e0380b7744054d6cb74224fe3adf062a029754933f575ca1e3b4c2ce977")
   (crate "ratatui-widgets" "0.3.2"
          "66e3d19bcc9130ca376277d93b60767ff121ace3be06f5f95f81dd68956407d1")
   (crate "redox_syscall" "0.5.18"
          "ed2bf2547551a7053d6fdfafda3f938979645c44812fbfcda098faae3f1a362d")
   (crate "redox_users" "0.5.3"
          "60dc65c0ff1a7ae1294b0c67b9f14baf70b644404010370171787bfac1038fc0")
   (crate "regex" "1.13.1"
          "f020237b6c8eed93db2e2cb53c00c60a8e1bc73da7d073199a1180401450218d")
   (crate "regex-automata" "0.4.18"
          "ad8553b9b26413251cbf30e620595c7a41b3887f03da04579c0e6b0d6a06b4b2")
   (crate "regex-syntax" "0.8.11"
          "d6f6ff9a378485b298a5286656da665ba74413d36db0979633275d2e708145d4")
   (crate "rustc_version" "0.4.1"
          "cfcb3a22ef46e85b45de6ee7e79d063319ebb6594faafcf1c225ea92ab6e9b92")
   (crate "rustix" "1.1.5"
          "891efababe418670775f199f0d233d84843c227a0949a883ce15b37c78d6629d")
   (crate "rustversion" "1.0.23"
          "cf54715a573b99ac80df0bc206da022bcd442c974952c7b9720069370852e21f")
   (crate "ryu" "1.0.23"
          "9774ba4a74de5f7b1c1451ed6cd5285a32eddb5cccb8cc655a4e50009e06477f")
   (crate "scopeguard" "1.2.0"
          "94143f37725109f92c262ed2cf5e59bce7498c01bcc1502d7b9afe439a4e9f49")
   (crate "semver" "1.0.28"
          "8a7852d02fc848982e0c167ef163aaff9cd91dc640ba85e263cb1ce46fae51cd")
   (crate "serde" "1.0.229"
          "4148590afebada386688f18773da617792bf2ef03ffc1e4cbd2b1d45b023e0ba")
   (crate "serde_core" "1.0.229"
          "67dca2c9c51e58a4791a4b1ed58308b39c64224d349a935ab5039aa360942a48")
   (crate "serde_derive" "1.0.229"
          "e7a5d71263a5a7d47b41f6b3f06ba276f10cc18b0931f1799f710578e2309348")
   (crate "serde_json" "1.0.151"
          "c841b55ecdae098c80dcae9cf767f6f8a0c2cdb3416bbef72181df4d0fe73f14")
   (crate "serde_path_to_error" "0.1.20"
          "10a9ff822e371bb5403e391ecd83e182e0e77ba7f6fe0160b795797109d1b457")
   (crate "serde_urlencoded" "0.7.1"
          "d3491c14715ca2294c4d6a88f15e84739788c1d030eed8c110436aafdaa2f3fd")
   (crate "sha2" "0.10.9"
          "a7507d819769d01a365ab707794a4084392c824f54a7a6a7862f8c3d0892b283")
   (crate "signal-hook" "0.3.18"
          "d881a16cf4426aa584979d30bd82cb33429027e42122b169753d6ef1085ed6e2")
   (crate "signal-hook-mio" "0.2.5"
          "b75a19a7a740b25bc7944bdee6172368f988763b744e3d4dfe753f6b4ece40cc")
   (crate "signal-hook-registry" "1.4.8"
          "c4db69cba1110affc0e9f7bcd48bbf87b3f4fc7c61fc9155afd4c469eb3d6c1b")
   (crate "simd-adler32" "0.3.10"
          "3a219298ac11a56ea9a6d2120044824d6f01aeb034955e7af7bc16858527deea")
   (crate "siphasher" "1.0.3"
          "8ee5873ec9cce0195efcb7a4e9507a04cd49aec9c83d0389df45b1ef7ba2e649")
   (crate "slab" "0.4.12"
          "0c790de23124f9ab44544d7ac05d60440adc586479ce501c1d6d7da3cd8c9cf5")
   (crate "smallvec" "1.16.1"
          "ba467056f1b547ed52077911161fc86985becbc60e8e1857c8a144dab0def891")
   (crate "socket2" "0.6.5"
          "c3d1e2c7f27f8d4cb10542a02c49005dbd6e93095799d6f3be745fae9f8fedd4")
   (crate "static_assertions" "1.1.0"
          "a2eb9349b6444b326872e140eb1cf5e7c522154d69e7a0ffb0fb81c06b37543f")
   (crate "strsim" "0.11.1"
          "7da8b5736845d9f2fcb837ea5d9e2628564b3b043a70948a3f0b778838c5fb4f")
   (crate "strum" "0.28.0"
          "9628de9b8791db39ceda2b119bbe13134770b56c138ec1d3af810d045c04f9bd")
   (crate "strum_macros" "0.28.0"
          "ab85eea0270ee17587ed4156089e10b9e6880ee688791d45a905f5b1ca36f664")
   (crate "syn" "1.0.109"
          "72b64191b275b66ffe2469e8af2c1cfe3bafa67b529ead792a6d0160888b4237")
   (crate "syn" "2.0.119"
          "872831b642d1a07999a962a351ed35b955ea2cfc8f3862091e2a240a84f17297")
   (crate "syn" "3.0.6"
          "8593e8e72159ed2257d083c7a454a85cbf854f37a0966d8d483aff8c8a3ebcee")
   (crate "sync_wrapper" "1.0.2"
          "0bf256ce5efdfa370213c1dabab5935a12e49f2c58d15e9eac2870d3b4f27263")
   (crate "termina" "0.3.3"
          "9048a889effe34a5cddee0af7f53285198b16dca3be510858d38dfdb3e62a04e")
   (crate "terminfo" "0.9.0"
          "d4ea810f0692f9f51b382fff5893887bb4580f5fa246fde546e0b13e7fcee662")
   (crate "termios" "0.3.3"
          "411c5bf740737c7918b8b1fe232dca4dc9f8e754b8ad5e20966814001ed0ac6b")
   (crate "termwiz" "0.23.3"
          "4676b37242ccbd1aabf56edb093a4827dc49086c0ffd764a5705899e0f35f8f7")
   (crate "thiserror" "1.0.69"
          "b6aaf5339b578ea85b50e080feb250a3e8ae8cfcdff9a461c9ec2904bc923f52")
   (crate "thiserror" "2.0.20"
          "ec86235f5fcc2a73650310756d2ac5b138a5780bbbdfae3eeccec992c435ba4f")
   (crate "thiserror-impl" "1.0.69"
          "4fee6c4efc90059e10f81e6d42c60a18f76588c3d74cb83a0b242a2b6c7504c1")
   (crate "thiserror-impl" "2.0.20"
          "bc04cd3e1236dd4a98afca4569f2deb3f120e5422a4023be2cb683f8486292af")
   (crate "time" "0.3.55"
          "cdb87b95ec50ddfa440816d227a17b2ccbdda963a316a727fda0fc4334f7d134")
   (crate "time-core" "0.1.9"
          "9e1c906769ad99c88eaa54e728060edef082f8e358ff32030cb7c7d315e81109")
   (crate "tokio" "1.53.1"
          "202caea871b69668250d242070849eb495be178ed697a3e98aebce5bc81a0bed")
   (crate "tokio-macros" "2.7.2"
          "78773a2a397f451582ce068015985c33193cf6dea8b74d2a639fe457b2f07b0e")
   (crate "tower" "0.5.3"
          "ebe5ef63511595f1344e2d5cfa636d973292adc0eec1f0ad45fae9f0851ab1d4")
   (crate "tower-layer" "0.3.3"
          "121c2a6cda46980bb0fcd1647ffaf6cd3fc79a013de288782836f6df9c48780e")
   (crate "tower-service" "0.3.3"
          "8df9b6e13f2d32c91b9bd719c00d1958837bc7dec474d94952798cc8e69eeec3")
   (crate "tracing" "0.1.44"
          "63e71662fa4b2a2c3a26f570f037eb95bb1f85397f3cd8076caed2f026a6d100")
   (crate "tracing-core" "0.1.36"
          "db97caf9d906fbde555dd62fa95ddba9eecfd14cb388e4f491a66d74cd5fb79a")
   (crate "typenum" "1.20.1"
          "b6f5e870be6c3b371b77fe0ee0bafb859fa4964b4404c27de1d380043c4dda20")
   (crate "ucd-trie" "0.1.7"
          "2896d95c02a80c6d6a5d6e953d479f5ddf2dfdb6a244441010e373ac0fb88971")
   (crate "unicode-ident" "1.0.26"
          "d245f478577f809a851594d02313b640fb437e0bb33866753cff937863096954")
   (crate "unicode-segmentation" "1.13.3"
          "c6f5d3c3b1bf09027a88a6bc961fc00497d651009560b5463668dc81b0fa87a8")
   (crate "unicode-truncate" "2.0.1"
          "16b380a1238663e5f8a691f9039c73e1cdae598a30e9855f541d29b08b53e9a5")
   (crate "unicode-width" "0.2.2"
          "b4ac048d71ede7ee76d585517add45da530660ef4390e49b098733c6e897f254")
   (crate "utf8parse" "0.2.2"
          "06abde3611657adf66d383f00b093d7faecc7fa57071cce2578660c9f1010821")
   (crate "uuid" "1.26.1"
          "2ef6dac1e96601b4fb3acccccff2139741fcb757cb9a36089bf5be91cfb285ce")
   (crate "version_check" "0.9.5"
          "0b928f33d975fc6ad9f86c8f283853ad26bdd5b10b7f1542aa2fa15e2289105a")
   (crate "vtparse" "0.6.2"
          "6d9b2acfb050df409c972a37d3b8e08cdea3bddb0c09db9d53137e504cfabed0")
   (crate "wasi" "0.11.1+wasi-snapshot-preview1"
          "ccf3ec651a847eb01de73ccad15eb7d99f80485de043efb2f370cd654f4ea44b")
   (crate "wasip2" "1.0.4+wasi-0.2.12"
          "b67efb37e106e55ce722a510d6b5f9c17f083e5fc79afc2badeb12cc313d9487")
   (crate "wasm-bindgen" "0.2.128"
          "aecb87a33d3b0c5e3b7aa46336eaf486cffafbd281b195e4c8b80d50df2351bf")
   (crate "wasm-bindgen-macro" "0.2.128"
          "a690d511e3c1a8b3a55e33511e3c2c00c78415cd23650f32b808627f5696b9ed")
   (crate "wasm-bindgen-macro-support" "0.2.128"
          "411e4887f0071ef2d2164a9d5fdf2d20efbef78fccd3a78b0c10a1dc5295e48a")
   (crate "wasm-bindgen-shared" "0.2.128"
          "81941cd78d0c92026c33e5e01312845a4cb1e9af3407f9134b100dd03144103e")
   (crate "wezterm-bidi" "0.2.3"
          "0c0a6e355560527dd2d1cf7890652f4f09bb3433b6aadade4c9b5ed76de5f3ec")
   (crate "wezterm-blob-leases" "0.1.1"
          "692daff6d93d94e29e4114544ef6d5c942a7ed998b37abdc19b17136ea428eb7")
   (crate "wezterm-color-types" "0.3.0"
          "7de81ef35c9010270d63772bebef2f2d6d1f2d20a983d27505ac850b8c4b4296")
   (crate "wezterm-dynamic" "0.2.1"
          "5f2ab60e120fd6eaa68d9567f3226e876684639d22a4219b313ff69ec0ccd5ac")
   (crate "wezterm-dynamic-derive" "0.1.1"
          "46c0cf2d539c645b448eaffec9ec494b8b19bd5077d9e58cb1ae7efece8d575b")
   (crate "wezterm-input-types" "0.1.0"
          "7012add459f951456ec9d6c7e6fc340b1ce15d6fc9629f8c42853412c029e57e")
   (crate "winapi" "0.3.9"
          "5c839a674fcd7a98952e593242ea400abe93992746761e38641405d28b00f419")
   (crate "winapi-i686-pc-windows-gnu" "0.4.0"
          "ac3b87c63620426dd9b991e5ce0329eff545bccbbb34f3be09ff6fb6ab51b7b6")
   (crate "winapi-x86_64-pc-windows-gnu" "0.4.0"
          "712e227841d057c1ee1cd2fb22fa7e5a5461ae8e48fa2ca79ec42cfc1931183f")
   (crate "windows-link" "0.2.1"
          "f0805222e57f7521d6a62e36fa9163bc891acd422f971defe97d64e70d0a4fe5")
   (crate "windows-sys" "0.61.2"
          "ae137229bcbd6cdf0f7b80a31df61766145077ddf49416a728b02cb3921ff3fc")
   (crate "wit-bindgen" "0.57.1"
          "1ebf944e87a7c253233ad6766e082e3cd714b5d03812acc24c318f549614536e")
   (crate "zlib-rs" "0.6.8"
          "b268e58e7c693d7c271f93ffc4ba3b380412554231c85bf61ca7af91042a4112")
   (crate "zmij" "1.0.23"
          "29666d0abbfad1e3dc4dcf6144730dd3a3ab225bbbdac83319345b1b44ccfc1b")))
