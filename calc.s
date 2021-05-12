%define STACK_MAX_SIZE 63
%define STACK_MIN_SIZE 2
%define STACK_DEF_SIZE 5
%define MAX_INPUT_SIZE 80
%macro prim_ptr 0  
    section .bss
        %%prim resd 1
%endmacro
%macro cmp_and_set_str 4
    mov esi, %1         ; argv[edx] - source string
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
    push 2                  ; stderr
    push %1                 ; string to print
    push format_string     
    call fprintf
    popad                   ; restore state
%endmacro


section	.rodata			; we define (global) read-only variables in .rodata section
	format_number: db "%d", 10, 0	; format string number
	format_string: db "%s", 10, 0	; format string
    error_stack_overflow: db "Error: Operand Stack Overflow", 10, 0
    error_num_of_args: db "Error: Insufficient Number of Arguments on Stack", 10, 0
    prompt: db "calc: ",0
    

section .data
    size_i:                 ; Used to determine the size of the structure
    struc node
        num:  resb  1
        next: resd  1
    endstruc
    node_len: equ $ - size_i     ; Size of the data type


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
    mov [counter]   , byte 0
    mov [debug]     , byte 0
    mov [stack_size], dword STACK_DEF_SIZE

    mov eax, [ebp + 8]          ; initialize counter = argc
    mov ebx, dword [ebp + 12]   ; **argv
    mov edx, 0
    mov ecx, 0                  ; flag
    args_loop:
        inc edx
        cmp edx, eax
        je .fin_args_loop
        ; compare current argument with debug flag
        cmp_and_set_str dword [ebx + 4*edx], "-d", 2, [debug]

        ; if cmp and set didn't set, we'll get here 
        pushad
        ; str_to_decimal gets two parameters - first is address of string and second is curr position
        shl edx, 2                ; multiply by 4 = size of ptr
        push edx
        push ebx
        call str_to_decimal
        mov [stack_size], eax
        add esp, 4                              ; remove the argument to str_to_octal from stack
        popad
        jmp args_loop
    .fin_args_loop:
        push dword [stack_size]
        call malloc                             ; stack allocation
        mov [stack_ptr], dword eax          
        mov [stack_curr_pos_ptr], dword eax     ; curr available position in stack

    ;V; allocate memory for stack
    ;; init primary pointers for each cell in stack - using macro prim_ptr

    call myCalc                 ; -> pushing return address as well

    end_main:    
        push eax                ; push return value of myCalc
        push format_number
        call printf
        ret                     ; ??

    myCalc:
        push ebp            ; backing up base pointer
        mov ebp, esp        ; set ebp to current activation frame
        main_loop:
            push prompt
            call printf
            ; call fgets with 3 parameters
            push dword [stdin]             
            push dword MAX_INPUT_SIZE       ; max lenght
            push dword buffer               ; input buffer
            call fgets
            add esp, 12                     ; remove the 3 pushes from stuck

            mov bl, byte [buffer]           ; get first char of buffer
            cmp bl, '0'             
            jge .maybe_number 
            jmp operator                    ; it must be an operator

            .maybe_number:
                cmp bl, '7' 
                jg operator                 ; it is not a number
                ; it is defitily a number
                jmp build_list  


            ;V; print  prompt calc
            ;V; fgets - take the current input to buffer
            ;; if it is an operand - call build_list
            ;; if it is an operator - check if it is 'q', else - call operator

            ; argc ebp+8
            ;   argv mov eax , dword [ebp +12]
            ;  mov ebx, dword [eax + 4 ] => argv[1]

        build_list:    
            ; check room in stack
            mov ecx, [stack_ptr]        
            add ecx, [stack_size]           ; ecx points to the end of the stack array
            sub ecx, [stack_curr_pos_ptr]   ; sub from ecx the location    
            cmp ecx, 0                      ; check if stack_curr_pos_ptr is end of stack
            jg .start_loop
            
            pushad
            push error_stack_overflow
            call print_err
            add esp, 4                      ; remove the argument to print_err from stack
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
            xor edi, edi
            mov edi, dword [buffer_len]
            add [buffer], edi                 ; point to the end
            mov [var], byte 1                 ; flag for first node creation
            
                ; ebx will contain curr node pointer
                ; ecx will contain the next node data - only cl because it's 8 bits 
                .loop:  
                    cmp [buffer_len], byte 0
                    je .end_build_list
                    mov cl, byte [buffer]           ; get last char of buffer
                    
                    ; change to decimal
                    sub cl, byte '0'
                
                    dec byte [buffer_len]
                    dec byte [buffer]

                    cmp byte [buffer_len], 0
                    je .build_node

                    mov bl, byte [buffer]           ; get next char of buffer
                    mul bl, 10          
                    add cl, bl                      ; cl contains the two octal digits 
                    
                    dec byte [buffer_len]
                    dec byte [buffer]
                    jmp .build_node

                    ; take the last byte from buffer
                    ; mov dl, [buffer]
                    ; call build node

                .build_node:
                    ; allocate memory for first node
                    push node_len
                    call malloc
                    add esp, 4                            ; remove the argument from stack
                    mov byte [eax + num], cl              ; set data
                    mov byte [eax + next], 0              ; set next to null
                    cmp byte [var], 1
                    jne .not_first

                    .first:
                        mov byte [var], 0           ; lower flag - not first anymore
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
            add byte [counter], 1         ;; increase counter
            mov bl, [buffer]              ; get curr char - it must be an operator
                                          ;; call the appropriate function for this operator
            cmp byte bl, '+'
            je .add                      ;; jump to add
            cmp byte bl, 'p'
            je .pop_n_print              ;; jump to pop and print
            cmp byte bl, 'd'
            je .duplicate                ;; jump to duplicate
            cmp byte bl, '&'
            jmp .and                      ;; jump to and
            cmp byte bl, 'n'
            je .num_bytes                ;; jump to number of bytes
            cmp byte bl, '*'
            je .mul                      ;; jump to multiply

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
            

            
            .pop_n_print:   ;p
            

                call pop
                ;loop from the last link to the first and print with printf recursively
                 ;base case - next is null
                 ;if yes printf on data 
                 ;else next link - aid function that gets a link 
                
                .loop:
                    ; get curr
                    cmp []

            .duplicate:     ;d
                ;call pop and then loop over the list and each node call build node and then push to the list
            .and:           ;&
                ;    
            .num_bytes:     ;n 
                ; pop the last number, push the number of bytes of it (in hexa rounded up) to stack
                ;call pop
                ;iterate over the list to get each links data size 
                ;copy links data and then shift left in a loop until we stumble upon 1 and then 8-counter
                ;summing up all the bytes we got and then division by 8 and then round up if there is a remainder (divide with remainder check)
                ;push back to the stack

            .mul:           ;*

        .end_main_loop:
            ret             ; return to main - which called myCalc


