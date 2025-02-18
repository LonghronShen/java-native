# Will need swig
set(CMAKE_SWIG_FLAGS)
find_package(SWIG REQUIRED)
include(UseSWIG)

if(${SWIG_VERSION} VERSION_GREATER_EQUAL 4)
  list(APPEND CMAKE_SWIG_FLAGS "-doxygen")
endif()

if(UNIX AND NOT APPLE)
  list(APPEND CMAKE_SWIG_FLAGS "-DSWIGWORDSIZE64")
endif()

# Find Java and JNI
find_package(Java COMPONENTS Development REQUIRED)
find_package(JNI REQUIRED)

# Find maven
# On windows mvn spawn a process while mvn.cmd is a blocking command
message(STATUS "Getting Maven: ...")
include(maven)
message(STATUS "Getting Maven: ...DONE")

if(NOT Maven_FOUND)
  message(FATAL_ERROR "Failed to fetch maven.")
else()
  message(STATUS "Found Maven: ${Maven_EXECUTABLE}")
endif()

# Needed by java/CMakeLists.txt
set(JAVA_DOMAIN_NAME "mizux")
set(JAVA_DOMAIN_EXTENSION "org")

set(JAVA_GROUP "${JAVA_DOMAIN_EXTENSION}.${JAVA_DOMAIN_NAME}")
set(JAVA_ARTIFACT "javanative")

set(JAVA_PACKAGE "${JAVA_GROUP}.${JAVA_ARTIFACT}")
if(APPLE)
  set(NATIVE_IDENTIFIER darwin-x86-64)
elseif(UNIX)
  set(NATIVE_IDENTIFIER linux-x86-64)
elseif(WIN32)
  set(NATIVE_IDENTIFIER win32-x86-64)
else()
  message(FATAL_ERROR "Unsupported system !")
endif()

set(JAVA_NATIVE_PROJECT ${JAVA_ARTIFACT}-${NATIVE_IDENTIFIER})
message(STATUS "Java runtime project: ${JAVA_NATIVE_PROJECT}")

set(JAVA_NATIVE_PROJECT_DIR ${PROJECT_BINARY_DIR}/java/${JAVA_NATIVE_PROJECT})
message(STATUS "Java runtime project build path: ${JAVA_NATIVE_PROJECT_DIR}")

set(JAVA_PROJECT ${JAVA_ARTIFACT}-java)
message(STATUS "Java project: ${JAVA_PROJECT}")

set(JAVA_PROJECT_DIR ${PROJECT_BINARY_DIR}/java/${JAVA_PROJECT})
message(STATUS "Java project build path: ${JAVA_PROJECT_DIR}")

# Create the native library
add_library(jni${JAVA_ARTIFACT} SHARED "")
set_target_properties(jni${JAVA_ARTIFACT} PROPERTIES
  POSITION_INDEPENDENT_CODE ON)
# note: macOS is APPLE and also UNIX !
if(APPLE)
  set_target_properties(jni${JAVA_ARTIFACT} PROPERTIES INSTALL_RPATH "@loader_path")
  # Xcode fails to build if library doesn't contains at least one source file.
  if(XCODE)
    file(GENERATE
      OUTPUT ${PROJECT_BINARY_DIR}/jni${JAVA_ARTIFACT}/version.cpp
      CONTENT "namespace {char* version = \"${PROJECT_VERSION}\";}")
    target_sources(jni${JAVA_ARTIFACT} PRIVATE ${PROJECT_BINARY_DIR}/jni${JAVA_ARTIFACT}/version.cpp)
  endif()
elseif(UNIX)
  set_target_properties(jni${JAVA_ARTIFACT} PROPERTIES INSTALL_RPATH "$ORIGIN")
endif()

