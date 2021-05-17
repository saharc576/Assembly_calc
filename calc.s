%define STACK_MAX_SIZE 63
%define STACK_MIN_SIZE 2
%define STACK_DEF_SIZE 5
%define MAX_INPUT_SIZE 80
%define NODE_LEN 5

%macro cmp_and_set_str 4
    mov esi, %1         ; argv[i] - source string
    mov edi, %2         ; destination string
    mov ecx, %3         ; number of bytes to compare
    rep cmpsb
    jne %%not_equal
    %%equal:
        mov %4, byte 1
        jmp args_loop   ; jmp to beginig of the loop in case it was "-d"
    %%not_equal:
%endmacro
%macro print_debug 1
    pushad                  ; save state
    push %1                 ; string to print
    push format_string   
    push dword [stderr]      
    call fprintf
    add esp, 12
    mov dword ecx, [stderr]
    push ecx
    call fflush
    add esp, 4
    popad                   ; restore state
%endmacro
%macro print_str 1
    pushad
    push %1
    push format_string
    call printf
    add esp, 8      ; clean stack
    mov dword ecx, [stdout]
    push ecx
    call fflush
    add esp, 4
    popad
%endmacro
%macro get_input 0
    ; call fgets with 3 parameters
    pushad
    mov dword ecx, [stdin]
    push ecx    
    push dword MAX_INPUT_SIZE    ; max lenght
    mov dword ebx, buffer
    push ebx                    ; input buffer
    call fgets
    add esp, 12                     ; remove the 3 pushes from stuck
    popad
%endmacro
%macro print_data 1
    pushad      
    mov dword ecx, %1
    xor ebx, ebx                
    mov byte bl, [ecx + data]
    push ebx                 ; string to print
    push format_number  
    call printf
    add esp, 8
    mov dword ecx, [stdout]
    push ecx
    call fflush
    add esp, 4
    popad                   ; restore state
%endmacro
%macro print_num 1
    pushad                  ; save state
    push %1                 ; string to print
    push format_number  
    call printf
    add esp, 8
    mov dword ecx, [stdout]
    push ecx
    call fflush
    add esp, 4
    popad                   ; restore state
%endmacro
%macro testing_pointer 1
    pushad      
    mov dword ecx, %1
    xor ebx, ebx            ; save state
    mov byte bl, [ecx + data]
    push ebx                 ; string to print
    push format_pointer  
    call printf
    add esp, 8
    mov dword ecx, [stdout]
    push ecx
    call fflush
    add esp, 4
    popad                   ; restore state
%endmacro
%macro testing_no_num 0
    pushad                  ; save state
    push format_test              ; string to print
    push format_string  
    call printf
    add esp, 8
    mov dword ecx, [stdout]
    push ecx
    call fflush
    add esp, 4
    popad                   ; restore state
%endmacro

section	.rodata			; we define (global) read-only variables in .rodata section
	format_number: db "%d", 0	; format string number
	format_string: db "%s", 0	    ; format string
    error_stack_overflow: db "Error: Operand Stack Overflow", 10, 0
    error_num_of_args: db "Error: Insufficient Number of Arguments on Stack", 10, 0
    prompt: db "calc: ",0
    debug_arg:   db "-d", 0
    new_line:    db "", 10, 0
    zero_str:    db "0", 0

	format_test: db "==== testing ==== ", 10, 0	; format string number
	format_pointer: db "value is %d", 10, 0	; format string number


section .data
    ; size_i:                 ; Used to determine the size of the structure
    struc node
        data:  resb  1
        next: resb  4
    endstruc
    ; node_len: equ $ - size_i     ; Size of the data type


section .bss
    spt                 resd   1     ; stack pointer
    buffer              resb   MAX_INPUT_SIZE
    buffer_len          resb   MAX_INPUT_SIZE
    aux_buffer          resb   MAX_INPUT_SIZE
    counter             resb   32    ; the total numebr of operations that were made
    debug               resb   1
    stack_size          resb   8     ; default is STACK_DEF_SIZE
    stack_ptr           resb   4     ; pointer to begining of stack
    stack_curr_pos_ptr  resb   4     ; pointer to current available position in stack
    var                 resb   4     ; aux variable to store registers before popad
    flag                resb   1     ; aux flag 
    prev_node_ptr       resb   4     ; previous node address for building list
section .text
  align 16
  global main
  extern printf
  extern fprintf 
  extern fflush
  extern malloc 
  extern calloc 
  extern free 
  extern getchar 
  extern fgets 
  extern stdout
  extern stdin
  extern stderr
