;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>

(define-module (securityops packages phive)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix base16)
  #:use-module (guix gexp)
  #:use-module (guix build-system trivial)
  #:use-module (gnu packages backup)
  #:use-module (securityops packages autofirma)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1)
  #:use-module ((guix licenses) #:prefix license:))

(define %java (@@ (securityops packages autofirma) temurin17-runtime))

;; Effective release POM runtime closure, including the reference JAXB provider.
;; Fields: group, artifact, version, classifier, JAR/POM/source SHA256 hex.
;; XMLresolver's data JAR contains original XML/DTD source, not compiled code.
(define %runtime-artifacts
  '(
    ("com.helger.phive" "phive-api" "12.2.0" "" "25e9ace5ea6a56bd32d8c67ee644b1a335d92306ae19833a1830a3ff92ebbe30" "cf1f2ece8a2524aae00cecbd905555e731b565cfb41cd8f5fd5ffcf5ced057bf" "3a12da5645f5f39bf65a71541c42188e93110870c5e00c9226f76ced9a9daa50")
    ("com.helger.phive" "phive-xml-source" "12.2.0" "" "8601f8eb6a818a509a93bc730c57f7801755b0930f23d3c959be81b5f60d2205" "ded56caea14e59e8351d29b4d68b3c761e108fba96e82edc6a1d1c1d03f15658" "733668bc6b467445901ea5f0e192fc64d0396de4e7af4691d4ff71b0edf6596f")
    ("com.helger.phive" "phive-ves-model" "12.2.0" "" "431c3b7a50325261682b88d1be42a1091c4765a2b48c8bcabe8841aa074a90c5" "c9644ab8be54fbc9cef9ad2d83ac93c695ad285a110b42a356ac686cf10cb1c6" "4bd0685e38d50ee91862ce6e92f27edaf07e32e3131b986883480b9089ec6b7b")
    ("com.helger.phive" "phive-ves-repo" "12.2.0" "" "911d916d8b18399cccddc0dc8fdf7fb81ad88531720486d861cfe1a924c8ce08" "debbbcbde4eb1dc9977a093916700f4f8de85f5f9558098bc3bdf2328e85ee55" "005c2523309bb1f939d617bcbdcd694a7bd64e368332b82b1fee1dd111577211")
    ("com.helger.phive" "phive-xml" "12.2.0" "" "f725ab7027678fafadec365bb9ed9bc2d87ac8fa2964c917afd0dd54b726e613" "b4e7f48104e471c17fb02022227ab0107ea2f7b4959de2ed8b5cd5f2fccebecc" "d3ce00fc62dda0c106489384db1decd40ee1b42128e1576c294efab5f7baed40")
    ("com.helger.phive" "phive-result" "12.2.0" "" "7e4d6c3f7a86dfefe0d6cadbe7d4d39177afc964dd37ac3a49d3edb5b7efe42f" "722e98c75cad6a8c94dc9b33cf8e44874964f7adcca227b942da470ee4c7226d" "1e7907081412ea472465b01ec862422a6032a74dac3326071bfb2ce0cc5b801b")
    ("com.helger.phive" "phive-result-html" "12.2.0" "" "2f42727c6e5e685ba078d49151fe68b0ad839d971999046453b51318e427c229" "afa952cc8ebf3afdbe83d0efb58605f322332b3ae4d3450be41a77c600caaebc" "f57c202ec6dab66bd125642ea4e8c5b3b51efec9face2b0980a4a5e4193adb45")
    ("com.helger.phive" "phive-ves-engine" "12.2.0" "" "7af08a52c43b072fcbb2760ff4a2bb1a254d112c87aea1289cd5f305ce0e8765" "83dfd083a62943dc66b660fb408829ded6cc9bf1a31183c0e7edbfa4a4b5a746" "c2aa6131c10ee3714cd6756f3d5b62771e07912a18c8bd204e104a56554e4614")
    ("org.slf4j" "slf4j-api" "2.0.18" "" "44508fd1576500688c790b190acdd16fec4f8c79a3e0b900afd70503cf055f55" "6c2c7f2c02774cc2b7b619fbd2df7873cdad29718926e44754b87f70d1eb43cb" "192e007cf7f2be41d40574e44521fc0b7ce55e01f13dbe0fa8707c8ae3329075")
    ("com.helger.commons" "ph-io" "12.5.0" "" "32f939c64fd119e6450e30afa3ba32289bbca83402501214f6b641b68b4c423f" "f912889e7d24fc7886102952f2100675af785383ad520ec3eea26fc6d4e3fb2f" "9769c42ea6da9a26c6513bb69b0721b60deb462ed1ea38676bf17f9427656c46")
    ("com.helger.commons" "ph-diagnostics" "12.5.0" "" "f119612fe088610ef8463d44e30a7cea631568c2d5d9b5361efd9f5419403c58" "a88aec39183f4088e7ada78ce32aaf0cc89ed45460f2cf1166f593bdc3f389f6" "7de9b0cf89c3e8172cb60c811e2c07d7713b4f7aba5503b0bceaa9d89ec0808d")
    ("com.helger.commons" "ph-datetime" "12.5.0" "" "70db55548f93a365134271cce8ee57a2681b3008f498696d46971e0362d11a08" "556134b41984f0625636aaf063c3680aab65bde9b3e2f426f4fb5f03a5a8039c" "9161af1f2c7b9953037116b728b4c4db03ab9b2804bf8cfc37055cad7a0ffcc3")
    ("com.helger.diver" "ph-diver-api" "4.2.2" "" "80b0dc5458d0d384add792e6161a0786c86b98d5cdd1d899a701a02903e84794" "69ca06094374cee0c4310cf97ef8bca3acf162a08fe97997f5801f87e23e6d8f" "f63ebbc574a71f63306bafd1c74ba6cb61798beeeca4ef0488d68dc580a6f0a3")
    ("com.helger.schematron" "ph-schematron-api" "10.2.0" "" "348d544b0c66acd700fbda44ef41494d3faf3e26314ecdb63cdbb36583fa4807" "97664ecf1c6661d4661101183d84b39e257041c35f8bca093dae481d8d4e41f8" "a193c7519a38310de4fcb2aaa3955c232f0d3d9806362792299bde6525176a11")
    ("com.helger.commons" "ph-xml" "12.5.0" "" "f8315bd0b188aef18dfdf0da3122ba39ffd9c547e267a75f9c259f9cffdebe95" "69ffa85eb68e96c5834e5aa234fc74b6d1544ec54b1f6d4ba1ca50c9e99809a6" "8e5e0f2a9e006f5cf510b1a802df8315e9c725bc7761478c78c9cc376d3b3c9d")
    ("com.helger.commons" "ph-jaxb" "12.5.0" "" "012f7d96a6a9b15793f0d7846db57e52901f9cd615942e8dd15c9c92bfc461af" "4bd29bc12f953392b0d1f59368f0b95bf18a4f8ff54f29962a2971f2c22a8e07" "36e2d4adfe7a119098b1757e69ad73822662f495daffe97316d730d2432c0a22")
    ("com.helger.commons" "ph-jaxb-adapter" "12.5.0" "" "d6a0da60a8c1fb29904db8e2d2d05d6e879cb53e212749a8bad121c4bbd35b8e" "3fae6da681e778b3881508f7fe57f4f1d565115391ade2cd623bdd274aa3bfd7" "e72548d355e0fee4dbd844ead5049198fa97855add38780ea50af52d83a2912d")
    ("com.sun.xml.bind" "jaxb-impl" "4.0.9" "" "6ec4361ade0b7e0267ee4d1ef495928bf722570af25904e1618c9949b67fdd86" "b7f6c41e0e1f396074fc925ce5f1318dc0e3ecbb8cb57ef6bbaf9db0e954f189" "9455837530e76331ac94468a1fe38c139e5aed0075275c72e3654b4ed3946179")
    ("com.helger.commons" "ph-csv" "12.5.0" "" "8f2ac78c81ad992b9ae5f577c2e9f12225bea46943dd41d4f2c5ed455edb96ed" "f5fd2690298181eb60b623df14442cf0c93ecaa9f5428f60b98013b62e03c192" "066555e94a784ec769fe03e1f28a97a16833fb2f970c8460c475973ba28dc80c")
    ("com.helger.diver" "ph-diver-repo" "4.2.2" "" "acc5bbfcb653605859d60fa4b2051facb7569273902798df68120f222d9b9ac6" "e85a77a8fd58a2ceb093cc2c6fe888f0873e27dca88ffaa170f23d785f0c3aba" "f55d2ad314d1f2e04076935a4cbd01dcfd0307c0005fc0d775dbf53df09e13f0")
    ("com.helger.schematron" "ph-schematron-xslt" "10.2.0" "" "3f0efffd8d884b2454e91ad3a0fb8644bac41e8eeb28d23e675676db63958f64" "55b89439a6a3ac90f3c03803b6eec060a09d4c02fab637b935447ea84e5f2fc2" "81e04ca4f9b5963e063e53edeb8d608a26989e11f176b1ea970b98ac6e738102")
    ("com.helger.schematron" "ph-schematron-isosch" "10.2.0" "" "b4c2c1455be2ad7a6e9ad13c6d818f2d60d967959f8f1e527219bff618da4f5a" "ee8775a8fd0ea78c7355ccbd6f45d4a1e24e31a0cc1d6c0ba9a33d7556a2ab48" "4d3d7fe095840946628124f3063fda47a415213b11fca2fb4dd17d69ead645f8")
    ("com.helger.schematron" "ph-schematron-schxslt" "10.2.0" "" "d4773ad7a06ddada81f44c69efcdc7f66e3e117b4b1b5c28c7bf7bfd16b6aa8a" "89ce2074de0fcc9b84d1def7fbf433904bda1f519a9bcd37bc927f06fe93fcbb" "07edea6e26a5514f0deb9ab1ddb7dd2b2e8f3fa713d598cc207de3c2f7cd898d")
    ("com.helger.schematron" "ph-schematron-schxslt2" "10.2.0" "" "11e703a06e43a32e84643c279639b90823806adfc0da74378a7d58c430c5a084" "4335e1f994a3498bd410b27fd7cb5b0fcd9847da21f617ec93bdd705bdbd9639" "047cb90887b0ea1f9c67ef79a11e04b71082f6a0d61247cb3bc41c38cc8e9943")
    ("com.helger.schematron" "ph-schematron-pure" "10.2.0" "" "36c0c7dea4c284c57a6c5ff5e9c9c887f243f0a83584c70711865995a767b8af" "dd98e603d61c8b0e367fd5e5189205835c435d7e40c95fff0d797a290aff4dd3" "73da9bf0e6f116e39f5beb967bb28fd8cc03c7a9651d5607424aa53d2a6f1994")
    ("com.helger.commons" "ph-json" "12.5.0" "" "4c565cc7b9af436a7c8eb442092c6f28eed4719230ef91310c1f33aba63a55c2" "b8c5fb9e299bbf2b8181b5d6c6a2e5d236dcfd11866aea841c52917256869c2f" "5e8edaa8a7f8e8150de46d38decc49ef1a6d1dbb0bbd5dc66c0fa32f65c6b3fe")
    ("com.helger.commons" "ph-annotations" "12.5.0" "" "d9e05391c280d1614ffb6238bdaa508cd1af751a7980bac07126f66dff2e907f" "79a40e7201ac9154728f305470801d9565cfc17d2aeb6e44ca01dc0f9227e951" "f1989a7d2feed2893fc3d0e5e0676b99c6bc7e010d0f99e7836944fc0799625b")
    ("com.helger.commons" "ph-base" "12.5.0" "" "7fb87cd97dacd778d338555d5c8def166b9cafce0755e1d483541952435d41d5" "cf03599b41f8ed535c0732c0a179f7d95ca3e67dfc4bfceacc0e37638ecb9118" "ba90e747cd23659539493c73e47ad8ff7cadc7d61efe1abb3e5a75c8bd2216fa")
    ("com.helger.commons" "ph-typeconvert" "12.5.0" "" "cb3f9e02a2afdfded65a5818bd67f83ee94bb2561a8ff94bdff98685815e060c" "f0af007a20dcaa5ce5447f0db94674fee36b5120f6a73d1a7bb093ede38a788d" "88a894bd38ef4122112ab50222bc78f45afd5de819213a66e4c795f5b07793a9")
    ("com.helger.commons" "ph-collection" "12.5.0" "" "03eaf9ecb53e688a8cfd54470e35845fac27303d4158896a37bd1d9b0d37b39a" "8907861431998664ee8fdfe443af1611b19e4df99ba4309d634860e913ff71f3" "b027ebe20a5a996d3fb6577d8c9062f25af503ba898a7fe2c2fd0ba37b7aa2c8")
    ("com.helger.commons" "ph-statistics" "12.5.0" "" "c56e44f463123535d714cf105ed8470667b91fdf3a7d1ee8d637f962931605e6" "6caf9931391efc78754d6a8ff1449d11b2ae77d5cfe1cd9a1d14d1215212b60c" "b96c6eee452fd7d20e587bcc183e59d008b7423bd1463aa654e37805a6d92519")
    ("com.helger.commons" "ph-cache" "12.5.0" "" "bccf9bc1e2eaf0c62665f32745dc867cedb63fa706185204839d7dfec6247371" "ba00dc20bc5e83ed02d6690872abd828ef81c443bb08da2819e04fc8e559cb92" "179be3068ec8e48c59d8e45dec2930da1c0235375883576628e0cb9c31b53e78")
    ("com.helger.commons" "ph-text" "12.5.0" "" "724e2dcf80dbd4caebf730f27041dca21c43a5eda8920d01effa79c33013ed95" "c9731081506bad5ac155e22fb64fd66384c93de9d58b0b8c9aabbf74f0a114e5" "b6c36847eb086ea4445bc1fadbb35364d3e63cedfacbec3ac19ddbb17f2cbc3a")
    ("com.helger.xsd" "ph-xsds-xml" "4.1.0" "" "bb0b294bb1ab29632139eff15aeffc46321338bbab5e3b694c75d376266ec475" "ad58d883d4f560544504902830c0a2544a76e82ebbe126273ebf06247512354e" "73cb4f622c4bfdd46ff086a5e1343d957921344f77755f9bf08e318d4136c442")
    ("com.helger.telemetry" "ph-telemetry" "1.1.1" "" "2caad8781c57af317bae1758cdd34f7f939e0f3e873bfd1de88a9e3228ea3e66" "55dc7804b3286747d5835798f8b469d14adbf539afea20b3a71f6359e30050a1" "baab4d773cc6206b05f73df9499b2b0159fabe478a6d4eac121849e603a49915")
    ("com.helger.commons" "ph-mime" "12.5.0" "" "f20b4f102998497ef6ed6bb23de79be34e7c7eea93540af968b96edbdc826e2c" "817d795d613ddaed2aad2d4db614381a2161928f8dbba2181155842fdada8776" "4e5585b4f2c5b632cd7c70d5edcea2223928c91fd9e482c14aed245ed92b3198")
    ("jakarta.xml.bind" "jakarta.xml.bind-api" "4.0.5" "" "5e489b6c874c4119e003ff1403db523ee3a8959ec499f3de29e77245efccf216" "596f65494651b79eb589b2f579a5686fabcd5cbb68f2c928c1cf360341d68c16" "5bcf811e6719582ab2be21c84bc48f963ba377dfe1dae5ecb2673c1efa00e422")
    ("com.sun.xml.bind" "jaxb-core" "4.0.9" "" "209eb94452d89644380e398e4ac126974718eeb3aa94ed1786654837ebcd3097" "520b0778102fd2a95b6fcb0b69d5fd0dad72442c4aee23f89198aad01ad15ca5" "2eb7cb9377d388905d7b30f87a756acc0e3c571a0ac516642ca6806f4c2394c5")
    ("com.helger.commons" "ph-security" "12.5.0" "" "e38ad4dbbcaaab8b40f57e58ffbaaa083e26f2927642141cc32f718875c1570a" "90fd52cca2812b3200b5632b3f1711d01dc9159944ecd117fc2640e2094bf744" "5ec0cd2947c93b62527db083229eee65ce41d303abfcd333ab2e3b8242427116")
    ("com.helger.schematron" "ph-schematron-saxon" "10.2.0" "" "8acaf0ea74897541012f6fddf77f2c82af7c1b5926dc2e5742906dbbea2490ef" "7e9843d9f91936a886aaa0dee489dd02dab2fe8aecf0f1df42c5834a38f200af" "910e1c28238318df349d994a66c3503de1e4daef87d2718f551ff2be764da75c")
    ("name.dmaus.schxslt" "schxslt" "1.10.1" "" "4f4f21edab7b37f96ad59ae12a344d3510f1092ac46b6d81a4efa0120b73cb58" "f604267abd49760565bf39fd0033abb57b3bdeb0b3d78d26c5d1fee8cee092d2" "878e3cd41d8ad7fd5a3c42c3e9d1fed6d2cf2b19bd97614f5a2a2b146cda4150")
    ("name.dmaus.schxslt" "schxslt2" "1.11.2" "" "7dbddd901b044e4005912d2fd5524dbecfd1b5315c61c64c1fd8e4f1049ea476" "c8862f0cfc8d84da2bfe29ad5d352dd979d593a3e385bd5ca9db3ee19079a1f9" "5abb6b1808470eed61da03c9709935b86481fa55ee585f1723294e62cac20efd")
    ("com.helger.schematron" "ph-schematron-model" "10.2.0" "" "1cd5384719ecfeaccd96cd19c0bfa26384a216e1035d76db51fbb928d4f3427b" "81d03347fd5e7f543771d816fa9a2157148d627c36716e045c1f95176f45ce47" "391b9d347d7922e3d4f70a6e9abf08f1a3c7a650e1a666a41aaec995dc37596e")
    ("net.sf.saxon" "Saxon-HE" "12.10" "" "b571af282f25d7301059f788b9a149aab8b5cdc14ef3d212dc5425d3dcbb9a97" "bf33b6583a588dc68610db6b0db390967047093c14533bfbf118be81d7c37b8f" "967e316e399138d286941641826c5100d8d8400171d426a446fd36ca943b626b")
    ("org.jspecify" "jspecify" "1.0.1" "" "070d75f261fe4c5b8202508366715f7f2d4660f88c8ef7e6d3575e48c9683b66" "55b38bf1a7b1d8ea518cf2f4f3ae9aaa236e61bbf0b6bd31ffb49753a059dd5e" "230c491aac6d2a2b7e66b68d4331b1d2626f1bf3a372c33bbe2b077297e46c45")
    ("jakarta.activation" "jakarta.activation-api" "2.1.4" "" "c9db52100ce6c8aac95cc39075f95720d2e561b11f8051b81c121ad4effd7004" "7577970dc09f1131a4a42769e1771ed062f08d22f40da3041ff3e16d5b2fdea8" "2aa5a3ba55059b778a3b467269404d7ac3b9485ed4a23ad26d2e63aa769ec35f")
    ("org.eclipse.angus" "angus-activation" "2.0.3" "" "a6bd35c538cf90fff941ad6258c40c08fca0b5c9c3f536c657114f27ce0527a7" "35c9e16209b2721261354e8aea971626648ad9d4201d221bd96901d900372da0" "14f863e0d6536e104263ac35f759fa3098bf7c617b66add58a7b8a24e0d58cee")
    ("com.helger.commons" "ph-url" "12.5.0" "" "292b24cf45abc4b97eee2a6527a6ff96f07fff26e7387932ac20ff52f5a990a1" "8f87f4317a36cd7e8eab901da3f1e35b3f1696763c960fa024c6c8686d08c254" "d168e2cac9e88cde2ef2cfa4e166c6b42490bea04f4e18c7ac53ca4fbaaf1171")
    ("org.xmlresolver" "xmlresolver" "5.3.3" "" "1fe4d5b92f708dcdb82dbce12919e0171e6b5ca62c6dca6220483625098feb5f" "261ada76d9e6676008dcac377a4d4589749166b606559f59f2e45ea62d8b75ec" "97606e7622b51b0177436102446377468fbc871b7eac415bacd8b23c77bf7085")
    ("org.xmlresolver" "xmlresolver" "5.3.3" "data" "b0c487ad2f3e558be8d829c916d2458d10aca6a5bafa7a4d0524b70845e48a5c" "261ada76d9e6676008dcac377a4d4589749166b606559f59f2e45ea62d8b75ec" "b0c487ad2f3e558be8d829c916d2458d10aca6a5bafa7a4d0524b70845e48a5c")))

