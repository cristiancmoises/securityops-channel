// SPDX-License-Identifier: GPL-3.0-or-later
import java.nio.charset.StandardCharsets;

/** Check the actual PATH and child-process runtime inside the compatibility view. */
public final class AutofirmaNssTools {
    public static void premain(String ignored) throws Exception {
        Process child = new ProcessBuilder("certutil", "-L", "-d",
                "sql:" + System.getProperty("afirma.test.nss.db"),
                "-n", "autofirma-nss-test")
                .redirectErrorStream(true).start();
        String listing = new String(child.getInputStream().readAllBytes(),
                StandardCharsets.UTF_8);
        if (child.waitFor() != 0 || !listing.contains("AutoFirma NSS package test")) {
            throw new IllegalStateException("certutil failed inside compatibility view: " + listing);
        }
        System.out.println("PASS: certutil reads the disposable NSS identity inside compatibility view");
    }
}
