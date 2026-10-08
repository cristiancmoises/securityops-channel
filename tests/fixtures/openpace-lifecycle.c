/* SPDX-License-Identifier: GPL-3.0-or-later
 * Benign, cardless installed-API probe.  Only original example CVC data is read.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <eac/cv_cert.h>
#include <eac/eac.h>
#include <openssl/crypto.h>
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv)
{
    static const unsigned char chr[] = "DECVCAeID00102";
    CVC_lookup_cvca_cert lookup;
    CVC_CERT *certificate;
    EAC_CTX *context;
    Dl_info eac_info, crypto_info;
    void *eac_address, *crypto_address;

    if (argc != 2)
        return 1;
    /* Function-pointer constants can name executable PLT stubs on x86-64.
     * Query the loader's actual definitions before identifying their DSOs. */
    eac_address = dlsym(RTLD_DEFAULT, "EAC_init");
    crypto_address = dlsym(RTLD_DEFAULT, "OpenSSL_version");
    if (!eac_address || !crypto_address
            || !dladdr(eac_address, &eac_info)
            || !dladdr(crypto_address, &crypto_info))
        return 2;
    printf("EAC_LIBRARY=%s\n", eac_info.dli_fname);
    printf("CRYPTO_LIBRARY=%s\n", crypto_info.dli_fname);
    printf("CRYPTO_VERSION=%s\n", OpenSSL_version(OPENSSL_VERSION));
    EAC_init();
    context = EAC_CTX_new();
    if (!context)
        return 3;
    EAC_CTX_clear_free(context);
    lookup = EAC_get_default_cvca_lookup();
    certificate = lookup(chr, sizeof(chr) - 1);
    if (certificate) {
        CVC_CERT_free(certificate);
        return 4;
    }
    /* Select a caller-owned copy, not a compiled-in example/default anchor. */
    EAC_set_cvc_default_dir(argv[1]);
    certificate = lookup(chr, sizeof(chr) - 1);
    if (!certificate)
        return 5;
    CVC_CERT_free(certificate);
    EAC_init();
    certificate = lookup(chr, sizeof(chr) - 1);
    if (certificate) {
        CVC_CERT_free(certificate);
        return 6;
    }
    EAC_cleanup();
    puts("PASS: cardless context lifecycle; empty default and explicit original-example lookup");
    return 0;
}
