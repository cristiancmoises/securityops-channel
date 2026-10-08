// SPDX-License-Identifier: GPL-3.0-or-later
// Run with AutoFirma's packaged Java 17 and a disposable, empty NSS database.
import java.nio.charset.StandardCharsets;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.KeyStore;
import java.security.Provider;
import java.security.Security;
import java.security.Signature;

class LibreWolfAutoFirmaNssTest {
    public static void main(String[] args) throws Exception {
        Provider provider = Security.getProvider("SunPKCS11").configure(args[0]);
        Security.addProvider(provider);
        KeyStore store = KeyStore.getInstance("PKCS11", provider);
        store.load(null, new char[0]);
        if (store.size() != 0) {
            throw new IllegalStateException("Use an isolated, empty NSS token");
        }
        KeyPairGenerator generator = KeyPairGenerator.getInstance("RSA", provider);
        generator.initialize(2048);
        KeyPair identity = generator.generateKeyPair();
        byte[] message = "Native NSS signing fixture".getBytes(StandardCharsets.UTF_8);
        Signature signer = Signature.getInstance("SHA256withRSA", provider);
        signer.initSign(identity.getPrivate());
        signer.update(message);
        byte[] signature = signer.sign();
        Signature verifier = Signature.getInstance("SHA256withRSA", "SunRsaSign");
        verifier.initVerify(identity.getPublic());
        verifier.update(message);
        if (!verifier.verify(signature)) {
            throw new IllegalStateException("Independent Java verification failed");
        }
        System.out.println("PASS: AutoFirma Java 17 loads and signs with the native NSS token");
    }
}
