set(TARGET_NAME "STT")

switchboard_add_console_app(${TARGET_NAME} EXTENSIONS
        SwitchboardOnnx
        SwitchboardSileroVAD
        SwitchboardWhisper
)

target_sources(${TARGET_NAME} PRIVATE
        main.cpp
)

install(
        FILES STTExample.json
        DESTINATION ${CMAKE_INSTALL_BINDIR}
)