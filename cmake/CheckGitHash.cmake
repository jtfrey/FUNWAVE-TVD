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
    file(WRITE ${CMAKE_BINARY_DIR}/git-hash.txt ${git_hash})
endfunction()

function(CheckGitHashRead git_hash)
    if (EXISTS ${CMAKE_BINARY_DIR}/git-hash.txt)
        file(STRINGS ${CMAKE_BINARY_DIR}/git-hash.txt CONTENT)
        LIST(GET CONTENT 0 var)

        set(${git_hash} ${var} PARENT_SCOPE)
    endif ()
endfunction()

function(CheckGitURLWrite git_url)
    file(WRITE ${CMAKE_BINARY_DIR}/git-url.txt ${git_url})
endfunction()

function(CheckGitURLRead git_url)
    if (EXISTS ${CMAKE_BINARY_DIR}/git-url.txt)
        file(STRINGS ${CMAKE_BINARY_DIR}/git-url.txt CONTENT)
        LIST(GET CONTENT 0 var)

        set(${git_url} ${var} PARENT_SCOPE)
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
    
    # Get the latest origin URL of the working branch
    execute_process(
        COMMAND git config --get remote.origin.url
        WORKING_DIRECTORY ${CMAKE_CURRENT_LIST_DIR}
        OUTPUT_VARIABLE GIT_URL
        OUTPUT_STRIP_TRAILING_WHITESPACE
        )
    If (NOT GIT_URL)
        Set(GIT_URL "unknown")
    EndIf()
    CheckGitURLRead(GIT_URL_CACHE)
    if (NOT DEFINED GIT_URL_CACHE)
        Set(GIT_URL_CACHE "unknown")
    endif ()

    # Only update the generated header when necessary:
    if (NOT "${GIT_HASH}" STREQUAL "${GIT_HASH_CACHE}" OR NOT "${GIT_URL}" STREQUAL "${GIT_URL_CACHE}")
        # Stash the hash for the next pass:
        CheckGitHashWrite(${GIT_HASH})
        # Stash the URL for the next pass:
        CheckGitURLWrite(${GIT_URL})
        If (EXISTS "${GIT_HASH_OUTFILE}")
            File(REMOVE "${GIT_HASH_OUTFILE}")
        EndIf()
    endif ()
    Configure_file("${GIT_HASH_INFILE}" "${GIT_HASH_OUTFILE}")
endfunction()

function(CheckGitHashSetup infile outfile)
    add_custom_target(AlwaysCheckGitHash COMMAND ${CMAKE_COMMAND}
        -DRUN_CHECK_GIT_HASH_VERSION=1
        -DGIT_HASH_INFILE=${infile}
        -DGIT_HASH_OUTFILE=${outfile}
        -P ${CMAKE_CURRENT_LIST_DIR}/cmake/CheckGitHash.cmake
        BYPRODUCTS ${outfile})
endfunction()

# This is used to run this function from an external cmake process.
if (RUN_CHECK_GIT_HASH_VERSION)
    CheckGitHashVersion()
endif ()
