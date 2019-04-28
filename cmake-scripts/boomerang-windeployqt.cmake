# Adapted from https://raw.githubusercontent.com/nitroshare/nitroshare-desktop/226dd32879981c0bf2ef4c78faee3af3b797bfdc/cmake/Windeployqt.cmake

# The MIT License (MIT)
#
# Copyright (c) 2017 Nathan Osman
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

find_package(Qt5 COMPONENTS Core REQUIRED HINTS $ENV{QTDIR})
if (Qt5_FOUND)
    mark_as_advanced(Qt5_DIR Qt5Core_DIR)
endif (Qt5_FOUND)

# Retrieve the absolute path to qmake and then use that path to find
# the windeployqt binary
get_target_property(_qmake_executable Qt5::qmake IMPORTED_LOCATION)
get_filename_component(_qt_bin_dir "${_qmake_executable}" DIRECTORY)
find_program(WINDEPLOYQT_EXECUTABLE windeployqt HINTS "${_qt_bin_dir}")


# Add commands that copy the Qt runtime to the target's output directory after
# build and install the Qt runtime to the specified directory
function(BOOMERANG_WINDEPLOYQT target directory)

    # Run windeployqt immediately after build
    add_custom_command(TARGET ${target} POST_BUILD
        COMMAND "${CMAKE_COMMAND}" ARGS -E
            env PATH="${_qt_bin_dir}" "${WINDEPLOYQT_EXECUTABLE}"
                --verbose 0
                --no-compiler-runtime
                --no-angle
                --no-opengl-sw
                --no-quick-import
                --no-translations
                --no-system-d3d-compiler
                --no-webkit2
                \"$<TARGET_FILE:${target}>\"
        COMMENT "Deploying Qt..."
    )

    # install(CODE ...) doesn't support generator expressions, but
    # file(GENERATE ...) does - store the path in a file
    file(GENERATE OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${target}"
        CONTENT "$<TARGET_FILE:${target}>"
    )

    # Before installation, run a series of commands that copy each of the Qt
    # runtime files to the appropriate directory for installation
    install(CODE
        "
        file(READ \"${CMAKE_CURRENT_BINARY_DIR}/${target}\" _file)
        execute_process(
            COMMAND \"${CMAKE_COMMAND}\" -E
                env PATH=\"${_qt_bin_dir}\" \"${WINDEPLOYQT_EXECUTABLE}\"
                    --dry-run
                    --no-angle
                    --no-opengl-sw
                    --no-quick-import
                    --no-translations
                    --no-system-d3d-compiler
                    --no-webkit2
                    --list mapping
                    \${_file}
            OUTPUT_VARIABLE _output
            OUTPUT_STRIP_TRAILING_WHITESPACE
        )
        separate_arguments(_files WINDOWS_COMMAND \${_output})
        while(_files)
            list(GET _files 0 _src)
            list(GET _files 1 _dest)
            get_filename_component(_path \${_dest} DIRECTORY)
            execute_process(
                COMMAND \"${CMAKE_COMMAND}\" -E
                    make_directory \"\${CMAKE_INSTALL_PREFIX}/${directory}/\${_path}\"
            )

            execute_process(
                COMMAND \"${CMAKE_COMMAND}\" -E
                    copy \${_src} \"\${CMAKE_INSTALL_PREFIX}/${directory}/\${_path}\"
            )
            list(REMOVE_AT _files 0 1)
        endwhile()
        "
    )

    # windeployqt doesn't work correctly with the system runtime libraries,
    # so we fall back to one of CMake's own modules for copying them over

    # Install the runtime libraries and copy them to the output directory
    # after build
    include(InstallRequiredSystemLibraries)
    foreach(lib ${CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS})
        get_filename_component(filename "${lib}" NAME)
        add_custom_command(TARGET ${target} POST_BUILD
            COMMAND "${CMAKE_COMMAND}" -E
                copy_if_different "${lib}" \"$<TARGET_FILE_DIR:${target}>\"
            COMMENT "Copying ${filename}...\n"
        )
    endforeach()

endfunction()

mark_as_advanced(WINDEPLOYQT_EXECUTABLE)
