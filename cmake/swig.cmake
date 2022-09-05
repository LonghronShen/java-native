message(STATUS "Getting SWIG: ...")

# swig
FetchContent_Declare(swig
  GIT_REPOSITORY https://github.com/swig/swig.git
  GIT_TAG master)

FetchContent_GetProperties(swig)
if(NOT swig_POPULATED)
  FetchContent_Populate(swig)

  # Define SWIG_DIR (used as "hint" by FindSWIG)
  set(SWIG_DIR ${swig_SOURCE_DIR}/Lib)
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
  endif()
endif()


message(STATUS "Getting SWIG: ...DONE")
message(STATUS "Using SWIG: ${SWIG_EXECUTABLE}")