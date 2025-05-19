
#include "SherpaExtension.hpp"

#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <switchboard/SwitchboardV3.hpp>

using namespace switchboard;

static std::optional<std::string> readContentsOfTextFile(const std::string& filePath) {
    std::filesystem::path fileSystemPath(filePath);
    if (!std::filesystem::exists(filePath)) {
        return std::nullopt;
    }
    std::ifstream fileStream(filePath);
    std::string fileContent((std::istreambuf_iterator<char>(fileStream)), std::istreambuf_iterator<char>());
    return fileContent;
}

int main(int argc, const char* argv[]) {
    // Load JSON
    std::string engineJSONFilePath = "TTSExample.json";
    auto engineJSON = readContentsOfTextFile(engineJSONFilePath);
    if (!engineJSON.has_value()) {
        std::cerr << "Failed to read engine JSON file: " << engineJSONFilePath << std::endl;
        return 1;
    }

    // Init Switchboard SDK and extensions
    Config sdkConfig({ { "appID", "demo" }, { "appSecret", "demo" } });
    SwitchboardV3::initialize(sdkConfig);
    extensions::sherpa::SherpaExtension::initialize();

    // Create audio engine
    Result<SwitchboardV3::ObjectID> result = SwitchboardV3::createEngine(engineJSON.value());
    if (result.isError()) {
        std::cerr << "Failed to create engine: " << result.error().value().message << std::endl;
        return 1;
    }
    const std::string engineID = result.value().value();

    // Start audio engine
    auto startEngineResult = SwitchboardV3::callAction(engineID, "start", {});
    if (startEngineResult.isError()) {
        std::cerr << "Failed to start engine: " << startEngineResult.error().value().message << std::endl;
        return 1;
    }
    // Loop to allow user to enter text and synthesize
    std::string text;
    while (true) {
        std::cout << "Enter text to synthesize (or press ESC and Enter to exit): " << std::endl;
        std::getline(std::cin, text);

        // Exit on ESC key
        if (text == "\x1b") { // ASCII code for ESC
            break;
        }

        // Call synthesize action with the entered text
        auto synthesizeResult = SwitchboardV3::callAction("ttsNode", "synthesize", { { "text", text } });
        if (synthesizeResult.isError()) {
            std::cerr << "Failed to synthesize text: " << synthesizeResult.error().value().message << std::endl;
        } else {
            std::cout << "Synthesis successful for text: " << text << std::endl;
        }
    }

    // Stop and tear down audio engine
    SwitchboardV3::callAction(engineID, "stop", {});
    SwitchboardV3::destroyObject(engineID);
    return 0;
}