# Swig wrap all libraries
set(JAVA_SRC_PATH src/main/java/${JAVA_DOMAIN_EXTENSION}/${JAVA_DOMAIN_NAME}/${JAVA_ARTIFACT})
set(JAVA_TEST_PATH src/test/java/${JAVA_DOMAIN_EXTENSION}/${JAVA_DOMAIN_NAME}/${JAVA_ARTIFACT})
set(JAVA_RESSOURCES_PATH src/main/resources)
foreach(SUBPROJECT IN ITEMS Foo Bar FooBar)
  add_subdirectory(${SUBPROJECT}/java)
  target_link_libraries(jni${JAVA_ARTIFACT} PRIVATE jni${SUBPROJECT})
endforeach()

#################################
##  Java Native Maven Package  ##
#################################
file(MAKE_DIRECTORY ${JAVA_NATIVE_PROJECT_DIR}/${JAVA_RESSOURCES_PATH}/${JAVA_NATIVE_PROJECT})

configure_file(
  ${PROJECT_SOURCE_DIR}/java/pom-native.xml.in
  ${JAVA_NATIVE_PROJECT_DIR}/pom.xml
  @ONLY)

add_custom_command(
  OUTPUT ${JAVA_NATIVE_PROJECT_DIR}/timestamp
  COMMAND ${CMAKE_COMMAND} -E copy
    $<TARGET_FILE:jni${JAVA_ARTIFACT}>
    $<$<NOT:$<PLATFORM_ID:Windows>>:$<TARGET_SONAME_FILE:Foo>>
    $<$<NOT:$<PLATFORM_ID:Windows>>:$<TARGET_SONAME_FILE:Bar>>
    $<$<NOT:$<PLATFORM_ID:Windows>>:$<TARGET_SONAME_FILE:FooBar>>
    ${JAVA_RESSOURCES_PATH}/${JAVA_NATIVE_PROJECT}/
  COMMAND ${Maven_EXECUTABLE} compile -B
  COMMAND ${Maven_EXECUTABLE} package -B $<$<BOOL:${BUILD_FAT_JAR}>:-Dfatjar=true>
  COMMAND ${Maven_EXECUTABLE} install -B $<$<BOOL:${SKIP_GPG}>:-Dgpg.skip=true>
  COMMAND ${CMAKE_COMMAND} -E touch ${JAVA_NATIVE_PROJECT_DIR}/timestamp
  DEPENDS
    ${JAVA_NATIVE_PROJECT_DIR}/pom.xml
  BYPRODUCTS
    ${JAVA_NATIVE_PROJECT_DIR}/target
  COMMENT "Generate Java native package ${JAVA_NATIVE_PROJECT} (${JAVA_NATIVE_PROJECT_DIR}/timestamp)"
  WORKING_DIRECTORY ${JAVA_NATIVE_PROJECT_DIR})

add_custom_target(java_native_package
  DEPENDS
    ${JAVA_NATIVE_PROJECT_DIR}/timestamp
  WORKING_DIRECTORY ${JAVA_NATIVE_PROJECT_DIR})

##########################
##  Java Maven Package  ##
##########################
file(MAKE_DIRECTORY ${JAVA_PROJECT_DIR}/${JAVA_SRC_PATH})

if(UNIVERSAL_JAVA_PACKAGE)
  configure_file(
    ${PROJECT_SOURCE_DIR}/java/pom-full.xml.in
    ${JAVA_PROJECT_DIR}/pom.xml
    @ONLY)
else()
  configure_file(
    ${PROJECT_SOURCE_DIR}/java/pom-local.xml.in
    ${JAVA_PROJECT_DIR}/pom.xml
    @ONLY)
endif()

file(GLOB_RECURSE java_files RELATIVE ${PROJECT_SOURCE_DIR}/java "java/*.java")
#message(WARNING "list: ${java_files}")
set(JAVA_SRCS)
foreach(JAVA_FILE IN LISTS java_files)
  #message(STATUS "java: ${JAVA_FILE}")
  set(JAVA_OUT ${JAVA_PROJECT_DIR}/${JAVA_SRC_PATH}/${JAVA_FILE})
  #message(STATUS "java out: ${JAVA_OUT}")
  add_custom_command(
    OUTPUT ${JAVA_OUT}
    COMMAND ${CMAKE_COMMAND} -E copy
      ${PROJECT_SOURCE_DIR}/java/${JAVA_FILE}
      ${JAVA_OUT}
    DEPENDS ${PROJECT_SOURCE_DIR}/java/${JAVA_FILE}
    COMMENT "Copy Java file ${JAVA_FILE}"
    VERBATIM)
  list(APPEND JAVA_SRCS ${JAVA_OUT})
