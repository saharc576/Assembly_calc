%define STACK_MAX_SIZE 63
%define STACK_MIN_SIZE 2
%define STACK_DEF_SIZE 5
%define MAX_INPUT_SIZE 80
%macro prim_ptr 0  
    section .bss
        %%prim resd 1
%endmacro

section	.rodata			; we define (global) read-only variables in .rodata section
	format_string: db "%s", 10, 0	; format string
    error_stack_overflow: db "Error: Operand Stack Overflow", 10, 0
    error_num_of_args: db "Error: Insufficient Number of Arguments on Stack", 10, 0
    prompt: db "calc: ",0
    

section .data
    size_i:             ; Used to determine the size of the structure
    struc node
        num: resb  1
        next: resd  1
    endstruc
    len: equ $ - size_i  ; Size of the data type



section .bss
    spt:    resd  1     ; stack pointer
    buffer: resb MAX_INPUT_SIZE

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
    init:     

    ; find if there is an argument for stack size - if not it is 5 
    ; allocate memory for stack
    ; init primary pointers for each cell in stack - using macro prim_ptr
    ; 

    .main_loop:
        ; print  prompt calc
        ; fgets - take the current input to buffer
        ; if it is an operand - call build_list
        ; if it is an operator - call operator
        

    build_list:
        .loop:
            ; take the last byte from buffer
            ; mov dl, [buffer]
            ; call build node

        .build_node:
        ;   build using append from example 5
        ;  https://codehost.wordpress.com/2011/07/29/59/

       

    operator:
        ; call the appropriate function for this operator

    .add:

    .pop_n_print:

    .duplicate:

    .and:

    .num_bytes:

    .mul:

    .end_main_loop:
