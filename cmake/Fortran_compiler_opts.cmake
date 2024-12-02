#
# Optionally include a per-compiler fixer-upper:
#
Set(COMPILER_OPTS_PATH "${CMAKE_CURRENT_LIST_DIR}/Fortran_compiler_opts/${CMAKE_Fortran_COMPILER_ID}.cmake")
If (EXISTS "${COMPILER_OPTS_PATH}")
    Include("${COMPILER_OPTS_PATH}")
EndIf()
