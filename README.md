# SwitchboardCLIDemo

This lightweight C++ project includes multiple CLI demo apps showcasing the capabilities of the Switchboard SDK, such as speech-to-text (STT), text-to-speech (TTS), and voice activity detection (VAD). Built with CMake for easy cross-platform support, it runs seamlessly on Windows, Linux, and macOS—making it an ideal starting point for exploring and integrating audio features into your own applications.

## Prerequisites

Ensure you have the following installed:
- **CMake** (>= 3.28)
- **C++ compiler** (e.g., GCC, Clang, MSVC)

## Build & Run

### macOS

```bash
inv build-macos --clean
cd out/bin
./Sine # or ./TTS ./STT ./STTtoTTS 
```

### Windows

```bash
inv build-windows --clean
cd out/bin
./Sine.exe # or ./TTS.exe ./STT.exe ./STTtoTTS.exe
```

### Linux

```bash
inv build-linux --clean
cd out/bin
./Sine # or ./TTS ./STT ./STTtoTTS 
```
