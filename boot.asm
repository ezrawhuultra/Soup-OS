; boot.asm
[BITS 32]
[EXTERN kernel_main]

section .multiboot
align 4
mb_header_start:
    dd 0x1BADB002              ; magic number
    dd 0x00                    ; flags
    dd -(0x1BADB002 + 0x00)    ; checksum
mb_header_end:

section .text
global _start
_start:
    ; Set up stack
    mov esp, stack_top
    
    ; Call kernel
    call kernel_main
    
    ; Infinite loop if kernel returns
    cli
.halt:
    hlt
    jmp .halt

section .bss
align 16
stack_bottom:
    resb 16384  ; 16 KiB stack
stack_top: