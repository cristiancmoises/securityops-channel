/* SPDX-License-Identifier: GPL-3.0-or-later */
import java.io.StringReader;
import java.io.StringWriter;
import java.net.URI;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.concurrent.atomic.AtomicInteger;
import javax.xml.XMLConstants;
import javax.xml.transform.TransformerException;
import javax.xml.transform.stream.StreamSource;
import javax.xml.transform.stream.StreamResult;
import javax.xml.validation.SchemaFactory;
import org.xml.sax.SAXException;
import jakarta.xml.bind.JAXBContext;
import com.helger.phive.ves.v10.VesType;

/** Offline acceptance fixture; not a PHIVE application or default-policy patch. */
public final class PhiveOfflineProbe {
    private static void require(boolean value, String message) {
        if (!value) throw new AssertionError(message);
    }

    private static void installed(Class<?> type, Path prefix) throws Exception {
        Path location = Path.of(type.getProtectionDomain().getCodeSource().getLocation().toURI());
        require(location.startsWith(prefix.resolve("share/phive/lib")),
                "class not loaded from the installed runtime: " + type.getName());
        System.out.println("CLASS: " + type.getName() + " from " + location.getFileName());
    }

    private static void schemaPolicy(Path work) throws Exception {
        Path included = work.resolve("owned-types.xsd");
        Files.writeString(included, """
            <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
              <xs:element name="value" type="xs:integer"/>
            </xs:schema>
            """);
        String root = "<xs:schema xmlns:xs='http://www.w3.org/2001/XMLSchema'>"
                + "<xs:include schemaLocation='" + included.toUri() + "'/></xs:schema>";
        SchemaFactory denied = SchemaFactory.newInstance(XMLConstants.W3C_XML_SCHEMA_NS_URI);
        denied.setProperty(XMLConstants.ACCESS_EXTERNAL_DTD, "");
        denied.setProperty(XMLConstants.ACCESS_EXTERNAL_SCHEMA, "");
        try {
            denied.newSchema(new StreamSource(new StringReader(root)));
            throw new AssertionError("configured schema policy allowed an external resource");
        } catch (SAXException expected) {
            require(expected.getMessage().contains("accessExternalSchema"),
                    "schema refused for an unrelated reason: " + expected.getMessage());
        }
        // Same otherwise-valid owned schema, with an explicit file-only policy.
        SchemaFactory allowed = SchemaFactory.newInstance(XMLConstants.W3C_XML_SCHEMA_NS_URI);
        allowed.setProperty(XMLConstants.ACCESS_EXTERNAL_DTD, "");
        allowed.setProperty(XMLConstants.ACCESS_EXTERNAL_SCHEMA, "file");
        allowed.newSchema(new StreamSource(new StringReader(root))).newValidator()
                .validate(new StreamSource(new StringReader("<value>42</value>")));
        System.out.println("PASS: configured schema-resource refusal and owned-file positive");
    }

    private static void stylesheetPolicy(Path work) throws Exception {
        Path included = work.resolve("owned-template.xsl");
        Files.writeString(included, """
            <xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
              <xsl:template match="/"><owned>42</owned></xsl:template>
            </xsl:stylesheet>
            """);
        String root = "<xsl:stylesheet version='2.0' "
                + "xmlns:xsl='http://www.w3.org/1999/XSL/Transform'>"
                + "<xsl:include href='" + included.toUri() + "'/></xsl:stylesheet>";
        AtomicInteger refusals = new AtomicInteger();
        var denied = new net.sf.saxon.TransformerFactoryImpl();
        denied.setURIResolver((href, base) -> {
            refusals.incrementAndGet();
            throw new TransformerException("fixture resource policy denied");
        });
        try {
            denied.newTemplates(new StreamSource(new StringReader(root)));
            throw new AssertionError("configured stylesheet resolver permitted the resource");
        } catch (TransformerException expected) {
            require(refusals.get() == 1, "configured refusal callback not reached exactly once");
            require(expected.getMessage().contains("fixture resource policy denied"),
                    "stylesheet refused for an unrelated reason: " + expected.getMessage());
        }
        AtomicInteger resolutions = new AtomicInteger();
        var allowed = new net.sf.saxon.TransformerFactoryImpl();
        allowed.setURIResolver((href, base) -> {
            if (!URI.create(href).equals(included.toUri()))
                throw new TransformerException("resource outside the owned fixture");
            resolutions.incrementAndGet();
            return new StreamSource(included.toFile());
        });
        var transformer = allowed.newTemplates(new StreamSource(new StringReader(root))).newTransformer();
        StringWriter result = new StringWriter();
        transformer.transform(new StreamSource(new StringReader("<input/>")), new StreamResult(result));
        require(resolutions.get() == 1 && result.toString().contains("<owned>42</owned>"),
                "owned stylesheet positive did not render");
        System.out.println("PASS: configured stylesheet-resource refusal and owned-file positive");
    }

    public static void main(String[] args) throws Exception {
        require(args.length == 1, "expected the immutable package prefix");
        Path prefix = Path.of(args[0]).toRealPath();
        require(System.getProperty("java.runtime.version").startsWith("17.0.20.1"),
                "unexpected selected Java runtime: " + System.getProperty("java.runtime.version"));
        for (String name : new String[] {
                "com.helger.phive.api.execute.ValidationExecutionManager",
                "com.helger.phive.xml.source.ValidationSourceXML",
                "com.helger.phive.ves.model.v1.VES1Marshaller",
                "com.helger.phive.ves.repo.RepoVESTopTocServiceCSV",
                "com.helger.phive.xml.xsd.ValidationExecutorXSD",
                "com.helger.phive.result.xml.PhiveXMLHelper",
                "com.helger.phive.result.html.PhiveHtmlHelper",
                "com.helger.phive.ves.engine.load.VESLoader"}) {
            installed(Class.forName(name), prefix);
        }
        JAXBContext context = JAXBContext.newInstance(VesType.class);
        installed(context.getClass(), prefix);
        require(context.getClass().getName().startsWith("org.glassfish.jaxb.runtime."),
                "reference JAXB implementation was not selected");
        System.out.println("RUNTIME: " + System.getProperty("java.runtime.version"));
        Path work = Files.createTempDirectory("phive-owned-resources-");
        schemaPolicy(work);
        stylesheetPolicy(work);
        System.out.println("PASS: eight installed framework modules and reference JAXB provider");
    }
}
