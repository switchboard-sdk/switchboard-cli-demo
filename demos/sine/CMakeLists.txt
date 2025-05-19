set(TARGET_NAME "Sine")

switchboard_add_console_app(${TARGET_NAME})

target_sources(${TARGET_NAME} PRIVATE
    main.cpp
)

install(
    FILES SineExample.json
    DESTINATION ${CMAKE_INSTALL_BINDIR}
)