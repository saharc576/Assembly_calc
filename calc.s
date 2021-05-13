%define STACK_MAX_SIZE 63
%define STACK_MIN_SIZE 2
%define STACK_DEF_SIZE 5
%define MAX_INPUT_SIZE 80

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
        data:  resb  1
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
            push stdin             
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
                    mov al, 10
                    mul bl          
                    add cl, al                      ; cl contains the two octal digits 
                    
                    dec byte [buffer_len]
                    dec byte [buffer]
                    jmp .build_node

                    ; take the last byte from buffer
                    ; mov dl, [buffer]
                    ; call build node

                .build_node:
                    ; allocate memory for first node
                    pushad
                    mov dword ecx, [node_len]
                    push ecx
                    call malloc
                    add esp, 4                            ; remove the argument from stack
                    popad
                    mov byte [eax + data], cl             ; set data
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
            je .mult                      ;; jump to multiply

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
                    mov ecx, [node_len]
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
        mov eax, [STACK_DEF_SIZE]    
        jmp .end
    .one_letter:
        mov eax, ecx
        jmp .end

    .end:
        pop ebp
        ret


print_err:
    push ebp            ; backing up base pointer
    mov ebp, esp        ; set ebp to current activation frame
    mov ebx, [ebp + 8]  ; get argument which is a string

    push ebx
    push format_string
    push stderr
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
    
    ; ecx contains curr cell
    mov dword ecx, [stack_curr_pos_ptr]
    .while:
        dec ecx                         ; first occupied cell
        mov ebx, ecx
        sub dword ebx, [stack_ptr]        
        cmp dword ebx, 0                 ; if ebx == 0, then curr_pos == stack_ptr
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
    push stdout
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
