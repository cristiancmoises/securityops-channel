;;; SPDX-License-Identifier: GPL-3.0-or-later

(define-module (securityops packages xml-security)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module (gnu packages documentation)
  #:use-module (gnu packages xml))

(define* (%bounded-build-environment #:optional (address-space 2147483648))
  #~(lambda _
      (setrlimit 'as #$address-space #$address-space)
      (setrlimit 'nproc 256 256)
      (setrlimit 'fsize 134217728 134217728)
      (setrlimit 'cpu 600 600)
      (setrlimit 'core 0 0)
      (setenv "HOME" (getcwd))
      (setenv "XDG_CACHE_HOME" (getcwd))
      (setenv "OPENBLAS_NUM_THREADS" "1")
      (setenv "OMP_NUM_THREADS" "1")))

(define libxml2-security
  (package
    (inherit libxml2)
    (version "2.15.4")
    (source
     (origin
       (inherit (package-source libxml2))
       (uri (string-append "https://download.gnome.org/sources/libxml2/2.15/"
                           "libxml2-" version ".tar.xz"))
       (patches
        (list (local-file "patches/python-libxml2-utf8-2.15.patch")))
       (sha256
        (base32 "08c82d04kx5g9lvq5n1bp67060yvfxrmripvycj0f1yrh78py24q"))))
    (native-inputs
     (modify-inputs (package-native-inputs libxml2)
       (append doxygen)))
    (arguments
     (substitute-keyword-arguments (package-arguments libxml2)
       ((#:configure-flags flags #~'())
        #~(append '("--with-python" "--enable-static") #$flags))
       ((#:phases phases)
        #~(modify-phases #$phases
            (add-before 'unpack 'bound-build-resources
              #$(%bounded-build-environment))
            (add-after 'check 'check-python-error-handler
              (lambda _
                (setenv "PYTHONPATH"
                        (string-append (getcwd) "/python:"
                                       (getcwd) "/python/.libs"))
                (invoke "python3" "-c"
                        "import libxml2
messages = []
libxml2.registerErrorHandler(lambda ctx, text: messages.append(text), None)
with open('invalid-utf8-regression.xml', 'wb') as stream:
    stream.write(b'<root>\\n\\x80</root>')
try:
    libxml2.parseFile('invalid-utf8-regression.xml')
except libxml2.parserError:
    pass
else:
    raise AssertionError('invalid UTF-8 was accepted')
assert messages and all(isinstance(text, str) for text in messages)
def failing_handler(ctx, text):
    raise UnicodeError('test callback failure')
libxml2.registerErrorHandler(failing_handler, None)
try:
    libxml2.parseFile('missing-utf8-regression.xml')
except libxml2.parserError:
    pass
else:
    raise AssertionError('missing file was accepted')
libxml2.registerErrorHandler(None, None)
libxml2.cleanupParser()
print('Python UTF-8 error-handler regression checks passed')")))
            (replace 'use-other-outputs
              (lambda* (#:key outputs #:allow-other-keys)
                ;; 2.15 makes installation of documentation optional.  Use
                ;; its generated API and distributed manuals without adding
                ;; an xsltproc -> libxslt -> libxml2 build-time cycle.
                (let* ((out (assoc-ref outputs "out"))
                       (doc (string-append (assoc-ref outputs "doc") "/share"))
                       (static (string-append (assoc-ref outputs "static") "/lib")))
                  (for-each mkdir-p (list doc static))
                  (copy-recursively "doc/html"
                                    (string-append doc "/doc/libxml2/html"))
                  (for-each
                   (lambda (file)
                     (install-file file (string-append doc "/doc/libxml2")))
                   '("dist-doc/xmllint.html" "dist-doc/xmlcatalog.html"))
                  (for-each
                   (lambda (file)
                     (install-file file (string-append out "/share/man/man1")))
                   '("doc/xml2-config.1" "dist-doc/xmllint.1"
                     "dist-doc/xmlcatalog.1"))
                  (for-each
                   (lambda (archive)
                     (rename-file archive
                                  (string-append static "/" (basename archive))))
                   (find-files (string-append out "/lib") "\\.a$"))
                  (substitute* (string-append out "/lib/libxml2.la")
                    (("^old_library='libxml2.a'") "old_library=''")))))))))))

(define libxslt-security
  (package
    (inherit libxslt)
    (version "1.1.45")
    (source
     (origin
       (inherit (package-source libxslt))
       (uri (string-append "https://download.gnome.org/sources/libxslt/1.1/"
                           "libxslt-" version ".tar.xz"))
       (sha256
        (base32 "0vi1bpp35rhrxaj2q1k52ks94bbn28r1ncjhqm2nml64362fdkws"))))
    (inputs
     (modify-inputs (package-inputs libxslt)
       (replace "libxml2" libxml2-security)))
    (arguments
     (substitute-keyword-arguments (package-arguments libxslt)
       ((#:phases phases)
        #~(modify-phases #$phases
            (add-before 'unpack 'bound-build-resources
              #$(%bounded-build-environment))))))))