;; These are not on the public runtime classpath or propagated to consumers.
(define %test-artifacts
  '(
    ("junit" "junit" "4.13.2" "" "8e495b634469d64fb8acfa3495a065cbacc8a0fff55ce1e31007be4c16dc57d3" "569b6977ee4603c965c1c46c3058fa6e969291b0160eb6964dd092cd89eadd94" "34181df6482d40ea4c046b063cb53c7ffae94bdf1b1d62695bdf3adf9dea7e3a")
    ("org.slf4j" "slf4j-simple" "2.0.18" "" "8268bd018a5709b07209e0d8ca6221a37584ba1bc12ba985b8335a82c648bdd0" "3ee8e3f118c0cb8d43ee2c96d90d825c69d84923f49ae4a14d533a007024b999" "977f636bc90dc879c56cd6b6158abf0ee77a6f4619ab23342781a273b743786b")
    ("com.helger.commons" "ph-unittest-support-ext" "12.5.0" "" "51fa45be1540a94e47437914163a72491fdf19ae7d365fdf30c633d412261082" "55b64267cccfc8f1c5b8e3e34399af0dfd4fbb3624f0e8209f85921afc2c58e9" "f77b8f1b9b47f10fc3bee72514f47d008c4cf5c5e1d7ee50ea7bfa2dccfa7ca2")
    ("org.hamcrest" "hamcrest-core" "1.3" "" "66fdef91e9739348df7a096aa384a5685f4e875584cce89386a7a47251c4d8e9" "fde386a7905173a1b103de6ab820727584b50d0e32282e2797787c20a64ffa93" "e223d2d8fbafd66057a8848cc94222d63c3cedd652cc48eddc0ab5c39c0f84df")
    ("com.helger.commons" "ph-unittest-support" "12.5.0" "" "ad9756b71549240508ea800e769d6cce145bc7dff9421e83d8b9d5e6b456af7a" "0886285c93aa48a67523ac144403a21cc0742db9051d9d24f93e1c8cf77ca989" "285b41d9c5d6d7b248d7a6bfadbfda57c39c7d89ef1c406f2fa870ff82681485")))

