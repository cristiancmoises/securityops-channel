// SPDX-License-Identifier: GPL-3.0-or-later
import java.nio.file.Path;
import de.kosit.validationtool.api.Configuration;
import de.kosit.validationtool.impl.ResolvingMode;
import de.kosit.validationtool.impl.xml.ProcessorProvider;

/** Exercise the non-default mode addressed by GHSA-hg2c-p2m3-q29m. */
public final class StrictLocalProbe {
    public static void main(String[] args) throws Exception {
        Path repository = Path.of(args[0]);
        Configuration.load(repository.resolve("scenarios.xml").toUri(),
                repository.toUri())
                .setResolvingMode(ResolvingMode.STRICT_LOCAL)
                .build(ProcessorProvider.getProcessor());
        System.out.println("Complete configuration loaded in STRICT_LOCAL mode");
    }
}
