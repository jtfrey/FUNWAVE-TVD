#
# Apply fixups for the GNU compiler and the chosen build type:
#
Add_compile_options("-ffree-line-length-none")
If (CMAKE_BUILD_TYPE STREQUAL "Debug")
    Add_compile_options("-fcheck=all" "-Wall")
Else()
    Add_compile_options("-O3")
EndIf()
