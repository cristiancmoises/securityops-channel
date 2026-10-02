// SPDX-License-Identifier: GPL-3.0-or-later
#include <digidocpp/Conf.h>
#include <digidocpp/Container.h>
#include <digidocpp/DataFile.h>
#include <digidocpp/Signature.h>
#include <dlfcn.h>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <iterator>
#include <stdexcept>

using namespace digidoc;
namespace fs = std::filesystem;

class FixtureConf : public ConfCurrent {
    std::string fixtures;
public:
    explicit FixtureConf(std::string path) : fixtures(std::move(path)) {}
    bool TSLAutoUpdate() const override { return false; }
    bool TSLOnlineDigest() const override { return false; }
    std::string TSLCache() const override { return fixtures; }
    std::string TSLUrl() const override { return fixtures + "/TSL.xml"; }
    std::vector<X509Cert> TSLCerts() const override {
        return {X509Cert(fixtures + "/TSL.crt", X509Cert::Pem)};
    }
};

int main(int argc, char **argv) {
    if (argc != 2) return 2;
    const auto fixtures = fs::absolute(argv[1]).string();
    unsigned passed = 0;
    auto require = [&](bool condition, const char *name) {
        if (!condition) throw std::runtime_error(name);
        std::cout << "PASS " << name << '\n';
        ++passed;
    };
    auto rejected = [&](auto operation, const char *name) {
        bool caught = false;
        try { operation(); } catch (const Exception &) { caught = true; }
        require(caught, name);
    };
    try {
        Conf::init(new FixtureConf(fixtures));
        initialize("guix-installed-acceptance");
        require(version().starts_with("4.5.0"), "installed version");
        const auto xmlVersion = static_cast<const char **>(dlsym(RTLD_DEFAULT, "xmlParserVersion"));
        const auto xsltVersion = static_cast<const int *>(dlsym(RTLD_DEFAULT, "xsltLibxsltVersion"));
        const auto sslVersion = reinterpret_cast<const char *(*)(int)>(
            dlsym(RTLD_DEFAULT, "OpenSSL_version"));
        require(xmlVersion && *xmlVersion && std::string(*xmlVersion) == "21504",
                "loaded libxml2 2.15.4");
        require(xsltVersion && *xsltVersion == 10145, "loaded libxslt 1.1.45");
        require(sslVersion && std::string(sslVersion(0)).starts_with("OpenSSL 3.5.9 "),
                "loaded OpenSSL 3.5.9");
        for (const char *symbol : {"xmlParserVersion", "xsltLibxsltVersion", "OpenSSL_version"}) {
            Dl_info library{};
            if (!dladdr(dlsym(RTLD_DEFAULT, symbol), &library) || !library.dli_fname)
                throw std::runtime_error("could not resolve loaded dependency path");
            std::cout << "LOADED " << symbol << " " << library.dli_fname << '\n';
        }
        std::ofstream("payload.txt") << "installed ASiC round trip\n";
        auto doc = Container::createPtr("roundtrip.asice");
        doc->addDataFile("payload.txt", "text/plain");
        doc->save();
        doc = Container::openPtr("roundtrip.asice");
        require(doc->dataFiles().size() == 1 && doc->signatures().empty(),
                "unsigned ASiC-E round trip counts");
        doc->dataFiles().front()->saveAs("extracted.txt");
        std::ifstream extracted("extracted.txt");
        std::string text((std::istreambuf_iterator<char>(extracted)), {});
        require(text == "installed ASiC round trip\n", "ASiC-E payload bytes");
        doc = Container::openPtr(fixtures + "/test.asics");
        require(doc->signatures().size() == 1, "ASiC-S fixture signature");
        doc->signatures().front()->validate();
        require(true, "ASiC-S fixture validates offline");
        doc->save("roundtrip.asics");
        doc = Container::openPtr("roundtrip.asics");
        require(doc->dataFiles().size() == 1 && doc->signatures().size() == 1,
                "signed ASiC-S round trip counts");
        doc->signatures().front()->validate();
        require(true, "ASiC-S round trip validates offline");
        doc = Container::openPtr(fixtures + "/test-tera-empty.asics");
        require(doc->dataFiles().size() == 1 && doc->dataFiles().front()->fileSize() == 0,
                "legitimate empty ZIP payload accepted");
        doc->signatures().front()->validate();
        require(true, "empty payload timestamp validates offline");

        // Preserve compressed bytes and CRC, but lie about their expanded size
        // in both ZIP headers. Opening must reject this before validation.
        std::ifstream zip(fixtures + "/test.asics", std::ios::binary);
        std::vector<unsigned char> bytes((std::istreambuf_iterator<char>(zip)), {});
        const auto originalBytes = bytes;
        auto u16 = [&](size_t pos) -> unsigned {
            return bytes.at(pos) | (unsigned(bytes.at(pos + 1)) << 8);
        };
        auto u32 = [&](size_t pos) -> unsigned {
            return u16(pos) | (u16(pos + 2) << 16);
        };
        bool changed = false;
        for (size_t pos = 0; pos + 46 <= bytes.size(); ++pos) {
            if (u32(pos) != 0x02014b50) continue;
            const auto length = u16(pos + 28);
            if (pos + 46 + length > bytes.size()) continue;
            std::string name(bytes.begin() + pos + 46, bytes.begin() + pos + 46 + length);
            if (name != "test1.txt") continue;
            const auto local = u32(pos + 42);
            require(u32(local) == 0x04034b50 && u32(pos + 24) > 0,
                    "forged-size fixture begins as a nonempty ZIP entry");
            for (unsigned i = 0; i < 4; ++i) {
                bytes.at(pos + 24 + i) = 0;
                bytes.at(local + 22 + i) = 0;
            }
            changed = true;
        }
        if (!changed) throw std::runtime_error("ZIP data entry not found");
        std::ofstream forged("forged-size.asics", std::ios::binary);
        forged.write(reinterpret_cast<const char *>(bytes.data()), bytes.size());
        forged.close();
        if (!forged.good()) throw std::runtime_error("could not write forged ZIP fixture");
        rejected([&] { Container::openPtr("forged-size.asics"); },
                 "nonempty entry with forged zero size rejected on open");
        if (originalBytes.size() < 22) throw std::runtime_error("ZIP fixture too short");
        std::ofstream truncated("truncated.asics", std::ios::binary);
        truncated.write(reinterpret_cast<const char *>(originalBytes.data()), originalBytes.size() - 22);
        truncated.close();
        if (!truncated.good()) throw std::runtime_error("could not write truncated ZIP fixture");
        std::ifstream truncatedInput("truncated.asics", std::ios::binary);
        const std::vector<unsigned char> truncatedBytes(
            (std::istreambuf_iterator<char>(truncatedInput)), {});
        require(truncatedBytes == std::vector<unsigned char>(
                    originalBytes.begin(), originalBytes.end() - 22),
                "truncation changes only untouched valid archive tail");
        rejected([&] { Container::openPtr("truncated.asics"); }, "truncated ZIP rejected");
        doc = Container::openPtr(fixtures + "/test-invalidts.asics");
        require(doc->signatures().size() == 1, "tampered ASiC-S has signature");
        rejected([&] { doc->signatures().front()->validate(); },
                 "tampered timestamp rejected");
        doc = Container::openPtr(fixtures + "/forged_lt.asice");
        require(!doc->signatures().empty(), "forged ASiC-E has signature");
        rejected([&] { doc->signatures().front()->validate(); },
                 "key substitution rejected");
        for (const char *file : {"asice-relative.asice", "dot.asice", "pt-empty.asice",
                                  "asics-subfolder.asics", "test-invalid.asics"}) {
            rejected([&] { Container::openPtr(fixtures + "/" + file); }, file);
        }
        terminate();
        std::cout << passed << " installed acceptance checks passed\n";
        return 0;
    } catch (const Exception &e) {
        std::cerr << "FAIL libdigidocpp: " << e.msg() << '\n';
    } catch (const std::exception &e) {
        std::cerr << "FAIL " << e.what() << '\n';
    }
    terminate();
    return 1;
}
