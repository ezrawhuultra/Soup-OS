[ORG 0x7C00]
[BITS 16]

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    
    ; Print loading message
    mov si, loading_msg
    call print_string
    
    ; Load FAT32 kernel from disk
    call load_kernel
    
    ; Jump to kernel because kernel is good.
    jmp 0x9000:0x0000

load_kernel:
    mov ah, 0x02        ; Read sectors
    mov al, 16          ; Read 16 sectors (8KB)
    mov ch, 0           ; Cylinder
    mov cl, 2           ; Start at sector 2
    mov dh, 0           ; Head
    mov dl, 0x80        ; First HDD
    mov bx, 0x9000      ; Load to segment 0x9000
    mov es, bx
    xor bx, bx          ; Offset 0
    int 0x13
    jc disk_error
    ret

print_string:
    lodsb
    cmp al, 0
    je done
    mov ah, 0x0E
    int 0x10
    jmp print_string
done:
    ret

disk_error:
    mov si, error_msg
    call print_string
    jmp $

loading_msg db 'Loading Soup OS...', 0
error_msg db 'Disk error. UH OH!', 0

times 510-($-start) db 0
dw 0xAA55