main:
    push ebp
    mov ebp, esp
    
    init:     
    mov byte  [counter]   , 0
    mov byte  [debug]     , 0
    mov dword [stack_size], STACK_DEF_SIZE

    mov eax, [ebp + 8]          ; initialize counter = argc
    mov esi, [ebp + 12]         ; **argv
    mov ebx, 0                  ; Index of argv

    args_loop:
        mov byte [var], 0           ; nullify
        inc ebx
        mov eax, [esi + ebx * 4]    ; *argv[ebx]
        test eax, eax               ; Null pointer?
        je .fin_args_loop           ; if it is, finish

        
        ; if debug is 1, this arg must be for stack size
        cmp byte [debug], 1
        je .get_stack_size

        ; check if curr arg is -d using cmp_str(str1, str2)
        pushad
        push eax
        push debug_arg
        call cmp_str
        add esp, 8
        mov byte [debug], al            ; if equal, 1 is returned. else 0
        mov byte [var], al              ; store result
        popad

        cmp dword [var], 1              ; the arg was indeed debug
        je args_loop                    ; no need to get_stack_size


        .get_stack_size:              ; if we got here, it is stack_size arg
            pushad
            push eax
            call str_to_decimal         ; convert to decimal using str_to_decimal(str)
            add esp, 4
            mov dword [stack_size], eax ; returned val is the stack size
            popad

        jmp args_loop               ; loop

    .fin_args_loop:
        mov dword eax, [stack_size]     
        mov ecx, 4
        mul ecx                               
        push eax                              ; eax contains num of bytes to allocate
        call malloc                           ; stack allocation
        add esp, 4
        mov dword [stack_ptr], eax          
        mov dword [stack_curr_pos_ptr], eax   ; curr available position in stack
    
    call myCalc                 ; -> pushing return address as well

    end_main:   
        print_num eax
        print_str new_line
        mov esp, ebp
        pop ebp
        ret

    myCalc:
        push ebp            ; backing up base pointer
        mov ebp, esp        ; set ebp to current activation frame
        main_loop:
            ; use macros to print prompt (calc: ) and to get input from user 
            print_str prompt
            get_input

            mov byte bl, [buffer]           ; get first char of buffer
            cmp bl, '0'             
            jge .maybe_number 
            jmp operator                    ; it must be an operator

            .maybe_number:
                cmp bl, '7' 
                jg operator                 ; it is not a number
                ; it is defitily a number
                pushad
                push buffer
                call build_list 
                add esp, 4
                popad
                jmp main_loop
        
        operator:
            xor ebx, ebx
            inc dword [counter]            ; increase operations counter
            mov byte bl, [buffer]         ; get curr char - it must be an operator

            ; call the appropriate function for this operator
            cmp byte bl, 'q'
            je .quit
            cmp byte bl, '+'
            je .add                      ; jump to add
            cmp byte bl, 'p'
            je .pop_n_print              ; jump to pop and print
            cmp byte bl, 'd'
            je .duplicate                ; jump to duplicate
            cmp byte bl, '&'
            je .and                     ; jump to and
            cmp byte bl, 'n'
            je .num_bytes                ; jump to number of bytes
            cmp byte bl, '*'
            je .mult                     ; jump to multiply
 
            .quit:
                dec dword [counter]            ; decrease operations counter - not counting quit
                call free_stack
                jmp .end_main_loop

            .add:           ;+
                
            mov ebx, [stack_curr_pos_ptr]
            sub ebx, [stack_ptr]
            cmp ebx, 2
            jb .error
            call pop_list
            mov edx, eax            ; store address of l1 in edx
            push edx                ; save pointer to l1
            call pop_list          
            pop edx                 ; restore pointer to l1
            mov ecx, eax            ; store address of l2 in ecx
            push ecx                ; save regs, restore later - after padding
            push edx
            xor esi, esi            ; counter for malloc

            .padding:
                add esi, 2
                cmp dword [ecx + next], 0
                je .pad_first
                cmp dword [edx + next], 0
                je .pad_second
                mov ecx, [ecx + next]
                mov edx, [edx + next]
                jmp .padding

            .pad_first:
                cmp dword [edx + next], 0
                je .add_node
                pushad
                push ecx
                push dword 0
                call build_node
                add esp, 8
                popad   
                mov edx, [edx + next]
                mov ecx, [ecx + next]
                jmp .padding

            .pad_second:
                pushad
                push edx
                push dword 0
                call build_node
                add esp, 8
                popad
                mov ecx, [ecx + next]
                mov edx, [edx + next]
                jmp .padding
                
            .add_node:
                pop edx               ; restore pointers to begining of lists
                pop ecx
                
                push ecx
                push edx
                ; allocate two buffers that will use to create the sum list
                push esi            ; store esi
                push esi            ; argument for malloc
                call malloc 
                add esp, 4          ; clean stack
                mov edi, eax        ; edi contains address of first buffer
                pop esi             ; restore esi - size of allocation
                
                push esi
                call malloc 
                mov edi, eax        ; edi contains address of second buffer
                add esp, 4          ; clean stack
                mov esi, eax        ; esi contains address of second buffer
               
                pop edx               ; restore pointers to begining of lists
                pop ecx
   
                
                pushad
                push edi            ; first buffer
                push ecx            ; l1
                push edx            ; l2
                call add_lists
                add esp, 12          ; clean stack
                mov dword [var], eax   ; store pointer to end of first buffer
                popad

                pushad              ; store regs for later free

                testing_no_num
                print_num 1
                print_str new_line

                mov dword eax, [var]   ; restore pointer to end of first buffer
                .reverse_loop:
                    cmp byte [eax], 0
                    je .build

                    mov byte bl, [eax]  ; curr char
                    mov byte [esi], bl  ; put it in second buffer

                    inc esi
                    dec eax
                    jmp .reverse_loop

                .build:
                    mov byte [esi], 0  ; put null char in second buffer
                    popad              ; restore pointer to begining of esi
                    pushad
                    push esi
                    call build_list
                    add esp, 4
                    popad

            .error:
                push error_num_of_args
                call print_err
                add esp, 4

            .end_add:
                pushad
                push esi
                call free       ; free first buffer
                add esp, 4
                popad
                 
                pushad
                push edi
                call free       ; free second buffer
                add esp, 4
                popad
                 
                pushad
                push ecx
                call free_list     ; free first list
                add esp, 4
                popad

                pushad
                push edx
                call free_list     ; free second list
                add esp, 4
                popad

                jmp main_loop
            
            .pop_n_print:   ;p
                pushad
                call pop_list                     ; pop the last node address in stack
                mov dword [prev_node_ptr], eax    ; store return value before poping regs
                popad
                mov dword eax, [prev_node_ptr]    ; restore return value
                cmp al, '-'         ; this means stack is empty, an error was printed
                je .skip_pop

                mov byte [flag], 1     ; set flag before call

                pushad
                push eax
                call pop_print_rec
                add esp, 4
                popad
                print_str new_line    

                ; delete list
                push eax
                call free_list
                add esp, 4

                .skip_pop:
                jmp main_loop

            .duplicate:     ;d
                ;call pop and then loop over the list and each node call build node and then push to the list
                call pop_list
                cmp al, '-'
                je .end               ; error was printed
                mov ecx, eax          ; pointer to the curr list we are duplicating
                mov dword ebx, [stack_curr_pos_ptr] ; ebx contains address of curr free location
                mov dword [ebx], eax                ; return the popped list to stack
                add ebx, 4                          ; move to next cell
                mov [stack_curr_pos_ptr], ebx       ; update curr free position
                xor eax, eax
                .loop:
                    xor edx, edx
                    mov byte dl, [ecx + data]   ; get data
                    push ecx                    ; store pointer to the list we are duplicating 
                    push eax                    ; argument 1 = previous link address
                    push edx                    ; argument 2 = data 
                    call build_node
                    add esp, 8
                    pop ecx                     ; restore the pointer
                    mov ecx, [ecx + next]       ; get next
                    cmp ecx, 0                  ; if null
                    je .end                     ; finish

                    jmp .loop
                
                .end:
                    mov dword ebx, [stack_curr_pos_ptr] ; ebx contains address of curr free location
                    add ebx, 4                          ; move to next cell
                    mov [stack_curr_pos_ptr], ebx       ; update curr free position
                    jmp main_loop
            
            
            .and:           ;&
                .start:
                    mov ebx, [stack_curr_pos_ptr]
                    sub ebx, [stack_ptr]
                    cmp ebx, 2
                    jb ._error

                    call pop_list
                    mov ebx, eax
                    push ebx
                    call pop_list
                    mov ecx, eax
                    pop ebx

                    xor edi, edi
                    mov dword [prev_node_ptr], 0
                    pushad                      ; will be popped in the end to free the memory of the lists
                    jmp .bitwise_and


                .bitwise_and:
                    ; first link address is in ebx, second is in ecx
                    ; divide each link in 10, to separate between first and second letter
                    xor edx, edx
                    xor eax, eax
                    mov edx, 0
                    mov byte al, [ebx + data]
                    mov dword [var], 10

                    div byte [var]      ; eax = eax / 10 --> remainder in edx
                    mov dl, al        ; store the second (MSB) digit in edi
                    mov esi, edx
                    shr eax, 8
                    mov edi, eax        ; store the first (LSB) digit in edi

                    xor edx, edx
                    xor eax, eax
                    mov byte al, [ecx + data]
                    div byte [var]           ; eax = eax / 10 --> remainder in edx

                    
                    mov dl, al          ; second digit - MSB
                    shr eax , 8         ; first digit - LSB

                    ; and between first digits- LSB (edi, edx)
                    and eax, edi      ; bitwise and between the first 2 digits


                    ; and between second digits -MSB (esi, eax)
                    and edx, esi      ; bitwise and on the second 2 digits

                    push eax
                    mov eax, edx
                    mul byte [var]      ; make the result a number again
                    mov edx, eax
                    pop eax
                    add edx, eax      ; sum up the two results to get the final answer
                    
                    pushad
                    push dword [prev_node_ptr]
                    push edx          ; store it in the new LL
                    call build_node  ; call build_node function impl
                    mov dword [prev_node_ptr], eax
                    add esp, 8
                    popad
                    cmp dword [ebx + next], 0
                    je ._end
                    cmp dword [ecx + next], 0
                    je ._end
                    mov ebx, [ebx + next]
                    mov ecx, [ecx + next]
                    jmp .bitwise_and

                ._error:
                    push error_num_of_args
                    call print_err
                    add esp, 4
                    jmp main_loop

                ; .reduce:                
                ;     mov byte [flag], 0
                ;     mov edx, [stack_curr_pos_ptr]
                ;     sub edx, 4
                ;     push dword [edx]
                ;     call .reduce_rec
                ;     add esp, 4
                ;     jmp ._end

                ;     .reduce_rec:
                ;         push ebp            
                ;         mov ebp, esp        
                ;         mov ebx, [ebp + 8] 
                ;         testing_no_num
                ;         print_str new_line
                ;         cmp dword [ebx + next], 0
                ;         jne .recursive_call

                ;     .con:
                ;         cmp byte [ebx + data], 0
                ;         jne ._done
                ;         push ebx
                ;         call free
                ;         add esp, 4
                ;         jmp .end_rec

                ;     .recursive_call:
                ;         push ecx                ; store curr link address
                ;         push dword [ecx + next]
                ;         call .reduce_rec
                ;         add esp, 4              ; clean stack
                ;         pop ecx                 ; restore the curr link
                ;         cmp byte [flag], 1
                ;         je .end_rec
                ;         jmp .con 
                    
                ;     ._done:
                ;         mov byte [flag], 1

                ;     .end_rec:
                ;         mov esp, ebp
                ;         pop ebp
                ;         ret

                ._end:
                    popad               ; popping the registers to restore the addresses of first links in lists
                    pushad
                    push ebx
                    call free_list
                    add esp ,4
                    popad
                    push ecx
                    call free_list
                    add esp, 4

                    ; increment curr_position
                    mov dword eax, [stack_curr_pos_ptr]
                    add eax, 4                          
                    mov dword [stack_curr_pos_ptr], eax

                    jmp main_loop
            
            .num_bytes:     ;n 
                    call pop_list
                    cmp al, '-'             ; empty stack, error was printed
                    je main_loop
                    mov esi, eax            ; store the pointer to first link -> to delete it later
                    mov byte [var], 0       ; init counter
                .loop_num_bytes:
                    test eax, eax               ; curr_link = eax is null?
                    je .done                    ; if yes, we are done

                    xor ecx, ecx                ; nullify
                    mov byte cl, [eax + data]   ; get curr link data
                    
                    ; count bits in node data 
                    ; data is max 2 chars number -> count bits for each char
                    pushad
                    mov eax, ecx
                    xor edx, edx
                    mov ebx, 10                 
                    div ebx

                    push eax
                    call count_bits
                    add esp, 4
                    add byte [var], al

                    push edx
                    call count_bits
                    add esp, 4
                    add byte [var], al

                    popad

                    mov eax, [eax + next]   ; get next
                    jmp .loop_num_bytes

                    .done:  ; divide by 8 and round up, get number of bits
                        xor ebx, ebx
                        xor ecx, ecx            ; nullify
                        xor eax, eax            ; nullify
                        mov byte bl, [var]
                       
                        ; ebx % 8 == 0  <-->  three right shifts will NOT set carry flag
                        shr ebx, 1          ; divide by 2
                        setc cl
                        shr ebx, 1          ; divide by 2 (total 2*2=4)
                        setc al

                        or al, cl           ; al contains 1 <-> cl or al contained 1
                        xor ecx, ecx
                        shr ebx, 1          ; divide by 2 (total 2*2*2=8)
                        setc cl
                        or al, cl

                        cmp dword eax, 0
                        je .create_n_push

                        .round_up:      ; there was remainder
                            inc ebx

                .create_n_push:
                    ; first, clean the memory of the popped list
                    pushad
                    push esi                ; esi is the pointer to the first link
                    call free_list          ; first we clean the current linked list 
                    add esp, 4              ; clean stack
                    popad
                    ; allocate memory for node
                    pushad
                    mov dword ecx, NODE_LEN
                    push ecx
                    call malloc
                    add esp, 4                            ; clean stack after malloc
                    mov dword [prev_node_ptr], eax        ; store pointer to allocation
                    popad                                 ; restore registers
                    mov dword eax, [prev_node_ptr]        ; restore the pointer
                    mov byte [eax + data], bl             ; set data (it's in ebx)
                    mov dword [eax + next], 0             ; set next to null

                    ; store it in curr position
                    mov dword ebx, [stack_curr_pos_ptr]   ; ebx contains pointer to curr position in stack
                    mov dword [ebx], eax                  ; change data in curr position of stack -> to curr link
                    
                    ; increment curr_position
                    mov dword eax, [stack_curr_pos_ptr]
                    add eax, 4                          
                    mov dword [stack_curr_pos_ptr], eax

                    jmp main_loop

            .mult:           ;*
                jmp main_loop


        .end_main_loop:
            mov dword eax, [counter]    ; return value is num of operations
            mov esp, ebp
            pop ebp
            ret                         ; return to main - which called myCalc


print_err:
    push ebp            ; backing up base pointer
    mov ebp, esp        ; set ebp to current activation frame
    mov ebx, [ebp + 8]  ; get argument which is a string


    print_debug ebx     ; debug prints to stderr, so we can use it

    mov esp, ebp
    pop ebp
    ret

free_list:
    push ebp            ; backing up base pointer
    mov ebp, esp        ; set ebp to current activation frame
    mov ebx, [ebp + 8]  ; get argument which is pointer to first link

    test ebx, ebx       ; this cell doesn't contain a list - it is null
    je .end             ; than finish

    cmp dword [ebx + next], 0   ; if curr->next == null
    je .delete                  ; go to base case -> delete it

    .call_again:
        mov dword ecx, [ebx + next]
        push ebx                    ; store the current link
        push ecx                    ; parameter to next call is curr->next
        call free_list          
        add esp, 4                  ; clean stack
        pop ebx                     ; restore curr link

    .delete:    
        ; clean link
        pushad
        push ebx
        call free
        add esp, 4          ; clean stack
        popad

    .end:
        mov esp, ebp
        pop ebp
        ret

free_stack:
    push ebp            ; backing up base pointer
    mov ebp, esp        ; set ebp to current activation frame

    mov dword ecx, [stack_curr_pos_ptr] ; ecx contains address of curr free cell 
    cmp dword ecx, [stack_ptr]
    je .end_while                       ; just clear stack allocation, stack is empty
    .while:
        sub ecx, 4                      ; first occupied cell
        mov ebx, ecx
        sub dword ebx, [stack_ptr]        
        cmp dword ebx, 0                ; if ebx == 0, then curr_pos == stack_ptr
        je .end_while                   ; than stack is empty so we are exiting loop to delete
        ; this isn't the last cell
        ; delete and continue to next iteration
        pushad
        push dword [ecx]            ; first link
        call free_list              ; free curr list
        add esp, 4                  ; clean stack
        popad                       ; restore state

        ; ; free curr cell
        ; pushad
        ; push ecx
        ; call free
        ; add esp, 4                  ; clean stack
        ; popad                       ; restore state

        jmp .while

        .end_while:    
            ; last call to free - free list in stack[0]
            pushad
            push dword [ecx]           ; pointer to first link
            call free_list
            add esp, 4                ; clean stack
            popad   
            .free_stack_allocation:
                pushad
                push dword [stack_ptr]
                call free
                add esp, 4                 ; clean stack
                popad

    .end:
        mov esp, ebp
        pop ebp
        ret

get_buff_size:  ; returns buffer size EXCLUDING \n

    push ebp            ; backing up base pointer
    mov ebp, esp        ; set ebp to current activation frame
    mov ebx, [ebp + 8]  ; get argument which is a string
    
    xor eax, eax
    .loop:
        ; check if it is max input size OR '\n'
        cmp eax, MAX_INPUT_SIZE
        je .end
        cmp byte [ebx], 10
        je .end
        inc ebx
        inc eax
        jmp .loop

    .end:
        mov esp, ebp
        pop ebp
        ret


pop_list: ; returns '-' if there are no elements
    push ebp            ; backing up base pointer
    mov ebp, esp        ; set ebp to current activation frame

    ; check if curr_pos is begining of list
    ; if it is, stack is empty (it points to next free spot), print error
    mov dword eax, [stack_curr_pos_ptr]
    sub dword eax, [stack_ptr]
    cmp dword eax, 0
    je .error

    ; else, there are args in cell
    xor eax, eax                    ; nullify 
    mov eax, [stack_curr_pos_ptr]   ; eax = address of the current free cell
    sub eax, 4                      ; eax = eax - cell_size, to get first occupied cell
    mov dword ebx, [eax]            ; ebx = address of node in first occupied cell

    mov dword [stack_curr_pos_ptr], eax     ; set curr free position to eax (the current first occupied cell)
    mov dword [eax], 0                      ; set the cell to contain null
    mov dword eax, ebx                      ; store return value in eax
    jmp .end

    .error:
        push error_num_of_args
        call print_err
        add esp, 4
        xor eax,eax
        mov al, '-'

    .end:
        mov esp, ebp
        pop ebp
        ret

pop_print_rec:
    push ebp                    ; backing up base pointer
    mov ebp, esp                ; set ebp to current activation frame
    mov ebx, [ebp + 8]          ; get argument which is first link address

    cmp dword [ebx + next], 0   ; if curr->next == null
    je .base_case               ; go to base case -> print data

    .call_again:
        mov dword ecx, [ebx + next]
        push ebx                    ; store the current link
        push ecx                    ; parameter to next call is curr->next
        call pop_print_rec          
        add esp, 4                  ; clean stack
        pop ebx                     ; restore curr link
   
    .base_case:
        cmp byte [ebx + data], 7    ; check if number is one digit
        jg .skip                    ; if not, print it regular
                                    
        cmp byte [flag], 0          ; else, check if this is the first printing. 
        jne .skip                    ; if it is (flag = 1), print leading zero
        print_str zero_str          ; if yes, add leading zero

        .skip:
            mov byte [flag], 0          ; lower flag
            print_data ebx

    .end:
        mov esp, ebp
        pop ebp
        ret

cmp_str:    ; length of comparision is 2
    push ebp                    ; backing up base pointer
    mov ebp, esp                ; set ebp to current activation frame
    mov ebx, [ebp + 8]          ; get str1
    mov ecx, [ebp + 12]         ; get str2

    .first_char:
        mov byte al, [ebx]
        mov byte bl, [ecx]
        cmp al, bl
        jne .not_equal

    .second_char:
        mov ebx, [ebp + 8]          ; get str1 again 
        mov ecx, [ebp + 12]         ; get str2 again
        inc ebx
        inc ecx
        mov byte al, [ebx]
        mov byte bl, [ecx]
        cmp al, bl
        jne .not_equal

    .equal:
        mov dword eax, 1
        jmp .end
    .not_equal:
        mov dword eax, 0
    
    .end:
        mov esp, ebp
        pop ebp
        ret


str_to_decimal:
    push ebp            ; backing up base pointer
    mov ebp, esp        ; set ebp to current activation frame
    mov ebx, [ebp + 8]  ; get arg - pointer to begining of string
    
    xor eax, eax
    xor ecx, ecx

    ; highest possible number is octal 77, meaning string length <= 2
    mov byte al, [ebx]  ; get char
    cmp al, 0           
    je .no_number       ; nothing was given - default size

    sub al, '0'         ; convert to decimal
    inc ebx             ; move to next char
    mov byte cl, [ebx]  ; get next char
    cmp cl, 0           
    je .end             ; one letter number

    .two_letter:
        sub cl, '0'        ; convert to decimal
        shl al, 3          ; multiply MSB letter by 8
        add al, cl         ; add both
        jmp .end

    .no_number:
        mov eax, STACK_DEF_SIZE    
        jmp .end

    .end:
        mov esp, ebp
        pop ebp
        ret

count_bits:
    push ebp            ; backing up base pointer
    mov ebp, esp        ; set ebp to current activation frame
    mov ebx, [ebp + 8]  ; get arg - data of node

    mov edi, 9          ; counter for num of bits- set to 9 cause we decrease first thing
    .loop:
        cmp edi, 0
        je .end
        dec edi                     
        shl bl, 1       ; if 1 was "popped", edi is the number of occupied bits
        jnc .loop

    .end:   
        mov eax, edi        ; return value
        mov esp, ebp
        pop ebp
        ret
                   
get_list_len:
    push ebp                    ; backing up base pointer
    mov ebp, esp                ; set ebp to current activation frame
    mov ebx, [ebp + 8]          ; get argument which is first link address

    xor eax, eax                ; set len to 0

    test ebx, ebx               ; if curr =- null
    je .end                     ; end, return 0
    
    .if:
        inc eax                     ; inc len
        cmp dword [ebx + next], 0   ; if curr->next == null
        je .end                     ; done

   .else:
        mov dword ebx, [ebx + next] ; get next
        jmp .if
    
    .end:
        mov esp, ebp
        pop ebp
        ret

pad_list:
    push ebp                    ; backing up base pointer
    mov ebp, esp                ; set ebp to current activation frame
    mov ebx, [ebp + 8]          ; get argument which is first link address
    mov eax, [ebp + 12]         ; second argument is target len

    ; get list len
    pushad
    push ebx
    call get_list_len
    mov dword [var], eax
    add esp, 4
    popad

    ; if target len is shorter or equal, nothing happens
    cmp dword eax, [var]
    jbe .end

    sub dword eax, [var]        ; eax contains number of nodes to add
    mov esi, eax                ; store in esi

    ; iterate list to get the last one, and start adding nodes
    .loop:
        cmp dword [ebx + next], 0   ; if curr->next == null
        je .while                   ; done

        mov dword ebx, [ebx + next] ; get next
        jmp .loop

    
    .while: 
        cmp esi, 0              ; if esi == 0
        je .end                 ; done

        push esi
        push 0                  ; node data
        push 1                  ; not first
        push ebx                ; node address
        call build_node
        add esp, 12
        pop esi
        mov ebx, eax            ; move return value (=address of added node) to ebx
        dec esi
        jmp .while

    .end:
        mov esp, ebp
        pop ebp
        ret

build_node:
    push ebp                    ; backing up base pointer
    mov ebp, esp                ; set ebp to current activation frame
    mov ecx, [ebp + 8]          ; get argument which is data of node
    mov ebx, [ebp + 12]         ; second argument is null or pointer to previous link
        ; allocate memory for node
        pushad
        mov dword ecx, NODE_LEN
        push ecx
        call malloc
        add esp, 4                            ; clean stack after malloc
        mov dword [var], eax                  ; store pointer to allocation
        popad                                 ; restore registers
        mov dword eax, [var]                  ; restore the pointer
        mov byte [eax + data], cl             ; set data
        mov dword [eax + next], 0             ; set next to null
        cmp ebx, 0                     
        jne .not_first                        ; if pointer is not null, it is not first

        .first:
            mov dword ebx, [stack_curr_pos_ptr] ; ebx contains pointer to curr position in stack
            mov dword [ebx], eax                ; change data in curr position of stack -> to curr link
           
            jmp .end
        .not_first:
            mov [ebx + next], eax             ; point prev node to next node
            mov dword ebx, [stack_curr_pos_ptr] ; ebx contains pointer to curr position in stack
            jmp .end          


    .end:
        mov esp, ebp
        pop ebp
        ret

add_lists:
    push ebp                    ; backing up base pointer
    mov ebp, esp                ; set ebp to current activation frame
    mov ebx, [ebp + 8]          ; get argument which is l1 first link address
    mov ecx, [ebp + 12]         ; get argument which is l2 first link address
    mov esi, [ebp + 16]         ; pointer to buffer

    mov byte [flag], 0          ; represents the carry

    mov byte [esi], 0    ; null char
    inc esi
    mov byte [esi], 10   ; \n
    dec esi             ; point to begining 

    
    
    .loop:
        test ecx, ecx               ; if curr == null
        je .end                     ; done 

        add esi, 2                  ; increment pointer by 2
        pushad
        push esi
        push ebx
        push ecx
        call add_links_data
        add esp, 12                  ; clean stack
        mov byte [flag], al         ; return value is the carry
        popad
        mov dword ebx, [ebx + next] ; get next l1
        mov dword ecx, [ecx + next] ; get next l2
   
        jmp .loop   

        ; if carry != 0, add to buffer
        cmp byte [flag], 0
        je .no_carry

        .carry:
            add esi, 2      ; point to the next free position
            mov byte [esi], 1
        
        .no_carry:
            inc esi
            cmp byte [esi], 0
            jne .end
            dec esi
        
    .end:
        mov eax, esi
        mov esp, ebp
        pop ebp
        ret

add_links_data: 
    push ebp                    ; backing up base pointer
    mov ebp, esp                ; set ebp to current activation frame
    mov ecx, [ebp + 8]          ; get address of link in l1
    mov ebx, [ebp + 12]         ; get address of link in l2
    mov esi, [ebp + 16]         ; pointer to buffer
    mov dword [var], esi    

    mov byte al, [ecx + data]
    xor ecx, ecx
    mov cl, al
    mov byte al, [ebx + data]
    xor ebx, ebx
    mov bl, al

    ; testing_no_num
    ; print_str new_line

    ; print_num ebx
    ; print_str new_line

    ; testing_no_num
    ; print_str new_line

    ; print_num ecx

    ; change first link to decimal
    xor eax, eax
    xor edx, edx
    mov eax, ecx          ; eax contains data of link in l1
    mov esi, 10           ; divisor      
    div esi
    
    push edx
    ;mov dl, al            ; MSB of l1
    ;shr eax, 8            ; LSB of l2
    ;mov ecx, eax          ; store LSB in ecx
    ;mov eax, edx          ; store MSB in eax

    mov esi, 8            ; multiplication product
    mul esi               ; eax = eax * 8

    pop edx
    add edx, eax          ; ecx contain decimal value of link in l1
    mov ecx, edx

    
    ; testing_no_num
    ; print_str new_line

    ; testing_no_num
    ; print_str new_line
    ; print_num ecx

    ; change second link to decimal
    xor eax, eax
    xor edx, edx
    mov eax, ebx          ; eax contains data of link in l1
    mov esi, 10           ; divisor      
    div esi
    
    push edx

    ;mov dl, al            ; MSB of l1
    ;shr eax, 8            ; LSB of l2
    ;mov ebx, eax          ; store LSB in ecx
    ;mov eax, edx          ; store MSB in eax

    mov esi, 8            ; multiplication product
    mul esi               ; eax = eax * 8

    pop edx

    add eax, edx          ; ebx contain decimal value of link in l2
    mov ebx, eax
    
    ; testing_no_num
    ; print_str new_line
    ; print_num ebx

    ; add both links with previous carry (flag)
    ; if result is a 3 digit number, set carry to 1 and remove MSB
    add ecx, ebx
    xor ebx, ebx
    add byte bl, [flag]
    add ebx, ecx
    mov ecx, ebx        ; store result in eax
    mov byte [flag], 0  ; reset carry flag

    
    mov dword ebx, [var]    ; restore pointer to buffer
    mov edi, 2
    ; change to octal
    .loop:
    cmp edi, 0
    je .check_carry
    mov eax, ecx
    mov esi, 8          ; divisor
    div esi
    mov eax, ecx
    shr eax, 3

    mov byte [ebx], dl  
    inc ebx
    dec edi
    mov ecx, eax
    jmp .loop

    .check_carry:
        cmp eax, 0 
        je .end

    mov byte [flag], 1  ; raise carry flag

    .end:
        sub ebx , 2
        testing_no_num
        print_str ebx
        print_str new_line
        add ebx ,2

        mov esp, ebp
        pop ebp
        ret



build_list:    
    push ebp                    ; backing up base pointer
    mov ebp, esp                ; set ebp to current activation frame
    mov esi, [ebp + 8]          ; get buffer


    ; check for room in stack
    mov ecx, [stack_ptr]            ; base pointer
    mov dword eax, [stack_size]     ; total size
    mov dword ebx, 4                ; cell size 
    mul ebx                         ; eax = eax*ebx -> eax is num of bytes allocated for stack
    add ecx, eax                    ; ecx points to the end of the stack array
    sub ecx, [stack_curr_pos_ptr]   ; sub from ecx the current location    
    cmp ecx, 0                      ; check if stack_curr_pos_ptr is end of stack
    jg .start_loop

    .error:
        pushad
        push error_stack_overflow
        call print_err
        add esp, 4                      ; clean atack
        popad
        jmp .end


    .start_loop:
    ; get buffer length
        pushad
        push esi
        call get_buff_size
        add esp, 4                      ; clean stack
        mov [buffer_len], eax
        popad


    ; make buffer point to end of the array
    ; edi holds the pointer
    xor edi, edi
    mov dword edi, esi
    add dword edi, [buffer_len]        ; point to the end 
    dec edi                            ; decrease one to point last element
    mov dword [flag], 1                ; flag for first node creation
    mov dword [prev_node_ptr], 0       ; nullify prev
    xor ecx, ecx

        ; ebx will contain curr node pointer
        ; ecx will contain the next node data - only cl because it's 8 bits 
        .loop:  
            cmp dword [buffer_len], 0
            je .end_build_list
            mov byte cl, [edi]           ; get last char of buffer
            
        ; change to decimal
            sub cl, byte '0'
            dec byte [buffer_len]
            dec edi

            cmp byte [buffer_len], 0
            je .build

            push ebx

            mov byte al, [edi]           ; get next char of buffer
            sub al, byte '0'             ; change from ascii val to number
            mov bl, 10                   ; for multiplication
            mul bl          
            add cl, al                   ; cl contains the two octal digits 
            
            pop ebx

            dec byte [buffer_len]
            dec edi
            
            .build:
                push dword [prev_node_ptr]
                push ecx
                call build_node
                add esp, 8
                mov dword [prev_node_ptr], eax  ; store pointer to prev
                jmp .loop

    .end_build_list:
        mov dword eax, [stack_curr_pos_ptr]
        add eax, 4                          ; go to next cell
        mov dword [stack_curr_pos_ptr], eax

    .end:
        mov esp, ebp
        pop ebp
        ret