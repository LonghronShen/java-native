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

# Find java
find_package(Java COMPONENTS Development REQUIRED)
message(STATUS "Found Java: ${Java_JAVA_EXECUTABLE} (found version \"${Java_VERSION_STRING}\")")

find_package(JNI REQUIRED)
message(STATUS "Found JNI: ${JNI_FOUND}")

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

# Create the native library
add_library(jnijavanative SHARED "")
set_target_properties(jnijavanative PROPERTIES
  POSITION_INDEPENDENT_CODE ON)
# note: macOS is APPLE and also UNIX !
if(APPLE)
  set_target_properties(jnijavanative PROPERTIES
    INSTALL_RPATH "@loader_path")
  # Xcode fails to build if library doesn't contains at least one source file.
  if(XCODE)
    file(GENERATE
      OUTPUT ${PROJECT_BINARY_DIR}/jnijavanative/version.cpp
      CONTENT "namespace {char* version = \"${PROJECT_VERSION}\";}")
    target_sources(jnijavanative PRIVATE ${PROJECT_BINARY_DIR}/jnijavanative/version.cpp)
  endif()
elseif(UNIX)
  set_target_properties(jnijavanative PROPERTIES INSTALL_RPATH "$ORIGIN")
endif()

# Needed by java/CMakeLists.txt
set(JAVA_PACKAGE org.mizux.javanative)
set(JAVA_PACKAGE_PATH src/main/java/org/mizux/javanative)
set(JAVA_RESOURCES_PATH src/main/resources)
if(APPLE)
  set(NATIVE_IDENTIFIER darwin)
elseif(UNIX)
  set(NATIVE_IDENTIFIER linux-x86-64)
elseif(WIN32)
  set(NATIVE_IDENTIFIER win32-x86-64)
else()
  message(FATAL_ERROR "Unsupported system !")
endif()
set(JAVA_NATIVE_PROJECT javanative-${NATIVE_IDENTIFIER})
set(JAVA_PROJECT javanative-java)

# Swig wrap all libraries
foreach(SUBPROJECT IN ITEMS Foo)
  add_subdirectory(${SUBPROJECT}/java)
  target_link_libraries(jnijavanative PRIVATE jni${SUBPROJECT})
endforeach()

#################################
##  Java Native Maven Package  ##
#################################
configure_file(
  ${PROJECT_SOURCE_DIR}/java/pom-native.xml.in
  ${PROJECT_BINARY_DIR}/java/pom-native.xml.in
  @ONLY)

add_custom_command(
  OUTPUT java/${JAVA_NATIVE_PROJECT}/pom.xml
	DEPENDS ${PROJECT_BINARY_DIR}/java/pom-native.xml.in
  COMMAND ${CMAKE_COMMAND} -E make_directory ${JAVA_NATIVE_PROJECT}
  COMMAND ${CMAKE_COMMAND} -E copy ./pom-native.xml.in ${JAVA_NATIVE_PROJECT}/pom.xml
  BYPRODUCTS
  java/${JAVA_NATIVE_PROJECT}
  WORKING_DIRECTORY java)

add_custom_target(java_native_package
  DEPENDS
  java/${JAVA_NATIVE_PROJECT}/pom.xml
  COMMAND ${CMAKE_COMMAND} -E remove_directory src
	COMMAND ${CMAKE_COMMAND} -E make_directory ${JAVA_RESOURCES_PATH}/${NATIVE_IDENTIFIER}
  COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:Foo> ${JAVA_RESOURCES_PATH}/${NATIVE_IDENTIFIER}/
  COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:jnijavanative> ${JAVA_RESOURCES_PATH}/${NATIVE_IDENTIFIER}/
  COMMAND ${MAVEN_EXECUTABLE} compile
  COMMAND ${MAVEN_EXECUTABLE} package
  COMMAND ${MAVEN_EXECUTABLE} install
  WORKING_DIRECTORY java/${JAVA_NATIVE_PROJECT})

##########################
##  Java Maven Package  ##
##########################
configure_file(
  ${PROJECT_SOURCE_DIR}/java/pom-local.xml.in
  ${PROJECT_BINARY_DIR}/java/pom-local.xml.in
  @ONLY)

add_custom_command(
  OUTPUT java/${JAVA_PROJECT}/pom.xml
	DEPENDS ${PROJECT_BINARY_DIR}/java/pom-local.xml.in
  COMMAND ${CMAKE_COMMAND} -E make_directory ${JAVA_PROJECT}
  COMMAND ${CMAKE_COMMAND} -E copy ./pom-local.xml.in ${JAVA_PROJECT}/pom.xml
  BYPRODUCTS
  java/${JAVA_PROJECT}
  WORKING_DIRECTORY java)

add_custom_target(java_package ALL
  DEPENDS
  java/${JAVA_PROJECT}/pom.xml
	COMMAND ${CMAKE_COMMAND} -E copy ${PROJECT_SOURCE_DIR}/java/Loader.java ${JAVA_PACKAGE_PATH}/
  COMMAND ${MAVEN_EXECUTABLE} compile
  COMMAND ${MAVEN_EXECUTABLE} package
  COMMAND ${MAVEN_EXECUTABLE} install
  WORKING_DIRECTORY java/${JAVA_PROJECT})
add_dependencies(java_package java_native_package)

#################
##  Java Test  ##
#################
set(JAVA_TEST_PROJECT javanative-test)
if(BUILD_TESTING)
  configure_file(
    ${PROJECT_SOURCE_DIR}/java/pom-test.xml.in
    ${PROJECT_BINARY_DIR}/java/pom-test.xml.in
    @ONLY)

  add_custom_command(
		OUTPUT java/${JAVA_TEST_PROJECT}/pom.xml
		COMMAND ${CMAKE_COMMAND} -E make_directory ${JAVA_TEST_PROJECT}
    COMMAND ${CMAKE_COMMAND} -E copy ./pom-test.xml.in ${JAVA_TEST_PROJECT}/pom.xml
    BYPRODUCTS
    java/${JAVA_TEST_PROJECT}
    WORKING_DIRECTORY java)

  add_custom_target(java_test_package ALL
    DEPENDS
    java/${JAVA_TEST_PROJECT}/pom.xml
    COMMAND ${CMAKE_COMMAND} -E remove_directory src
		COMMAND ${CMAKE_COMMAND} -E make_directory ${JAVA_PACKAGE_PATH}
		COMMAND ${CMAKE_COMMAND} -E copy ${PROJECT_SOURCE_DIR}/java/Test.java ${JAVA_PACKAGE_PATH}/
    COMMAND ${MAVEN_EXECUTABLE} compile
    COMMAND ${MAVEN_EXECUTABLE} package
		WORKING_DIRECTORY java/${JAVA_TEST_PROJECT})
	add_dependencies(java_test_package java_package)

  add_test(
    NAME JavaTest
    COMMAND ${MAVEN_EXECUTABLE} exec:java -Dexec.mainClass=org.mizux.javanative.Test
    WORKING_DIRECTORY ${PROJECT_BINARY_DIR}/java/${JAVA_TEST_PROJECT})
endif()