endforeach()

add_custom_command(
  OUTPUT ${JAVA_PROJECT_DIR}/timestamp
  COMMAND ${Maven_EXECUTABLE} compile -B
  COMMAND ${Maven_EXECUTABLE} package -B $<$<BOOL:${BUILD_FAT_JAR}>:-Dfatjar=true>
  COMMAND ${Maven_EXECUTABLE} install -B $<$<BOOL:${SKIP_GPG}>:-Dgpg.skip=true>
  COMMAND ${CMAKE_COMMAND} -E touch ${JAVA_PROJECT_DIR}/timestamp
  DEPENDS
    ${JAVA_PROJECT_DIR}/pom.xml
    ${JAVA_SRCS}
  java_native_package
  BYPRODUCTS
    ${JAVA_PROJECT_DIR}/target
  COMMENT "Generate Java package ${JAVA_PROJECT} (${JAVA_PROJECT_DIR}/timestamp)"
  WORKING_DIRECTORY ${JAVA_PROJECT_DIR})

add_custom_target(java_package ALL
  DEPENDS
    ${JAVA_PROJECT_DIR}/timestamp
  WORKING_DIRECTORY ${JAVA_PROJECT_DIR})

#################
##  Java Test  ##
#################
# add_java_test()
# CMake function to generate and build java test.
# Parameters:
#  the java filename
# e.g.:
# add_java_test(FooTests.java)
function(add_java_test FILE_NAME)
  message(STATUS "Configuring test ${FILE_NAME}: ...")
  get_filename_component(TEST_NAME ${FILE_NAME} NAME_WE)
  get_filename_component(COMPONENT_DIR ${FILE_NAME} DIRECTORY)
  get_filename_component(COMPONENT_NAME ${COMPONENT_DIR} NAME)

  set(JAVA_TEST_DIR ${PROJECT_BINARY_DIR}/java/${COMPONENT_NAME}/${TEST_NAME})
  message(STATUS "build path: ${JAVA_TEST_DIR}")

  add_custom_command(
    OUTPUT ${JAVA_TEST_DIR}/${JAVA_TEST_PATH}/${TEST_NAME}.java
    COMMAND ${CMAKE_COMMAND} -E make_directory
      ${JAVA_TEST_DIR}/${JAVA_TEST_PATH}
    COMMAND ${CMAKE_COMMAND} -E copy
      ${FILE_NAME}
      ${JAVA_TEST_DIR}/${JAVA_TEST_PATH}/
    MAIN_DEPENDENCY ${FILE_NAME}
    VERBATIM
  )

  string(TOLOWER ${TEST_NAME} JAVA_TEST_PROJECT)
  configure_file(
    ${PROJECT_SOURCE_DIR}/java/pom-test.xml.in
    ${JAVA_TEST_DIR}/pom.xml
    @ONLY)

  add_custom_command(
    OUTPUT ${JAVA_TEST_DIR}/timestamp
    COMMAND ${Maven_EXECUTABLE} compile -B
    COMMAND ${CMAKE_COMMAND} -E touch ${JAVA_TEST_DIR}/timestamp
    DEPENDS
      ${JAVA_TEST_DIR}/pom.xml
      ${JAVA_TEST_DIR}/${JAVA_TEST_PATH}/${TEST_NAME}.java
      java_package
    BYPRODUCTS
      ${JAVA_TEST_DIR}/target
    COMMENT "Compiling Java ${COMPONENT_NAME}/${TEST_NAME}.java (${JAVA_TEST_DIR}/timestamp)"
    WORKING_DIRECTORY ${JAVA_TEST_DIR})

  add_custom_target(java_${COMPONENT_NAME}_${TEST_NAME} ALL
    DEPENDS
      ${JAVA_TEST_DIR}/timestamp
    WORKING_DIRECTORY ${JAVA_TEST_DIR})

  if(BUILD_TESTING)
    add_test(
      NAME java_${COMPONENT_NAME}_${TEST_NAME}
      COMMAND ${Maven_EXECUTABLE} test
      WORKING_DIRECTORY ${JAVA_TEST_DIR})
  endif()
  message(STATUS "Configuring test ${FILE_NAME}: ...DONE")
