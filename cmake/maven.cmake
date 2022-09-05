# maven
FetchContent_Declare(maven
    URL https://dlcdn.apache.org/maven/maven-3/3.8.6/binaries/apache-maven-3.8.6-bin.tar.gz)

FetchContent_GetProperties(maven)
if(NOT maven_POPULATED)
    FetchContent_Populate(maven)
endif()

set(MAVEN_ROOT ${maven_SOURCE_DIR}/bin CACHE STRING "maven directory" FORCE)
find_package(Maven)