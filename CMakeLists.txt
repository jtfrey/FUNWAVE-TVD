CMake_minimum_required(VERSION 3.20)


Project(FUNWAVE-TVD
    VERSION 3.4.0
    DESCRIPTION "Total Variation Diminishing (TVD) version of the fully nonlinear Boussinesq wave model (FUNWAVE)"
    HOMEPAGE_URL "https://fengyanshi.github.io/build/html/index.html"
    LANGUAGES Fortran)


#
# Validate the build type:
#
If (NOT DEFINED CMAKE_BUILD_TYPE OR NOT CMAKE_BUILD_TYPE)
    Set(CMAKE_BUILD_TYPE "Release")
EndIf()
If (NOT CMAKE_BUILD_TYPE MATCHES "^(Release|Debug|RelWithDebInfo|MinSizeRel)$")
    Message(FATAL_ERROR "Invalid CMAKE_BUILD_TYPE `${CMAKE_BUILD_TYPE}`; please choose Release, Debug, RelWithDebInfo, or MinSizeRel")
EndIf()


#
# The original make infrastructure used an indexed set of flags
# to enable/disable optional features in the program.
#
Option(ENABLE_COUPLING "Enable COUPLING" False)
Option(ENABLE_ZALPHA "Enable ZALPHA" False)
Option(ENABLE_MANNING "Enable MANNING" False)
Option(ENABLE_VESSEL "Enable VESSEL" False)
Option(ENABLE_METEO "Enable METEO" False)
Option(ENABLE_WIND "Enable WIND" False)
Option(ENABLE_SEDIMENT "Enable SEDIMENT" False)
Option(ENABLE_CHECK_MASS_CONSERVATION "Enable CHECK_MASS_CONSERVATION" False)
Option(ENABLE_TMP "Enable TMP" False)
Option(ENABLE_TRACKING "Enable TRACKING" False)
Option(ENABLE_FOAM "Enable FOAM" False)
Option(ENABLE_PRECIPITATION "Enable PRECIPITATION" False)
Option(ENABLE_SUBGRID "Enable SUBGRID" False)
Option(ENABLE_DEEP_DRAFT_VESSEL "Enable DEEP_DRAFT_VESSEL" False)
Option(ENABLE_FILTERING "Enable FILTERING" False)
Option(ENABLE_ITERATION "Enable ITERATION" False)
Option(ENABLE_AB_OUTPUT "Enable AB_OUTPUT" False)
Option(ENABLE_SPHERICAL_IJ_STATION "Enable SPHERICAL_IJ_STATION" False)
Option(ENABLE_UseEtaScreen "Enable UseEtaScreen" False)
#
# Each of the optional feature names must be added to this list,
# too:
#
Set(FUNWAVE_FEATURE_LIST "COUPLING" "ZALPHA" "MANNING" "VESSEL" "METEO"
                         "WIND" "SEDIMENT" "CHECK_MASS_CONSERVATION"
                         "TMP" "TRACKING" "FOAM" "PRECIPITATION" "SUBGRID"
                         "DEEP_DRAFT_VESSEL" "FILTERING" "ITERATION"
                         "AB_OUTPUT" "SPHERICAL_IJ_STATION" "UseEtaScreen")

#
# Additional options based on enabled features:
#
If (ENABLE_VESSEL)
    Option(ENABLE_VESSEL_PANEL_SOURCE "Enable VESSEL_PANEL_SOURCE" False)
    Option(ENABLE_REALISTIC_VESSEL_BODY "Enable REALISTIC_VESSEL_BODY" False)
    Option(ENABLE_PROPELLER "Enable PROPELLER" False)
    List(APPEND FUNWAVE_FEATURE_LIST "VESSEL_PANEL_SOURCE" "REALISTIC_VESSEL_BODY"
                                     "PROPELLER")
EndIf()


#
# Additional options:
#
# What floating-point precision should we use?
If (NOT DEFINED FP_PRECISION OR NOT FP_PRECISION)
    Set(FP_PRECISION "double" CACHE STRING "Floating-point precision ([double], single)")
EndIf()
Set_property(CACHE FP_PRECISION PROPERTY STRINGS "double" "single")
If (FP_PRECISION STREQUAL "double")
    Set(ENABLE_DOUBLE_PRECISION True)
Else()
    Set(ENABLE_DOUBLE_PRECISION False)
EndIf()

# What coordinate system should we use?
If (NOT DEFINED COORD_SYSTEM OR NOT COORD_SYSTEM)
    Set(COORD_SYSTEM "spherical" CACHE STRING "Coordinate system ([spherical], cartesian)")
EndIf()
Set_property(CACHE COORD_SYSTEM PROPERTY STRINGS "spherical" "cartesian")
If (COORD_SYSTEM STREQUAL "spherical")
    Set(ENABLE_COORD_SPHERICAL True)
Else()
    Set(ENABLE_COORD_SPHERICAL False)
EndIf()

# Use MPI?
Option(ENABLE_MPI "Enable parallel (MPI) build" False)
If (ENABLE_MPI)
    Find_package(MPI REQUIRED)
EndIf()

