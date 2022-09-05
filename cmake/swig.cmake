message(STATUS "Getting SWIG: ...")

# swig
FetchContent_Declare(swig
  GIT_REPOSITORY https://github.com/swig/swig.git
  GIT_TAG master)

FetchContent_GetProperties(swig)
if(NOT swig_POPULATED)
  FetchContent_Populate(swig)

  file(STRINGS "${swig_SOURCE_DIR}/configure.ac" line LIMIT_COUNT 1 REGEX "AC_INIT\\(.*\\)" )
  if(line MATCHES "AC_INIT\\(\\[(.*)\\],[ \t]*\\[(.*)\\],[ \t]*\\[(.*)\\]\\)" )
    set(SWIG_VERSION ${CMAKE_MATCH_2})
    set(PACKAGE_BUGREPORT ${CMAKE_MATCH_3})
  else()
    message(SEND_ERROR "Could not parse version from configure.ac")
  endif()

  # Define SWIG_DIR (used as "hint" by FindSWIG)
  set(SWIG_DIR ${CMAKE_BINARY_DIR}/external/swig/share/swig/${SWIG_VERSION})
  set(SWIG_EXECUTABLE ${swig_BINARY_DIR}/bin/swig.exe)

  if(NOT ((EXISTS "${SWIG_EXECUTABLE}") AND (EXISTS "${SWIG_DIR}")))
    include(WinFlexBison)

    execute_process(COMMAND ${CMAKE_COMMAND}
      -S ${swig_SOURCE_DIR}
      -B ${swig_BINARY_DIR}
      -G ${CMAKE_GENERATOR}
      -D CMAKE_BUILD_TYPE=Debug
      -D CMAKE_RUNTIME_OUTPUT_DIRECTORY=${swig_BINARY_DIR}/bin
      -D CMAKE_RUNTIME_OUTPUT_DIRECTORY_DEBUG=${swig_BINARY_DIR}/bin
      -D CMAKE_RUNTIME_OUTPUT_DIRECTORY_RELEASE=${swig_BINARY_DIR}/bin
      -D WITH_PCRE=OFF
      -D BISON_EXECUTABLE=${BISON_EXECUTABLE}
    )

    execute_process(COMMAND ${CMAKE_COMMAND}
      --build ${swig_BINARY_DIR}
    )

    execute_process(COMMAND ${CMAKE_COMMAND}
      --install ${swig_BINARY_DIR} --prefix ${CMAKE_BINARY_DIR}/external/swig
    )
  endif()
endif()


message(STATUS "Getting SWIG: ...DONE")
message(STATUS "Using SWIG: ${SWIG_EXECUTABLE}")