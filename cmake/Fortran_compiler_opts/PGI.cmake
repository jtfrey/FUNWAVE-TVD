#
# Apply fixups for the PGI compiler and the chosen build type:
#
If (NOT CMAKE_BUILD_TYPE STREQUAL "Debug")
    Add_compile_options("-w" "-O2")
EndIf()
