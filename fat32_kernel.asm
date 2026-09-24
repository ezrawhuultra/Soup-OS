; oh wow it starts at zero
[ORG 0x0000]
[BITS 16]

; FAT32 BPB offsets (think these are right)
BytesPerSector      equ 0x0B
SectorsPerCluster   equ 0x0D
ReservedSectors     equ 0x0E
NumFATs             equ 0x10
TotalSectors32      equ 0x20
FATSz32             equ 0x24
RootCluster         equ 0x2C
VolumeLabel         equ 0x47

; Directory entry offsets
DIR_Name            equ 0x00
DIR_Attributes      equ 0x0B
DIR_FstClusHI       equ 0x14
DIR_FstClusLO       equ 0x1A
DIR_FileSize        equ 0x1C

; FAT32 values
FAT32_EndChain       equ 0x0FFFFFF8
FAT32_BadCluster     equ 0x0FFFFFF7

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x9000
    
    call clear_screen
    mov si, init_msg
    call print_string
    call newline
    
    ; Load VBR
    call load_vbr
    jc disk_error
    
    ; Parse BPB
    call parse_bpb
    
    ; Print volume info
    call print_volume_info
    call newline
    
    ; Read root directory
    call read_root_directory
    jc disk_error
    
    ; List files
    call list_files
    
    jmp $

load_vbr:
    mov ah, 0x02
    mov al, 1           ; Read 1 sector
    mov ch, 0           ; Cylinder
    mov cl, 1           ; Sector 1 (VBR)
    mov dh, 0           ; Head
    mov dl, 0x80        ; First HDD
    mov bx, 0x8000      ; Load to 0x8000
    mov es, bx
    xor bx, bx
    int 0x13
    ret

parse_bpb:
    mov ax, [es:BytesPerSector]
    mov [bytes_per_sector], ax
    
    mov al, [es:SectorsPerCluster]
    mov [sectors_per_cluster], al
    
    mov ax, [es:ReservedSectors]
    mov [reserved_sectors], ax
    
    mov al, [es:NumFATs]
    mov [num_fats], al
    
    mov eax, [es:FATSz32]
    mov [fat_size], eax
    
    mov eax, [es:RootCluster]
    mov [root_cluster], eax
    
    ; Calculate data start sector
    mov eax, [reserved_sectors]
    movzx ebx, byte [num_fats]
    mul ebx
    mov ebx, [fat_size]
    mul ebx
    add eax, 2          ; Skip first two reserved clusters
    mov [data_start], eax
    ret

print_volume_info:
    mov si, volume_msg
    call print_string
    
    mov si, 0x8000
    add si, VolumeLabel
    mov cx, 11
volume_loop:
    lodsb
    cmp al, ' '
    je volume_skip
    mov ah, 0x0E
    int 0x10
    jmp volume_next
volume_skip:
    inc si
volume_next:
    loop volume_loop
    
    call newline
    ret

read_root_directory:
    mov eax, [root_cluster]
    call read_cluster
    ret

read_cluster:
    ; Convert cluster to LBA
    mov eax, [data_start]
    mov ebx, [current_cluster]
    sub ebx, 2          ; Cluster 2 is first data cluster
    movzx ecx, byte [sectors_per_cluster]
    mul ecx
    add eax, ebx
    
    ; Read cluster
    mov [lba], eax
    movzx eax, byte [sectors_per_cluster]
    mov [sectors_to_read], eax
    
    mov ah, 0x02
    mov al, [sectors_to_read]
    mov ebx, [lba]
    xor edx, edx
    mov cx, 63
    div cx
    inc dx              ; Sector (1-based)
    mov cl, dl
    xor edx, edx
    mov cx, 255
    div cx
    mov ch, al          ; Cylinder
    mov dh, dl          ; Head
    mov dl, 0x80        ; Drive
    mov bx, 0x9000      ; Buffer
    mov es, bx
    xor bx, bx
    int 0x13
    ret

list_files:
    mov si, files_msg
    call print_string
    call newline
    
    mov si, 0x9000      ; Directory buffer
    mov cx, 16          ; Max 16 entries per cluster
file_loop:
    call process_directory_entry
    add si, 32          ; Next entry (32 bytes per entry)
    loop file_loop
    ret

process_directory_entry:
    ; Check for valid entry (first byte not 0x00 or 0xE5)
    mov al, [si + DIR_Name]
    cmp al, 0x00
    je entry_done
    cmp al, 0xE5
    je entry_done
    
    ; Check for directory attribute
    mov al, [si + DIR_Attributes]
    test al, 0x10      ; Directory bit
    jnz entry_done     ; Skip directories
    
    ; Print filename (8.3 format)
    push si
    mov di, filename_buffer
    mov cx, 8
name_loop:
    mov al, [si + DIR_Name]
    cmp al, ' '
    je name_skip
    mov [di], al
    inc di
name_skip:
    inc si
    loop name_loop
    
    ; Add dot and extension
    mov byte [di], '.'
    inc di
    mov cx, 3
ext_loop:
    mov al, [si + DIR_Name]
    cmp al, ' '
    je ext_skip
    mov [di], al
    inc di
ext_skip:
    inc si
    loop ext_loop
    
    mov byte [di], 0    ; Null terminate
    
    ; Print filename
    mov si, filename_buffer
    call print_string
    
    ; Print file size
    mov si, size_msg
    call print_string
    
    mov eax, [si + DIR_FileSize]
    call print_decimal
    
    call newline
    pop si
entry_done:
    ret

print_decimal:
    ; Print EAX as decimal
    mov ebx, 10
    mov di, decimal_buffer
    add di, 10
    mov byte [di], 0
    mov byte [di-1], 0
decimal_loop:
    xor edx, edx
    div ebx
    add dl, '0'
    dec di
    mov [di], dl
    test eax, eax
    jnz decimal_loop
    
    mov si, di
    call print_string
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

newline:
    mov ah, 0x0E
    mov al, 13
    int 0x10
    mov al, 10
    int 0x10
    ret

clear_screen:
    mov ah, 0x00
    mov al, 0x03        ; 80x25 text mode
    int 0x10
    ret

disk_error:
    mov si, error_msg
    call print_string
    jmp $

; These mean and do nothing right now. What a shame.
init_msg db 'Soup OS', 0
volume_msg db 'Volume: ', 0
files_msg db 'Files in root:', 0
size_msg db ' - Size: ', 0
error_msg db 'Disk error!', 0

; BPB variables
bytes_per_sector    dw 0
sectors_per_cluster db 0
reserved_sectors    dw 0
num_fats            db 0
fat_size            dd 0
root_cluster        dd 0
data_start          dd 0
current_cluster     dd 0
lba                 dd 0
sectors_to_read     db 0

; Buffers
filename_buffer times 13 db 0
decimal_buffer times 12 db 0

times 8192-($-start) db 0  ; 8KB kernel
