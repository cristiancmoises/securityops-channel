;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Cristian Cezar Moisés <ethicalhacker@riseup.net>

(define-module (securityops packages containers)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (gnu packages golang)
  #:use-module ((gnu packages containers) #:prefix upstream:)
  #:use-module ((gnu packages docker) #:prefix upstream-docker:)
  #:use-module (securityops packages esquema)
  #:re-export (esquema))

(define %docker-runtime-labels
  (map car (package-inputs upstream-docker:docker)))

(define-public podman-latest
  (package
    (inherit upstream:podman)
    (version "6.1.3")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://codeload.github.com/podman-container-tools/podman/"
             "tar.gz/85b994955e0b4e30fbce9c8351cab85676140ede"))
       (file-name "podman-6.1.3.tar.gz")
       (sha256
        (base32 "1blr9waq8hbzm8a11xic6daxsx4pnxqn0y9l6w2vbwwmmqz6dppy"))))
    (native-inputs (modify-inputs (package-native-inputs upstream:podman)
                     (replace "go" go-1.26)))))

(define-public docker-latest
  (package
    (inherit upstream-docker:docker)
    (version "29.8.2")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://codeload.github.com/moby/moby/"
                           "tar.gz/8af9fe3a36bab3e039862a2ab1cef1880c9b4d03"))
       (file-name "docker-29.8.2.tar.gz")
       (sha256
        (base32 "14plaga75hv1wfx8var37df8g6052phjfgm1d1i6sqqlgp283xrx"))))
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)
          (add-after 'unpack 'offline-go
            (lambda _
              (setenv "GOTOOLCHAIN" "local")
              (setenv "GOPROXY" "off")
              (setenv "GOFLAGS" "-mod=vendor")
              (setenv "GOCACHE"
                      (string-append (getcwd) "/.go-cache"))))
          (replace 'build
            (lambda _
              (invoke "go"
                      "build"
                      "-trimpath"
                      "-o"
                      "dockerd"
                      "-ldflags"
                      (string-append
                       "-X github.com/moby/moby/v2/dockerversion.Version=29.8.2 "
                       "-X github.com/moby/moby/v2/dockerversion.GitCommit="
                       "8af9fe3a36bab3e039862a2ab1cef1880c9b4d03")
                      "./cmd/dockerd")))
          (replace 'check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (invoke "go" "test" "./dockerversion" "./pkg/homedir"
                        "./pkg/ioutils")
                (invoke "./dockerd" "--version"))))
          (replace 'install
            (lambda* (#:key outputs #:allow-other-keys)
              (install-file "dockerd"
                            (string-append (assoc-ref outputs "out") "/bin"))))
          (add-after 'install 'wrap-runtime-tools
            (lambda* (#:key outputs inputs #:allow-other-keys)
              (let* ((out (assoc-ref outputs "out"))
                     (paths (filter file-exists?
                                    (apply append
                                           (map (lambda (label)
                                                  (let ((root (assoc-ref
                                                               inputs label)))
                                                    (unless root
                                                      (error
                                                       "Missing Docker input"
                                                       label))
                                                    (list (string-append root
                                                           "/bin")
                                                          (string-append root
                                                           "/sbin"))))
                                                '#$%docker-runtime-labels)))))
                (wrap-program (string-append out "/bin/dockerd")
                  `("PATH" prefix
                    ,paths))))))))
    (native-inputs (modify-inputs (package-native-inputs
                                   upstream-docker:docker)
                     (replace "go" go-1.26)))))

(define-public docker-cli-latest
  (package
    (inherit upstream-docker:docker-cli)
    (version "29.8.2")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://codeload.github.com/docker/cli/"
                           "tar.gz/7fc2dff9bceb96b266a3b2c3117c0955a0d9e616"))
       (file-name "docker-cli-29.8.2.tar.gz")
       (sha256
        (base32 "1bd6gh2br1grczpzcvg7m9ks2vcb7j1bwmyrfk3jbbv11ybr6cyl"))))
    (arguments
     (list
      #:import-path "github.com/docker/cli"
      #:phases
      #~(modify-phases %standard-phases
          (add-before 'build 'prepare-build
            (lambda _
              ;; go-build-system adds its older Go before native-inputs.
              (setenv "PATH"
                      (string-append #$go-1.26 "/bin:"
                                     (getenv "PATH")))
              (setenv "GOTOOLCHAIN" "local")
              (setenv "GOPROXY" "off")
              (setenv "VERSION" "29.8.2")
              (setenv "BUILDTIME" "1970-01-01T00:00:01Z")
              (setenv "GO_LINKMODE" "dynamic")
              (symlink "src/github.com/docker/cli/scripts" "./scripts")
              (symlink "src/github.com/docker/cli/docker.Makefile"
                       "./docker.Makefile")))
          (replace 'build
            (lambda _
              (invoke "./scripts/build/binary")))
          (replace 'check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (with-directory-excursion "src/github.com/docker/cli"
                  (invoke "go" "test" "./cli/command/formatter"))
                (invoke "./build/docker" "--version"))))
          (replace 'install
            (lambda* (#:key outputs #:allow-other-keys)
              (let ((out (assoc-ref outputs "out")))
                (with-directory-excursion "src/github.com/docker/cli/contrib/completion"
                  (install-file "bash/docker"
                                (string-append out "/etc/bash_completion.d"))
                  (install-file "fish/docker.fish"
                                (string-append out "/etc/fish/completions"))
                  (install-file "zsh/_docker"
                                (string-append out "/etc/zsh/site-functions")))
                (install-file "build/docker"
                              (string-append out "/bin"))))))))
    (native-inputs (modify-inputs (package-native-inputs
                                   upstream-docker:docker-cli)
                     (replace "go" go-1.26)))))