endfunction()

####################
##  Java Example  ##
####################
# add_java_example()
# CMake function to generate and build java example.
# Parameters:
#  the java filename
# e.g.:
# add_java_example(Foo.java)
function(add_java_example FILE_NAME)
  message(STATUS "Configuring example ${FILE_NAME}: ...")
  get_filename_component(EXAMPLE_NAME ${FILE_NAME} NAME_WE)
  get_filename_component(COMPONENT_DIR ${FILE_NAME} DIRECTORY)
  get_filename_component(COMPONENT_NAME ${COMPONENT_DIR} NAME)

  set(JAVA_EXAMPLE_DIR ${PROJECT_BINARY_DIR}/java/${COMPONENT_NAME}/${EXAMPLE_NAME})
  message(STATUS "build path: ${JAVA_EXAMPLE_DIR}")

  add_custom_command(
    OUTPUT ${JAVA_EXAMPLE_DIR}/${JAVA_SRC_PATH}/${COMPONENT_NAME}/${EXAMPLE_NAME}.java
    COMMAND ${CMAKE_COMMAND} -E make_directory
      ${JAVA_EXAMPLE_DIR}/${JAVA_SRC_PATH}/${COMPONENT_NAME}
    COMMAND ${CMAKE_COMMAND} -E copy
      ${FILE_NAME}
      ${JAVA_EXAMPLE_DIR}/${JAVA_SRC_PATH}/${COMPONENT_NAME}/
    MAIN_DEPENDENCY ${FILE_NAME}
    VERBATIM
  )

  string(TOLOWER ${EXAMPLE_NAME} JAVA_EXAMPLE_PROJECT)
  set(JAVA_MAIN_CLASS
    "${JAVA_PACKAGE}.${COMPONENT_NAME}.${EXAMPLE_NAME}")
  configure_file(
    ${PROJECT_SOURCE_DIR}/java/pom-example.xml.in
    ${JAVA_EXAMPLE_DIR}/pom.xml
    @ONLY)

  add_custom_command(
    OUTPUT ${JAVA_EXAMPLE_DIR}/timestamp
    COMMAND ${Maven_EXECUTABLE} compile -B
    COMMAND ${CMAKE_COMMAND} -E touch ${JAVA_EXAMPLE_DIR}/timestamp
    DEPENDS
      ${JAVA_EXAMPLE_DIR}/pom.xml
      ${JAVA_EXAMPLE_DIR}/${JAVA_SRC_PATH}/${COMPONENT_NAME}/${EXAMPLE_NAME}.java
      java_package
    BYPRODUCTS
      ${JAVA_EXAMPLE_DIR}/target
    COMMENT "Compiling Java ${COMPONENT_NAME}/${EXAMPLE_NAME}.java (${JAVA_EXAMPLE_DIR}/timestamp)"
    WORKING_DIRECTORY ${JAVA_EXAMPLE_DIR})

  add_custom_target(java_${COMPONENT_NAME}_${EXAMPLE_NAME} ALL
    DEPENDS
      ${JAVA_EXAMPLE_DIR}/timestamp
    WORKING_DIRECTORY ${JAVA_EXAMPLE_DIR})

  if(BUILD_TESTING)
    add_test(
      NAME java_${COMPONENT_NAME}_${EXAMPLE_NAME}
      COMMAND ${Maven_EXECUTABLE} exec:java
      WORKING_DIRECTORY ${JAVA_EXAMPLE_DIR})
  endif()
  message(STATUS "Configuring example ${FILE_NAME}: ...DONE")
endfunction()
