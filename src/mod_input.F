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
    USE MOD_DICTIONARY
#if defined (PARALLEL)
    USE GLOBAL,ONLY : myid,ier
    USE MPI
# endif
    IMPLICIT NONE

#if defined(PARALLEL)
        Integer, Private :: LAST_MPI_ERR
#   define COND_WARNING_OPEN1(COND, ARG1) \
        If ((COND)) Then ; \
            IF (MYID == 0) Write(*,*) ARG1
#   define COND_WARNING_OPEN2(COND, ARG1, ARG2) \
        If ((COND)) Then ; \
            IF (MYID == 0) Write(*,*) ARG1, ARG2
#   define COND_WARNING_OPEN3(COND, ARG1, ARG2, ARG3) \
        If ((COND)) Then ; \
            IF (MYID == 0) Write(*,*) ARG1, ARG2, ARG3
#   define COND_STOP1(COND, ARG1) \
        If ((COND)) Then ; \
            IF (MYID == 0) Write(*,*) ARG1 ; \
            Call MPI_Finalize(LAST_MPI_ERR) ; \
            Stop ; \
        End If
#   define COND_STOP2(COND, ARG1, ARG2) \
        If ((COND)) Then ; \
            IF (MYID == 0) Write(*,*) ARG1, ARG2 ; \
            Call MPI_Finalize(LAST_MPI_ERR) ; \
            Stop ; \
        End If
#   define COND_STOP3(COND, ARG1, ARG2, ARG3) \
        If ((COND)) Then ; \
            IF (MYID == 0) Write(*,*) ARG1, ARG2, ARG3 ; \
            Call MPI_Finalize(LAST_MPI_ERR) ; \
            Stop ; \
        End If
#else
#   define COND_WARNING_OPEN1(COND, ARG1) \
        If ((COND)) Then ; \
            Write(*,*) ARG1
#   define COND_WARNING_OPEN2(COND, ARG1, ARG2) \
        If ((COND)) Then ; \
            Write(*,*) ARG1, ARG2
#   define COND_WARNING_OPEN3(COND, ARG1, ARG2, ARG3) \
        If ((COND)) Then ; \
            Write(*,*) ARG1, ARG2, ARG3
#   define COND_STOP1(COND, ARG1) \
        If ((COND)) Then ; \
            Write(*,*) ARG1 ; \
            Stop ; \
        End If
#   define COND_STOP2(COND, ARG1, ARG2) \
        If ((COND)) Then ; \
            Write(*,*) ARG1, ARG2 ; \
            Stop ; \
        End If
#   define COND_STOP3(COND, ARG1, ARG2, ARG3) ; \
        If ((COND)) Then ; \
            Write(*,*) ARG1, ARG2, ARG3 ; \
            Stop ; \
        End If
#endif
#define COND_WARNING_CLOSE() End If


! Set when the code (attempts) to open the input file:
    LOGICAL :: FILE_EXIST = .FALSE.

! For stashing the last-accessed input file path/name:
    CHARACTER(LEN=:), ALLOCATABLE :: KEYVALUE_FILE_NAME

! The key-value pairs will be stashed in this table:
    TYPE(dictionary) :: KEYVALUE_PAIRS

! Expose these to external callers:
    PUBLIC :: FILE_EXIST

    INTERFACE READ_FOUR_TYPE_VALUES
        Module Procedure READ_FLOAT
        Module Procedure READ_STRING
        Module Procedure READ_LOGICAL
        Module Procedure READ_INTEGER
    END INTERFACE

CONTAINS

! Raw value

    SUBROUTINE READ_VALUE(FileName,MatchCharacter,VAL,ERR_IF_ONE)
        IMPLICIT NONE
        CHARACTER(LEN=*), INTENT(IN ) :: FileName 
        CHARACTER(LEN=*), INTENT(IN ) :: MatchCharacter 
        CHARACTER(LEN=*), INTENT(OUT) :: VAL
        INTEGER,          INTENT(OUT) :: ERR_IF_ONE
        INTEGER                       :: IERR
        
        ERR_IF_ONE = 1
        IF (.NOT. Allocated(KEYVALUE_FILE_NAME) .OR. &
              (Allocated(KEYVALUE_FILE_NAME) .AND. (FileName /= KEYVALUE_FILE_NAME))) THEN
            IF (Allocated(KEYVALUE_FILE_NAME)) Deallocate(KEYVALUE_FILE_NAME)
            CALL KEYVALUE_PAIRS%init_with_file(TRIM(FileName), FILE_EXIST, IERR)
            KEYVALUE_FILE_NAME = TRIM(FileName)
        END IF
        IF (FILE_EXIST) THEN
            IF (KEYVALUE_PAIRS%get(MatchCharacter, VAL)) ERR_IF_ONE = 0
        END IF
    END SUBROUTINE READ_VALUE
  
! INTEGER

    SUBROUTINE READ_INTEGER(INTEGER_VAL,InputFileName,MatchCharacter,ERR_IF_ONE)  
        IMPLICIT NONE
        INTEGER,          INTENT(OUT) :: INTEGER_VAL 
        CHARACTER(LEN=*), INTENT(IN ) :: InputFileName
        CHARACTER(LEN=*), INTENT(IN ) :: MatchCharacter
        INTEGER,          INTENT(OUT) :: ERR_IF_ONE
        INTEGER                       :: ierr
        CHARACTER(LEN=80)             :: RAW_VALUE, VAL_TYPE
        
        CALL READ_VALUE(InputFileName, MatchCharacter, RAW_VALUE, ERR_IF_ONE)
        
        COND_WARNING_OPEN2(ERR_IF_ONE, TRIM(MatchCharacter), ' DOES NOT EXIST. USE DEFAULT VALUE')
            ELSE
                ! Check argument type
                CALL CHECK_CONSISTENCY_TYPE(RAW_VALUE, VAL_TYPE)
                COND_STOP2(TRIM(VAL_TYPE) .NE. 'INTEGER', TRIM(MatchCharacter), &
                            ' IS NOT INTEGER, STOP!')
                READ(RAW_VALUE,*) INTEGER_VAL
        COND_WARNING_CLOSE()
    END SUBROUTINE READ_INTEGER