(define (artifact-name entry kind)
  (match entry
    ((group artifact version classifier jar-hash pom-hash source-hash)
     (string-append artifact "-" version
       (cond ((eq? kind 'pom) ".pom")
             ((eq? kind 'source)
              (if (string=? classifier "data") "-data.jar" "-sources.jar"))
             (else (string-append
                    (if (string-null? classifier) ""
                        (string-append "-" classifier)) ".jar")))))))

(define (artifact-url entry kind)
  (match entry
    ((group artifact version . rest)
     (string-append "https://repo.maven.apache.org/maven2/"
       (string-map (lambda (char) (if (char=? char #\.) #\/ char)) group)
       "/" artifact "/" version "/" (artifact-name entry kind)))))

(define (pinned-file url name hash)
  (origin
    (method url-fetch)
    (uri url)
    (file-name name)
    (sha256 (base16-string->bytevector hash))))

(define (artifact-origin entry kind)
  (pinned-file (artifact-url entry kind) (artifact-name entry kind)
    (list-ref entry (case kind ((jar) 4) ((pom) 5) (else 6)))))

(define %supplements
  '(
    ("https://codeload.github.com/phax/phive/tar.gz/6df39cb01e7fb11a2353c424c7ef50561ea3c513" "phive-12.2.0-source.tar.gz" "4d4b634fc03ed953041f3dbc872302aef54a5cdcf70060b7884d72dd3f5c1932")
    ("https://codeberg.org/SchXslt/schxslt/archive/17f63a42c2d417206e1289cf767359c4fa047919.tar.gz" "schxslt-1.10.1-source.tar.gz" "da80a071b0799d2a299938830c183e14f6f601def4bcf8c93903f6cc578043a6")
    ("https://codeberg.org/SchXslt/schxslt2/archive/ed703cc4a353d8c97888171e3a5c78b76485867d.tar.gz" "schxslt2-1.11.2-source.tar.gz" "1efd046cfa67d3286963ef7f44993592af05138abcdf381aa4ef5618df70886f")
    ("https://github.com/Saxonica/Saxon-HE/releases/download/SaxonHE12-10/saxon12-10source.zip" "saxon12-10source.zip" "e6e217f0e53da0259f58f64f51d9edff2984fa2e65e9a5127c15b32cb6013b18")
    ("https://github.com/Saxonica/Saxon-HE/releases/download/SaxonHE12-10/SaxonHE12-10J.zip" "SaxonHE12-10J.zip" "1c7db9f726df835349c64edd631de0310eca31291100230064eba153f607b0be")
    ("https://raw.githubusercontent.com/jspecify/jspecify/v1.0.1/LICENSE" "phive-jspecify-license-1.0.1.txt" "cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30")
    ("https://codeload.github.com/xmlresolver/xmlresolver/tar.gz/5.3.3" "xmlresolver-5.3.3-source.tar.gz" "d3da9e5d2316caa92ff202f3d1d21a6d66593dde82ccc5717743b72f704f4da5")))

(define %supplement-origins
  (map (lambda (entry) (apply pinned-file entry)) %supplements))

(define %w3c-software-and-document
  (license:license "W3C Software and Document License"
    "https://www.w3.org/Consortium/Legal/2015/copyright-software-and-document"
    "See the exact original notice in XMLresolver's data JAR."))

(define-public phive
  (package
    (name "phive")
    (version "12.2.0")
    (source (car %supplement-origins))
    (build-system trivial-build-system)
    (outputs '("out" "tests"))
    (arguments
     (list
      #:modules '((guix build utils) (ice-9 match) (srfi srfi-1))
      #:builder
      #~(begin
          (use-modules (guix build utils) (ice-9 match) (srfi srfi-1))
          (define (install-artifacts output records jars poms sources)
            (let ((share (string-append output "/share/phive")))
              (mkdir-p (string-append share "/lib"))
              (mkdir-p (string-append share "/maven"))
              (mkdir-p (string-append share "/source"))
              (call-with-output-file (string-append share "/artifacts.tsv")
                (lambda (port)
                  (format port
                    "group\tartifact\tversion\tclassifier\tjar\tjar_sha256\tpom\tpom_sha256\tsource\tsource_sha256~%")
                  (for-each
                   (lambda (entry jar pom source)
                     (match entry
                       ((group artifact version classifier jhash phash shash)
                        (let ((jar-name (basename jar))
                              (pom-name (basename pom))
                              (source-name (basename source))
                              (stem (string-append artifact "-" version
                                      (if (string-null? classifier) ""
                                          (string-append "-" classifier)))))
                          ;; Remove only the Guix store hash from filenames.
                          (set! jar-name (substring jar-name 33))
                          (set! pom-name (substring pom-name 33))
                          (set! source-name (substring source-name 33))
                          (copy-file jar (string-append share "/lib/" jar-name))
                          ;; Classifier artifacts share the same exact GAV POM.
                          ;; Store inputs are read-only; do not overwrite a POM
                          ;; already copied for its main artifact.
                          (unless (file-exists? (string-append share "/maven/" pom-name))
                            (copy-file pom (string-append share "/maven/" pom-name)))
                          (mkdir-p (string-append share "/source/" stem))
                          (copy-file source
                            (string-append share "/source/" stem "/" source-name))
                          (format port "~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a\t~a~%"
                            group artifact version classifier jar-name jhash
                            pom-name phash
                            (string-append stem "/" source-name) shash)))))
                   records jars poms sources)))
              (call-with-output-file (string-append share "/classpath")
                (lambda (port)
                  (format port "~a~%"
                    (string-join
                      (map (lambda (jar)
                             (string-append share "/lib/"
                               (substring (basename jar) 33))) jars) ":"))))
              ;; Extract embedded notices separately for convenient inspection;
              ;; the original signed JARs and source JARs remain byte-identical.
              (for-each
               (lambda (entry jar source)
                 (let ((stem (string-append (cadr entry) "-" (caddr entry)
                               (if (string-null? (list-ref entry 3)) ""
                                   (string-append "-" (list-ref entry 3))))))
                   (for-each
                    (lambda (archive label)
                      (let ((temporary (string-append "notices-" stem "-" label)))
                        (mkdir-p temporary)
                        (invoke #$(file-append libarchive "/bin/bsdtar")
                          "-xf" archive "-C" temporary)
                        (for-each
                         (lambda (file)
                           (let ((target (string-append share "/notices/"
                                           stem "/" label "/"
                                           (substring file (+ 1 (string-length temporary))))))
                             (mkdir-p (dirname target))
                             (copy-file file target)))
                         (find-files temporary
                           "(LICENSE|NOTICE|COPYRIGHT|license|notice|copyright)"))))
                    (list jar source) '("binary" "source"))))
               records jars sources)))
          (install-artifacts #$output '#$%runtime-artifacts
            (list #$@(map (lambda (entry) (artifact-origin entry 'jar)) %runtime-artifacts))
            (list #$@(map (lambda (entry) (artifact-origin entry 'pom)) %runtime-artifacts))
            (list #$@(map (lambda (entry) (artifact-origin entry 'source)) %runtime-artifacts)))
          (install-artifacts #$output:tests '#$%test-artifacts
            (list #$@(map (lambda (entry) (artifact-origin entry 'jar)) %test-artifacts))
            (list #$@(map (lambda (entry) (artifact-origin entry 'pom)) %test-artifacts))
            (list #$@(map (lambda (entry) (artifact-origin entry 'source)) %test-artifacts)))
          (let ((share (string-append #$output "/share/phive")))
            (mkdir-p (string-append share "/source/supplements"))
            (call-with-output-file (string-append share "/supplements.tsv")
              (lambda (port)
                (format port "file\tsha256\turl~%")
                (for-each
                 (lambda (entry origin)
                   (match entry
                     ((url name hash)
                      (copy-file origin (string-append share "/source/supplements/" name))
                      (format port "~a\t~a\t~a~%" name hash url)
                      (unless (string-suffix? ".txt" name)
                        (let ((temporary (string-append "supplement-" name)))
                          (mkdir-p temporary)
                          (invoke #$(file-append libarchive "/bin/bsdtar")
                            "-xf" origin "-C" temporary)
                          (for-each
                           (lambda (file)
                             (let ((target (string-append share "/notices/supplements/"
                                             name "/"
                                             (substring file (+ 1 (string-length temporary))))))
                               (mkdir-p (dirname target))
                               (copy-file file target)))
                           (find-files temporary
                             "(LICENSE|NOTICE|COPYRIGHT|license|notice|copyright|JAMESCLARK)"))))
                      (when (string-suffix? ".txt" name)
                        (install-file origin (string-append share "/notices/supplements"))))))
                 '#$%supplements (list #$@%supplement-origins))))
            (call-with-output-file (string-append share "/java")
              (lambda (port) (format port "~a~%" #$(file-append %java "/bin/java"))))))))
    (inputs (list %java))
    (native-inputs (list libarchive))
    (supported-systems (package-supported-systems %java))
    (home-page "https://github.com/phax/phive")
    (synopsis "Modular Java XML and Schematron validation framework")
    (description
     "PHIVE is a Java library for XML schema and Schematron validation,
validation execution sets and result serialization.  This package retains the
eight original release modules and their complete pinned runtime closure,
including a reference JAXB provider, unchanged individual JARs, exact POMs,
sources and license notices.  A classpath file and Java 17 runtime path are
provided under share/phive; there is no PHIVE command-line application or fiscal
rule bundle.  Original test-only libraries are isolated in the tests output.
This is an adaptation of published artifacts, not a Maven source rebuild.")
    ;; EPL/BSD apply to the separate original JUnit/Hamcrest test libraries.
    (license (list license:asl2.0 license:expat license:x11 license:mpl2.0
                   license:edl1.0 %w3c-software-and-document
                   license:epl1.0 license:bsd-3))))
