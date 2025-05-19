set(TARGET_NAME "SileroVAD")

switchboard_add_console_app(${TARGET_NAME} EXTENSIONS
        SwitchboardOnnx
        SwitchboardSileroVAD
)

target_sources(${TARGET_NAME} PRIVATE
        main.cpp
)

install(
        FILES SileroVADExample.json
        DESTINATION ${CMAKE_INSTALL_BINDIR}
)