
#include "SherpaExtension.hpp"

#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <switchboard/Switchboard.hpp>

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
    extensions::sherpa::SherpaExtension::load();
    Config sdkConfig({
        { "appID", "demo" },
        { "appSecret", "demo" },
        { "extensions", Config({
            {"Sherpa", Config()}
        })}
    });
    Switchboard::initialize(sdkConfig);
    
    // Create audio engine
    Result<Switchboard::ObjectID> result = Switchboard::createEngine(engineJSON.value());
    if (result.isError()) {
        std::cerr << "Failed to create engine: " << result.error().message << std::endl;
        return 1;
    }
    const std::string engineID = result.value();

    // Start audio engine
    auto startEngineResult = Switchboard::callAction(engineID, "start", {});
    if (startEngineResult.isError()) {
        std::cerr << "Failed to start engine: " << startEngineResult.error().message << std::endl;
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
        auto synthesizeResult = Switchboard::callAction("ttsNode", "synthesize", { { "text", text } });
        if (synthesizeResult.isError()) {
            std::cerr << "Failed to synthesize text: " << synthesizeResult.error().message << std::endl;
        } else {
            std::cout << "Synthesis successful for text: " << text << std::endl;
        }
    }

    // Stop and tear down audio engine
    Switchboard::callAction(engineID, "stop", {});
    Switchboard::destroyEngine(engineID);
    return 0;
}