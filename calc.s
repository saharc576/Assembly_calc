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
    jne not_equal
    %%equal:
        mov %4, 1
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
    len: equ $ - size_i     ; Size of the data type


section .bss
    spt:            resd   1     ; stack pointer
    buffer:         resb   MAX_INPUT_SIZE
    counter:        resb   4     ; the total numebr of operations that were made
    debug:          resb   1
    stack_size:     resb   4     ; default is STACK_DEF_SIZE
    stack_ptr:      resb   4     ; pointer to begining of stack
    stack_curr_pos: resb   4     ; pointer to current available position in stack
    var:            resb   32    ; aux variable
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
    move ebp, esp

    init:     
    mov [counter]   , byte 0
    mov [debug]     , byte 0
    mov [stack_size], dword STACK_DEF_SIZE
    ;V; find if there is an argument for stack size - if not it is 5 
    ;V; find if there is a debug mode flag; debug should support AT LEAST prinitnig everey number from user and every result pushed to stack - to stder 
    ;V; inital counter for number of operations

    mov eax, [ebp + 8]          ; initialize counter = argc
    mov ebx, dword [ebp + 12]   ; **argv
    mov edx, 0
    mov ecx, 0                  ; flag
    .args_loop:
        inc edx
        cmp edx, eax
        je .fin_args_loop
        ; compare current argument with debug flag
        cmp_and_set_str dword [ebx + 4*edx], "-d", 2, [debug]

        ; if cmp and set didn't set, we'll get here 
        pushad
        push [ebx + 4*edx]        ; argument for func, curr argument
        call str_to_decimal
        mov [stack_size], eax
        add esp, 4                ; remove the argument to str_to_octal from stack
        popad
        jmp args_loop
    .fin_args_loop:
        push [stack_size]
        call malloc                         ; stack allocation
        mov [stack_ptr], dword eax          
        mov [stack_curr_pos], dword eax     ; curr available position in stack

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
        .main_loop:
            push prompt
            call printf
            ; call fgets with 3 parameters
            push dword [stdin]             
            push dword MAX_INPUT_SIZE       ; max lenght
            push dword buffer               ; input buffer
            call fgets
            add esp, 12                     ; remove 3 push from stuck

            mov bl, byte [buffer]           ; get first char of 
            cmp bl, '0'             
            jge maybe_number 
            jmp operator                    ; it must be an operator

            .maybe_number:
                cmp bl, '7' 
                jg operator                 ; it is not a number
                ; it is defitily a number



            ;V; print  prompt calc
            ;V; fgets - take the current input to buffer
            ;; if it is an operand - call build_list
            ;; if it is an operator - check if it is 'q', else - call operator

            ; argc ebp+8
            ;   argv mov eax , dword [ebp +12]
            ;  mov ebx, dword [eax + 4 ] => argv[1]

        build_list:
        ;; check room in stack
            .loop:
                ; take the last byte from buffer
                ; mov dl, [buffer]
                ; call build node

            .build_node:
            ;   build using append from example 5
            ;  https://codehost.wordpress.com/2011/07/29/59/

        

        operator:
            ;; increase counter
            ;; call the appropriate function for this operator


            .add:           ;+

            .pop_n_print:   ;p

            .duplicate:     ;d

            .and:           ;&
            
            .num_bytes:     ;n 
                ; pop the last number, push the number of bytes of it (in hexa rounded up) to stack

            .mul:           ;*

        .end_main_loop:
            ret             ; return to main - which called myCalc


str_to_decimal:
    push ebp            ; backing up base pointer
    mov ebp, esp        ; set ebp to current activation frame
    mov ebx, [ebp + 8]  ; get argument which is a string

    ; highest possible number is octal 77, meaning string length <= 2
    mov cl, byte [ebx]  ; get char
    cmp cl, 0           
    je no_number        ; nothing was given


    add ebx, 1          ; move to next char
    mov bl, [ebx]       ; get next char
    cmp cl, 0           
    je one_letter       ; one letter number

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
        jmp end
    .one_letter:
        mov eax, byte cl
        jmp end

    .end:
        pop ebp
        ret
