set(TARGET_NAME "STTtoTTS")

switchboard_add_console_app(${TARGET_NAME} EXTENSIONS
        SwitchboardOnnx
        SwitchboardSherpa
        SwitchboardSileroVAD
        SwitchboardWhisper
)

target_sources(${TARGET_NAME} PRIVATE
        main.cpp
)

install(
        FILES STTtoTTSExample.json
        DESTINATION ${CMAKE_INSTALL_BINDIR}
)