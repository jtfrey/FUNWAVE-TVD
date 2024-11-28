!------------------------------------------------------------------------------------
!
!      FILE mod_dictionary.F
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
!  mod_dictionary declares and defines a Fortran class that implements a basic
!  key-value store, called a dictionary.  The API borrows heavily from the Python dict
!  class.
!
!  There are two subclasses that override the key normalization subroutine to
!  fix all keys to upper- or lowercase strings.  This essentially affords caseless
!  key comparisons.  
!
!  HISTORY :
!    11/27/2024  Jeffrey T Frey
!
!-------------------------------------------------------------------------------------
Module mod_dictionary
    Implicit None
    
    ! All elements default to being private scope
    Private
    
    ! Fixed dimension of our key-value strings:
    Integer, Public, Parameter :: DICTIONARY_MAX_KEY_LEN = 80
    Integer, Public, Parameter :: DICTIONARY_MAX_VALUE_LEN = 80
    
    ! Default capacity:
    Integer, Parameter :: DICTIONARY_DEFAULT_CAPACITY = 24
    
    ! How many slots to grow the keypair list:
    Integer, Parameter :: DICTIONARY_KEYPAIR_LIST_DELTA = 24
    
    ! A key and value pair; the strings use fixed
    ! dimensions so each instance occupies a fixed
    ! number of bytes.
    Type :: keypair
        Character(Len=DICTIONARY_MAX_KEY_LEN)   :: k
        Character(Len=DICTIONARY_MAX_VALUE_LEN) :: v
    End Type keypair
    
    ! A dictionary consists of an allocatable
    ! array of keypair's and a capacity versus
    ! in-use length.  Only the [1:length] indices
    ! are deemed in-use, and the keypair's therein
    ! are sorted by key.  This allows for a binary
    ! search to lookup keys.
    Type, Public :: dictionary
        Integer                                  :: capacity, length, iter_idx
        Type(keypair), Dimension(:), Allocatable :: keypairs
    Contains
        Procedure, Public  :: init => dictionary_init
        Procedure, Public  :: init_with_file => dictionary_init_with_file
        
        Procedure, Public  :: dealloc => dictionary_dealloc
        
        Procedure, Private :: fixup_key => dictionary_fixup_key
        
        Procedure, Public  :: clear => dictionary_clear
        Procedure, Public  :: get => dictionary_get
        Procedure, Public  :: set => dictionary_set
        
        Procedure, Public  :: iter_start => dictionary_iter_start
        Procedure, Public  :: iter_next_key => dictionary_iter_next_key
        Procedure, Public  :: iter_next => dictionary_iter_next
        
        Procedure, Public  :: take => dictionary_take
        
        Procedure, Public  :: summarize => dictionary_summarize
    End Type dictionary
    
    ! A subclass that normalizes all keys to lowercase character
    ! strings.
    Type, Public, Extends(dictionary) :: lc_dictionary
    Contains
        Procedure, Private :: fixup_key => lc_dictionary_fixup_key
    End Type lc_dictionary
    
    ! A subclass that normalizes all keys to uppercase character
    ! strings.
    Type, Public, Extends(dictionary) :: uc_dictionary
    Contains
        Procedure, Private :: fixup_key => uc_dictionary_fixup_key
    End Type uc_dictionary
    

