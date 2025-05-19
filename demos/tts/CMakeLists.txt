set(TARGET_NAME "TTS")

switchboard_add_console_app(${TARGET_NAME} EXTENSIONS
        SwitchboardSherpa
)

target_sources(${TARGET_NAME} PRIVATE
        main.cpp
)

install(
        FILES TTSExample.json
        DESTINATION ${CMAKE_INSTALL_BINDIR}
)