! Float

    SUBROUTINE READ_FLOAT(FLOAT_VAL,InputFileName,MatchCharacter,ERR_IF_ONE)  
        IMPLICIT NONE
        REAL(SP),         INTENT(OUT) :: FLOAT_VAL 
        CHARACTER(LEN=*), INTENT(IN ) :: InputFileName
        CHARACTER(LEN=*), INTENT(IN ) :: MatchCharacter
        INTEGER,          INTENT(OUT) :: ERR_IF_ONE
        INTEGER                       :: ierr
        CHARACTER(LEN=80)             :: RAW_VALUE, VAL_TYPE
        
        CALL READ_VALUE(InputFileName, MatchCharacter, RAW_VALUE, ERR_IF_ONE)
        
        COND_WARNING_OPEN2(ERR_IF_ONE, TRIM(MatchCharacter), ' DOES NOT EXIST. USE DEFAULT VALUE')
            ELSE
                ! Check argument type
                CALL CHECK_CONSISTENCY_TYPE(RAW_VALUE, VAL_TYPE)
                COND_STOP2(TRIM(VAL_TYPE) .NE. 'float', TRIM(MatchCharacter), &
                            ' IS NOT FLOAT, STOP!')
                READ(RAW_VALUE,*) FLOAT_VAL
        COND_WARNING_CLOSE()
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
        
        COND_WARNING_OPEN2(ERR_IF_ONE, TRIM(MatchCharacter), ' DOES NOT EXIST. USE DEFAULT VALUE')
            ELSE
                ! Check argument type
                CALL CHECK_CONSISTENCY_TYPE(RAW_VALUE, VAL_TYPE)
                COND_WARNING_OPEN2(TRIM(VAL_TYPE) .NE. 'logical', TRIM(MatchCharacter), &
                            ' IS NOT LOGICAL, SET FALSE EXCEPT FIRST LETTER IS T')
                COND_WARNING_CLOSE()
                
                LOGICAL_VAL = .FALSE.
                IF(RAW_VALUE(1:1) == 'T') LOGICAL_VAL = .TRUE.
        COND_WARNING_CLOSE()
    END SUBROUTINE READ_LOGICAL

! STRING

    SUBROUTINE READ_STRING(STRING_VAL,InputFileName,MatchCharacter,ERR_IF_ONE)  
        IMPLICIT NONE
        CHARACTER(LEN=*), INTENT(OUT) :: STRING_VAL 
        CHARACTER(LEN=*), INTENT(IN ) :: InputFileName
        CHARACTER(LEN=*), INTENT(IN ) :: MatchCharacter
        INTEGER,          INTENT(OUT) :: ERR_IF_ONE
        INTEGER                       :: ierr
        CHARACTER(LEN=80)             :: RAW_VALUE, VAL_TYPE
        
        CALL READ_VALUE(InputFileName, MatchCharacter, RAW_VALUE, ERR_IF_ONE)
        COND_WARNING_OPEN2(ERR_IF_ONE, TRIM(MatchCharacter), ' DOES NOT EXIST. USE DEFAULT VALUE')
            ELSE
                ! Check argument type
                CALL CHECK_CONSISTENCY_TYPE(RAW_VALUE, VAL_TYPE)
                COND_STOP2(TRIM(VAL_TYPE) .NE. 'string', TRIM(MatchCharacter), &
                            ' IS NOT STRING, STOP!')
                STRING_VAL = ADJUSTL(TRIM(RAW_VALUE))
        COND_WARNING_CLOSE()
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

#if defined(ENABLE_MOD_INPUT_TEST_PROGRAM)

PROGRAM TEST
    USE INPUT_READ
    IMPLICIT NONE
    
    CHARACTER(LEN=80) :: SVal
    REAL(SP)          :: FVal
    INTEGER           :: ERR_IF_ONE, IVal
    LOGICAL           :: LVal
        
    CALL READ_STRING(SVal, 'input.txt', 'RESULT_FOLDER', ERR_IF_ONE)
    IF (ERR_IF_ONE /= 1) WRITE(*,*) 'RESULT_FOLDER = ',TRIM(SVal)
    
    CALL READ_FLOAT(FVal, 'input.txt', 'Sponge_west_width', ERR_IF_ONE)
    IF (ERR_IF_ONE /= 1) WRITE(*,*) 'Sponge_west_width = ',FVal
    
    CALL READ_INTEGER(IVal, 'input.txt', 'ITER', ERR_IF_ONE)
    IF (ERR_IF_ONE /= 1) WRITE(*,*) 'ITER = ',IVal
    
    CALL READ_INTEGER(IVal, 'input2.txt', 'ITER', ERR_IF_ONE)
    IF (ERR_IF_ONE /= 1) WRITE(*,*) 'ITER = ',IVal
    
    CALL READ_LOGICAL(LVal, 'input.txt', 'WaveHeight', ERR_IF_ONE)
    IF (ERR_IF_ONE /= 1) WRITE(*,*) 'WaveHeight = ',LVal
END PROGRAM

#endif
