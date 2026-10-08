;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>

(define-module (securityops packages wazuh)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages cmake)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages gawk)
  #:use-module (gnu packages base)
  #:use-module (gnu packages admin)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages ssh)
  #:use-module (gnu packages tcl)
  #:use-module (gnu packages perl)
  #:use-module (gnu packages python)
  #:export (wazuh-source wazuh-agent wazuh-manager))

;; The upstream wheels require CPython's 3.10 ABI.  Its bundled interpreter
;; also requires obsolete distribution libraries; rebuild the interpreter
;; and standard-library extensions natively instead of inventing SONAME links.
;; 3.10.22 is the final 3.10 release: this ABI is now upstream end-of-life.
(define %wazuh-native-python
  (package
    (inherit python-3.10)
    (version "3.10.22")
    (source
     (origin
       (inherit (package-source python-3.10))
       (uri "https://www.python.org/ftp/python/3.10.22/Python-3.10.22.tar.xz")
       (sha256
        (base32 "0hr5rgybvxdb4390cdlym0jm72ipghc69rl80c5jmv57l6qyj7y6"))))
    (arguments
     (substitute-keyword-arguments (package-arguments python-3.10)
       ((#:phases phases)
        #~(modify-phases #$phases
            (add-after 'unpack 'bound-bytecode-workers
              (lambda _
                (substitute* "Makefile.pre.in"
                  (("-j0") (format #f "-j~a" (min 4 (parallel-job-count)))))))))))))

;; This source is the shared prerequisite for native agent/manager packaging.
;; It does not advertise a runnable stack: native dependencies, runtime
;; closures and authenticated component interoperability still need builds.
(define wazuh-source
  (origin
    (method url-fetch)
    (uri "https://github.com/wazuh/wazuh/archive/refs/tags/v4.14.8.tar.gz")
    (sha256
     (base32 "16a4ia19wqq21bg5bqi46f66n65qqv3sjd1igmgc6vn3jhc5whss"))
    (modules '((guix build utils)))
    (snippet
     '(begin
        ;; Upstream derives state from the executable's real path.  On Guix
        ;; that path is immutable, and upstream's deprecated -D is ignored.
        ;; An explicit state root must take precedence in both definitions.
        (substitute* "src/shared/file_op.c"
          (("^char \\*w_homedir\\(char \\*arg\\) \\{" line)
           (string-append
            "int w_safe_path_ancestry(const char *path, uid_t owner, int directory) {\n"
            "    char walk[PATH_MAX];\n"
            "    struct stat metadata, link_metadata;\n"
            "    int first = 1;\n"
            "    if (!path || path[0] != '/' || strlen(path) >= sizeof(walk)) return 0;\n"
            "    snprintf(walk, sizeof(walk), \"%s\", path);\n"
            "    for (;;) {\n"
            "        if (lstat(walk, &link_metadata) < 0 ||\n"
            "            (S_ISLNK(link_metadata.st_mode) && link_metadata.st_uid != 0 && link_metadata.st_uid != owner) ||\n"
            "            stat(walk, &metadata) < 0 ||\n"
            "            (metadata.st_uid != 0 && metadata.st_uid != owner) ||\n"
            "            ((first && !directory) ? !S_ISREG(metadata.st_mode) : !S_ISDIR(metadata.st_mode))) return 0;\n"
            "        if ((metadata.st_mode & (S_IWGRP | S_IWOTH)) &&\n"
            "            (first || metadata.st_uid != 0 || !(metadata.st_mode & S_ISVTX))) return 0;\n"
            "        if (strcmp(walk, \"/\") == 0) break;\n"
            "        char *slash = strrchr(walk, '/');\n"
            "        if (!slash) return 0;\n"
            "        if (slash == walk) walk[1] = '\\0'; else *slash = '\\0';\n"
            "        first = 0;\n"
            "    }\n"
            "    return 1;\n"
            "}\n\n"
            "int w_safe_code_path(const char *path, int directory) {\n"
            "    char absolute[PATH_MAX], canonical[PATH_MAX], cwd[PATH_MAX];\n"
            "    int length;\n"
            "    if (path[0] == '/') length = snprintf(absolute, sizeof(absolute), \"%s\", path);\n"
            "    else {\n"
            "        if (!getcwd(cwd, sizeof(cwd))) return 0;\n"
            "        length = snprintf(absolute, sizeof(absolute), \"%s/%s\", cwd, path);\n"
            "    }\n"
            "    if (length < 0 || (size_t)length >= sizeof(absolute) || !realpath(absolute, canonical)) return 0;\n"
            "    return w_safe_path_ancestry(absolute, 0, directory) && w_safe_path_ancestry(canonical, 0, directory);\n"
            "}\n\n" line))
          (("^    os_calloc\\(PATH_MAX, sizeof\\(char\\), buff\\);" line)
           (string-append
            line "\n    char *explicit_home = getenv(WAZUH_HOME_ENV);\n"
            "    if (explicit_home && *explicit_home) {\n"
            "        if (explicit_home[0] != '/' ||\n"
            "            realpath(explicit_home, buff) == NULL ||\n"
            "            strcmp(buff, \"/\") == 0 ||\n"
            "            strcmp(buff, \"/gnu/store\") == 0 ||\n"
            "            strncmp(buff, \"/gnu/store/\", 11) == 0 ||\n"
            "            w_stat(buff, &buff_stat) < 0 ||\n"
            "            !w_safe_path_ancestry(explicit_home, geteuid(), 1) ||\n"
            "            !w_safe_path_ancestry(buff, geteuid(), 1)) {\n"
            "            os_free(buff);\n"
            "            merror_exit(\"Unsafe WAZUH_HOME state ownership or ancestry\");\n"
            "        }\n"
            "    } else {"))
          (("^    if \\(\\(w_stat\\(buff, &buff_stat\\) < 0\\)" line)
           (string-append "    }\n" line)))
        (substitute* "framework/wazuh/core/common.py"
          (("    abs_path = os.path.abspath\\(os.path.dirname\\(__file__\\)\\)" line)
           (string-append
            "    explicit_home = os.environ.get('WAZUH_HOME')\n"
            "    if explicit_home:\n"
            "        if not os.path.isabs(explicit_home) or not os.path.isdir(explicit_home):\n"
            "            raise ValueError('WAZUH_HOME must be an existing absolute directory')\n"
            "        canonical_home = os.path.realpath(explicit_home)\n"
            "        for candidate in (explicit_home, canonical_home):\n"
            "            first = True\n"
            "            while True:\n"
            "                link_stat = os.lstat(candidate)\n"
            "                state_stat = os.stat(candidate)\n"
            "                if (os.path.islink(candidate) and link_stat.st_uid not in (0, os.geteuid())) or not os.path.isdir(candidate) or state_stat.st_uid not in (0, os.geteuid()):\n"
            "                    raise ValueError('WAZUH_HOME ancestry must be safely owned directories')\n"
            "                if state_stat.st_mode & 0o022 and (first or state_stat.st_uid != 0 or not state_stat.st_mode & 0o1000):\n"
            "                    raise ValueError('WAZUH_HOME ancestry must not be group/world-writable')\n"
            "                if not candidate.strip('/'):\n"
            "                    break\n"
            "                candidate = os.path.dirname(candidate)\n"
            "                first = False\n"
            "        explicit_home = canonical_home\n"
            "        if explicit_home == '/':\n"
            "            raise ValueError('WAZUH_HOME cannot be the filesystem root')\n"
            "        if explicit_home == '/gnu/store' or explicit_home.startswith('/gnu/store/'):\n"
            "            raise ValueError('WAZUH_HOME cannot be the immutable store')\n"
            "        return explicit_home\n"
            line)))
        ;; execd deliberately retains root UID.  Protect the lexical code
        ;; alias parent as well as its canonical target before configuration
        ;; and again for each configured command; do not change privilege
        ;; separation or require custom root-admin-owned code to be in store.
        (substitute* "src/headers/file_op.h"
          (("^char \\*w_homedir\\(char \\*arg\\);")
           "#ifndef WIN32\nint w_safe_path_ancestry(const char *path, uid_t owner, int directory);\nint w_safe_code_path(const char *path, int directory);\n#endif\nchar *w_homedir(char *arg);"))
        (substitute* "src/os_execd/main.c"
          (("^    const char \\*group = GROUPGLOBAL;" line)
           (string-append
            "#ifndef WIN32\n"
            "    if (geteuid() == 0 && !w_safe_code_path(AR_BINDIR, 1)) {\n"
            "        merror_exit(\"Unsafe active-response executable directory ownership or ancestry\");\n"
            "    }\n"
            "#endif\n" line)))
        (substitute* "src/os_execd/exec.c"
          (("^    /\\* Fork and leave it running \\*/" line)
           (string-append
            "    if (geteuid() == 0 && (!*cmd || !w_safe_code_path(*cmd, 0))) {\n"
            "        merror(\"Unsafe or unavailable active-response executable. Refusing to execute.\");\n"
            "        return;\n"
            "    }\n" line))
          (("^            process_file = wfopen\\(exec_cmd\\[exec_size\\], \"r\"\\);" line)
           (string-append
            "#ifndef WIN32\n"
            "            if (geteuid() == 0 && !w_safe_code_path(exec_cmd[exec_size], 0)) {\n"
            "                merror(\"Unsafe or unavailable active-response executable: '%s'. Not using it on this system.\", exec_cmd[exec_size]);\n"
            "                exec_cmd[exec_size][0] = '\\0';\n"
            "                continue;\n"
            "            }\n"
            "#endif\n" line)))
        ;; Guard the sinks, not only configured names: custom commands,
        ;; restart.sh, pending cleanup and timeout paths bypass the read check.
        (substitute* "src/os_execd/execd.c"
          (("^int repeated_offenders_timeout" line)
           (string-append
            "static wfd_t *ExecdOpenCommand(const char *path, char *const *argv, int flags) {\n"
            "#ifndef WIN32\n"
            "    if (geteuid() == 0 && (!path || !w_safe_code_path(path, 0))) {\n"
            "        merror(\"Unsafe or unavailable active-response executable. Refusing to execute.\");\n"
            "        errno = EPERM;\n"
            "        return NULL;\n"
            "    }\n"
            "#endif\n"
            "    return wpopenv(path, argv, flags);\n"
            "}\n\n" line))
          (("= wpopenv\\(") "= ExecdOpenCommand("))
        (substitute* "src/os_execd/wcom.c"
          (("^        switch \\(fork\\(\\)\\)" line)
           (string-append
            "        if (geteuid() == 0 && !w_safe_code_path(exec_cmd[0], 0)) {\n"
            "            merror(\"Unsafe or unavailable restart/control executable. Refusing to execute.\");\n"
            "            os_strdup(\"err Unsafe restart/control executable\", *output);\n"
            "            return strlen(*output);\n"
            "        }\n" line)))
        ;; First boot must never activate upstream's public example passwords.
        ;; Existing RBAC databases retain their authentication and policies.
        (substitute* "framework/wazuh/rbac/orm.py"
          (("^import os.*$") "import os\nimport stat\n")
          (("^logger = logging.getLogger" line)
           (string-append
            "def load_initial_users():\n"
            "    private_users = os.path.join(SECURITY_PATH, 'initial-users.yaml')\n"
            "    descriptor = os.open(private_users, os.O_RDONLY | os.O_NOFOLLOW)\n"
            "    with os.fdopen(descriptor, 'r') as stream:\n"
            "        metadata = os.fstat(stream.fileno())\n"
            "        if not stat.S_ISREG(metadata.st_mode) or metadata.st_mode & 0o077 or metadata.st_uid not in (0, os.geteuid()):\n"
            "            raise ValueError('Initial API users must be privately owned regular data')\n"
            "        users = yaml.safe_load(stream)\n"
            "    if not isinstance(users, dict) or set(users) != {'default_users'}:\n"
            "        raise ValueError('Invalid initial API users schema')\n"
            "    payloads = users['default_users']\n"
            "    if not isinstance(payloads, dict) or not {'wazuh', 'wazuh-wui'}.issubset(payloads):\n"
            "        raise ValueError('Initial API users must preserve the reserved RBAC accounts')\n"
            "    for payload in payloads.values():\n"
            "        if not isinstance(payload, dict) or not isinstance(payload.get('password'), str) or len(payload['password']) < 16 or not isinstance(payload.get('allow_run_as'), bool):\n"
            "            raise ValueError('Initial API users require explicit passwords and run-as policy')\n"
            "    return users\n\n"
            line))
          (("^        with open\\(os.path.join\\(DEFAULT_RBAC_RESOURCES, \"users.yaml\"\\), 'r'\\) as stream:")
           "        default_users = load_initial_users()")
          (("^            default_users = yaml.safe_load\\(stream\\)") "")
          (("^            with AuthenticationManager\\(self.sessions\\[database\\]\\) as auth:")
           "        with AuthenticationManager(self.sessions[database]) as auth:")
          (("^                for d_username, payload in default_users" line)
           (substring line 4))
          (("^                    auth.add_user\\(username=d_username" line)
           (substring line 4))
          (("^                    auth.edit_run_as\\(user_id=auth.get_user\\(username=d_username" line)
           (substring line 4))
          (("^                                     allow_run_as=payload\\['allow_run_as'\\]" line)
           (substring line 4)))))))

;; Upstream's versioned dependency bundle contains headers and prebuilt static
;; libraries.  The Wazuh C/C++ programs themselves are compiled below; this is
;; not a claim that every bundled dependency has been rebuilt from source.
(define %wazuh-dependency-pins
  '(("cJSON" . "1s7izq3r4il2jxh9894nxqcyw20isfpn6in10awdhxcdpnk82ssd")
    ("curl" . "0dqvpy3rg9dxij5vffydybladz23qpq2a9n2wzy1n71gg5ci29kv")
    ("libdb" . "1zaf80dndxrasv5087jl1m6ws3jlwqds2pmb2wl5l74njbpghz3s")
    ("libffi" . "17sxjrzsxz0k53b9grpsw2bq3xk0455dm8xkx9s6vpcv5i56pkva")
    ("libyaml" . "0xpdd1fchp3wc6mms8dsvz2pv5ri89ridp83x2ah0v13q3pdr1lr")
    ("openssl" . "1h2ky1pzlwg9fcv79jv1f0kjic4x55ynbfxa05bhrzpik97csfj0")
    ("procps" . "0dc7a6yv0hnzcif7hn7m38kmwz12yc7jp5016slw6qam56cjvs7h")
    ("sqlite" . "01gpyhirkyc4hjgi2w1d6dizjydrdsza3f4kkzb66672jq5bp5wk")
    ("zlib" . "1gdx1blpvnf4vlgrs79yj6pcha0qzgfljzdm72vdchcpfrfc5xq2")
    ("audit-userspace" . "1cdgafyz772hb1k30dm2ng2mzpp3y22ydingfyg060mg258gak43")
    ("msgpack" . "1rq9qqzfi9jnb0hn7a6sh0cr2ham3ykdr649nmlzs6kk3rip26ir")
    ("bzip2" . "0h4403y7pws2rcrw3zi86fj26x6x8m6hj87a7y53dzg517kjn8dc")
    ("nlohmann" . "04wwmdq8r0sc1jq8asw16kka995fg4irrgkp26bqw5id8d1vcy13")
    ("googletest" . "0ynhcxw9wwni2g6jc8cpn1cp6nhmbg506sh904aqxkbk2608ynyb")
    ("libpcre2" . "1b5ssc17di02apn1ycfagajdklzy0zvhnmii7h9gc35d9nahj2gr")
    ("libplist" . "09chnr0fkcsx0030byc76c0dp5d4mrps7j5f29rjxwq6rj14mn1i")
    ("pacman" . "1dnw0fj6a7s48xxjs5af3r75xapvwn1jinbhap5hr1w6cpy3n6kv")
    ("libarchive" . "1ilyapbmggix5b3r585gq5hph598f7wghxrx7x884rc4apw47drp")
    ("popt" . "0bw1zaybf850nh0qfg0glg1ca3nw59wba8g6sp1xidv218x8bs4g")
    ("lua" . "1z34q34pjjjgm6lw34l5x0dp3f7vaqqpx08snbbr67ww61qcf27c")
    ("rpm" . "1h46c8bfzypnabqsnw0lvzz1rpbyjiv3hw60mkds1v1khpjavcy3")
    ("rocksdb" . "1dz3lyn8h26c0kgar3zfixjywihwgmg6vl9l89xnp9dvnfj1jhxk")
    ("lzma" . "1vbgqpjc95c4sklh9brzmzqvfzys4q5lq9f59mi25anrxq90a5jh")
    ("cpp-httplib" . "1l9n50lvichpbcmgdyibmp051z0knav15iz9a6l74ny316qhhn21")
    ("benchmark" . "1c78gs8inmgfz040kf7wz8rfi4yg7c0nsiwrrnlmjdky4w13ppz6")
    ("libbpf-bootstrap" . "1q33qcpxwmgrmdfgm98hnx7jb9nxvnxr55dgykkg9wqf9a146a9q")
    ("dbus" . "0z6f1838lmp898440ibjb5bxclnhx484xdxvs6zijp1kf03fqyvq")
    ("jemalloc" . "1xw4f6lr28pqarfm4i3fmhmff2l0xdazcla5d9r9k6cxf0xhizf3")
    ("flatbuffers" . "0iiw3j6gfmy5gv3i6n6aqj40c5hxh18z7b78xr46j72wv8zv42jw")
    ("simdjson" . "0d7y9ham9qfi2g9whjia98n0ryc7ngnddkqla82jzv714r553y5l")))

(define %wazuh-dependencies
  (map (lambda (pin)
         (list (string-append "bundle-" (car pin))
               (origin
                 (method url-fetch)
                 (uri (string-append
                       "https://packages.wazuh.com/deps/54/libraries/linux/amd64/"
                       (car pin) ".tar.gz"))
                 (sha256 (base32 (cdr pin))))))
       %wazuh-dependency-pins))

(define %wazuh-http-request
  (origin
    (method url-fetch)
    (uri "https://github.com/wazuh/wazuh-http-request/tarball/cd50797cfe03c27f3759bdc243fecca6f7535d35")
    (sha256 (base32 "18nri2vx74w9shfy35y2c4hcs0sqy10fzgm6f4h6wmiln45ccyq7"))))

(define %wazuh-python-runtime
  (origin
    (method url-fetch)
    (uri "https://packages.wazuh.com/deps/54/libraries/linux/amd64/cpython.tar.gz")
    (sha256 (base32 "0r44nlncs4a3dcc7jhq7xhf260a7m5dibrr3bjs9lmkxx7d5nvnf"))))

(define %wazuh-mitre-license
  (origin
    (method url-fetch)
    (uri "https://raw.githubusercontent.com/mitre-attack/attack-stix-data/3aba8a0e56096f2d7e966f4492f592106a7aa8e5/LICENSE.txt")
    (sha256 (base32 "0pmzv3namnj17anccx655z0isd0h2z2nfcwxxyj24iq5zgvl90bk"))))

(define %wazuh-shared-python
  (package
    (name "wazuh-python-runtime")
    (version "4.14.8")
    (source wazuh-source)
    (build-system gnu-build-system)
    (arguments
     (list
      #:modules '((guix build gnu-build-system) (guix build utils)
                  (guix elf) (rnrs io ports) (ice-9 popen) (ice-9 rdelim)
                  (srfi srfi-1))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)
          (delete 'build)
          (delete 'check)
          (replace 'install
            (lambda* (#:key inputs #:allow-other-keys)
              (let* ((runtime (string-append #$output "/libexec/wazuh/python"))
                     (site (string-append runtime "/lib/python3.10/site-packages"))
                     ;; rename-file requires the same filesystem as runtime.
                     (wheels (string-append #$output "/libexec/wazuh/pinned-site-packages"))
                     (system-libs
                      (string-join
                       (delete-duplicates
                        (map (lambda (file) (dirname (search-input-file inputs file)))
                             '("lib/libgcc_s.so.1" "lib/libstdc++.so.6"
                               "lib/libz.so.1" "lib/libelf.so.1"
                               "lib/ld-linux-x86-64.so.2"))) ":")))
                (mkdir-p runtime)
                (invoke "tar" "xf" #$%wazuh-python-runtime "-C" runtime)
                (rename-file site wheels)
                (delete-file-recursively runtime)
                (copy-recursively (assoc-ref inputs "native-python") runtime
                                  #:keep-permissions? #f)
                ;; Do not retain bootstrap pip or Guix sitecustomize: runtime
                ;; -I must not import user-supplied GUIX_PYTHONPATH code.
                (delete-file-recursively site)
                (copy-recursively wheels site #:keep-permissions? #f)
                (delete-file-recursively wheels)
                (for-each
                 (lambda (file)
                   (when (and (not (file-is-directory? file)) (elf-file? file)
                              (memv (elf-type
                                     (parse-elf (call-with-input-file file get-bytevector-all)))
                                    (list ET_EXEC ET_DYN)))
                     (chmod file #o755)
                     (let* ((pipe (open-pipe* OPEN_READ "patchelf" "--print-rpath" file))
                            (old (read-line pipe))
                            (paths
                             (filter (lambda (path)
                                       (or (string-prefix? "$ORIGIN" path)
                                           (string-prefix? "${ORIGIN}" path)
                                           (string-prefix? "/gnu/store/" path)))
                                     (if (string? old) (string-split old #\:) '()))))
                       (unless (zero? (close-pipe pipe))
                         (error "cannot inspect bundled ELF RUNPATH" file))
                       (invoke "patchelf" "--set-rpath"
                               (string-append (string-join paths ":") ":"
                                              (dirname file) ":" runtime "/lib:"
                                              system-libs) file))))
                 (find-files runtime))
                (for-each
                 (lambda (file)
                   (when (elf-file? file)
                     (invoke "patchelf" "--set-interpreter"
                             (search-input-file inputs "lib/ld-linux-x86-64.so.2") file)))
                 (find-files (string-append runtime "/bin") "^python3(\\.10)?$"))
                (copy-recursively "framework/wazuh" (string-append site "/wazuh"))
                (copy-recursively "api/api" (string-append site "/api"))
                ;; Numeric IDs 1/2 have upstream reserved semantics.  Private
                ;; configuration order must not exchange those two accounts.
                (substitute* (string-append site "/wazuh/rbac/orm.py")
                  (("^    return users.*$")
                   "    ordered = {name: payloads[name] for name in ('wazuh', 'wazuh-wui')}\n    ordered.update({name: payload for name, payload in payloads.items() if name not in ordered})\n    users['default_users'] = ordered\n    return users\n")))))
          (add-after 'install 'check-isolated-runtime
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (invoke (string-append #$output "/libexec/wazuh/python/bin/python3")
                        "-I" "-B" "-c"
                        "import sys, ssl, sqlite3, lzma, bz2, ctypes, uuid, cryptography, grpc, numpy, pyarrow, connexion, uvicorn, uvloop, sqlalchemy, docker, boto3, google.cloud.storage, google.cloud.pubsub_v1, requests; assert sys.version_info[:3] == (3, 10, 22); assert sys.prefix == sys.argv[1]; print('PASS: isolated shared native interpreter and exact upstream helper dependencies')"
                        (string-append #$output "/libexec/wazuh/python"))))))))
    (native-inputs (list patchelf))
    (inputs (list (list "native-python" %wazuh-native-python)
                  (list "gcc:lib" gcc "lib") (list "zlib" zlib)
                  (list "elfutils" elfutils)))
    (supported-systems '("x86_64-linux"))
    (home-page "https://wazuh.com")
    (synopsis "Private ABI-compatible Wazuh Python environment")
    (description "This private runtime shares the native final CPython 3.10.22
interpreter, immutable Wazuh modules, and the exact upstream deps54 cp310 wheel
set between core components.  It retains the wheel license notices.  The 3.10
ABI is end-of-life; this is not a claim that every dependency is source-built
or independently security-certified.")
    (license
     (list license:gpl2 license:psfl license:asl2.0 license:expat
           license:bsd-2 license:bsd-3 license:bsd-0 license:mpl2.0
           license:lgpl2.1+ license:lgpl3 license:gpl3
           (license:fsf-free "https://www.gnu.org/licenses/gcc-exception-3.1.html"
                             "NumPy GCC runtime exception 3.1.")
           (license:non-copyleft
            "file://libexec/wazuh/python/lib/python3.10/site-packages/regex-2026.5.9.dist-info/licenses/LICENSE.txt")))))

(define (wazuh-core-package target)
  (package
    (name (if (string=? target "agent") "wazuh-agent" "wazuh-manager"))
    (version "4.14.8")
    (source wazuh-source)
    (build-system gnu-build-system)
    (arguments
     (list
      #:modules '((guix build gnu-build-system) (guix build utils)
                  (guix elf) (rnrs io ports)
                  (ice-9 match) (ice-9 popen) (ice-9 rdelim)
                  (srfi srfi-1) (srfi srfi-26))
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)
          (add-after 'unpack 'prepare-upstream-dependencies
            (lambda* (#:key inputs #:allow-other-keys)
              ;; Store libraries are read-only.  Upstream copies and strips
              ;; two compiler-runtime files as intermediate build targets.
              (substitute* "src/Makefile"
                (("\\$\\{STRIP_TOOL\\} -x \\$@")
                 "chmod u+w $@ && ${STRIP_TOOL} -x $@"))
              ;; Locks are mutable data; preserve the upstream algorithm.
              (for-each
               (lambda (file)
                 (substitute* file
                   (("active-response/bin/host-deny-lock") "var/run/active-response/host-deny-lock")
                   (("active-response/bin/fw-drop") "var/run/active-response/fw-drop")
                   (("active-response/bin/temp-hosts-deny") "var/run/active-response/temp-hosts-deny")))
               '("src/active-response/host-deny.c"
                 "src/active-response/firewalld-drop.c"
                 "src/active-response/firewalls/default-firewall-drop.c"))
              (substitute* "src/active-response/kaspersky.c"
                (("#define PATH_TO_KASPERSKY.*$")
                 (format #f "#define PATH_TO_KASPERSKY ~s\n"
                         (string-append #$output "/libexec/wazuh/active-response/bin/kaspersky.py")))
                (("char \\*exec_cmd\\[4\\] = \\{python_path, PATH_TO_KASPERSKY, extra_args, NULL\\};")
                 "char *exec_cmd[6] = {python_path, \"-I\", \"-B\", PATH_TO_KASPERSKY, extra_args, NULL};"))
              (mkdir-p "src/external")
              (for-each
               (match-lambda
                 ((label . path)
                  (when (string-prefix? "bundle-" label)
                    (invoke "tar" "xf" path "-C" "src/external"))))
               inputs)
              (mkdir-p "src/shared_modules/http-request")
              (invoke "tar" "xf" #$%wazuh-http-request
                      "--strip-components=1" "-C" "src/shared_modules/http-request")
              (when (string=? #$target "server")
                ;; Rebuild the schema compiler: changing the bundled flatc's
                ;; loader alone produces a reproducible crash on this libc.
                (invoke "cmake" "-S" "src/external/flatbuffers"
                        "-B" "src/external/flatbuffers/native-guix"
                        "-DCMAKE_POLICY_VERSION_MINIMUM=3.5")
                (invoke "cmake" "--build" "src/external/flatbuffers/native-guix"
                        "--parallel" "2")
                (invoke "ctest" "--test-dir" "src/external/flatbuffers/native-guix"
                        "--output-on-failure")
                (copy-file "src/external/flatbuffers/native-guix/flatc"
                           "src/external/flatbuffers/build/flatc"))))
          (replace 'build
            (lambda _
              (invoke "make" "-C" "src" "-j2"
                      (string-append "TARGET=" #$target)
                      "CMAKE_OPTS=-DCMAKE_POLICY_VERSION_MINIMUM=3.5")))
          (replace 'check
            (lambda _
              ;; These are closure checks, not the root-required acceptance
              ;; test.  The latter runs separately in a disposable guest.
              (setenv "LD_LIBRARY_PATH"
                      (string-append (getcwd) "/src:"
                                     (getcwd) "/src/external/jemalloc/lib"))
              (call-with-output-file "etc/ossec.conf"
                (lambda (port)
                  (display "<ossec_config></ossec_config>\n" port)))
              (setenv "WAZUH_HOME" (getcwd))
              (invoke "src/wazuh-logcollector" "-V")
              (invoke (string-append "src/wazuh-"
                                     (if (string=? #$target "agent")
                                         "agentd" "analysisd")) "-V")
              (for-each
               (lambda (invalid)
                 (setenv "WAZUH_HOME" invalid)
                 (when (zero? (system* "src/wazuh-logcollector" "-V"))
                   (error "compiled core accepted an unsafe state root" invalid)))
               '("/" "/gnu/store" "relative-state"))
              (setenv "WAZUH_HOME" (getcwd))))
          (replace 'install
            (lambda* (#:key inputs #:allow-other-keys)
              (let ((bin (string-append #$output "/bin"))
                    (lib (string-append #$output "/lib"))
                    (data (string-append #$output "/share/wazuh"))
                    (system-libs
                     (string-join
                      (delete-duplicates
                       (map (lambda (file) (dirname (search-input-file inputs file)))
                            '("lib/libgcc_s.so.1" "lib/libstdc++.so.6"
                              "lib/libz.so.1" "lib/libelf.so.1"
                              "lib/ld-linux-x86-64.so.2"))) ":")))
                (mkdir-p bin)
                (mkdir-p lib)
                (for-each
                 (lambda (file)
                   (when (and (string=? (dirname file) "src")
                              (file-exists? file)
                              (elf-file? file)
                              (not (string-contains (basename file) ".so")))
                     (install-file file bin)))
                 (find-files "src" "^[^/]+$" #:directories? #f))
                (install-file "src/syscheckd/build/bin/wazuh-syscheckd" bin)
                (for-each
                 (lambda (file)
                   (install-file file lib)
                   (invoke "patchelf" "--set-rpath"
                           (string-append lib ":" system-libs)
                           (string-append lib "/" (basename file))))
                 (append (filter (lambda (file)
                                   (not (string-prefix? "src/external/" file)))
                                 (find-files "src" "^lib.*\\.so(\\.[0-9]+)*$"))
                         (find-files "src/external/libbpf-bootstrap/build/libbpf" "^libbpf\\.so.*$")
                         (find-files "src/external/jemalloc/lib" "\\.so\\.2$")
                         (if (string=? #$target "server")
                             (append
                              (find-files "src/external/rocksdb/build" "^librocksdb\\.so.*$")
                              (find-files "src/external/curl/lib/.libs" "^libcurl\\.so.*$"))
                             '())))
                (install-file "src/external/libbpf-bootstrap/build/modern.bpf.o" lib)
                (for-each
                 (lambda (file)
                   (invoke "patchelf" "--set-rpath"
                           (string-append lib ":" system-libs) file))
                 (find-files bin))
                (mkdir-p data)
                (delete-file "etc/ossec.conf")
                (copy-recursively "etc" (string-append data "/etc"))
                (copy-recursively "ruleset" (string-append data "/ruleset"))
                (copy-recursively "ruleset/lists" (string-append data "/etc/lists"))
                (install-file "src/wazuh_modules/syscollector/norm_config.json"
                              (string-append data "/queue/syscollector"))
                (let ((control (string-append bin "/wazuh-control")))
                  (copy-file (string-append "src/init/wazuh-"
                                            (if (string=? #$target "agent") "client" "server")
                                            ".sh") control)
                  (chmod control #o755)
                  (substitute* control
                    (("^LOCAL=.*$")
                     (format #f ": \"${WAZUH_HOME:?Set an explicit mutable state root}\";\nLC_ALL=C; export LC_ALL\ncase \"$WAZUH_HOME\" in *[!A-Za-z0-9_./-]*|'') echo 'Control requires a supported ASCII state path' >&2; exit 1;; esac\nDIR=$(~a/libexec/wazuh/python/bin/python3 -I -B -c 'import re, sys\ntry:\n from wazuh.core.common import find_wazuh_path\n home = find_wazuh_path()\n if re.fullmatch(r\"/[A-Za-z0-9_./-]*\", home) is None:\n  print(\"Control requires a supported ASCII state path\", file=sys.stderr)\n  sys.exit(1)\n print(home)\nexcept (OSError, ValueError):\n print(\"Unsafe WAZUH_HOME state ownership or ancestry\", file=sys.stderr)\n sys.exit(1)') || exit 1\ncase \"$DIR\" in *[!A-Za-z0-9_./-]*|'') echo 'Control requires a supported ASCII state path' >&2; exit 1;; esac\nWAZUH_HOME=$DIR; export WAZUH_HOME\nLOCAL=$DIR;\n" #$output))
                    (("^cd \\$\\{LOCAL\\}.*$") "cd \"${LOCAL}\" || exit 1\n")
                    (("^DIR=`dirname \\$PWD`;.*$") "DIR=\"$PWD\";\n"))
                  (when (string=? #$target "server")
                    (substitute* control
                      (("^PLIST=.*$") "PLIST=\"${DIR}/var/run/.process_list\";\n")
                      (("^\\. \\$\\{PLIST\\};.*$")
                       "[ ! -L \"${PLIST}\" ] || exit 1\nwhile IFS= read -r setting || [ -n \"$setting\" ]; do\n  case \"$setting\" in\n    'DEBUG_CLI=\"-d\"') DEBUG_CLI=\"-d\";;\n    'DEBUG_CLI=\"\"'|'') DEBUG_CLI=\"\";;\n    *) echo 'Invalid mutable debug settings' >&2; exit 1;;\n  esac\ndone < \"${PLIST}\"\n")))
                  (wrap-program control
                    `("PATH" =
                      ,(map (lambda (name)
                              (dirname (search-input-file inputs name)))
                            '("bin/stat" "bin/find" "bin/grep" "bin/sed"
                              "bin/awk" "bin/ps")))))
                (copy-file "LICENSE" (string-append data "/LICENSE"))
                (let* ((runtime (string-append #$output "/libexec/wazuh/python"))
                       (scripts (string-append #$output "/libexec/wazuh/scripts")))
                  (mkdir-p (dirname runtime))
                  (symlink (string-append (assoc-ref inputs "python-runtime")
                                          "/libexec/wazuh/python") runtime)
                  (when (string=? #$target "server")
                    (mkdir-p scripts)
                    (copy-recursively "framework/scripts" scripts)
                    (copy-file "api/scripts/wazuh_apid.py"
                               (string-append scripts "/wazuh_apid.py"))
                    (copy-recursively "api/api/configuration"
                                      (string-append data "/api/configuration"))
                    (for-each
                     (lambda (script)
                       (let ((wrapper (string-append bin "/"
                                                     (string-map
                                                      (lambda (character)
                                                        (if (char=? character #\_) #\- character))
                                                      (basename script ".py")))))
                         (call-with-output-file wrapper
                           (lambda (port)
                             (format port "#!~a~%: \"${WAZUH_HOME:?Set an explicit mutable state root}\"~%exec ~a/bin/python3 -I -B ~a \"$@\"~%"
                                     (which "sh") runtime script)))
                         (chmod wrapper #o555)))
                     (filter (lambda (file)
                               (and (string=? (dirname file) scripts)
                                    (not (string=? (basename file) "__init__.py"))))
                             (find-files scripts "^[^/]+\\.py$"))))))))
          (add-after 'install 'install-default-assets
            (lambda* (#:key inputs #:allow-other-keys)
              (let* ((data (string-append #$output "/share/wazuh"))
                     (helpers (string-append #$output "/libexec/wazuh"))
                     (runtime (string-append helpers "/python"))
                     (wodles (string-append helpers "/wodles"))
                     (integrations (string-append helpers "/integrations"))
                     (ar (string-append helpers "/active-response/bin"))
                     (agentless (string-append helpers "/agentless")))
                (define (python-wrapper script command)
                  ;; Only immutable sibling imports are added with -I.
                  (call-with-output-file command
                    (lambda (port)
                      (format port "#!~a~%[ -n \"$WAZUH_HOME\" ] || exit 1~%exec ~a/bin/python3 -I -B -c 'import sys,runpy; from wazuh.core.common import find_wazuh_path; find_wazuh_path(); script=sys.argv.pop(1); sys.path[:0]=[~s,~s]; runpy.run_path(script,run_name=\"__main__\")' ~s \"$@\"~%"
                              (which "sh") runtime (dirname script) wodles script)))
                  (chmod command #o555))
                (mkdir-p wodles)
                (copy-file "wodles/utils.py" (string-append wodles "/utils.py"))
                (substitute* (string-append wodles "/utils.py")
                  (("    abs_path = os.path.abspath.*$" line)
                   (string-append "    from wazuh.core.common import find_wazuh_path as checked_state\n    return checked_state()\n" line)))
                (for-each
                 (match-lambda
                   ((directory source command)
                    (let ((destination (string-append wodles "/" directory)))
                      (copy-recursively (string-append "wodles/" source) destination)
                      (let ((tests (string-append destination "/tests")))
                        (when (file-exists? tests) (delete-file-recursively tests)))
                      (python-wrapper (string-append destination "/" command ".py")
                                      (string-append destination "/"
                                                     (if (string=? directory "aws") "aws-s3" command))))))
                 '(("aws" "aws" "aws_s3") ("gcloud" "gcloud" "gcloud")
                   ("azure" "azure" "azure-logs")
                   ("docker" "docker-listener" "DockerListener")))
                (substitute* (string-append wodles "/aws/wazuh_integration.py")
                  (("path.join\\(self.wazuh_path, \"wodles\", \"aws\"\\)")
                   "path.join(self.wazuh_path, \"var\", \"wodles\", \"aws\")"))
                (substitute* (string-append wodles "/gcloud/buckets/bucket.py")
                  (("wodles/gcloud/gcloud.db") "var/wodles/gcloud/gcloud.db"))
                (substitute* (string-append wodles "/azure/db/orm.py")
                  (("^MODULE_ROOT_DIR =.*$")
                   "from wazuh.core.common import find_wazuh_path\nMODULE_ROOT_DIR = join(find_wazuh_path(), 'var', 'wodles', 'azure')\n"))
                (substitute* (string-append wodles "/docker/DockerListener.py")
                  (("        self.wazuh_path =.*$")
                   "        from wazuh.core.common import find_wazuh_path\n        self.wazuh_path = find_wazuh_path()\n"))
                (mkdir-p ar)
                ;; Linux fw-check selects this implementation without probing
                ;; or modifying the build host's firewall.
                (for-each
                 (lambda (name)
                   (symlink (string-append #$output "/bin/" name)
                            (string-append ar "/" name)))
                 '("default-firewall-drop" "firewalld-drop" "disable-account"
                   "host-deny" "route-null" "restart-wazuh" "kaspersky"))
                (symlink (string-append #$output "/bin/default-firewall-drop")
                         (string-append ar "/firewall-drop"))
                (copy-file "src/active-response/restart.sh" (string-append ar "/restart.sh"))
                (chmod (string-append ar "/restart.sh") #o555)
                (substitute* (string-append ar "/restart.sh")
                  (("^LOCAL=.*$")
                   (format #f "[ -n \"$WAZUH_HOME\" ] || exit 1\n~a/bin/python3 -I -B -c 'from wazuh.core.common import find_wazuh_path; find_wazuh_path()' || exit 1\nLOCAL=$WAZUH_HOME;\n" runtime))
                  (("^cd ../../.*$") "")
                  (("^cd \\$LOCAL.*$") "cd \"$LOCAL\" || exit 1\n"))
                (copy-file "src/active-response/kaspersky.py" (string-append ar "/kaspersky.py"))
                (substitute* (string-append ar "/kaspersky.py")
                  (("^wazuh_path =.*$")
                   "from wazuh.core.common import find_wazuh_path\nwazuh_path = find_wazuh_path()\n")
                  (("current_path = dirname\\(abspath\\(__file__\\)\\)")
                   "current_path = os.path.join(wazuh_path, 'var', 'active-response')"))
                (python-wrapper (string-append ar "/kaspersky.py") (string-append ar "/kaspersky-helper"))
                (when (string=? #$target "server")
                  (mkdir-p integrations)
                  (for-each
                   (lambda (name)
                     (let ((script (string-append integrations "/" name ".py")))
                       (copy-file (string-append "integrations/" name ".py") script)
                       (substitute* script
                         (("^pwd(: str)? =.*$")
                          "from wazuh.core.common import find_wazuh_path\npwd = find_wazuh_path()\n"))
                       (python-wrapper script (string-append integrations "/" name))))
                   '("slack" "pagerduty" "virustotal" "shuffle" "maltiverse"))
                  (copy-recursively "src/agentlessd/scripts" agentless)
                  (for-each
                   (lambda (file)
                     (substitute* file
                       (("agentless/main.exp") (string-append agentless "/main.exp"))
                       (("set (sshsrc|susrc|sshloginsrc|sshnopasssrc) \"agentless/([^\"]+)\"" _ variable name)
                        (string-append "set " variable " \"" agentless "/" name "\""))))
                   (find-files agentless))
                  (substitute* (string-append agentless "/register_host.sh")
                    (("^# Check the location.*$")
                     (format #f "[ -n \"$WAZUH_HOME\" ] || exit 1\n~a/bin/python3 -I -B -c 'from wazuh.core.common import find_wazuh_path; find_wazuh_path()' || exit 1\numask 027\ncd \"$WAZUH_HOME/agentless\" || exit 1\n" runtime))
                    (("^    LOCALDIR=.*$") "    LOCALDIR=$WAZUH_HOME/agentless;\n"))
                  (for-each (lambda (file) (chmod file #o555)) (find-files agentless))
                  (mkdir-p (string-append data "/templates"))
                  (for-each
                   (lambda (file) (install-file file (string-append data "/templates")))
                   (find-files "src/wazuh_modules/inventory_harvester/indexer/template" "\\.json$"))
                  (copy-file "src/wazuh_modules/vulnerability_scanner/indexer/template/index-template.json"
                             (string-append data "/templates/vd_states_template.json"))
                  (copy-file "src/wazuh_modules/vulnerability_scanner/indexer/template/update-mappings.json"
                             (string-append data "/templates/vd_states_update_mappings.json"))
                  (mkdir-p (string-append data "/var/db"))
                  ;; Only source/destination and build-user ownership differ
                  ;; from the upstream MITRE data transform.
                  (substitute* "tools/mitre/mitredb.py"
                    (("pathfile = find\\('enterprise-attack.json', '../..'\\)")
                     (format #f "pathfile = ~s" (string-append (getcwd) "/ruleset/mitre/enterprise-attack.json")))
                    (("uid = pwd.getpwnam.*$") "uid = os.getuid()\n")
                    (("gid = grp.getgrnam.*$") "gid = os.getgid()\n"))
                  (setenv "WAZUH_HOME" (getcwd))
                  (invoke (string-append runtime "/bin/python3") "-I" "-B" "-c"
                          "import sys,runpy; script=sys.argv.pop(1); sys.path.insert(0,sys.argv.pop(1)); runpy.run_path(script,run_name='__main__')"
                          (string-append (getcwd) "/tools/mitre/mitredb.py")
                          (string-append (getcwd) "/tools/mitre")
                          "--database" (string-append data "/var/db/mitre.db"))
                  (install-file #$%wazuh-mitre-license (string-append data "/licenses/mitre"))))))
          (add-after 'install-default-assets 'pin-command-paths
            (lambda* (#:key inputs #:allow-other-keys)
              (let ((path (cons (string-append #$output "/libexec/wazuh/python/bin")
                               (map (lambda (name) (dirname (search-input-file inputs name)))
                               '("bin/stat" "bin/find" "bin/grep" "bin/sed"
                                 "bin/awk" "bin/ps" "bin/ssh" "bin/expect"
                                 "sbin/iptables" "bin/route" "bin/passwd" "sbin/usermod")))))
                (for-each
                 (lambda (file)
                   (when (elf-file? file)
                     (wrap-program file (list "PATH" '= path))))
                 (find-files (string-append #$output "/bin")))
                (for-each
                 (lambda (file) (wrap-program file (list "PATH" '= path)))
                 (append
                  (list (string-append #$output "/libexec/wazuh/active-response/bin/restart.sh"))
                  (if (string=? #$target "server")
                      (list (string-append #$output "/libexec/wazuh/agentless/register_host.sh")) '()))))))
          (add-after 'pin-command-paths 'normalize-python-implementations
            (lambda _
              ;; These are interpreted/imported by the pinned -I -B launchers,
              ;; never executed as standalone scripts.  Dropping both the
              ;; shebang and execute bits prevents GNU's shebang phase from
              ;; retaining the unrelated build interpreter in the closure.
              (let ((helpers (string-append #$output "/libexec/wazuh")))
                (for-each
                 (lambda (directory)
                   (let ((path (string-append helpers "/" directory)))
                     (when (file-exists? path)
                       (for-each
                        (lambda (file)
                          (substitute* file (("^#!.*") ""))
                          (chmod file #o444))
                        (find-files path "\\.py$")))))
                 '("scripts" "wodles" "active-response" "integrations")))
              ;; Upstream's developer harness edits a test installation and
              ;; hardcodes /var/ossec for coverage.  It is not a production
              ;; CLI; retain its original source in the pinned source origin,
              ;; rather than advertising a broken immutable runtime entry.
              (delete-file-recursively
               (string-append #$output "/share/wazuh/ruleset/testing"))))
          (add-after 'install 'check-python-runtime
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (invoke (string-append #$output "/libexec/wazuh/python/bin/python3")
                        "-I" "-B" "-c"
                        "import os, sys, ssl, sqlite3, lzma, bz2, ctypes, uuid, cryptography, grpc, numpy, pyarrow, connexion, uvicorn, uvloop, sqlalchemy, docker; assert sys.version_info[:3] == (3, 10, 22); assert os.path.realpath(sys.prefix) == os.path.realpath(sys.argv[1]); print('PASS: isolated packaged upstream API dependency imports and native prefix')"
                        (string-append #$output "/libexec/wazuh/python")))))
          (add-after 'install 'preserve-bundled-notices
            (lambda _
              (let ((notices (string-append #$output "/share/wazuh/licenses")))
                (for-each
                 (lambda (file)
                   (install-file
                    file
                    (string-append notices "/"
                                   (dirname (substring file (string-length "src/external/"))))))
                 (find-files "src/external"
                             "^(LICENSE.*|LICENCE.*|COPYING.*|NOTICE.*|copyright.*)$"))
                ;; These bundles carry their license grants in headers.
                (install-file "src/external/lua/lua.h"
                              (string-append notices "/lua"))
                (install-file "src/external/dbus/include/dbus-1.0/dbus/dbus.h"
                              (string-append notices "/dbus"))
                (for-each
                 (lambda (file)
                   (install-file file (string-append notices "/http-request")))
                 (find-files "src/shared_modules/http-request"
                             "^(LICENSE.*|COPYING.*|NOTICE.*)$"))))))))
    (native-inputs
     (append (list (list "cmake" cmake) (list "perl" perl)
                   (list "patchelf" patchelf) (list "python" python))
             %wazuh-dependencies))
    (inputs (append (list (list "gcc:lib" gcc "lib")
                  (list "zlib" zlib) (list "elfutils" elfutils)
                  (list "coreutils" coreutils) (list "findutils" findutils)
                  (list "grep" grep) (list "sed" sed) (list "gawk" gawk)
                  (list "procps" procps)
                  (list "openssh" openssh-sans-x) (list "expect" expect)
                  (list "iptables" iptables) (list "net-tools" net-tools)
                  (list "shadow" shadow)
                  (list "python-runtime" %wazuh-shared-python))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://wazuh.com")
    (synopsis (if (string=? target "agent")
                  "Wazuh endpoint event agent" "Wazuh event analysis manager"))
    (description "Wazuh processes security events.  This native core package
requires an explicit, safely owned WAZUH_HOME mutable state root and the upstream
wazuh account/group and privilege separation.  Executables and libraries remain
immutable; installation neither initializes state nor activates a daemon.
Versioned upstream dependency libraries and Python wheels are preserved as
binaries.  Their CPython 3.10 ABI is upstream end-of-life.  Companion indexer,
dashboard and alert-forwarding components are packaged separately.")
    ;; This lists the component grants, not a blanket compatibility guarantee.
    ;; Exact source-bundle notices and wheel metadata are preserved above.
    (license
     (append
      (list license:gpl2 license:asl2.0 license:expat
            (license:non-copyleft "https://attack.mitre.org/resources/terms-of-use/"
                                  "MITRE ATT&CK data; exact attribution and license are retained.")
            license:bsd-2 license:bsd-3 license:lgpl2.0+
            license:lgpl2.1+ license:public-domain license:zlib
            license:boost1.0
            (license:non-copyleft "file://share/wazuh/licenses/curl/COPYING")
            (license:non-copyleft "file://share/wazuh/licenses/bzip2/LICENSE"))
      (if (string=? target "server")
          (list license:psfl license:mpl2.0 license:bsd-0
                license:lgpl3 license:gpl3
                (license:fsf-free
                 "https://www.gnu.org/licenses/gcc-exception-3.1.html"
                 "Bundled NumPy GCC runtime: GPLv3 with runtime exception 3.1.")
                (license:non-copyleft
                 "file://libexec/wazuh/python/lib/python3.10/site-packages/regex-2026.5.9.dist-info/licenses/LICENSE.txt"
                 "The regex wheel retains its Apache-2.0 and CNRI-Python grants."))
          '())))))

(define-public wazuh-agent
  (let ((base (wazuh-core-package "agent")))
    (package
      (inherit base)
      (arguments
       (substitute-keyword-arguments (package-arguments base)
         ((#:phases phases)
          #~(modify-phases #$phases
              ;; Endpoint rulesets also carry ATT&CK data, although only the
              ;; manager builds the SQLite index.
              (add-after 'install-default-assets 'retain-attack-data-license
                (lambda _
                  (install-file #$%wazuh-mitre-license
                                (string-append #$output "/share/wazuh/licenses/mitre")))))))))))
(define-public wazuh-manager (wazuh-core-package "server"))
