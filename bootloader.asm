; -----------------------------------------------------------------------------
; MyOS Bootloader
; Copyright (C) 2026 student25‑ch
;
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <https://www.gnu.org/licenses/>.
; -----------------------------------------------------------------------------
[org 0x7c00]
[bits 16]

mov ax, 0
mov ds, ax
mov es, ax
mov ss, ax
mov sp, 0x7c00

;读取内核到 0x1000，64扇区(32KB)
mov bx, 0x1000
mov ah, 0x02
mov al, 64
mov ch, 0
mov cl, 2
mov dh, 0
mov dl, 0x80
int 0x13
jc disk_error

menu:
mov si, menu_str
call print_str

mov ah,00h
int 16h

cmp al, '1'
je start_gui
cmp al, '2'
je start_cli
jmp menu

start_gui:
mov byte [0x1000], 1   ; ✔ 和内核保持同一位置标记
jmp 0x1000

start_cli:
mov byte [0x1000], 2   ; ✔ 和内核保持同一位置标记
jmp 0x1000

disk_error:
mov si, err_msg
call print_str
jmp $

print_str:
lodsb
cmp al,0
jz .done
mov ah,0x0E
int 0x10
jmp print_str
.done:
ret

menu_str db 0x0D,0x0A,"==== MYOS v0.4 ====",0x0D,0x0A
db "1 : Graphical GUI Desktop",0x0D,0x0A
db "2 : Text CLI Terminal",0x0D,0x0A
db "Select 1 or 2 > ",0
err_msg db "Disk Read Fail!",0

times 510 - ($-$$) db 0
dw 0xaa55
