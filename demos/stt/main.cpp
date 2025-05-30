
#include "SileroVADExtension.hpp"
#include "WhisperExtension.hpp"

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
    std::string engineJSONFilePath = "STTExample.json";
    auto engineJSON = readContentsOfTextFile(engineJSONFilePath);
    if (!engineJSON.has_value()) {
        std::cerr << "Failed to read engine JSON file: " << engineJSONFilePath << std::endl;
        return 1;
    }

    // Init Switchboard SDK and extensions
    Config sdkConfig({ { "appID", "demo" }, { "appSecret", "demo" } });
    SwitchboardV3::initialize(sdkConfig);
    extensions::silerovad::SileroVADExtension::initialize();
    extensions::whisper::WhisperExtension::initialize();

    // Create audio engine
    Result<SwitchboardV3::ObjectID> result = SwitchboardV3::createEngine(engineJSON.value());
    if (result.isError()) {
        std::cerr << "Failed to create engine: " << result.error().value().message << std::endl;
        return 1;
    }
    const std::string engineID = result.value().value();

    // Add listener for transcription event
    SwitchboardV3::addEventListener("sttNode", "transcription", [](const std::any& data) {
        const auto text = std::any_cast<std::string>(data);
        std::cout << "STT node transcribed: " << text << std::endl;
    });

    // Start audio engine
    auto startEngineResult = SwitchboardV3::callAction(engineID, "start", {});
    if (startEngineResult.isError()) {
        std::cerr << "Failed to start engine: " << startEngineResult.error().value().message << std::endl;
        return 1;
    }

    // Wait for user to press a key
    std::cout << "Press any key to stop the engine..." << std::endl;
    std::cin.get();

    // Stop and tear down audio engine
    SwitchboardV3::callAction(engineID, "stop", {});
    SwitchboardV3::destroyObject(engineID);
    return 0;
}