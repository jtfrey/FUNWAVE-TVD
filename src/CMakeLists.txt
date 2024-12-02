#
# This CMake fragment is expected to be descendent from the
# CMakeLists.txt in the parent directory.
#

If (NOT DEFINED FUNWAVE_EXE OR NOT FUNWAVE_EXE)
    #
    # Base name:
    #
    Set(FUNWAVE_EXE "funwave")
    #
    # Append strings for each optional feature:
    #
    ForEach(FUNWAVE_FEATURE IN LISTS FUNWAVE_FEATURE_LIST)
        Set(FUNWAVE_FEATURE_NAME "ENABLE_${FUNWAVE_FEATURE}")
        If (${${FUNWAVE_FEATURE_NAME}})
            Set(FUNWAVE_EXE "${FUNWAVE_EXE}-${FUNWAVE_FEATURE}")
        EndIf()
    EndForEach()
    #
    # Append compiler id:
    #
    String(TOLOWER ${CMAKE_Fortran_COMPILER_ID} CMAKE_Fortran_COMPILER_ID_LC) 
    Set(FUNWAVE_EXE "${FUNWAVE_EXE}-${CMAKE_Fortran_COMPILER_ID_LC}")
    #
    # Append parallel vs. sequential:
    #
    If (ENABLE_MPI)
        Set(FUNWAVE_EXE "${FUNWAVE_EXE}-parallel")
    Else()
        Set(FUNWAVE_EXE "${FUNWAVE_EXE}-sequential")
    EndIf()
    #
    # Append floating-point precision:
    #
    Set(FUNWAVE_EXE "${FUNWAVE_EXE}-${FP_PRECISION}")
    #
    # Append debug id:
    #
    If (ENABLE_DEBUG)
        Set(FUNWAVE_EXE "${FUNWAVE_EXE}-DEBUG")
    EndIf()
    #
    # Append coord system:
    #
    If (ENABLE_COORD_SPHERICAL)
        Set(FUNWAVE_EXE "${FUNWAVE_EXE}-SPHERICAL")
    EndIf()
EndIf()


#
# Baseline source files, regardless of optional features:
#
Set(FUNWAVE_SOURCES
        mod_param.F mod_global.F mod_dictionary.F mod_input.F mod_bathy_correction.F
        mod_tide.F mod_time_spectra.F

        main.F bc.F fluxes.F init.F io.F tridiagnal.F breaker.F derivatives.F
        dispersion.F etauv_solver.F sponge.F sources.F masks.F statistics.F
        wavemaker.F mixing.F misc.F samples.F
    )
#
# Add source files for optional features:
#
If (ENABLE_COUPLING)
    List(APPEND FUNWAVE_SOURCES nesting.F)
EndIf()
If (ENABLE_VESSEL)
    List(APPEND FUNWAVE_SOURCES mod_vessel.F)
EndIf()
If (ENABLE_METEO)
    List(APPEND FUNWAVE_SOURCES mod_meteo.F)
EndIf()
If (ENABLE_SEDIMENT)
    List(APPEND FUNWAVE_SOURCES mod_sediment.F)
EndIf()
If (ENABLE_TRACKING)
    List(APPEND FUNWAVE_SOURCES mod_tracer.F)
EndIf()
If (ENABLE_FOAM)
    List(APPEND FUNWAVE_SOURCES mod_foam.F)
EndIf()
If (ENABLE_PRECIPITATION)
    List(APPEND FUNWAVE_SOURCES mod_precipitation.F)
EndIf()
If (ENABLE_SUBGRID)
    List(APPEND FUNWAVE_SOURCES mod_subgrid.F)
EndIf()
If (ENABLE_MPI)
    List(APPEND FUNWAVE_SOURCES mod_parallel_field_io.F parallel.F)
EndIf()


#
# Add the executable target with the set of source files computed
# above:
#
Add_executable(${FUNWAVE_EXE} ${FUNWAVE_SOURCES})

#
# Source code is free-format:
#
Set_target_properties(${FUNWAVE_EXE} PROPERTIES Fortran_FORMAT "FREE")

If (ENABLE_MPI)
    #
    # Add any additional preprocessing/compilation/link flags provided
    # by the FindMPI module:
    #
    If (MPI_Fortran_COMPILER_INCLUDE_DIRS)
        Target_include_directories(${FUNWAVE_EXE} PUBLIC ${MPI_Fortran_COMPILER_INCLUDE_DIRS})
    EndIf()
     If (MPI_Fortran_ADDITIONAL_INCLUDE_DIRS)
        Target_include_directories(${FUNWAVE_EXE} PUBLIC ${MPI_Fortran_ADDITIONAL_INCLUDE_DIRS})
    EndIf()
    If (MPI_Fortran_COMPILE_DEFINITIONS)
        Target_compile_definitions(${FUNWAVE_EXE} PUBLIC ${MPI_Fortran_COMPILE_DEFINITIONS})
    EndIf()
    If (MPI_Fortran_COMPILE_OPTIONS)
        Target_compile_options(${FUNWAVE_EXE} PUBLIC ${MPI_Fortran_COMPILE_OPTIONS})
    EndIf()
    If (MPI_Fortran_LINK_FLAGS)
        #
        # Use the SHELL: prefix to avoid deduplication of arguments that would
        # scrub repeated '-Xlinker' clauses, for example:
        #
        Target_link_options(${FUNWAVE_EXE} PUBLIC "SHELL:${MPI_Fortran_LINK_FLAGS}")
    EndIf()
    If (MPI_Fortran_LIBRARIES)
        Target_link_libraries(${FUNWAVE_EXE} PUBLIC ${MPI_Fortran_LIBRARIES})
    EndIf()
EndIf()

#
# Items to install:
#
Install(TARGETS ${FUNWAVE_EXE})
