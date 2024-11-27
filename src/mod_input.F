!------------------------------------------------------------------------------------
!
!      FILE main.F
!
!      This file is part of the FUNWAVE-TVD program under the Simplified BSD license
!
!-------------------------------------------------------------------------------------
! 
!    Copyright (c) 2016, FUNWAVE Development Team
!
!    (See http://www.udel.edu/kirby/programs/funwave/funwave.html
!     for Development Team membership)
!
!    All rights reserved.
!
!    FUNWAVE_TVD is free software: you can redistribute it and/or modify
!    it under the terms of the Simplified BSD License as released by
!    the Berkeley Software Distribution (BSD).
!
!    Redistribution and use in source and binary forms, with or without
!    modification, are permitted provided that the following conditions are met:
!
!    1. Redistributions of source code must retain the above copyright notice, this
!       list of conditions and the following disclaimer.
!    2. Redistributions in binary form must reproduce the above copyright notice,
!    this list of conditions and the following disclaimer in the documentation
!    and/or other materials provided with the distribution.
!
!    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
!    ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
!    WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
!    DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
!    ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
!    (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
!    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
!    ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
!    (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
!    SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
!  
!    The views and conclusions contained in the software and documentation are those
!    of the authors and should not be interpreted as representing official policies,
!    either expressed or implied, of the FreeBSD Project.
!  
!-------------------------------------------------------------------------------------
!
!  INPUT_READ is a module to handle reading input.txt     
!
!  HISTORY :
!    02/17/2016  Fengyan Shi
!    11/27/2024  Jeffrey T Frey (caching of keyword-value pairs)
!
!-------------------------------------------------------------------------------------

MODULE INPUT_READ

    USE PARAM,ONLY : SP
#if defined (PARALLEL)
    USE GLOBAL,ONLY : myid,ier
    USE MPI
# endif
    IMPLICIT NONE
  
!
! Define a data type for our keyword-value pairs.  We could use allocatable
! fields, but by using a static dimension we ensure a simple bulk allocation
! of memory to the array of pairs.
!
    TYPE :: KEYVALUE_PAIR
        CHARACTER(LEN=80) :: KEYWORD, VALUE
    END TYPE KEYVALUE_PAIR

! Set when the code (attempts) to open the input file:
    LOGICAL :: FILE_EXIST = .FALSE.

! For stashing the last-accessed input file path/name:
    CHARACTER(LEN=:), ALLOCATABLE :: KEYVALUE_FILE_NAME

! The key-value pairs will be stashed in this table:
    INTEGER :: KEYVALUE_LEN = 0, KEYVALUE_CAPACITY = 0
    TYPE(KEYVALUE_PAIR), DIMENSION(:), ALLOCATABLE :: KEYVALUE_PAIRS

! Expose these to external callers:
    PUBLIC :: FILE_EXIST
    PUBLIC :: KEYVALUE_PAIRS_INIT, KEYVALUE_PAIRS_DEALLOC, KEYVALUE_PAIRS_SUMMARIZE
    PUBLIC :: KEYVALUE_PAIRS_RESET, READ_VALUE

! Hide these from external access:
    PRIVATE :: KEYVALUE_FILE_NAME, KEYVALUE_LEN, KEYVALUE_CAPACITY, KEYVALUE_PAIRS
    PRIVATE :: KEYVALUE_PAIRS_BSEARCH, KEYVALUE_PAIRS_ADD, KEYVALUE_PAIRS_GET

    INTERFACE READ_FOUR_TYPE_VALUES
        Module Procedure READ_FLOAT
        Module Procedure READ_STRING
        Module Procedure READ_LOGICAL
        Module Procedure READ_INTEGER
    END INTERFACE

CONTAINS

!
! Returns the index at which the keyword is found:
!
    FUNCTION KEYVALUE_PAIRS_BSEARCH(Keyword) RESULT(OUT_IDX)
        IMPLICIT NONE
        CHARACTER(LEN=*), INTENT(IN) :: Keyword
        INTEGER :: I_LO, I_HI, I_MID, OUT_IDX
        
        OUT_IDX = 0
        I_LO = 1
        I_HI = KEYVALUE_LEN
        DO WHILE (I_LO <= I_HI)
            I_MID = I_LO + ((I_HI - I_LO) / 2)
            IF (Keyword == KEYVALUE_PAIRS(I_MID)%Keyword) THEN
                OUT_IDX = I_MID
                EXIT
            ELSE IF (LGT(Keyword, KEYVALUE_PAIRS(I_MID)%Keyword)) THEN
                I_LO = I_MID + 1
            ELSE
                I_HI = I_MID - 1
            END IF
        END DO
        RETURN
    END FUNCTION KEYVALUE_PAIRS_BSEARCH

!
! Add a keyword-value pair to the table:
!
    SUBROUTINE KEYVALUE_PAIRS_ADD(Keyword, Value)
        IMPLICIT NONE
        CHARACTER(LEN=*), INTENT(IN) :: Keyword
        CHARACTER(LEN=*), INTENT(IN) :: Value
        TYPE(KEYVALUE_PAIR), DIMENSION(:), ALLOCATABLE :: NEW_KEYVALUE_PAIRS
        INTEGER :: I_IDX, J_IDX
        LOGICAL :: WAS_PRESENT = .FALSE.
        
        !
        ! Keep the list sorted by keyword; we do a binary search
        ! to seek out the incoming Keyword.  If it exists, then we
        ! alter the value and that's all.  Otherwise, the search
        ! will have left us with I_LO/I_HI on the last-compared
        ! keyword that did not match:
        !
        IF (KEYVALUE_LEN .GT. 0) THEN
            I_IDX = KEYVALUE_PAIRS_BSEARCH(Keyword)
            IF (I_IDX > 0) THEN
                KEYVALUE_PAIRS(I_IDX)%Value = Value
                WAS_PRESENT = .TRUE.
            END IF
        END IF
        IF (.NOT. WAS_PRESENT) THEN
            !
            ! Resize the array if necessary -- or if it hasn't been allocated yet:
            !
            IF (.NOT. Allocated(KEYVALUE_PAIRS)) THEN
                KEYVALUE_CAPACITY = 25
                KEYVALUE_LEN = 0
                Allocate(KEYVALUE_PAIRS(KEYVALUE_CAPACITY))
            ELSE IF (KEYVALUE_LEN == KEYVALUE_CAPACITY) THEN
                Allocate(NEW_KEYVALUE_PAIRS(KEYVALUE_CAPACITY + 25))
                NEW_KEYVALUE_PAIRS(1:KEYVALUE_LEN) = KEYVALUE_PAIRS(1:KEYVALUE_LEN)
                Deallocate(KEYVALUE_PAIRS)
                KEYVALUE_PAIRS = NEW_KEYVALUE_PAIRS
                KEYVALUE_CAPACITY = KEYVALUE_CAPACITY + 25
            END IF
            !
            ! Find the insertion slot:
            !
            I_IDX = 1
            DO WHILE (I_IDX <= KEYVALUE_LEN)
                IF (LLT(Keyword, KEYVALUE_PAIRS(I_IDX)%Keyword)) EXIT
                I_IDX = I_IDX + 1
            END DO
            IF (I_IDX <= KEYVALUE_LEN) THEN
                !
                ! Shift trailing slots up one index:
                !
                J_IDX = KEYVALUE_LEN
                DO WHILE (J_IDX >= I_IDX)
                    KEYVALUE_PAIRS(J_IDX+1) = KEYVALUE_PAIRS(J_IDX)
                    J_IDX = J_IDX - 1
                END DO
            END IF
            KEYVALUE_PAIRS(I_IDX)%Keyword = Keyword
            KEYVALUE_PAIRS(I_IDX)%Value = Value
            KEYVALUE_LEN = KEYVALUE_LEN + 1
        END IF
    END SUBROUTINE KEYVALUE_PAIRS_ADD

!
! Add a keyword-value pair to the table:
!
    FUNCTION KEYVALUE_PAIRS_GET(Keyword, Value) RESULT(WAS_PRESENT)
        IMPLICIT NONE
        CHARACTER(LEN=*), INTENT(IN) :: Keyword
        CHARACTER(LEN=*), INTENT(OUT) :: Value
        LOGICAL :: WAS_PRESENT
        INTEGER :: I_IDX

        WAS_PRESENT = .FALSE.
        IF (KEYVALUE_LEN .GT. 0) THEN
            I_IDX = KEYVALUE_PAIRS_BSEARCH(Keyword)
            IF (I_IDX > 0) THEN
                Value = KEYVALUE_PAIRS(I_IDX)%Value
                WAS_PRESENT = .TRUE.
            END IF
        END IF
        RETURN
    END FUNCTION KEYVALUE_PAIRS_GET

!
! Empty the cached keyword-value pairs if they exist:
!
    SUBROUTINE KEYVALUE_PAIRS_RESET()
        IMPLICIT NONE
        
        IF (Allocated(KEYVALUE_FILE_NAME)) Deallocate(KEYVALUE_FILE_NAME)
        FILE_EXIST = .FALSE.
        KEYVALUE_LEN = 0
    END SUBROUTINE KEYVALUE_PAIRS_RESET

!
! Destroy the cached keyword-value pairs if they exist:
!
    SUBROUTINE KEYVALUE_PAIRS_DEALLOC()
        IMPLICIT NONE

        IF (Allocated(KEYVALUE_FILE_NAME)) Deallocate(KEYVALUE_FILE_NAME)
        IF (Allocated(KEYVALUE_PAIRS)) Deallocate(KEYVALUE_PAIRS)
        FILE_EXIST = .FALSE.
        KEYVALUE_CAPACITY = 0
        KEYVALUE_LEN = 0
    END SUBROUTINE KEYVALUE_PAIRS_DEALLOC

!
! Summarize the keyword-value pairs:
!
    SUBROUTINE KEYVALUE_PAIRS_SUMMARIZE()
        IMPLICIT NONE
        INTEGER :: idx
        
        idx = 1
        WRITE(*,'("File name: ",A," with ",I0," pairs")') TRIM(KEYVALUE_FILE_NAME), KEYVALUE_LEN
        DO WHILE (idx <= KEYVALUE_LEN)
            WRITE(*,1000) TRIM(KEYVALUE_PAIRS(idx)%Keyword), TRIM(KEYVALUE_PAIRS(idx)%Value)
            idx = idx + 1
        END DO
1000 FORMAT('    [',A,'] = [',A,']')
    END SUBROUTINE KEYVALUE_PAIRS_SUMMARIZE

!
! Read the input file and stash all keyword-value pairs:
!
    SUBROUTINE KEYVALUE_PAIRS_INIT(InputFileName)
        IMPLICIT NONE
    
        CHARACTER(LEN=*), INTENT(IN) :: InputFileName
        CHARACTER(LEN=132) :: TextBuffer
        CHARACTER(LEN=1), PARAMETER :: CommentDelim = '!'
        INTEGER :: ierr, equalIdx, endIdx, TextLength
    
        IF (.NOT. Allocated(KEYVALUE_FILE_NAME) .OR. (Allocated(KEYVALUE_FILE_NAME) .AND. &
                InputFileName /= KEYVALUE_FILE_NAME)) THEN
            CALL KEYVALUE_PAIRS_RESET()
            INQUIRE(FILE=InputFileName, EXIST=FILE_EXIST)
            IF (FILE_EXIST) THEN
                OPEN(10, FILE=InputFileName, ACTION='READ', POSITION='REWIND', STATUS='OLD', &
                         IOSTAT=ierr)
                IF (ierr == 0) THEN
                    KEYVALUE_FILE_NAME = InputFileName
                    !
                    ! Read the file line by line:
                    !
                    ierr = 0
                    DO WHILE (ierr == 0)
                        READ(10, '(A)', iostat=ierr) TextBuffer
                        IF (ierr == 0) THEN
                            ! Any comment delimiter in the line?  If not, set the endIdx to
                            ! the last character of the string:
                            endIdx = INDEX(TextBuffer, CommentDelim)
                            IF (endIdx == 0) endIdx = LEN_TRIM(TextBuffer) + 1
                            ! Cut the string to length:
                            TextBuffer = TRIM(TextBuffer(1:endIdx - 1))
                            TextLength = LEN(TextBuffer)
                            ! Find the keyword-value separator:
                            equalIdx = INDEX(TextBuffer, '=')
                            IF (equalIdx > 0) THEN
                                CALL KEYVALUE_PAIRS_ADD(ADJUSTL(TRIM(TextBuffer(1:equalIdx-1))), &
                                                        ADJUSTL(TRIM(TextBuffer(equalIdx+1:TextLength))))
                            END IF
                        END IF
                    END DO
                    CLOSE(10)
                ELSE
#if defined (PARALLEL)
                    IF (MYID == 0)  &
#endif
                    WRITE(*,*) TRIM(InputFileName), ' CAN NOT BE OPENED (iostat=',ierr,'). STOP'
#if defined (PARALLEL)
                    MPI_FINALIZE(ierr)
#endif
                    STOP
                END IF
            ELSE
#if defined (PARALLEL)
                IF (MYID == 0)  &
#endif
                WRITE(*,*) TRIM(InputFileName), ' CAN NOT BE FOUND. STOP'
#if defined (PARALLEL)
                MPI_FINALIZE(ierr)
#endif
                STOP
            END IF
        END IF
    END SUBROUTINE KEYVALUE_PAIRS_INIT

! Raw value

    SUBROUTINE READ_VALUE(FileName,MatchCharacter,VAL,ERR_IF_ONE)
        IMPLICIT NONE
        CHARACTER(LEN=*), INTENT(IN ) :: FileName 
        CHARACTER(LEN=*), INTENT(IN ) :: MatchCharacter 
        CHARACTER(LEN=*), INTENT(OUT) :: VAL
        INTEGER,          INTENT(OUT) :: ERR_IF_ONE
        
        ERR_IF_ONE = 1
        CALL KEYVALUE_PAIRS_INIT(FileName)
        IF (FILE_EXIST) THEN
            IF (KEYVALUE_PAIRS_GET(MatchCharacter, VAL)) ERR_IF_ONE = 0
        END IF
    END SUBROUTINE READ_VALUE
  
! INTEGER

    SUBROUTINE READ_INTEGER(INTEGER_VAL,InputFileName,MatchCharacter,ERR_IF_ONE)  
        IMPLICIT NONE
        INTEGER,          INTENT(OUT) :: INTEGER_VAL 
        CHARACTER(LEN=*), INTENT(IN ) :: InputFileName
        CHARACTER(LEN=*), INTENT(IN ) :: MatchCharacter
        INTEGER,          INTENT(OUT) :: ERR_IF_ONE
        CHARACTER(LEN=80)             :: RAW_VALUE, VAL_TYPE
        
        CALL READ_VALUE(InputFileName, MatchCharacter, RAW_VALUE, ERR_IF_ONE)
        IF (ERR_IF_ONE == 1) THEN
#if defined (PARALLEL)
            IF (MYID == 0)  &
#endif
            WRITE(*,*) TRIM(MatchCharacter), ' DOES NOT EXIST. USE DEFAULT VALUE'
        ELSE
            ! Check argument type
            CALL CHECK_CONSISTENCY_TYPE(RAW_VALUE, VAL_TYPE)
            IF(TRIM(VAL_TYPE) .NE. 'INTEGER') THEN
#if defined (PARALLEL)
                IF (MYID == 0)  &
#endif
                WRITE(*,*) TRIM(MatchCharacter), ' IS NOT INTEGER, STOP!'
#if defined (PARALLEL)
                MPI_FINALIZE(ierr)
#endif
                STOP
            END IF
            READ(RAW_VALUE,*) INTEGER_VAL   
        END IF
    END SUBROUTINE READ_INTEGER

! Float

    SUBROUTINE READ_FLOAT(FLOAT_VAL,InputFileName,MatchCharacter,ERR_IF_ONE)  
        IMPLICIT NONE
        REAL(SP),         INTENT(OUT) :: FLOAT_VAL 
        CHARACTER(LEN=*), INTENT(IN ) :: InputFileName
        CHARACTER(LEN=*), INTENT(IN ) :: MatchCharacter
        INTEGER,          INTENT(OUT) :: ERR_IF_ONE
        CHARACTER(LEN=80)             :: RAW_VALUE, VAL_TYPE
        
        CALL READ_VALUE(InputFileName, MatchCharacter, RAW_VALUE, ERR_IF_ONE)
        IF (ERR_IF_ONE == 1) THEN
#if defined (PARALLEL)
            IF (MYID == 0)  &
#endif
            WRITE(*,*) TRIM(MatchCharacter), ' DOES NOT EXIST. USE DEFAULT VALUE'
        ELSE
            ! Check argument type
            CALL CHECK_CONSISTENCY_TYPE(RAW_VALUE, VAL_TYPE)
            IF(TRIM(VAL_TYPE) .NE. 'float') THEN
#if defined (PARALLEL)
                IF (MYID == 0)  &
#endif
                WRITE(*,*) TRIM(MatchCharacter), ' IS NOT FLOAT, STOP!'
#if defined (PARALLEL)
                MPI_FINALIZE(ierr)
#endif
                STOP
            END IF
            READ(RAW_VALUE,*) FLOAT_VAL   
        END IF
    END SUBROUTINE READ_FLOAT

! Logical

    SUBROUTINE READ_LOGICAL(LOGICAL_VAL,InputFileName,MatchCharacter,ERR_IF_ONE)  
        IMPLICIT NONE
        LOGICAL,          INTENT(OUT) :: LOGICAL_VAL 
        CHARACTER(LEN=*), INTENT(IN ) :: InputFileName
        CHARACTER(LEN=*), INTENT(IN ) :: MatchCharacter
        INTEGER,          INTENT(OUT) :: ERR_IF_ONE
        CHARACTER(LEN=80)             :: RAW_VALUE, VAL_TYPE
        
        CALL READ_VALUE(InputFileName, MatchCharacter, RAW_VALUE, ERR_IF_ONE)
        IF (ERR_IF_ONE == 1) THEN
#if defined (PARALLEL)
            IF (MYID == 0)  &
#endif
            WRITE(*,*) TRIM(MatchCharacter), ' DOES NOT EXIST. USE DEFAULT VALUE'
        ELSE
            ! Check argument type
            CALL CHECK_CONSISTENCY_TYPE(RAW_VALUE, VAL_TYPE)
            IF(TRIM(VAL_TYPE) .NE. 'logical') THEN
#if defined (PARALLEL)
                IF (MYID == 0)  &
#endif
                WRITE(*,*) TRIM(MatchCharacter), ' IS NOT LOGICAL, SET FALSE EXCEPT FIRST LETTER IS T'
            END IF
            LOGICAL_VAL = .FALSE.
            IF(RAW_VALUE(1:1) == 'T') LOGICAL_VAL = .TRUE.
        END IF
    END SUBROUTINE READ_LOGICAL

! STRING

    SUBROUTINE READ_STRING(STRING_VAL,InputFileName,MatchCharacter,ERR_IF_ONE)  
        IMPLICIT NONE
        CHARACTER(LEN=*), INTENT(OUT) :: STRING_VAL 
        CHARACTER(LEN=*), INTENT(IN ) :: InputFileName
        CHARACTER(LEN=*), INTENT(IN ) :: MatchCharacter
        INTEGER,          INTENT(OUT) :: ERR_IF_ONE
        CHARACTER(LEN=80)             :: RAW_VALUE, VAL_TYPE
        
        CALL READ_VALUE(InputFileName, MatchCharacter, RAW_VALUE, ERR_IF_ONE)
        IF (ERR_IF_ONE == 1) THEN
#if defined (PARALLEL)
            IF (MYID == 0)  &
#endif
            WRITE(*,*) TRIM(MatchCharacter), ' DOES NOT EXIST. USE DEFAULT VALUE'
        ELSE
            ! Check argument type
            CALL CHECK_CONSISTENCY_TYPE(RAW_VALUE, VAL_TYPE)
            IF(TRIM(VAL_TYPE) .NE. 'string') THEN
#if defined (PARALLEL)
                IF (MYID == 0)  &
#endif
                WRITE(*,*) TRIM(MatchCharacter), ' IS NOT STRING, STOP!'
#if defined (PARALLEL)
                MPI_FINALIZE(ierr)
#endif
                STOP
            END IF
            STRING_VAL = ADJUSTL(TRIM(RAW_VALUE))
        END IF
    END SUBROUTINE READ_STRING 

! Infer type of value read from file

    SUBROUTINE CHECK_CONSISTENCY_TYPE(VREAD, VTYPE)
        IMPLICIT NONE
        CHARACTER(LEN=*), INTENT(IN)  :: VREAD
        CHARACTER(LEN=*), INTENT(OUT) :: VTYPE
        CHARACTER(LEN=16), PARAMETER  :: NUMBERS = '0123456789+-Ee. '
        INTEGER                       :: LOGICAL_VAL_READ, DotLocation, I
        
        LOGICAL_VAL_READ = LEN_TRIM(ADJUSTL(VREAD))
        
        ! Logical?
        IF (LOGICAL_VAL_READ == 1) THEN            
            IF (VREAD(1:1) == "T" .or. VREAD(1:1) == "F") THEN 
                VTYPE = 'logical' 
                RETURN
            END IF
        END IF
        
        ! String?
        DO I = 1, LOGICAL_VAL_READ
            IF (INDEX(NUMBERS, VREAD(I:I)) == 0) THEN
                VTYPE = 'string'
                RETURN
            END IF
        END DO
        
        ! Float?
        DotLocation = INDEX(VREAD, '.')
        IF (DotLocation /= 0) THEN
            VTYPE = 'float'
        ELSE
            VTYPE = 'INTEGER'
        END IF
    END SUBROUTINE CHECK_CONSISTENCY_TYPE

END MODULE INPUT_READ

#if defined(MOD_INPUT_TEST_PROGRAM)

PROGRAM TEST
    USE INPUT_READ
    IMPLICIT NONE
    
    CHARACTER(LEN=80) :: SVal
    REAL(SP)          :: FVal
    INTEGER           :: ERR_IF_ONE, IVal
    LOGICAL           :: LVal
    
    !
    ! Calling KEYVALUE_PAIRS_INIT() is optional; on the first call to a
    ! READ_(INTEGER|FLOAT|LOGICAL|STRING) subroutine the cache will be
    ! populated from the named file.
    !
    ! Any time the file name passed to one of those functions changes
    ! relative to the last-cached file name, the cache will be purged and
    ! repopulated from that file.  Since the majority of input file reads
    ! come from the same file and occur in sequence, the number of file
    ! reads is minimized at the expense of a little RAM.
    !
    CALL KEYVALUE_PAIRS_INIT('input.txt')
    IF (FILE_EXIST) THEN
        CALL KEYVALUE_PAIRS_SUMMARIZE()
        WRITE(*,*)
        
        CALL READ_STRING(SVal, 'input.txt', 'RESULT_FOLDER', ERR_IF_ONE)
        IF (ERR_IF_ONE /= 1) WRITE(*,*) 'RESULT_FOLDER = ',TRIM(SVal)
        
        CALL READ_FLOAT(FVal, 'input.txt', 'Sponge_west_width', ERR_IF_ONE)
        IF (ERR_IF_ONE /= 1) WRITE(*,*) 'Sponge_west_width = ',FVal
        
        CALL KEYVALUE_PAIRS_DEALLOC()
        
        CALL READ_INTEGER(IVal, 'input.txt', 'ITER', ERR_IF_ONE)
        IF (ERR_IF_ONE /= 1) WRITE(*,*) 'ITER = ',IVal
        
        CALL KEYVALUE_PAIRS_RESET()
        
        CALL READ_LOGICAL(LVal, 'input.txt', 'WaveHeight', ERR_IF_ONE)
        IF (ERR_IF_ONE /= 1) WRITE(*,*) 'WaveHeight = ',LVal
    END IF
END PROGRAM

#endif