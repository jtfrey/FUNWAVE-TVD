
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
    If (GIT_HASH MATCHES ^[a-f0-9]+$)
        CheckGitHashRead(GIT_HASH_CACHE)
        if (NOT DEFINED GIT_HASH_CACHE)
            Set(GIT_HASH_CACHE "unknown")
        endif ()
    Else()
        Set(GIT_HASH "unknown")
    EndIf()

    # Only update the git_version.cpp if the hash has changed. This will
    # prevent us from rebuilding the project more than we need to.
    if (NOT ${GIT_HASH} STREQUAL ${GIT_HASH_CACHE})
        # Stash the hash for the next pass:
        CheckGitHashWrite(${GIT_HASH})
        If (EXISTS "$GIT_HASH_OUTFILE")
            File(REMOVE "$GIT_HASH_OUTFILE")
        EndIf()
    endif ()

endfunction()

function(CheckGitHashSetup outfile)
    add_custom_target(AlwaysCheckGitHash COMMAND ${CMAKE_COMMAND}
        -DRUN_CHECK_GIT_HASH_VERSION=1
        -DGIT_HASH_CACHE=${GIT_HASH_CACHE}
        -DGIT_HASH_OUTFILE=${outfile}
        -P ${CMAKE_CURRENT_LIST_DIR}/CheckGitHash.cmake
        BYPRODUCTS ${outfile})
    CheckGitHashVersion()
endfunction()

# This is used to run this function from an external cmake process.
if (RUN_CHECK_GIT_HASH_VERSION)
    CheckGitHashVersion()
endif ()