str_to_decimal:
    push ebp            ; backing up base pointer
    mov ebp, esp        ; set ebp to current activation frame
    mov ebx, [ebp + 8]  ; get first argument - pointer to begining of string
    mov edi, [ebp + 12] ; second argument is curr position
    mov ebx, [ebx + edi]

    ; highest possible number is octal 77, meaning string length <= 2
    mov cl, byte [ebx]  ; get char
    cmp cl, 0           
    je .no_number        ; nothing was given


    add ebx, 1          ; move to next char
    mov bl, [ebx]       ; get next char
    cmp cl, 0           
    je .one_letter       ; one letter number

    .two_letter:
        sub cl, '0'                 ; convert to decimal
        sub bl, '0'                 ; convert to decimal

        ; convert from octal to decimal and store in eax
        mov [var], byte bl
        mov ebx, [var]
        shl ebx, 3                  ; multiply second letter by 8
        mov [var], cl               ; move first letter
        add [var], dword ebx        ; add both
        mov eax, [var]              ; store return value

    .no_number:
        mov eax, STACK_DEF_SIZE    
        jmp .end
    .one_letter:
        mov eax, ecx
        jmp .end

    .end:
        pop ebp
        ret

;;TODO
print_err:
    push ebp            ; backing up base pointer
    mov ebp, esp        ; set ebp to current activation frame
    mov ebx, [ebp + 8]  ; get argument which is a string

    push ebx
    push format_string
    push [stderr]
    call fprintf
    add esp, 12         ; clean stack

    mov esp, ebp
    pop ebp
    ret




free_list:

free_stack:

get_buff_size:
    push ebp            ; backing up base pointer
    mov ebp, esp        ; set ebp to current activation frame
    mov ebx, [ebp + 8]  ; get argument which is a string
    
    xor eax, eax
    .loop:
        ; check if it is max input size OR null char
        cmp eax, MAX_INPUT_SIZE
        je .end
        cmp byte [ebx], 0
        je .end
        inc ebx
        inc eax
        jmp .loop

    .end:
        mov esp, ebp
        pop ebp
        ret


pop:
    push ebp            ; backing up base pointer
    mov ebp, esp        ; set ebp to current activation frame

    dec [stack_curr_pos_ptr]
    mov eax, [stack_curr_pos_ptr]
    mov byte [stack_curr_pos_ptr], 0

    .end:
        mov esp, ebp
        pop ebp
        ret

