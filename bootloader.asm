; -----------------------------------------------------------------------------
; MyOS Bootloader v0.4‑fix
; Copyright (C) 2026 student25‑ch
;
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
; -----------------------------------------------------------------------------
[org 0x7c00]
[bits 16]

cli
mov ax, 0
mov ds, ax
mov es, ax
mov ss, ax
mov sp, 0x7000   ; 修复：栈远离0x7C00引导代码，防止栈覆盖自身
sti

; BIOS传入dl = 启动设备号，不要硬编码0x80！软盘镜像dl=0，硬盘启动dl=0x80
mov bx, 0x1000
mov ah, 0x02
mov al, 64
mov ch, 0
mov cl, 2
mov dh, 0
; dl保留BIOS传入的启动驱动器号，不写死
int 0x13
jc disk_error

; 校验实际读取扇区数量，al=实际读取扇区
cmp al, 64
jne disk_error

menu:
mov si, menu_str
call print_str

mov ah,00h
int 16h
mov ah,0x0E   ; 回显按键
int 10h

; 兼容大小写/shift输入
cmp al, '1'
je start_gui
cmp al, '2'
je start_cli
jmp menu

start_gui:
mov byte [0x1000], 1
jmp far 0:0x1000   ; 远跳转强制cs=0，保证内核环境干净

start_cli:
mov byte [0x1000], 2
jmp far 0:0x1000

disk_error:
mov si, err_msg
call print_str
jmp $

print_str:
push bx
xor bx, bx
lodsb
cmp al,0
jz .done
mov ah,0x0E
int 0x10
jmp print_str
.done:
pop bx
ret

menu_str db 0x0D,0x0A,"==== MYOS v0.4 ====",0x0D,0x0A
db "1 : Graphical GUI Desktop",0x0D,0x0A
db "2 : Text CLI Terminal",0x0D,0x0A
db "Select 1 or 2 > ",0
err_msg db 0x0D,0x0A,"Disk Read Fail!",0

times 510 - ($-$$) db 0
dw 0xaa55
