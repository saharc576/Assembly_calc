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
    push dword [stderr]             ; stderr
    call fprintf
    add esp, 12
    popad                   ; restore state
%endmacro
%macro print_prompt 0
    pushad
    push prompt
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
%macro testing_num 1
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
	format_number: db "%d", 10, 0	; format string number
	format_string: db "%s", 0	    ; format string
    error_stack_overflow: db "Error: Operand Stack Overflow", 10, 0
    error_num_of_args: db "Error: Insufficient Number of Arguments on Stack", 10, 0
    prompt: db "calc: ",0
    debug_arg:   db "-d", 0

	format_test: db "==== testing ==== ", 10, 0	; format string number
    argcstr:     db "argc = %d", 10, 0      ; backquotes for C-escapes
    argvstr:     db "argv[%u] = %s", 10, 0
    

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
    counter             resb   32    ; the total numebr of operations that were made
    debug               resb   1
    stack_size          resb   8     ; default is STACK_DEF_SIZE
    stack_ptr           resb   4     ; pointer to begining of stack
    stack_curr_pos_ptr  resb   4     ; pointer to current available position in stack
    var                 resb   4     ; aux variable
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
        mov ecx, NODE_LEN
        mul ecx                               
        push eax                              ; eax contains num of bytes to allocate
        call malloc                           ; stack allocation
        add esp, 4
        mov dword [stack_ptr], eax          
        mov dword [stack_curr_pos_ptr], eax   ; curr available position in stack
    
    call myCalc                 ; -> pushing return address as well

    end_main:    
        push eax                ; push return value of myCalc
        push format_number
        call printf
        add esp, 8
        ret                     ; ??

    myCalc:
        push ebp            ; backing up base pointer
        mov ebp, esp        ; set ebp to current activation frame
        main_loop:
            ; use macros to print prompt (calc: ) and to get input from user 
            print_prompt
            get_input

            mov byte bl, [buffer]           ; get first char of buffer
            cmp bl, '0'             
            jge .maybe_number 
            jmp operator                    ; it must be an operator

            .maybe_number:
                cmp bl, '7' 
                jg operator                 ; it is not a number
                ; it is defitily a number
                jmp build_list  

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; build_list seems to work fine -- if we don't add [stack_size] it does point to same place ;;;;;;;;;;;;;;;;;;;;

        build_list:    
            ; check room in stack
            mov ecx, stack_ptr  
            mov dword eax, [stack_size]      
            add ecx, eax                    ; ecx points to the end of the stack array
            sub ecx, stack_curr_pos_ptr     ; sub from ecx the location    
            cmp ecx, 0                      ; check if stack_curr_pos_ptr is end of stack
            jg .start_loop
            
            pushad
            push error_stack_overflow
            call print_err
            add esp, 4                      ; clean atack
            popad
            jmp main_loop


            .start_loop:
            ; get buffer length
            pushad
            push buffer
            call get_buff_size
            add esp, 4                      ; remove the argument to print_err from stack
            mov [buffer_len], eax
            popad


            ; make buffer point to end of the array
            ; edi holds the pointer
            xor edi, edi
            mov dword edi, buffer
            add dword edi, [buffer_len]        ; point to the end 
            dec edi                            ; decrease one to point last element
            mov dword [var], 1                 ; flag for first node creation
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
                    testing_no_num
                    testing_num ecx

                    cmp byte [buffer_len], 0
                    je .build_node

                    mov byte al, [edi]           ; get next char of buffer
                    sub al, byte '0'             ; change from ascii val to number
                    mov bl, 10                   ; for multiplication
                    mul bl          
                    add cl, al                   ; cl contains the two octal digits 
                 
                    dec byte [buffer_len]
                    dec edi
                    jmp .build_node

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; works untill here ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

                .build_node:
                    ; allocate memory for first node
                    pushad
                    mov dword ecx, NODE_LEN
                    push ecx
                    call malloc
                    add esp, 4                            ; remove the argument from stack
                    popad
                    mov byte [eax + data], cl             ; set data
                    mov byte [eax + next], 0              ; set next to null
                    cmp dword [var], 1
                    jne .not_first

                    .first:
                        mov dword [var], 0           ; lower flag - not first anymore
                        mov [stack_curr_pos_ptr], eax  
                        mov ebx, eax                ; ebx contains curr node pointer
                        jmp .loop
                    .not_first:
                        mov [ebx + next], eax       ; point to next node
                        mov ebx, eax
                        jmp .loop


                ;   build using append from example 5
                ;  https://codehost.wordpress.com/2011/07/29/59/

        .end_build_list:
            inc byte [stack_curr_pos_ptr]
            jmp main_loop
        

        operator:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; this works from here ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
            inc dword [counter]            ; increase operations counter
            mov byte bl, [buffer]         ; get curr char - it must be an operator
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; to here ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
 
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
            jmp .and                     ; jump to and
            cmp byte bl, 'n'
            je .num_bytes                ; jump to number of bytes
            cmp byte bl, '*'
            je .mult                     ; jump to multiply

            .quit:
                dec dword [counter]            ; decrease operations counter - not counting quit
                call free_stack
                jmp .end_main_loop

            .add:           ;+
            ; pop two linked lists l1 l2 and save them in regs
            ; pad the shorter linked list - add zero links by calling build node
            ; loop simultaniousely on both l1 l2 and send curr link of both to add_link + carry of last add_link (first is 0)
            ; if done, check if there is carry. if there is, create another node with data = carry. 
            ;
            ; after all, free memory, and push res

            ; add_link:
            ; sum three right bites of both linkes + carry of last add_link
            ; if res <= 7 do nothing. 
            ; else add 2 to res, then sub 10 and add 1 to carry.
            ; then sum next 3 bits of both links with carry
            ; do same as before with carry
            ; build res node with current data
            
            jmp main_loop
            
            .pop_n_print:   ;p
                
                call pop_list
                cmp al, '-'         ; this means stack is empty, an error was printed
                je .skip

                push eax
                call pop_print_rec

                .skip:
                jmp main_loop

            .duplicate:     ;d
                ;call pop and then loop over the list and each node call build node and then push to the list
                
                jmp main_loop
            
            
            .and:           ;&
                ;    
                jmp main_loop

            
            .num_bytes:     ;n 
                .start: 
                    mov dword ebx, 0         ; init counter
                    call pop_list
                    cmp al, '-'             ; empty stack, error was printed
                    je main_loop
                .loop:
                    cmp dword eax, 0             ; check if null
                    je .done
                    mov byte cl, [eax + data]   ; get curr link data
                    ; change it to decimal
                    pushad
                    mov eax, ecx
                    xor edx, edx
                    mov ebx, 10
                    div ebx
                    shl eax, 3                  ; mul res by 8
                    add eax, edx                ; add remainder*1
                    mov byte [var], al          ; store before popad
                    popad

                    mov byte cl, [var]          ; now cl contains the decimal value of curr.data
                    mov edi, 9                  ; counter for num of bits- 6 is max number but cl is 8-bits
                    .count_bits:
                        dec edi                     ; first decreasing, that's the reason edi initialized with 9
                        shl cl, 1
                        jnc .count_bits
                    add ebx, edi            ; add curr num of bits to counter
                    mov eax, [eax + next]   ; get next
                    jmp .loop

                    .done:  ; divide by 8 and round up, get number of bits
                        pushad
                        push eax
                        call free_list
                        add esp, 4              ; clean stack
                        popad

                        xor ecx, ecx            ; nullify
                        xor eax, eax            ; nullify
                        ; ebx % 8 == 0  <-->  three right shifts will NOT set carry flag
                        shr ebx, 1
                        setc cl
                        shr ebx, 1
                        setc al

                        or al, cl
                        xor ecx, ecx
                        shr ebx, 1
                        setc cl

                        or al, cl

                        cmp dword ecx, 0
                        je .create_n_push
                        .round_up:      ; there was remainder
                            add dword ebx, 1

                .create_n_push:
                    ; allocate memory for node
                    pushad
                    mov ecx, NODE_LEN
                    push ecx
                    call malloc
                    add esp, 4                         ; remove the argument from stack
                    popad
                    mov byte [eax + data], bl          ; set data
                    mov byte [eax + next], 0           ; set next to null

                    mov [stack_curr_pos_ptr], eax  
                    inc byte [stack_curr_pos_ptr]

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

    push ebx
    push format_string
    push dword [stderr]
    call fprintf
    add esp, 12         ; clean stack

    mov esp, ebp
    pop ebp
    ret

