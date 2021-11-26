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
if(UNIX)
  find_program(MAVEN_EXECUTABLE mvn)
else()
  find_program(MAVEN_EXECUTABLE mvn.cmd)
endif()
if(NOT MAVEN_EXECUTABLE)
  message(FATAL_ERROR "Check for maven Program: not found")
else()
  message(STATUS "Found Maven: ${MAVEN_EXECUTABLE}")
endif()

# Needed by java/CMakeLists.txt
set(JAVA_DOMAIN_NAME "mizux")
set(JAVA_DOMAIN_EXTENSION "org")

set(JAVA_GROUP "${JAVA_DOMAIN_EXTENSION}.${JAVA_DOMAIN_NAME}")
set(JAVA_ARTIFACT "javanative")

set(JAVA_PACKAGE "${JAVA_GROUP}.${JAVA_ARTIFACT}")
set(JAVA_PACKAGE_SRC_PATH src/main/java/${JAVA_DOMAIN_EXTENSION}/${JAVA_DOMAIN_NAME}/${JAVA_ARTIFACT})
set(JAVA_PACKAGE_TEST_PATH src/test/java/${JAVA_DOMAIN_EXTENSION}/${JAVA_DOMAIN_NAME}/${JAVA_ARTIFACT})
set(JAVA_PACKAGE_RESOURCES_PATH src/main/resources)
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
set(JAVA_PROJECT ${JAVA_ARTIFACT}-java)

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
foreach(SUBPROJECT IN ITEMS Foo Bar FooBar)
  add_subdirectory(${SUBPROJECT}/java)
  target_link_libraries(jni${JAVA_ARTIFACT} PRIVATE jni${SUBPROJECT})
endforeach()

#################################
##  Java Native Maven Package  ##
#################################
set(JAVA_NATIVE_PROJECT_PATH ${PROJECT_BINARY_DIR}/java/${JAVA_NATIVE_PROJECT})
file(MAKE_DIRECTORY ${JAVA_NATIVE_PROJECT_PATH}/${JAVA_RESOURCES_PATH}/${JAVA_NATIVE_PROJECT})

configure_file(
  ${PROJECT_SOURCE_DIR}/java/pom-native.xml.in
  ${JAVA_NATIVE_PROJECT_PATH}/pom.xml
  @ONLY)

add_custom_target(java_native_package
  DEPENDS
  ${JAVA_NATIVE_PROJECT_PATH}/pom.xml
  COMMAND ${CMAKE_COMMAND} -E copy
    $<TARGET_FILE:jni${JAVA_ARTIFACT}>
    $<$<NOT:$<PLATFORM_ID:Windows>>:$<TARGET_SONAME_FILE:Foo>>
    $<$<NOT:$<PLATFORM_ID:Windows>>:$<TARGET_SONAME_FILE:Bar>>
    $<$<NOT:$<PLATFORM_ID:Windows>>:$<TARGET_SONAME_FILE:FooBar>>
    ${JAVA_RESOURCES_PATH}/${JAVA_NATIVE_PROJECT}/
  COMMAND ${MAVEN_EXECUTABLE} compile -B
  COMMAND ${MAVEN_EXECUTABLE} package -B
  COMMAND ${MAVEN_EXECUTABLE} install -B $<$<BOOL:${SKIP_GPG}>:-Dgpg.skip=true>
  BYPRODUCTS
    ${JAVA_NATIVE_PROJECT_PATH}/target
  WORKING_DIRECTORY ${JAVA_NATIVE_PROJECT_PATH})

##########################
##  Java Maven Package  ##
##########################
set(JAVA_PROJECT_PATH ${PROJECT_BINARY_DIR}/java/${JAVA_PROJECT})
file(MAKE_DIRECTORY ${JAVA_PROJECT_PATH}/${JAVA_PACKAGE_SRC_PATH})

configure_file(
  ${PROJECT_SOURCE_DIR}/java/pom-local.xml.in
  ${JAVA_PROJECT_PATH}/pom.xml
  @ONLY)

add_custom_target(java_package ALL
  DEPENDS
  ${JAVA_PROJECT_PATH}/pom.xml
  COMMAND ${CMAKE_COMMAND} -E copy
    ${PROJECT_SOURCE_DIR}/java/Loader.java
    ${JAVA_PACKAGE_SRC_PATH}/
  COMMAND ${MAVEN_EXECUTABLE} compile -B
  COMMAND ${MAVEN_EXECUTABLE} package -B $<$<BOOL:${BUILD_FAT_JAR}>:-Dfatjar=true>
  COMMAND ${MAVEN_EXECUTABLE} install -B $<$<BOOL:${SKIP_GPG}>:-Dgpg.skip=true>
  BYPRODUCTS
    ${JAVA_PROJECT_PATH}/target
  WORKING_DIRECTORY ${JAVA_PROJECT_PATH})
add_dependencies(java_package java_native_package)

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

  set(JAVA_TEST_PATH ${PROJECT_BINARY_DIR}/java/${COMPONENT_NAME}/${TEST_NAME})
  message(STATUS "build path: ${JAVA_TEST_PATH}/${JAVA_PACKAGE_TEST_PATH}")
  file(MAKE_DIRECTORY ${JAVA_TEST_PATH}/${JAVA_PACKAGE_TEST_PATH})

  file(COPY ${FILE_NAME} DESTINATION ${JAVA_TEST_PATH}/${JAVA_PACKAGE_TEST_PATH})

  string(TOLOWER ${TEST_NAME} JAVA_TEST_PROJECT)
  configure_file(
    ${PROJECT_SOURCE_DIR}/java/pom-test.xml.in
    ${JAVA_TEST_PATH}/pom.xml
    @ONLY)

  add_custom_target(java_${COMPONENT_NAME}_${TEST_NAME} ALL
    DEPENDS
      ${JAVA_TEST_PATH}/pom.xml
      ${JAVA_TEST_PATH}/${JAVA_PACKAGE_TEST_PATH}/${TEST_NAME}.java
    COMMAND ${MAVEN_EXECUTABLE} compile -B
    BYPRODUCTS
      ${JAVA_TEST_PATH}/target
    WORKING_DIRECTORY ${JAVA_TEST_PATH})
  add_dependencies(java_${COMPONENT_NAME}_${TEST_NAME} java_package)

  if(BUILD_TESTING)
    add_test(
      NAME java_${COMPONENT_NAME}_${TEST_NAME}
      COMMAND ${MAVEN_EXECUTABLE} test
      WORKING_DIRECTORY ${JAVA_TEST_PATH})
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

  set(JAVA_EXAMPLE_PATH ${PROJECT_BINARY_DIR}/java/${COMPONENT_NAME}/${EXAMPLE_NAME})
  message(STATUS "build path: ${JAVA_EXAMPLE_PATH}/${JAVA_PACKAGE_SRC_PATH}")
  file(MAKE_DIRECTORY ${JAVA_EXAMPLE_PATH}/${JAVA_PACKAGE_SRC_PATH})

  file(COPY ${FILE_NAME} DESTINATION ${JAVA_EXAMPLE_PATH}/${JAVA_PACKAGE_SRC_PATH})

  string(TOLOWER ${EXAMPLE_NAME} JAVA_EXAMPLE_PROJECT)
  set(JAVA_MAIN_CLASS "${JAVA_PACKAGE}.${COMPONENT_NAME}.${EXAMPLE_NAME}")
  configure_file(
    ${PROJECT_SOURCE_DIR}/java/pom-example.xml.in
    ${JAVA_EXAMPLE_PATH}/pom.xml
    @ONLY)

  add_custom_target(java_${COMPONENT_NAME}_${EXAMPLE_NAME} ALL
    DEPENDS
      ${JAVA_EXAMPLE_PATH}/pom.xml
      ${JAVA_EXAMPLE_PATH}/${JAVA_PACKAGE_SRC_PATH}/${EXAMPLE_NAME}.java
    COMMAND ${MAVEN_EXECUTABLE} compile -B
    BYPRODUCTS
      ${JAVA_EXAMPLE_PATH}/target
    WORKING_DIRECTORY ${JAVA_EXAMPLE_PATH})
  add_dependencies(java_${COMPONENT_NAME}_${EXAMPLE_NAME} java_package)

  if(BUILD_TESTING)
    add_test(
      NAME java_${COMPONENT_NAME}_${EXAMPLE_NAME}
      COMMAND ${MAVEN_EXECUTABLE} exec:java
      WORKING_DIRECTORY ${JAVA_EXAMPLE_PATH})
  endif()
  message(STATUS "Configuring example ${FILE_NAME}: ...DONE")
endfunction()
