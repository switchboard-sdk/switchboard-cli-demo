# FindSwitchboardSDK.cmake - CMake find module

# Specify the components available in SwitchboardSDK
set(SwitchboardSDK_FOUND FALSE)

if(NOT DEFINED SWITCHBOARD_PACKAGE_VERSION)
    set(SWITCHBOARD_PACKAGE_VERSION "3.2.2") # Default version
endif()

# Detect platform (adjust as needed)
if(CMAKE_SYSTEM_NAME MATCHES "Linux")
    set(SwitchboardSDK_PLATFORM "linux")
elseif(CMAKE_SYSTEM_NAME MATCHES "Darwin")
    set(SwitchboardSDK_PLATFORM "macos")
elseif(CMAKE_SYSTEM_NAME MATCHES "Windows")
    set(SwitchboardSDK_PLATFORM "windows")
else()
    message(FATAL_ERROR "Unsupported platform: ${CMAKE_SYSTEM_NAME}")
endif()

set(SwitchboardSDK_DIR "${CMAKE_BINARY_DIR}/SwitchboardSDK")

# Function to download and extract a zip package
function(download_and_extract url file_name output_dir)
    set(zip_file "${SwitchboardSDK_DIR}/Downloads/${file_name}.zip")

    # Ensure the Downloads directory exists
    file(MAKE_DIRECTORY "${SwitchboardSDK_DIR}/Downloads")

    # Download if the zip file does not exist
    if(NOT EXISTS ${zip_file})
        message(STATUS "Downloading ${file_name} from ${url}")
        file(DOWNLOAD ${url} ${zip_file}
                SHOW_PROGRESS
                STATUS download_status
                LOG download_log)
        list(GET download_status 0 status_code)
        list(GET download_status 1 status_string)
        if(NOT status_code EQUAL 0)
            message(FATAL_ERROR "Download failed with status ${status_code}: ${status_string}\nLog:\n${download_log}")
        endif()
    endif()

    # Ensure output directory exists and extract only if needed
    if(NOT EXISTS ${output_dir})
        file(MAKE_DIRECTORY ${output_dir})
        message(STATUS "Extracting ${zip_file} to ${output_dir}")
        if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
            # WINDOWS EXTRACTION — NEEDS INVESTIGATION ON A WINDOWS MACHINE
            #
            # Both extraction methods below have been tried in CI (GitHub Actions
            # windows-latest) and both silently produce an empty output directory
            # while returning exit code 0. The FATAL_ERROR at the bottom fires if
            # both produce nothing, with Expand-Archive's stdout/stderr captured
            # so you can see the actual error.
            #
            # Things to check when on Windows:
            #   1. Run cmake -B build . from the repo root and look for the
            #      "Expand-Archive exit=..." STATUS lines in the CMake output.
            #   2. Manually verify the downloaded zip is valid:
            #        7z l build/SwitchboardSDK/Downloads/SwitchboardSDK-windows-3.2.2.zip
            #   3. If 7z is available (it is on GitHub runners at C:\Program Files\7-Zip\7z.exe),
            #      consider replacing both methods below with:
            #        execute_process(COMMAND "C:/Program Files/7-Zip/7z.exe" x ${zip_file} -o${output_dir} -y)
            #   4. Check whether cmake -E tar works for the zip on your machine:
            #        cmake -E tar xf <zip> (run from an empty directory)
            #   5. The Windows SDK zip structure should be:
            #        x86_64/bin/*.dll
            #        x86_64/lib/*.lib
            #        include/   (headers at zip root, no arch prefix)
            execute_process(
                COMMAND ${CMAKE_COMMAND} -E tar xf ${zip_file}
                WORKING_DIRECTORY ${output_dir}
                RESULT_VARIABLE extract_result
            )
            file(GLOB _check_extracted "${output_dir}/*")
            if(NOT _check_extracted)
                message(STATUS "cmake -E tar produced no output, trying PowerShell Expand-Archive...")
                execute_process(
                    COMMAND powershell -NoProfile -Command
                        "Expand-Archive -LiteralPath '${zip_file}' -DestinationPath '${output_dir}' -Force"
                    RESULT_VARIABLE extract_result
                    OUTPUT_VARIABLE extract_out
                    ERROR_VARIABLE extract_err
                )
                message(STATUS "Expand-Archive exit=${extract_result} out=${extract_out} err=${extract_err}")
            endif()
        else()
            execute_process(
                COMMAND unzip -q ${zip_file} -d ${output_dir}
                RESULT_VARIABLE extract_result
            )
            if(NOT extract_result EQUAL 0)
                message(FATAL_ERROR "unzip failed (exit code ${extract_result}): ${zip_file}")
            endif()
        endif()
        file(GLOB _final_extracted "${output_dir}/*")
        if(NOT _final_extracted)
            message(FATAL_ERROR
                "Extraction of ${zip_file} produced no files in ${output_dir}.\n"
                "cmake -E tar and PowerShell Expand-Archive both failed.\n"
                "Verify the zip is a valid archive and that the download succeeded.")
        endif()
    endif()

    # Ensure extraction was successful
    if(NOT EXISTS "${output_dir}")
        message(FATAL_ERROR "Failed to extract ${file_name}")
    endif()

    # On macOS, xcframework zips omit Versions/Current and the top-level Resources
    # symlink. NSBundle bundleForClass: relies on these to locate bundled resources
    # (e.g. silero_vad.onnx). Create them if missing.
    if(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
        file(GLOB_RECURSE _all_items LIST_DIRECTORIES true "${output_dir}/*")
        foreach(_item IN LISTS _all_items)
            if(IS_DIRECTORY "${_item}" AND "${_item}" MATCHES "\\.framework$"
                    AND IS_DIRECTORY "${_item}/Versions")
                file(GLOB _ver_entries LIST_DIRECTORIES true "${_item}/Versions/*")
                set(_ver_dirs "")
                foreach(_entry IN LISTS _ver_entries)
                    if(IS_DIRECTORY "${_entry}" AND NOT IS_SYMLINK "${_entry}")
                        list(APPEND _ver_dirs "${_entry}")
                    endif()
                endforeach()
                if(_ver_dirs)
                    list(GET _ver_dirs 0 _first_ver)
                    get_filename_component(_ver_name "${_first_ver}" NAME)
                    if(NOT EXISTS "${_item}/Versions/Current")
                        file(CREATE_LINK "${_ver_name}" "${_item}/Versions/Current" SYMBOLIC)
                    endif()
                    if(IS_DIRECTORY "${_item}/Versions/${_ver_name}/Resources"
                            AND NOT EXISTS "${_item}/Resources")
                        file(CREATE_LINK "Versions/Current/Resources" "${_item}/Resources" SYMBOLIC)
                    endif()
                endif()
            endif()
        endforeach()
    endif()
endfunction()

# Function to find and set up a Switchboard package (SDK or extension)
function(find_switchboard_package PACKAGE_NAME PACKAGE_VERSION)

    # If target already exists, skip setup
    if (TARGET ${PACKAGE_NAME})
        set(${PACKAGE_NAME}_FOUND TRUE PARENT_SCOPE)
        return()
    endif ()

    # Construct the URL dynamically
    set(SWITCHBOARD_PACKAGE_URL "https://switchboard-sdk-public.s3.amazonaws.com/builds/release/${PACKAGE_VERSION}/${SwitchboardSDK_PLATFORM}/${PACKAGE_NAME}.zip")
    set(SWITCHBOARD_PACKAGE_DIR "${SwitchboardSDK_DIR}/libs/${PACKAGE_NAME}/${SwitchboardSDK_PLATFORM}/${PACKAGE_VERSION}")

    # Download and extract the package
    set(SWITCHBOARD_PACKAGE_FILE_NAME "${PACKAGE_NAME}-${SwitchboardSDK_PLATFORM}-${PACKAGE_VERSION}")
    download_and_extract(${SWITCHBOARD_PACKAGE_URL} ${SWITCHBOARD_PACKAGE_FILE_NAME} ${SWITCHBOARD_PACKAGE_DIR})

    # Define package as an INTERFACE library
    add_library(${PACKAGE_NAME} SHARED IMPORTED)
    if(${SwitchboardSDK_PLATFORM} STREQUAL "windows" AND EXISTS "${SWITCHBOARD_PACKAGE_DIR}/x86_64/include")
        target_include_directories(${PACKAGE_NAME} INTERFACE "${SWITCHBOARD_PACKAGE_DIR}/x86_64/include")
    elseif(EXISTS "${SWITCHBOARD_PACKAGE_DIR}/Release/${CMAKE_SYSTEM_PROCESSOR}/include")
        target_include_directories(${PACKAGE_NAME} INTERFACE "${SWITCHBOARD_PACKAGE_DIR}/Release/${CMAKE_SYSTEM_PROCESSOR}/include")
    elseif(EXISTS "${SWITCHBOARD_PACKAGE_DIR}/Release/include")
        target_include_directories(${PACKAGE_NAME} INTERFACE "${SWITCHBOARD_PACKAGE_DIR}/Release/include")
    elseif(EXISTS "${SWITCHBOARD_PACKAGE_DIR}/${CMAKE_SYSTEM_PROCESSOR}/Release/include")
        target_include_directories(${PACKAGE_NAME} INTERFACE "${SWITCHBOARD_PACKAGE_DIR}/${CMAKE_SYSTEM_PROCESSOR}/Release/include")
    elseif(EXISTS "${SWITCHBOARD_PACKAGE_DIR}/${CMAKE_SYSTEM_PROCESSOR}/include")
        target_include_directories(${PACKAGE_NAME} INTERFACE "${SWITCHBOARD_PACKAGE_DIR}/${CMAKE_SYSTEM_PROCESSOR}/include")
    else()
        target_include_directories(${PACKAGE_NAME} INTERFACE "${SWITCHBOARD_PACKAGE_DIR}/include")
    endif()
    if(${SwitchboardSDK_PLATFORM} STREQUAL "macos")
        if(EXISTS "${SWITCHBOARD_PACKAGE_DIR}/Release")
            set(SWITCHBOARD_PACKAGE_DIR "${SWITCHBOARD_PACKAGE_DIR}/Release")
        endif()
        set_target_properties(${PACKAGE_NAME} PROPERTIES
            IMPORTED_LOCATION "${SWITCHBOARD_PACKAGE_DIR}/${PACKAGE_NAME}.xcframework"
        )
        # if macos-arm64_x86_64 directory exists, use it
        if(EXISTS "${SWITCHBOARD_PACKAGE_DIR}/${PACKAGE_NAME}.xcframework/macos-arm64_x86_64")
            set(FRAMEWORK_PATH "${SWITCHBOARD_PACKAGE_DIR}/${PACKAGE_NAME}.xcframework/macos-arm64_x86_64/${PACKAGE_NAME}.framework")
        else()
            set(FRAMEWORK_PATH "${SWITCHBOARD_PACKAGE_DIR}/${PACKAGE_NAME}.xcframework/macos-arm64/${PACKAGE_NAME}.framework")
        endif()
        set(SwitchboardSDK_FRAMEWORK_PATHS ${SwitchboardSDK_FRAMEWORK_PATHS} ${FRAMEWORK_PATH} PARENT_SCOPE)
    elseif(${SwitchboardSDK_PLATFORM} STREQUAL "windows")
        # MSVC reports AMD64 but SDK packages use x86_64
        set(_WIN_ARCH ${CMAKE_SYSTEM_PROCESSOR})
        if(_WIN_ARCH STREQUAL "AMD64")
            set(_WIN_ARCH "x86_64")
        endif()
        if(EXISTS "${SWITCHBOARD_PACKAGE_DIR}/${_WIN_ARCH}/lib")
            set_target_properties(${PACKAGE_NAME} PROPERTIES
                IMPORTED_IMPLIB_RELEASE "${SWITCHBOARD_PACKAGE_DIR}/${_WIN_ARCH}/lib/${PACKAGE_NAME}.lib"
                IMPORTED_LOCATION_RELEASE "${SWITCHBOARD_PACKAGE_DIR}/${_WIN_ARCH}/bin/${PACKAGE_NAME}.dll"
                IMPORTED_IMPLIB "${SWITCHBOARD_PACKAGE_DIR}/${_WIN_ARCH}/lib/${PACKAGE_NAME}.lib"
                IMPORTED_LOCATION "${SWITCHBOARD_PACKAGE_DIR}/${_WIN_ARCH}/bin/${PACKAGE_NAME}.dll"
            )
        elseif(EXISTS "${SWITCHBOARD_PACKAGE_DIR}/${CMAKE_SYSTEM_PROCESSOR}/Release/lib")
            set_target_properties(${PACKAGE_NAME} PROPERTIES
                IMPORTED_IMPLIB_RELEASE "${SWITCHBOARD_PACKAGE_DIR}/${CMAKE_SYSTEM_PROCESSOR}/Release/lib/${PACKAGE_NAME}.lib"
                IMPORTED_LOCATION_RELEASE "${SWITCHBOARD_PACKAGE_DIR}/${CMAKE_SYSTEM_PROCESSOR}/Release/bin/${PACKAGE_NAME}.dll"
                IMPORTED_IMPLIB "${SWITCHBOARD_PACKAGE_DIR}/${CMAKE_SYSTEM_PROCESSOR}/Debug/lib/${PACKAGE_NAME}.lib"
                IMPORTED_LOCATION "${SWITCHBOARD_PACKAGE_DIR}/${CMAKE_SYSTEM_PROCESSOR}/Debug/bin/${PACKAGE_NAME}.dll"
            )
        elseif(EXISTS "${SWITCHBOARD_PACKAGE_DIR}/Release/${CMAKE_SYSTEM_PROCESSOR}/lib" AND EXISTS "${SWITCHBOARD_PACKAGE_DIR}/Debug/${CMAKE_SYSTEM_PROCESSOR}/lib"
            AND EXISTS "${SWITCHBOARD_PACKAGE_DIR}/Release/${CMAKE_SYSTEM_PROCESSOR}/bin" AND EXISTS "${SWITCHBOARD_PACKAGE_DIR}/Debug/${CMAKE_SYSTEM_PROCESSOR}/bin")
            set_target_properties(${PACKAGE_NAME} PROPERTIES
                IMPORTED_IMPLIB_RELEASE "${SWITCHBOARD_PACKAGE_DIR}/Release/${CMAKE_SYSTEM_PROCESSOR}/lib/${PACKAGE_NAME}.lib"
                IMPORTED_LOCATION_RELEASE "${SWITCHBOARD_PACKAGE_DIR}/Release/${CMAKE_SYSTEM_PROCESSOR}/bin/${PACKAGE_NAME}.dll"
                IMPORTED_IMPLIB "${SWITCHBOARD_PACKAGE_DIR}/Debug/${CMAKE_SYSTEM_PROCESSOR}/lib/${PACKAGE_NAME}.lib"
                IMPORTED_LOCATION "${SWITCHBOARD_PACKAGE_DIR}/Debug/${CMAKE_SYSTEM_PROCESSOR}/bin/${PACKAGE_NAME}.dll"
            )
        else()
            set_target_properties(${PACKAGE_NAME} PROPERTIES
                    IMPORTED_IMPLIB_RELEASE "${SWITCHBOARD_PACKAGE_DIR}/Release/${CMAKE_SYSTEM_PROCESSOR}/${PACKAGE_NAME}.lib"
                    IMPORTED_LOCATION_RELEASE "${SWITCHBOARD_PACKAGE_DIR}/Release/${CMAKE_SYSTEM_PROCESSOR}/${PACKAGE_NAME}.dll"
                    IMPORTED_IMPLIB "${SWITCHBOARD_PACKAGE_DIR}/Debug/${CMAKE_SYSTEM_PROCESSOR}/${PACKAGE_NAME}.lib"
                    IMPORTED_LOCATION "${SWITCHBOARD_PACKAGE_DIR}/Debug/${CMAKE_SYSTEM_PROCESSOR}/${PACKAGE_NAME}.dll"
            )
        endif()
    elseif(${SwitchboardSDK_PLATFORM} STREQUAL "linux")
        if(EXISTS "${SWITCHBOARD_PACKAGE_DIR}/${CMAKE_SYSTEM_PROCESSOR}/lib")
            set_target_properties(${PACKAGE_NAME} PROPERTIES
                    IMPORTED_LOCATION "${SWITCHBOARD_PACKAGE_DIR}/${CMAKE_SYSTEM_PROCESSOR}/lib/lib${PACKAGE_NAME}.so"
            )
        elseif(EXISTS "${SWITCHBOARD_PACKAGE_DIR}/Release/${CMAKE_SYSTEM_PROCESSOR}/lib")
            set_target_properties(${PACKAGE_NAME} PROPERTIES
                    IMPORTED_LOCATION "${SWITCHBOARD_PACKAGE_DIR}/Release/${CMAKE_SYSTEM_PROCESSOR}/lib/lib${PACKAGE_NAME}.so"
            )
        else()
            set_target_properties(${PACKAGE_NAME} PROPERTIES
                IMPORTED_LOCATION "${SWITCHBOARD_PACKAGE_DIR}/Release/${CMAKE_SYSTEM_PROCESSOR}/lib${PACKAGE_NAME}.so"
            )
        endif()
    else ()
        message(FATAL_ERROR "Unsupported platform: ${CMAKE_SYSTEM_NAME}")
    endif()

    # Mark as found
    set(${PACKAGE_NAME}_FOUND TRUE PARENT_SCOPE)
endfunction()

find_switchboard_package("SwitchboardSDK" "${SWITCHBOARD_PACKAGE_VERSION}")
if (SwitchboardSDK_FOUND)
    set(SwitchboardSDK_LIBRARIES ${SwitchboardSDK_LIBRARIES} "SwitchboardSDK")
    set(_sdk_base "${SwitchboardSDK_DIR}/libs/SwitchboardSDK/${SwitchboardSDK_PLATFORM}/${SWITCHBOARD_PACKAGE_VERSION}")
    if(EXISTS "${_sdk_base}/x86_64/bin")
        set(SwitchboardSDK_PACKAGE_DIRECTORIES_RELEASE ${SwitchboardSDK_PACKAGE_DIRECTORIES_RELEASE} "${_sdk_base}/x86_64/bin")
    elseif(EXISTS "${_sdk_base}/${CMAKE_SYSTEM_PROCESSOR}/Release")
        set(SwitchboardSDK_PACKAGE_DIRECTORIES_RELEASE ${SwitchboardSDK_PACKAGE_DIRECTORIES_RELEASE} "${_sdk_base}/${CMAKE_SYSTEM_PROCESSOR}/Release")
    else()
        set(SwitchboardSDK_PACKAGE_DIRECTORIES_RELEASE ${SwitchboardSDK_PACKAGE_DIRECTORIES_RELEASE} "${_sdk_base}/Release/${CMAKE_SYSTEM_PROCESSOR}")
    endif()
else()
    message(SEND_ERROR "Could not find SwitchboardSDK")
endif ()

# Check if required components are specified
set(_missing_components "")
foreach(_comp IN LISTS SwitchboardSDK_FIND_COMPONENTS)
    find_switchboard_package(${_comp} "${SWITCHBOARD_PACKAGE_VERSION}")
    if(${_comp}_FOUND)
        set(package_dir "${SwitchboardSDK_DIR}/libs/${_comp}/${SwitchboardSDK_PLATFORM}/${SWITCHBOARD_PACKAGE_VERSION}")
        message(STATUS "Found SwitchboardSDK component: ${_comp} at ${package_dir}")
        if(EXISTS "${package_dir}/x86_64/bin")
            message(STATUS "Adding ${package_dir}/x86_64/bin to package directories for ${_comp}")
            set(SwitchboardSDK_PACKAGE_DIRECTORIES_RELEASE ${SwitchboardSDK_PACKAGE_DIRECTORIES_RELEASE} "${package_dir}/x86_64/bin")
        elseif(EXISTS "${package_dir}/${CMAKE_SYSTEM_PROCESSOR}/Release/bin")
            message(STATUS "Adding ${package_dir}/${CMAKE_SYSTEM_PROCESSOR}/Release/bin to package directories for ${_comp}")
            set(SwitchboardSDK_PACKAGE_DIRECTORIES_RELEASE ${SwitchboardSDK_PACKAGE_DIRECTORIES_RELEASE} "${package_dir}/${CMAKE_SYSTEM_PROCESSOR}/Release/bin")
        elseif(EXISTS "${package_dir}/Release/${CMAKE_SYSTEM_PROCESSOR}/bin")
            message(STATUS "Adding ${package_dir}/Release/${CMAKE_SYSTEM_PROCESSOR}/bin to package directories for ${_comp}")
            set(SwitchboardSDK_PACKAGE_DIRECTORIES_RELEASE ${SwitchboardSDK_PACKAGE_DIRECTORIES_RELEASE} "${package_dir}/Release/${CMAKE_SYSTEM_PROCESSOR}/bin")
        elseif(EXISTS "${package_dir}/${CMAKE_SYSTEM_PROCESSOR}/Release")
            message(STATUS "Adding ${package_dir}/${CMAKE_SYSTEM_PROCESSOR}/Release to package directories for ${_comp}")
            set(SwitchboardSDK_PACKAGE_DIRECTORIES_RELEASE ${SwitchboardSDK_PACKAGE_DIRECTORIES_RELEASE} "${package_dir}/${CMAKE_SYSTEM_PROCESSOR}/Release")
        else()
            message(STATUS "Adding ${package_dir}/Release/${CMAKE_SYSTEM_PROCESSOR} to package directories for ${_comp}")
            set(SwitchboardSDK_PACKAGE_DIRECTORIES_RELEASE ${SwitchboardSDK_PACKAGE_DIRECTORIES_RELEASE} "${package_dir}/Release/${CMAKE_SYSTEM_PROCESSOR}")
        endif()
        set(SwitchboardSDK_LIBRARIES ${SwitchboardSDK_LIBRARIES} ${_comp})
    else()
        list(APPEND _missing_components ${_comp})
    endif ()
endforeach()

# If any required component is missing, fail
if(_missing_components)
    set(SwitchboardSDK_FOUND FALSE)
    message(SEND_ERROR "Missing SwitchboardSDK components: ${_missing_components}")
else()
    set(SwitchboardSDK_FOUND TRUE)
endif()
