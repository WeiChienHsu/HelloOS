[bits 16]
[org 0x7C00]

; ������ �޸𸮿� �ø��� �Ǵ� �ּ�
LoadAddress          equ 0x9000

jmp short main
nop

;-----------------------------------------
; File Allocation Table
;-----------------------------------------
OemID               db "HELLOOS "
BytesPerSector      dw 0x0200
SectorsPerCluster   db 0x08
ReservedSectors     dw 0x073E
TotalFATs           db 0x02
MaxRootEntries      dw 0x0000
NumberOfSectors     dw 0x0000
MediaDescriptor     db 0xF8
SectorsPerFAT       dw 0x0000
SectorsPerTrack     dw 0x003F
SectorsPerHead      dw 0x00FF
HiddenSectors       dd 0x00000000
TotalSectors        dd 0x00F007FD
BigSectorsPerFAT    dd 0x00003C61
Flags               dw 0x0000
FSVersion           dw 0x0000
RootDirectoryStart  dd 0x00000002
FSInfoSector        dw 0x0001
BackupBootSector    dw 0x0006

Reserved1           dd 0
Reserved2           dd 0
Reserved3           dd 0

BootDiskNumber      db 0x80
Reserved4           db 0
Signature           db 0x29
VolumeID            dd 0xFFFFFFFF
VolumeLabel         db "HELLOOS    "
SystemID            db "FAT32   "

;-----------------------------------------
; Bootloader Main Function
;-----------------------------------------
main:               xor ax, ax
                    mov es, ax
                    mov ds, ax
                    mov ss, ax
                    mov fs, ax
                    mov gs, ax
                    mov sp, 0xFFF8

.loader:            xor ebx, ebx
                    xor ecx, ecx
                    mov cl, byte [TotalFATs]
                    mov eax, dword [BigSectorsPerFAT]
                    mov bx, word [ReservedSectors]
                    mul ecx
                    ; dx:ax = ax * r16
                    ; edx:eax = eax * r32
                    add eax, ebx

                    ; RootDir�� ��ġ : eax
                    mov dword [StartSector], eax

                    ; ��ũ�� �����͸� �о���� ���� ���ͷ�Ʈ�� ȣ���Ѵ�.
                    mov ah, 0x42
                    mov dl, byte [BootDiskNumber]
                    mov si, DiskAddressPacket
                    int 0x13
                    jc .failed
                    ; RootDirEntry�� ������ ������(������ ���ִ����� ���� ����� ������)
                    ; 0x8000 -> loader.sys ������ ã�ƾߵ� -> �����Ͱ� ����� ��ġ�� ã��
                    ; -> ã�� ��ġ�� int 0x13 �̿��ؼ� 0x8000���� �޸𸮿� ���� -> jmp 0x8000

                    ; ���� RootDirEntry�� ���� loader.sys������ ã�´�
                    mov di, DiskAddressPacket + 4

.find:              mov al, byte [di]
                    cmp al, 0xE5
                    je .next
                    ; ���� ù��° ����Ʈ�� 0xE5 ?? => ������ ����
                    ; �����Ȱ� �ƴҰ�� �����̸� ��
                    test al, al
                    jz .failed

                    ; �� �κ��� ����ȴٴ� ���� ������ ������ �ƴ϶�� ���̴�.
                    mov cx, 8
                    mov bx, LoaderName
                    mov si, di

.compare:           mov al, byte [bx]
                    cmp al, byte [si]
                    jne .next
                    ; dx�� 1����Ʈ�� si�� 1����Ʈ�� ������ ���� ��� �ٸ��� ���� �������� ã��

                    add bx, 1
                    add si, 1
                    loop .compare
                    ; for (int i = ??; i > 0; i--) { ... }
                    jmp .video

.next:              add di, 0x20
                    jmp .find

.video:             xor eax, eax
                    ; �� ������ ��ġ�� ������ ��� ���ϴ� ������ ã�� �����̴�.
                    mov ax, word [di + 20]
                    shl eax, 16
                    mov ax, word [di + 26]
                    sub eax, 2
                    ; �̶��� eax ���� ���� ������ ����� Ŭ������ ��ġ ���̴�.
                    mov ecx, 0
                    mov cl, byte [SectorsPerCluster]
                    mul ecx

                    add eax, dword [StartSector]
                    mov dword [StartSector], eax
                    mov word [DiskAddressPacket + 4], LoadAddress

                    ; ��ũ�� �����͸� �о���� ���� ���ͷ�Ʈ�� ȣ���Ѵ�.
                    mov ah, 0x42
                    mov dl, byte [BootDiskNumber]
                    mov si, DiskAddressPacket
                    int 0x13
                    jc .failed

.success:           mov ax, 0
                    mov ds, ax
                    mov es, ax

                    mov si, LoadAddress
                    jmp si

.failed:            mov ax, 0xB800
                    mov es, ax

                    mov si, ErrorMsg
                    mov di, 0
.print:             mov cl, byte [si]
                    cmp cl, 0
                    je .shutdown

                    mov byte [es:di], cl
                    add di, 1
                    mov byte [es:di], 0x04
                    add di, 1
                    add si, 1
                    jmp .print

.shutdown:          hlt
                    jmp .shutdown

;-----------------------------------------
; Disk Address Packet
;-----------------------------------------
DiskAddressPacket   db 0x10
                    db 0        ; ����ü ũ��
                    dw 8        ; �а��� �ϴ� ������ ����
                    dw 0x8000   ; offset
                    dw 0x0000   ; segment
StartSector         dq 0

;-----------------------------------------
; Etc Datas
;-----------------------------------------
ErrorMsg            db "Do not find out file..", 0
LoaderName          db "BOOTMGR ", "ELF"

times 510-($-$$)    db 0x00
                    dw 0xAA55