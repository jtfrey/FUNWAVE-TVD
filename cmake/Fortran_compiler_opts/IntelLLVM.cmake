#
# Apply fixups for the Intel oneAPI compiler and the chosen build type:
#
If (CMAKE_BUILD_TYPE STREQUAL "Debug")
    Add_compile_options("-check" "-warn")
Else()
    Add_compile_options("-O2")
    If (ENABLE_INTEL_IPO)
        Add_compile_options("-ipo")
    EndIf()
EndIf()