free_list:
    push ebp            ; backing up base pointer
    mov ebp, esp        ; set ebp to current activation frame
    mov ebx, [ebp + 8]  ; get argument which is first link

    mov ecx, [ebx]              ; ecx = curr link
    cmp dword [ecx + next], 0   ; if curr.next != null
    jne .call_again             ; call again with next link

    ; next link is null, delete it 
    ; clean data
    pushad
    xor ecx, ecx
    mov byte cl, [ecx + data]
    push ecx
    call free
    add esp, 4          ; clean stack
    popad

    ; clean next
    pushad
    mov dword ecx, [ecx + next]
    push ecx
    call free
    add esp, 4          ; clean stack
    popad

    ; clean link
    pushad
    push ecx
    call free
    add esp, 4          ; clean stack
    popad

    .call_again:
        inc ebx
        push ebx
        call pop_print_rec
        add esp, 4        ; clean stack

    .end:
        mov esp, ebp
        pop ebp
        ret

free_stack:
    push ebp            ; backing up base pointer
    mov ebp, esp        ; set ebp to current activation frame

    ; while curr_pos != stack_ptr
    ;   curr_link = pop
    ;   free_list (curr_link)
    ;   dec curr_pos
    ; free_list (curr_link)  
    
    
    mov dword ecx, [stack_curr_pos_ptr] ; ecx contains curr cell 
    .while:
        dec ecx                         ; first occupied cell
        mov ebx, ecx
        sub dword ebx, [stack_ptr]        
        cmp dword ebx, 0                ; if ebx == 0, then curr_pos == stack_ptr
        je .end_while
        ; this isn't the last cell
        ; delete and continue to next iteration
        pushad
        push dword ecx              ; first link
        call free_list
        add esp, 4                  ; clean stack
        popad

        ; free curr cell
        pushad
        push ecx
        call free
        add esp, 4                  ; clean stack
        popad

        jmp .while

        .end_while:     ; last call to free
            pushad
            push dword ecx            ; first link
            call free_list
            add esp, 4                ; clean stack
            popad   

            ; free curr cell
            pushad
            push ecx
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
    ; if it is stack is empty (it points to next free spot), print error
    mov dword eax, [stack_curr_pos_ptr]
    sub dword eax, [stack_ptr]
    cmp dword eax, 0
    je .error

    ; else, there are args in cell
    xor eax, eax
    dec byte [stack_curr_pos_ptr]
    mov eax, [stack_curr_pos_ptr]
    mov byte [stack_curr_pos_ptr], 0
    jmp .end

    .error:
        push error_num_of_args
        call print_err
        xor eax,eax
        mov al, '-'

    .end:
        mov esp, ebp
        pop ebp
        ret

pop_print_rec:
    push ebp                    ; backing up base pointer
    mov ebp, esp                ; set ebp to current activation frame
    mov ebx, [ebp + 8]          ; get argument which is first link

    mov ecx, [ebx]              ; ecx = curr link
    cmp dword [ecx + next], 0   ; if curr.next != null
    jne .call_again             ; call again with next link

    ; next link is null, print it's data
    pushad
    mov ecx, [ecx + data]
    push ecx
    push format_number
    push dword [stdout]
    call fprintf
    add esp, 12          ; clean stack
    popad
    jmp .end

    .call_again:
        inc ebx
        push ebx
        call pop_print_rec
        add esp, 4          ; clean stack

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