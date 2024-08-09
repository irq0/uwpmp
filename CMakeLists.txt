cmake_minimum_required(VERSION 3.14)
project(unwindpmp CXX)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Set default build type
if(NOT CMAKE_BUILD_TYPE)
        set(CMAKE_BUILD_TYPE "RelWithDebInfo" CACHE STRING "Options are: Debug Release RelWithDebInfo MinSizeRel." FORCE)
endif(NOT CMAKE_BUILD_TYPE)

option(WITH_SYSTEM_ELFUTILS "Use system elfutils" ON)

add_executable(${PROJECT_NAME} src/common.cc
                               src/unwindpmp.cc
                               src/uwpmp_types.cc
                               src/tracer/uwpmp_tracer.cc
                               src/tracer/unwind_tracer.cc
                               src/tracer/dw_tracer.cc
)

include(ExternalProject)
include(FetchContent)
FetchContent_Declare(
        cxxopts
        GIT_REPOSITORY "https://github.com/jarro2783/cxxopts"
        GIT_TAG "v2.2.1"
)
FetchContent_Declare(
        fmt
        GIT_REPOSITORY "https://github.com/fmtlib/fmt"
        GIT_TAG "8.0.1"
)
FetchContent_Declare(
        json
        GIT_REPOSITORY "https://github.com/ArthurSonzogni/nlohmann_json_cmake_fetchcontent"
        GIT_TAG "v3.10.2"
)
FetchContent_GetProperties(json)
if(NOT json_POPULATED)
  FetchContent_Populate(json)
  add_subdirectory(${json_SOURCE_DIR} ${json_BINARY_DIR} EXCLUDE_FROM_ALL)
endif()
FetchContent_MakeAvailable(cxxopts fmt json)

ExternalProject_Add(
	libunwind
	GIT_REPOSITORY https://github.com/libunwind/libunwind.git
	GIT_TAG "v1.5"
	PREFIX ${CMAKE_BINARY_DIR}/libunwind
	CONFIGURE_COMMAND
	/bin/sh -c "cd <SOURCE_DIR> && autoreconf -i && ./configure --prefix=<INSTALL_DIR> --disable-minidebuginfo --disable-shared --enable-static"
	BUILD_COMMAND
	cd <SOURCE_DIR> && make -s -j${BUILD_JOBS_NUM}
	INSTALL_COMMAND make install
	LOG_CONFIGURE TRUE
	UPDATE_DISCONNECTED TRUE
	BUILD_IN_SOURCE TRUE
)
add_dependencies(${PROJECT_NAME} libunwind)
ExternalProject_Get_Property(libunwind SOURCE_DIR)
set(libunwind_SOURCE_DIR ${SOURCE_DIR})
set(libunwind_LIBS_DIR ${CMAKE_CURRENT_BINARY_DIR}/${libunwind_SOURCE_DIR}/src/.libs)
set(libunwind_INCLUDE_DIR ${libunwind_SOURCE_DIR}/include)

if(WITH_SYSTEM_ELFUTILS)
	find_package(LibElf REQUIRED)
	list(APPEND CMAKE_REQUIRED_INCLUDES ${LIBELF_INCLUDE_DIRS})
	target_link_libraries(${PROJECT_NAME} dw)
else()
	ExternalProject_Add(
		elfutils
		GIT_REPOSITORY git://sourceware.org/git/elfutils.git
		GIT_TAG "elfutils-0.191"
		PREFIX ${CMAKE_BINARY_DIR}/elfutils
 		CONFIGURE_COMMAND
 		/bin/sh -c "cd <SOURCE_DIR> && autoreconf -i -f && ./configure --prefix=<INSTALL_DIR> --enable-maintainer-mode --disable-debuginfod --enable-libdebuginfod"
		INSTALL_COMMAND make install
 		BUILD_COMMAND
 		make -s -j${BUILD_JOBS_NUM}
 		BUILD_IN_SOURCE TRUE
 		LOG_CONFIGURE TRUE
 		UPDATE_DISCONNECTED TRUE
	)
	ExternalProject_Get_Property(elfutils install_dir)
	add_dependencies(${PROJECT_NAME} elfutils)
	set(elfutils_INSTALL_DIR ${install_dir})
	set(elfutils_INCLUDE_DIR ${elfutils_INSTALL_DIR}/include)
	target_include_directories(${PROJECT_NAME} PRIVATE ${elfutils_INCLUDE_DIR})
	target_link_directories(${PROJECT_NAME} PRIVATE ${elfutils_INSTALL_DIR}/lib PRIVATE ${elfutils_INSTALL_DIR}/lib64)
	target_link_libraries(${PROJECT_NAME} dw debuginfod)
	## for static linking - beware lib vs lib64
	# set(elfutils_LIBS_DIR ${elfutils_INSTALL_DIR}/${CMAKE_INSTALL_LIBDIR})
	# target_link_libraries(${PROJECT_NAME} ${elfutils_LIBS_DIR}/libdw.a)
	# target_link_libraries(${PROJECT_NAME} ${elfutils_LIBS_DIR}/libelf.a)
	# target_link_libraries(${PROJECT_NAME} z lzma bz2 zstd)
endif()

target_include_directories(${PROJECT_NAME} PRIVATE src src/tracer ${libunwind_INCLUDE_DIR})
target_link_libraries(${PROJECT_NAME} stdc++ cxxopts nlohmann_json::nlohmann_json fmt)
target_link_libraries(${PROJECT_NAME} ${libunwind_LIBS_DIR}/libunwind-ptrace.a)
target_link_libraries(${PROJECT_NAME} ${libunwind_LIBS_DIR}/libunwind-x86_64.a)
target_link_libraries(${PROJECT_NAME} ${libunwind_LIBS_DIR}/libunwind.a)
