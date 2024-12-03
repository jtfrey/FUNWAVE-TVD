#
# A set of functions that check and cache the full git hash
# for the current source directory.  When/if the hash differs
# from the cached version, an input template file is used to
# generate an output file using Configure_file().
#
# The hash is cached in ${CMAKE_BINARY_DIR}/git-state.txt relative
# to the calling context of CheckGitHashSetup().
#

function(CheckGitHashWrite git_hash)
    file(WRITE ${CMAKE_BINARY_DIR}/git-state.txt ${git_hash})
endfunction()

function(CheckGitHashRead git_hash)
    if (EXISTS ${CMAKE_BINARY_DIR}/git-state.txt)
        file(STRINGS ${CMAKE_BINARY_DIR}/git-state.txt CONTENT)
        LIST(GET CONTENT 0 var)

        set(${git_hash} ${var} PARENT_SCOPE)
    endif ()
endfunction()

function(CheckGitHashVersion)
    # Get the latest commit hash of the working branch
    execute_process(
        COMMAND git log -1 --format=%H
        WORKING_DIRECTORY ${CMAKE_CURRENT_LIST_DIR}
        OUTPUT_VARIABLE GIT_HASH
        OUTPUT_STRIP_TRAILING_WHITESPACE
        )
    If (NOT GIT_HASH MATCHES ^[a-f0-9]+$)
        Set(GIT_HASH "unknown")
    EndIf()
    CheckGitHashRead(GIT_HASH_CACHE)
    if (NOT DEFINED GIT_HASH_CACHE)
        Set(GIT_HASH_CACHE "unknown")
    endif ()
    Message("${GIT_HASH} == ${GIT_HASH_CACHE}")

    # Only update the git_version.cpp if the hash has changed. This will
    # prevent us from rebuilding the project more than we need to.
    if (NOT "${GIT_HASH}" STREQUAL "${GIT_HASH_CACHE}")
        # Stash the hash for the next pass:
        CheckGitHashWrite(${GIT_HASH})
        If (EXISTS "${GIT_HASH_OUTFILE}")
            File(REMOVE "${GIT_HASH_OUTFILE}")
        EndIf()
    endif ()
    If (NOT EXISTS "${GIT_HASH_OUTFILE}" AND EXISTS "${GIT_HASH_INFILE}")
        Configure_file("${GIT_HASH_INFILE}" "${GIT_HASH_OUTFILE}")
    EndIf()
endfunction()

function(CheckGitHashSetup infile outfile)
    add_custom_target(AlwaysCheckGitHash COMMAND ${CMAKE_COMMAND}
        -DRUN_CHECK_GIT_HASH_VERSION=1
        -DGIT_HASH_CACHE=${GIT_HASH_CACHE}
        -DGIT_HASH_INFILE=${infile}
        -DGIT_HASH_OUTFILE=${outfile}
        -P ${CMAKE_CURRENT_LIST_DIR}/cmake/CheckGitHash.cmake
        BYPRODUCTS ${outfile})
    CheckGitHashVersion()
endfunction()

# This is used to run this function from an external cmake process.
if (RUN_CHECK_GIT_HASH_VERSION)
    CheckGitHashVersion()
endif ()