Contains

    !
    ! @method dictionary_init
    !
    ! Initialize a dictionary object to have _at least_ the
    ! desired capacity.  If the object was previously initialized
    ! and the existing capacity exceeds the incoming capacity
    ! value, the keypairs array is _not_ reallocated at a
    ! smaller size.
    !
    Subroutine dictionary_init(this, capacity)
        Implicit None
        
        Class(dictionary), Intent(INOUT) :: this
        Integer, Optional, Intent(IN)    :: capacity
        Integer                          :: actual_capacity
        
        If (.NOT. Present(capacity)) Then
            actual_capacity = DICTIONARY_DEFAULT_CAPACITY
        Else
            actual_capacity = capacity
        End If
        If (Allocated(this%keypairs)) Then
            If (actual_capacity > this%capacity) Then
                Deallocate(this%keypairs)
                Allocate(this%keypairs(actual_capacity))
                this%capacity = actual_capacity
            End If
        Else
            Allocate(this%keypairs(actual_capacity))
            this%capacity = actual_capacity
        End If
        this%length = 0
    End Subroutine dictionary_init

    !
    ! @method dictionary_init_with_file
    !
    ! Initialize a dictionary object to have the key-value pairs
    ! present in the file at the given filepath.  On return, does_file_exist
    ! is set to indicate whether or not the file was present and ierr contains any
    ! i/o error code associated with opening/reading the file.
    !
    Subroutine dictionary_init_with_file(this, filepath, does_file_exist, ierr, capacity)
        Implicit None
        
        Class(dictionary), Intent(INOUT) :: this
        Character(Len=*), Intent(IN)     :: filepath
        Logical, Intent(OUT)             :: does_file_exist
        Integer, Intent(OUT)             :: ierr
        Integer, Optional, Intent(IN)    :: capacity
        Character(Len=1), Parameter      :: comment_delim = '!'
        Character(Len=132)               :: text_buffer
        Integer                          :: actual_capacity, &
                                            equal_idx, end_idx, text_length
        
        If (.NOT. Present(capacity)) Then
            actual_capacity = DICTIONARY_DEFAULT_CAPACITY
        Else
            actual_capacity = capacity
        End If
        Call this%init(actual_capacity)
        
        Inquire(FILE=filepath, EXIST=does_file_exist, IOSTAT=ierr)
        If (does_file_exist) Then
            Open(10, FILE=filepath, ACTION='READ', POSITION='REWIND', STATUS='OLD', &
                         IOSTAT=ierr)
            If (ierr == 0) Then
                !
                ! Read the file line by line:
                !
                Do While (.True.)
                    Read(10, '(A)', iostat=ierr) text_buffer
                    If (ierr == 0) Then
                        ! Any comment delimiter in the line?  If not, set the end_idx to
                        ! the last character of the string:
                        end_idx = Index(text_buffer, comment_delim)
                        IF (end_idx == 0) end_idx = Len_Trim(text_buffer) + 1
                        ! Cut the string to length:
                        text_buffer = Trim(text_buffer(1:end_idx - 1))
                        text_length = Len(text_buffer)
                        ! Find the keyword-value separator:
                        equal_idx = Index(text_buffer, '=')
                        If (equal_idx > 0) Then
                            Call this%set(AdjustL(Trim(text_buffer(1:equal_idx - 1))), &
                                          AdjustL(Trim(text_buffer(equal_idx + 1:text_length))))
                        End If
                    Else If (ierr < 0) Then
                        ! Do not report end-of-file
                        ierr = 0
                        Exit
                    Else
                        Exit
                    End If
                End Do
                Close(10)
            End If
        End If
    End Subroutine dictionary_init_with_file
    
    !
    ! @method dictionary_destructor
    !
    ! Cleanup the dynamically-allocated storage associated with
    ! the object in preparation for its going out of scope.
    !
    Subroutine dictionary_dealloc(this)
        Implicit None
        
        Class(dictionary), Intent(INOUT)         :: this
    
        If (Allocated(this%keypairs)) Deallocate(this%keypairs)
        this%capacity = 0
        this%length = 0
    End Subroutine dictionary_dealloc
    
    !
    ! @method dictionary_fixup_key
    !
    ! Apply any normalization to the key prior to all interaction with
    ! the object.
    !
    ! The base implementation does nothing to the key.  Subclasses can
    ! force the string to lowercase, for example.
    !
    Subroutine dictionary_fixup_key(this, k)
        Implicit None
        
        Class(dictionary), Intent(INOUT)                     :: this
        Character(Len=DICTIONARY_MAX_KEY_LEN), Intent(INOUT) :: k
    End Subroutine
    
    !
    ! @method dictionary_key_bsearch
    !
    ! A private method that locates the index of the key pair
    ! whose key matches the string in argument k.  Returns
    ! zero (0) if the key is not found.
    !
    Function dictionary_key_bsearch(this, k) Result(out_idx)
        Implicit None
        
        Integer                          :: out_idx
        Class(dictionary), Intent(INOUT) :: this
        Character(Len=*),  Intent(IN)    :: k
        Integer                          :: i_lo, i_hi, i_mid
        
        out_idx = 0
        i_lo = 1
        i_hi = this%length
        Do While (i_lo <= i_hi)
            i_mid = i_lo + ((i_hi - i_lo) / 2)
            If (k == this%keypairs(i_mid)%k) Then
                out_idx = i_mid
                Return
            Else If (LGT(k, this%keypairs(i_mid)%k)) Then
                i_lo = i_mid + 1
            Else
                i_hi = i_mid - 1
            End If
        End Do
        Return
    End Function dictionary_key_bsearch
    
    !
    ! @method dictionary_clear
    !
    ! Drop all key-value pairs in the object.  The keypair
    ! storage is not deallocated, the number of keypair's
    ! in-use is just reset to zero (0).
    !
    Subroutine dictionary_clear(this)
        Implicit None
        
        Class(dictionary), Intent(INOUT) :: this
        
        this%length = 0
    End Subroutine dictionary_clear
    
    !
    ! @method dictionary_get
    !
    ! Attempt to retrieve the value associated with key k in
    ! the object.  If the key is present the value is copied to
    ! v and the return value is .True.  Otherwise, if a
    ! default_v value is provided it is copied to v (but the
    ! return value is still .False.).
    !
    Function dictionary_get(this, k, v, default_v) Result(was_present)
        Implicit None
        
        Logical                                 :: was_present
        Class(dictionary), Intent(INOUT)        :: this
        Character(Len=*),  Intent(IN)           :: k
        Character(Len=*),  Intent(OUT)          :: v
        Character(Len=*),  Intent(IN), Optional :: default_v
        Character(Len=DICTIONARY_MAX_KEY_LEN)   :: kk
        Integer                                 :: k_idx
        
        kk = k
        Call this%fixup_key(kk)
        
        was_present = .False.
        k_idx = dictionary_key_bsearch(this, kk)
        If (k_idx > 0) Then
            was_present = .True.
            v = this%keypairs(k_idx)%v
        Else If (Present(default_v)) Then
            v = default_v
        End If
        Return
    End Function dictionary_get
    
    !
    ! @method dictionary_set
    !
    ! Attempt to associate the value v with key k in the object's
    ! list of key-value pairs.  If k is already present, the existing
    ! value is replaced.  If k is not present and the object's keypair
    ! capacity has been reached, the keypairs array must be resized
    ! before the new key is inserted.
    !
    Subroutine dictionary_set(this, k, v)
        Implicit None
        
        Class(dictionary), Intent(INOUT)         :: this
        Character(Len=*),  Intent(IN)            :: k
        Character(Len=*),  Intent(IN)            :: v
        Character(Len=DICTIONARY_MAX_KEY_LEN)    :: kk
        Integer                                  :: k_idx, i_idx
        Type(keypair), Dimension(:), Allocatable :: new_keypairs
        
        kk = k
        Call this%fixup_key(kk)
        
        k_idx = dictionary_key_bsearch(this, kk)
        If (k_idx > 0) Then
            this%keypairs(k_idx)%v = v
        Else
            ! We're going to have to add a new key to the
            ! list, so ensure we have enough capacity:
            If (this%length == this%capacity) Then
                Allocate(new_keypairs(this%capacity + DICTIONARY_KEYPAIR_LIST_DELTA))
                new_keypairs(1:this%length) = this%keypairs(1:this%length)
                If (Allocated(this%keypairs)) Deallocate(this%keypairs)
                this%keypairs = new_keypairs
                this%capacity = this%capacity + DICTIONARY_KEYPAIR_LIST_DELTA
            End If
            
            ! Find the insertion index:
            k_idx = 1
            Do While (k_idx <= this%length)
                If (LLT(k, this%keypairs(k_idx)%k)) Exit
                k_idx = k_idx + 1
            End Do
            
            If (k_idx <= this%length) Then
                ! Shift trailing slots up one index:
                i_idx = this%length
                Do While (i_idx >= k_idx)
                    this%keypairs(i_idx+1) = this%keypairs(i_idx)
                    i_idx = i_idx - 1
                End Do
            End If
            this%keypairs(k_idx)%k = kk
            this%keypairs(k_idx)%v = v
            this%length = this%length + 1
        End If
    End Subroutine dictionary_set
    
    !
    ! @method dictionary_iter_start
    !
    ! Reset the iteration index used by the iter*() funtions.
    !
    Subroutine dictionary_iter_start(this)
        Implicit None
        
        Class(dictionary), Intent(INOUT) :: this
        
        this%iter_idx = 1
    End Subroutine dictionary_iter_start
    
    !
    ! @method dictionary_iter_next_key
    !
    ! If the iteration index has not traversed the entire array,
    ! set k to the current key and return .True.  Otherwise,
    ! return .False.
    !
    Function dictionary_iter_next_key(this, k) Result(is_not_done)
        Implicit None
        
        Logical                          :: is_not_done
        Class(dictionary), Intent(INOUT) :: this
        Character(Len=*),  Intent(OUT)   :: k
        
        If ( this%iter_idx <= this%length ) Then
            k = this%keypairs(this%iter_idx)%k
            this%iter_idx = this%iter_idx + 1
            is_not_done = .True.
        Else
            is_not_done = .False.
        End If
        Return
    End Function dictionary_iter_next_key
    
    !
    ! @method dictionary_iter_next
    !
    ! If the iteration index has not traversed the entire array,
    ! set k to the current key and v to its value, then return .True.
    ! Otherwise, return .False.
    !
    Function dictionary_iter_next(this, k, v) Result(is_not_done)
        Implicit None
        
        Logical                          :: is_not_done
        Class(dictionary), Intent(INOUT) :: this
        Character(Len=*),  Intent(OUT)   :: k, v
        
        If ( this%iter_idx <= this%length ) Then
            k = this%keypairs(this%iter_idx)%k
            v = this%keypairs(this%iter_idx)%v
            this%iter_idx = this%iter_idx + 1
            is_not_done = .True.
        Else
            is_not_done = .False.
        End If
        Return
    End Function dictionary_iter_next
    
    !
    ! @method dictionary_take
    !
    ! Add key-value pairs from other_dict to this dictionary.
    ! Any existing pairs in this dictionary are overridden with
    ! the value coming from other_dict.
    !
    Subroutine dictionary_take(this, other_dict)
        Implicit None
        
        Class(dictionary), Intent(INOUT) :: this
        Class(dictionary), Intent(IN)    :: other_dict
        Integer                          :: k_idx
        
        k_idx = 1
        Do While (k_idx <= other_dict%length)
            Call this%set(other_dict%keypairs(k_idx)%k, other_dict%keypairs(k_idx)%v)
            k_idx = k_idx + 1
        End Do
    End Subroutine dictionary_take
    
    !
    ! @method dictionary_summarize
    !
    ! Write all key-value pairs to stdout.
    !
    Subroutine dictionary_summarize(this)
        Implicit None
        
        Class(dictionary), Intent(INOUT) :: this
        Integer                          :: k_idx
        
        k_idx = 1
        Do While (k_idx <= this%length)
            Write(*,'("[",A,"] = [",A,"]")') TRIM(this%keypairs(k_idx)%k), &
                                             TRIM(this%keypairs(k_idx)%v)
            k_idx = k_idx + 1
        End Do
    End Subroutine dictionary_summarize
    
    !
    ! @method lc_dictionary_fixup_key
    !
    ! Force keys to lowercase character strings.
    !
    Subroutine lc_dictionary_fixup_key(this, k)
        Implicit None
        
        Class(lc_dictionary), Intent(INOUT)                  :: this
        Character(Len=DICTIONARY_MAX_KEY_LEN), Intent(INOUT) :: k
        Integer                                              :: k_idx, c
        
        Do k_idx = 1, Len(k)
            c = Iachar(k(k_idx:k_idx))
            If (c >= Iachar('A') .AND. c <= Iachar('Z')) c = c + 32
            k(k_idx:k_idx) = Achar(c)
        End Do
    End Subroutine lc_dictionary_fixup_key
    
    !
    ! @method uc_dictionary_fixup_key
    !
    ! Force keys to uppercase character strings.
    !
    Subroutine uc_dictionary_fixup_key(this, k)
        Implicit None
        
        Class(uc_dictionary), Intent(INOUT)                  :: this
        Character(Len=DICTIONARY_MAX_KEY_LEN), Intent(INOUT) :: k
        Integer                                              :: k_idx, c
        
        Do k_idx = 1, Len(k)
            c = Iachar(k(k_idx:k_idx))
            If (c >= Iachar('a') .AND. c <= Iachar('z')) c = c - 32
            k(k_idx:k_idx) = Achar(c)
        End Do
    End Subroutine uc_dictionary_fixup_key

