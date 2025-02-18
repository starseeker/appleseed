# SPDX-License-Identifier: BSD-3-Clause
# Copyright Contributors to the OpenColorIO Project.
#
# Locate OpenShadingLanguage (OSL)
#
# Variables defined by this module:
#   OSL_FOUND                          - Indicate whether the library was found or not
#   OSL_LIB_DIR                        - Location of the libary files
#   OSL_INCLUDE_DIR                    - Location of the header files
#   OSL_VERSION                        - Library's version
#   OSL_SHADERS_INCLUDE_DIR            - Location of the shader's header files
#   OSL_SHADERS_DIR                    - Used for OSL unit tests
#   
#   These variables are set only when OSL_ROOT is provided:
#   oslcomp_LIBRARY                    - Path to the library file
#   oslexec_LIBRARY                    - Path to the library file
#   oslquery_LIBRARY                   - Path to the library file
#
# Global targets defined by this module:
#   osl::osl
#
# Usually CMake will use the dynamic library rather than static, if both are present. 
#
# If the library is not installed in a typical location where CMake will find it, you may specify 
# the location using one of the following methods:
# -- Set -DOpenShadingLanguage_DIR to point to the directory containing the CMake configuration file for the package.
# -- Set -DOpenShadingLanguage_ROOT to point to the directory containing the lib and include directories.
#

###############################################################################
### Try to find package ###

if(NOT DEFINED OSL_ROOT)
    find_package(OSL ${OSL_FIND_VERSION} CONFIG QUIET)

    set(OSL_SHADERS_INCLUDE_DIR ${OSL_INCLUDE_DIR}/../share)
    # Variable used by the OSL unit tests. 
    set(OSL_SHADERS_DIR ${OSL_SHADERS_INCLUDE_DIR}/OSL/shaders)

    include (FindPackageHandleStandardArgs)
    find_package_handle_standard_args (OSL
        REQUIRED_VARS 
            OSL_INCLUDE_DIR 
            OSL_LIB_DIR 
        VERSION_VAR   
            OSL_VERSION
    )
else()
    # helper macro to get library location and implib for use with set_target_properties
    macro (osl_library_loc_and_imp library _LOC _IMP)
        # Find the library.
        find_library(${_IMP}
            NAMES
                lib${library} ${library}
            HINTS
                ${OSL_ROOT}
            PATH_SUFFIXES
                lib
        )
        if (MSVC)
            # on windows, IMPORTED_LOCATION should be fullpath to .dll
            #             IMPORTED_IMPLIB should point to .lib
            find_file(${_LOC}
            NAMES
                ${library}.dll
            HINTS
                ${OSL_ROOT}
            PATH_SUFFIXES
                bin
        )
        else()
            # everywhere else, IMPORTED_LOCATION should be fullpath to .lib
            #                  IMPORTED_IMPLIB should point to .lib
            set(${_LOC} ${_IMP})
        endif (MSVC)
    endmacro()

    set(OSL_INCLUDE_DIR ${OSL_ROOT}/include)
    set(OSL_VERSION_HEADER "${OSL_INCLUDE_DIR}/OSL/oslversion.h")

    if(EXISTS "${OSL_VERSION_HEADER}")
        # Try to figure out version number
        file (STRINGS "${OSL_VERSION_HEADER}" TMP REGEX "^#define OSL_LIBRARY_VERSION_MAJOR .*$")
        string (REGEX MATCHALL "[0-9]+" OSL_VERSION_MAJOR ${TMP})
        file (STRINGS "${OSL_VERSION_HEADER}" TMP REGEX "^#define OSL_LIBRARY_VERSION_MINOR .*$")
        string (REGEX MATCHALL "[0-9]+" OSL_VERSION_MINOR ${TMP})
        file (STRINGS "${OSL_VERSION_HEADER}" TMP REGEX "^#define OSL_LIBRARY_VERSION_PATCH .*$")
        string (REGEX MATCHALL "[0-9]+" OSL_VERSION_PATCH ${TMP})
        file (STRINGS "${OSL_VERSION_HEADER}" TMP REGEX "^#define OSL_LIBRARY_VERSION_TWEAK .*$")

        if (TMP)
            string (REGEX MATCHALL "[0-9]+" OSL_VERSION_TWEAK ${TMP})
        else ()
            set (OSL_VERSION_TWEAK 0)
        endif ()

        set (OSL_VERSION "${OSL_VERSION_MAJOR}.${OSL_VERSION_MINOR}.${OSL_VERSION_PATCH}.${OSL_VERSION_TWEAK}")

        # Fine the oslcomp library.
        osl_library_loc_and_imp(oslcomp oslcomp_LIBRARY_LOC oslcomp_LIBRARY_IMP)
        add_library(OSL::oslcomp SHARED IMPORTED)
        set_target_properties(OSL::oslcomp PROPERTIES 
            IMPORTED_LOCATION ${oslcomp_LIBRARY_LOC}
            IMPORTED_IMPLIB ${oslcomp_LIBRARY_IMP}
        )

        # Find the oslexec library.
        osl_library_loc_and_imp(oslexec oslexec_LIBRARY_LOC oslexec_LIBRARY_IMP)
        add_library(OSL::oslexec SHARED IMPORTED)
        set_target_properties(OSL::oslexec PROPERTIES
            IMPORTED_LOCATION ${oslexec_LIBRARY_LOC}
            IMPORTED_IMPLIB ${oslexec_LIBRARY_IMP}
        )

        # Find the oslquery library.
        osl_library_loc_and_imp(oslquery oslquery_LIBRARY_LOC oslquery_LIBRARY_IMP)
        add_library(OSL::oslquery SHARED IMPORTED)
        set_target_properties(OSL::oslquery PROPERTIES
            IMPORTED_LOCATION ${oslquery_LIBRARY_LOC}
            IMPORTED_IMPLIB ${oslquery_LIBRARY_IMP}
        )

        set(OSL_SHADERS_INCLUDE_DIR ${OSL_ROOT}/share)
        # Variable used by the OSL unit tests. 
        set(OSL_SHADERS_DIR ${OSL_SHADERS_INCLUDE_DIR}/OSL/shaders)
    endif()

    include (FindPackageHandleStandardArgs)
    find_package_handle_standard_args (OSL
        REQUIRED_VARS 
            OSL_INCLUDE_DIR
            OSL_SHADERS_DIR
            oslcomp_LIBRARY_IMP
            oslexec_LIBRARY_IMP
        VERSION_VAR   
            OSL_VERSION
    )
endif()

# Programs
find_program(OSL_QUERY_INFO oslinfo ${OSL_LIB_DIR}/../bin)
find_program(OSL_COMPILER oslc ${OSL_LIB_DIR}/../bin)

###############################################################################
### Create target

if(NOT TARGET osl::osl)
    add_library(osl::osl INTERFACE IMPORTED GLOBAL)
endif()

###############################################################################
### Configure target ###

if(OSL_FOUND)
    list(APPEND LIB_INCLUDE_DIRS ${OSL_INCLUDE_DIR})
    list(APPEND LIB_INCLUDE_DIRS ${OSL_SHADERS_INCLUDE_DIR})

    target_include_directories(osl::osl INTERFACE "${LIB_INCLUDE_DIRS}")
    target_link_libraries(osl::osl INTERFACE OSL::oslcomp OSL::oslexec)

    # C++14 is required for OSL 1.12+
    if (${OSL_VERSION} VERSION_GREATER_EQUAL "1.12" AND ${CMAKE_CXX_STANDARD} LESS_EQUAL 11)
        set(OSL_FOUND OFF)
        message(WARNING "Need C++14 or higher to compile OpenShadingLanguage. Skipping build the OSL unit tests")
    endif()

    mark_as_advanced(OSL_INCLUDE_DIR
        oslcomp_LIBRARY oslcomp_FOUND
        oslexec_LIBRARY oslexec_FOUND
    )
endif()
