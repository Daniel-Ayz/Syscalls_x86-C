section .data
    newline db 0xA            ; Newline character
    stdin  EQU 0
    stdout EQU 1
    stderr EQU 2
    write  EQU 4
    read   EQU 3
    open   EQU 5
    close  EQU 6
    lseek  EQU 19
    input dd stdin
    output dd stdout
    mode_read EQU 0               ; Mode for read-only
    mode_write EQU 577            ; Mode for write, create, truncate
    set_file_permissions EQU 420  ; chmod 0644

section .text
global _start
global system_call
extern strlen
_start:
    pop    dword ecx    ; ecx = argc
    mov    esi,esp      ; esi = argv
    mov     eax,ecx     ; put the number of arguments into eax
    shl     eax,2       ; compute the size of argv in bytes
    add     eax,esi     ; add the size to the address of argv 
    add     eax,4       ; skip NULL at the end of argv
    push    dword eax   ; char *envp[]
    push    dword esi   ; char* argv[]
    push    dword ecx   ; int argc

    call    main        ; int main( int argc, char *argv[], char *envp[] )

    mov     ebx,eax
    mov     eax,1
    int     0x80
    nop

main:
    push ebp
    mov ebp, esp

    mov     edi, [ebp+8] ; argc
    mov     esi, [ebp+12] ; argv

    xor     ecx, ecx        ; Counter for argv elements
    loop:
        cmp     ecx, edi        ; Compare counter with argc
        jge     done_debug           ; If counter >= argc, we're done

        mov     eax, [esi + ecx*4] ; Load the pointer to the current argv string
        push    ecx             ; Save ecx, because we're going to use it for strlen
        push    eax             ; Save current argv pointer

        call    strlen          ; Call strlen to calculate the length of the current argv string
        mov     edx, eax        ; Move return value (length) into edx

        pop     ebx             ; Restore current argv pointer to ebx
        pop     ecx             ; Restore ecx (the counter for argv elements)
        
        ; Prepare arguments for system_call to print the string
        push    edx             ; Length of the string
        push    ebx             ; Pointer to the string
        push    dword stderr         ; File descriptor (stderr)
        push    dword write         ; Syscall number for sys_write
        call    system_call     ; Make the syscall to print the string
        add     esp, 16

        ; Optionally print a newline after each argument
        push    dword 1         ; Length of the newline character
        push    dword newline   ; Pointer to newline character
        push    dword stderr         ; File descriptor (stderr)
        push    dword write         ; Syscall number for sys_write
        call    system_call     ; Make the syscall to print the newline
        add     esp, 16

        inc     ecx             ; Increment the counter
        jmp     loop           ; Continue the loop

    done_debug:
        xor    ecx, ecx               ; Counter for argv elements
        parse_args:
            cmp    ecx, edi               ; Compare counter with argc
            jge    done_parse             ; If counter >= argc, we're done parsing args

            mov    eax, [esi + ecx*4]     ; Load the pointer to the current argv string
            cmp    byte [eax], '-'        ; Check if the argument starts with '-'
            jne    next_arg

            cmp    byte [eax+1], 'i'      ; Check if the argument is for input file
            je     open_input
            cmp    byte [eax+1], 'o'      ; Check if the argument is for output file
            je     open_output
            jmp    next_arg
        
        open_input:
            add    eax, 2                 ; Skip '-i' to get the filename
            push   mode_read              ; Mode for read-only
            push   eax                    ; Filename
            push   open                   ; Syscall number for open
            call   system_call
            mov    [input], eax           ; Update input file descriptor
            add    esp, 12
            jmp    next_arg

        open_output:
            push   set_file_permissions
            add    eax, 2                 ; Skip '-o' to get the filename
            push   mode_write             ; Mode for write, create, truncate
            push   eax                    ; Filename
            push   open                   ; Syscall number for open
            call   system_call
            add    esp,16
            mov    [output], eax          ; Update output file descriptor
            jmp    next_arg

        next_arg:
            inc    ecx                    ; Increment the counter
            jmp    parse_args             ; Continue parsing arguments

        done_parse:
            call    encode
            pop     ebp
            mov     eax, 0          ; Return 0 from main
            ret                     ; Return to caller


system_call:
    push    ebp             ; Save caller state
    mov     ebp, esp
    sub     esp, 4          ; Leave space for local var on stack
    pushad                  ; Save some more caller state

    mov     eax, [ebp+8]    ; Copy function args to registers: leftmost...        
    mov     ebx, [ebp+12]   ; Next argument...
    mov     ecx, [ebp+16]   ; Next argument...
    mov     edx, [ebp+20]   ; Next argument...
    int     0x80            ; Transfer control to operating system
    mov     [ebp-4], eax    ; Save returned value...
    popad                   ; Restore caller state (registers)
    mov     eax, [ebp-4]    ; place returned value where caller can see it
    add     esp, 4          ; Restore caller state
    pop     ebp             ; Restore caller state
    ret                     ; Back to caller

encode:
    ; Assuming Infile and Outfile are meant to be stdin (0) and stdout (1) respectively
    mov ebx, input      ; Move stdin descriptor to ebx for reading
    mov ecx, output     ; Move stdout descriptor to ecx for writing

    ; Create a buffer for a single character
    sub esp, 1          ; Allocate space on the stack for the character
    mov edi, esp        ; Point EDI to the character space

    read_loop:
        ; Prepare for reading a single character
        push 1
        push edi
        mov ebx, [input]
        push ebx
        push read
        call system_call
        add esp, 16
        cmp eax, 0          ; Check if read was successful
        je  done_encode            ; If 0 characters were read (EOF), we're done
        

        ;; encoding
        ; Check if character is between 'A' and 'Z'
        mov al, [edi]           ; Load the read character into al
        cmp al, 'A'             
        jl  write_char          ; Jump if less than 'A'
        cmp al, 'Z'             
        jg  check_lowercase     ; Jump if greater than 'Z'

        ; Character is between 'A' and 'Z', increment it
        inc byte [edi]          
        jmp write_char          ; Jump to write the character

        check_lowercase:
            ; Check if character is between 'a' and 'z'
            cmp al, 'a'
            jl  write_char          ; Jump if less than 'a'
            cmp al, 'z'
            jg  write_char          ; Jump if greater than 'z'

            ; Character is between 'a' and 'z', increment it
            inc byte [edi]


        write_char:
            ; Write the character to stdout
            push 1
            push edi
            mov ebx, [output]
            push ebx
            push write
            call system_call
            add esp, 16

            jmp read_loop       ; Loop back to read the next character

    done_encode:
        add esp, 1          ; Clean up the stack
        ret                 ; Return from the encode function