End Module mod_dictionary

#if defined(ENABLE_MOD_DICTIONARY_TEST_PROGRAM)

Program dict_test
    Use mod_dictionary
    Implicit None
    
    type(uc_dictionary)                     :: d
    Character(Len=DICTIONARY_MAX_KEY_LEN)   :: k
    Character(Len=DICTIONARY_MAX_VALUE_LEN) :: v
    Integer                                 :: ierr
    Logical                                 :: l_dummy, file_exist
    
    ! Initialize the dictionary with a capacity of 4 key-value pairs:
    Call d%init_with_file('input.txt', file_exist, ierr)
    
    ! Demonstrate setting value in the dictionary:
    Call d%set('x', '1.5')
    Call d%set('y', '-3.25')
    Call d%set('z', '0.44')
    Call d%set('Author', '<frey@udel.edu>')
    
    ! Demonstrate getting a value with no default:
    l_dummy = d%get('Author', v)
    Write(*,*) '"Author" = "',Trim(v),'"'
    Write(*,*)
    
    ! Demonstrate getting a value with default:
    l_dummy = d%get('DummyKeyShouldNotExist', v, default_v='this-is-a-default-value')
    Write(*,*) '"DummyKeyShouldNotExist" = "',Trim(v),'"'
    Write(*,*)
    
    ! Demonstrate using iteration over the dictionary:
    Call d%iter_start()
    Do While (d%iter_next(k, v))
        Write(*,*) 'k="',Trim(k),'", v="',Trim(v),'"'
    End Do
    
End Program

#endif