# Intel Fortran compiler?
If (CMAKE_Fortran_COMPILER_ID MATCHES "Intel")
    Set(HAVE_INTEL_FORTRAN True)
    #
    # Add the option for requesting interprocedural optimizations:
    #
    OPTION(ENABLE_INTEL_IPO "Enable Intel interprocedural optimizations (non-Debug builds)" False)
Else()
    Set(HAVE_INTEL_FORTRAN False)
EndIf()

# Are we doing a Debug build?
If (CMAKE_BUILD_TYPE STREQUAL "Debug")
    Set(ENABLE_DEBUG True)
Else()
    Set(ENABLE_DEBUG False)
EndIf()


#
# If VESSEL is enabled, CARTESIAN must also be enabled:
#
If (ENABLE_VESSEL AND ENABLE_COORD_SPHERICAL)
    Message(FATAL_ERROR "VESSEL must use 'cartesian' coordinates, not 'spherical'")
EndIf()

#
# If METEO is enabled, CARTESIAN must also be enabled:
#
If (ENABLE_METEO AND ENABLE_COORD_SPHERICAL)
    Message(FATAL_ERROR "METEO must use 'cartesian' coordinates, not 'spherical'")
EndIf()

#
# If FOAM is enabled, CARTESIAN must also be enabled:
#
If (ENABLE_FOAM AND ENABLE_COORD_SPHERICAL)
    Message(FATAL_ERROR "FOAM must use 'cartesian' coordinates, not 'spherical'")
EndIf()

#
# Add the top-level build directory as a global include path so that
# the generated funwave-tvd-config.h file can be include'd in project
# source files, for example:
#
Include_directories(AFTER ${CMAKE_CURRENT_BINARY_DIR})


#
# Add our local modules path and make some additions
# for optimization, etc.
#
List(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/cmake")
Include("Fortran_compiler_opts")


#
# Git hash handling:
#
Include("CheckGitHash")
CheckGitHashSetup("${CMAKE_CURRENT_LIST_DIR}/funwave-tvd-config.h.in" "${CMAKE_CURRENT_BINARY_DIR}/funwave-tvd-config.h")


#
# Add global compiler -D flags based on the feature options:
#
Set(FUNWAVE_FEATURE_LIST_FULL "")
If (ENABLE_MPI)
    List(APPEND FUNWAVE_FEATURE_LIST_FULL "MPI")
EndIf()
If (ENABLE_DEBUG)
    List(APPEND FUNWAVE_FEATURE_LIST_FULL "Debug")
EndIf()
ForEach(FUNWAVE_FEATURE IN LISTS FUNWAVE_FEATURE_LIST)
    Set(FUNWAVE_FEATURE_NAME "ENABLE_${FUNWAVE_FEATURE}")
    If (${${FUNWAVE_FEATURE_NAME}})
        Add_compile_definitions(${FUNWAVE_FEATURE})
        #
        # Add the name to the feature string:
        #
        List(APPEND FUNWAVE_FEATURE_LIST_FULL "${FUNWAVE_FEATURE}")
    EndIf()
EndForEach()
#
# Generate the feature string:
#
If (FUNWAVE_FEATURE_LIST_FULL)
    List(SORT FUNWAVE_FEATURE_LIST_FULL COMPARE STRING CASE INSENSITIVE)
    List(JOIN FUNWAVE_FEATURE_LIST_FULL "+" FUNWAVE_TVD_FEATURES_STRING)
Else()
    Set(FUNWAVE_FEATURE_LIST_FULL "")
EndIf()

#
# During build we want to specify that the config header is
# available:
#
Add_compile_definitions(HAVE_FUNWAVE_TVD_CONFIG_H)


#
# Generate the boilerplate header file; this ensures if the program
# gets installed there's some record of which optional components were
# enabled during compilation.  
#
Configure_file(funwave-tvd-config.h.in funwave-tvd-config.h)


#
# Add other global compiler -D flags:
#
If (ENABLE_DOUBLE_PRECISION)
    Add_compile_definitions(DOUBLE_PRECISION)
EndIf()
If (NOT ENABLE_COORD_SPHERICAL)
    Add_compile_definitions(CARTESIAN)
EndIf()
If (ENABLE_MPI)
    Add_compile_definitions(PARALLEL)
EndIf()
If (HAVE_INTEL_FORTRAN)
    Add_compile_definitions(INTEL)
EndIf()
If (CMAKE_BUILD_TYPE STREQUAL "Debug")
    Add_compile_definitions(DEBUG)
    
    #
    # Optional sediment debugging defaults to True if a
    # debug build is being performed:
    #
    Option(ENABLE_SEDIMENT_DEBUG "Enable SEDIMENT_DEBUG" True)
    If (ENABLE_SEDIMENT_DEBUG)
        Add_compile_definitions(SEDIMENT_DEBUG)
    EndIf()
EndIf()


#
# Add the src subdirectory to the build spec:
#
Add_subdirectory("src")


#
# Installation items:
#
Include(GNUInstallDirs)
Install(FILES "${CMAKE_CURRENT_BINARY_DIR}/funwave-tvd-config.h" TYPE INCLUDE)
