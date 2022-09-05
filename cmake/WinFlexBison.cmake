# winflexbision
FetchContent_Declare(winflexbision
    GIT_REPOSITORY https://github.com/LonghronShen/winflexbison.git
    GIT_TAG master)

FetchContent_GetProperties(winflexbision)
if(NOT winflexbision_POPULATED)
    FetchContent_Populate(winflexbision)
    add_subdirectory(${winflexbision_SOURCE_DIR} ${winflexbision_BINARY_DIR} EXCLUDE_FROM_ALL)

    execute_process(COMMAND ${CMAKE_COMMAND}
        -S ${winflexbision_SOURCE_DIR}
        -B ${CMAKE_BINARY_DIR}/external/winflexbision
        -G ${CMAKE_GENERATOR}
        -D CMAKE_BUILD_TYPE=Debug
        -D CMAKE_RUNTIME_OUTPUT_DIRECTORY=${winflexbision_BINARY_DIR}
        -D CMAKE_RUNTIME_OUTPUT_DIRECTORY_DEBUG=${winflexbision_BINARY_DIR}
        -D CMAKE_RUNTIME_OUTPUT_DIRECTORY_RELEASE=${winflexbision_BINARY_DIR}
    )

    execute_process(COMMAND ${CMAKE_COMMAND}
        --build ${CMAKE_BINARY_DIR}/external/winflexbision
    )

    execute_process(COMMAND ${CMAKE_COMMAND}
        --install ${CMAKE_BINARY_DIR}/external/winflexbision --prefix ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}
    )

    set(BISON_ROOT_DIR "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}" CACHE STRING "BISON_ROOT_DIR" FORCE)
    set(FLEX_ROOT_DIR "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}" CACHE STRING "FLEX_ROOT_DIR" FORCE)

    set(BISON_EXECUTABLE "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/win_bison.exe" CACHE STRING "BISON_EXECUTABLE" FORCE)
    set(BISON_version_result "0" CACHE STRING "BISON_version_result" FORCE)
    set(BISON_version_output "bison++ Version 1,0,0" CACHE STRING "BISON_version_result" FORCE)

    set(FLEX_EXECUTABLE "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/win_flex.exe" CACHE STRING "FLEX_EXECUTABLE" FORCE)
    set(FLEX_version_result "0" CACHE STRING "FLEX_version_result" FORCE)
    set(FLEX_FIND_REQUIRED "0" CACHE STRING "FLEX_FIND_REQUIRED" FORCE)

    include(UseBISON)
    # include(UseFLEX)
endif()