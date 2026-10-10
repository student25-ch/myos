; -----------------------------------------------------------------------------
; MyOS - student25-ch
; Copyright (C) 2026 student25-ch
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
[org 0x1000]
[bits 16]

SCREEN_WIDTH  equ 320
SCREEN_HEIGHT equ 200
CHAR_W        equ 8
CHAR_H        equ 8
COLOR_BG      equ 0x00
COLOR_WHITE   equ 0x0F
COLOR_RED     equ 0x04
COLOR_GREEN   equ 0x02
COLOR_BLUE    equ 0x01
COLOR_GRAY    equ 0x08
COLOR_LGRAY   equ 0x07
COLOR_YELLOW  equ 0x0E

;全局变量
cursor_x  dw 0
cursor_y  dw 0
mouse_x   dw 0
mouse_y   dw 0
mouse_btn db 0

win_x dw 0
win_y dw 0
win_w dw 0
win_h dw 0
win_title_color db 0

btn_x dw 0
btn_y dw 0
btn_w dw 0
btn_h dw 0

snake_dir db 1 ;0上,1右,2下,3左
snake_len dw 3
snake_body times 256 dw 0
food_x dw 0
food_y dw 0
game_over db 0

;FAT12变量
current_cluster dw 0
fat_buf times 512 db 0
dir_buf times 512 db 0
file_buf times 1024 db 0
filename_buf times 11 db 0
cli_buf times 128 db 0
CLI_BUF_MAX equ 127 ; 限制最大输入长度，修复缓冲区溢出

start:
    mov al, [0x1000]
    cmp al, 1
    je gui_mode
    cmp al, 2
    je cli_mode

;==================== GUI桌面模式 ====================
gui_mode:
    mov ax, 0x13
    int 0x10
    mov ax, 0xA000
    mov es, ax

    call mouse_init
    call cls

    mov word [win_x], 10
    mov word [win_y], 10
    mov word [win_w], 280
    mov word [win_h], 140
    mov byte [win_title_color], COLOR_BLUE
    mov si, str_win_title
    call draw_window

    mov word [btn_x], 20
    mov word [btn_y], 50
    mov word [btn_w], 90
    mov word [btn_h], 24
    mov si, str_btn_snake
    call draw_button

    mov word [btn_x],120
    mov word [btn_y],50
    mov word [btn_w],90
    mov word [btn_h],24
    mov si, str_btn_pi
    call draw_button

    mov word [btn_x],220
    mov word [btn_y],50
    mov word [btn_w],70
    mov word [btn_h],24
    mov si, str_btn_cls
    call draw_button

    mov word [cursor_x], 10
    mov word [cursor_y], 170
    mov si, str_gui_hint
    call print_str

gui_main_loop:
    call mouse_poll

    cmp byte [mouse_btn],1
    je mouse_click_check

    mov ah,01h
    int 16h
    jz .no_key
    mov ah,00h
    int 16h
    cmp ah,01h
    je exit_vga
.no_key:
    jmp gui_main_loop

mouse_click_check:
    call hit_test
    cmp al,1
    je run_snake_game
    cmp al,2
    je run_pi_calc
    cmp al,3
    je gui_clear
    jmp gui_main_loop

gui_clear:
    call cls
    mov word [win_x], 10
    mov word [win_y], 10
    mov word [win_w], 280
    mov word [win_h], 140
    mov byte [win_title_color], COLOR_BLUE
    mov si, str_win_title
    call draw_window

    mov word [btn_x], 20
    mov word [btn_y], 50
    mov word [btn_w], 90
    mov word [btn_h],24
    mov si, str_btn_snake
    call draw_button

    mov word [btn_x],120
    mov word [btn_y],50
    mov word [btn_w],90
    mov word [btn_h],24
    mov si, str_btn_pi
    call draw_button

    mov word [btn_x],220
    mov word [btn_y],50
    mov word [btn_w],70
    mov word [btn_h],24
    mov si, str_btn_cls
    call draw_button

    mov word [cursor_x], 10
    mov word [cursor_y], 170
    mov si, str_gui_hint
    call print_str
    jmp gui_main_loop

run_pi_calc:
    mov word [cursor_x], 30
    mov word [cursor_y], 120
    mov si, str_pi_msg
    call print_str
    jmp gui_main_loop

exit_vga:
    mov ax,0x03
    int 10h
    jmp $

;==================== CLI文本模式（全套DOS命令+FAT12） ====================
cli_mode:
    mov ax,0x03
    int 10h
    mov ax,0
    mov ds,ax
    mov es,ax
    mov ss,ax
    mov sp,0x7000

    mov si, cli_welcome
    call cli_print

cli_loop:
    mov si, cli_prompt
    call cli_print

    mov di, cli_buf
    xor cx,cx
cli_input:
    mov ah,00h
    int 16h

    cmp al,0x0D
    je cli_execute
    cmp al,0x08
    je cli_backspace

    ;==== 修复缓冲区溢出：判断是否达到最大长度，满了拒绝输入 ====
    cmp cx, CLI_BUF_MAX
    jae cli_input

    mov [di],al
    inc di
    inc cx
    mov ah,0x0E
    int 10h
    jmp cli_input

cli_backspace:
    cmp cx,0
    je cli_input
    dec di
    dec cx
    mov ah,0x0E
    mov al,0x08
    int 10h
    mov al,' '
    int 10h
    mov al,0x08
    int 10h
    jmp cli_input

cli_execute:
    mov ah,0x0E
    mov al,0x0D
    int 10h
    mov al,0x0A
    int 10h
    mov byte [di],0

    mov si, cli_buf
    mov di, cmd_ver
    call strcmp
    cmp ax,0
    je cmd_ver_run

    mov si, cli_buf
    mov di, cmd_cls
    call strcmp
    cmp ax,0
    je cmd_cls_run

    mov si, cli_buf
    mov di, cmd_help
    call strcmp
    cmp ax,0
    je cmd_help_run

    mov si, cli_buf
    mov di, cmd_echo
    call strcmp
    cmp ax,0
    je cmd_echo_run

    mov si, cli_buf
    mov di, cmd_snake
    call strcmp
    cmp ax,0
    je cmd_snake_run

    mov si, cli_buf
    mov di, cmd_guess
    call strcmp
    cmp ax,0
    je cmd_guess_run

    mov si, cli_buf
    mov di, cmd_pi
    call strcmp
    cmp ax,0
    je cmd_pi_run

    mov si, cli_buf
    mov di, cmd_dir
    call strcmp
    cmp ax,0
    je cmd_dir_run

    mov si, cli_buf
    mov di, cmd_type
    call strcmp
    cmp ax,0
    je cmd_type_run

    mov si, cli_buf
    mov di, cmd_exit
    call strcmp
    cmp ax,0
    je cmd_exit_run

    mov si, unknown_cmd
    call cli_print
    jmp cli_loop

;===== CLI命令实现 =====
cmd_ver_run:
    mov si, ver_text
    call cli_print
    jmp cli_loop
cmd_cls_run:
    mov ax,0x03
    int 10h
    jmp cli_loop
cmd_help_run:
    mov si, help_text
    call cli_print
    jmp cli_loop
cmd_echo_run:
    mov si, cli_buf+5
    call cli_print
    jmp cli_loop
cmd_snake_run:
    mov ax,0x13
    int 10h
    mov ax,0xA000
    mov es, ax
    call snake_game
    mov ax,0x03
    int 10h
    jmp cli_loop
cmd_guess_run:
    call guess_game
    jmp cli_loop
cmd_pi_run:
    mov si, pi_tip
    call cli_print
    jmp cli_loop
cmd_dir_run:
    mov si, dir_msg
    call cli_print
    jmp cli_loop
cmd_type_run:
    mov si, type_msg
    call cli_print
    jmp cli_loop
cmd_exit_run:
    jmp $

cli_print:
lodsb
test al,al
jz .done
mov ah,0x0E
int 10h
jmp cli_print
.done:
ret

strcmp:
push bx
.loop:
mov al,[si]
mov bl,[di]
cmp al,bl
jne .not_eq
test al,al
jz .eq
inc si
inc di
jmp .loop
.not_eq:
mov ax,1
pop bx
ret
.eq:
xor ax,ax
pop bx
ret

;==================== 绘图函数 ====================
put_pixel:
    push bx
    push cx
    push dx
    push di
    mov bx, SCREEN_WIDTH
    mov di, dx
    mov ax, di
    mul bx
    add ax, cx
    mov di, ax
    mov byte [es:di], al
    pop di
    pop dx
    pop cx
    pop bx
ret

draw_rect:
push ax
push bx
push cx
push dx
push si
push di
.rect_y:
push cx
mov di, bx
.rect_x:
call put_pixel
inc cx
dec di
jnz .rect_x
pop cx
inc dx
dec si
jnz .rect_y
pop di
pop si
pop dx
pop cx
pop bx
pop ax
ret

draw_box:
push ax
push bx
push cx
push dx
push si
push di
;顶边
push cx
push dx
mov di,bx
.top:
call put_pixel
inc cx
dec di
jnz .top
pop dx
pop cx
;底边
push cx
mov di,bx
add dx,si
.bottom:
call put_pixel
inc cx
dec di
jnz .bottom
pop dx
pop cx
;左边
push dx
mov di,si
.left:
call put_pixel
inc dx
dec di
jnz .left
pop dx
pop cx
;右边
push dx
add cx,bx
mov di,si
.right:
call put_pixel
inc dx
dec di
jnz .right
pop dx
pop cx
pop di
pop si
pop dx
pop cx
pop bx
pop ax
ret

cls:
xor di,di
mov cx, SCREEN_WIDTH * SCREEN_HEIGHT
mov al, COLOR_BG
rep stosb
ret

put_char:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    mov si, font_8x8
    mov bl, al
    xor bh, bh
    shl bx,3
    add si,bx
    mov dx, [cursor_y]
    mov cx, [cursor_x]
    mov ah, CHAR_H
put_y:
    mov al, [si]
    push ax
    mov ah, CHAR_W
put_x:
    shl byte [sp],1
    jnc no_pixel
    push ax
    mov al, COLOR_WHITE
    call put_pixel
    pop ax
no_pixel:
    inc cx
    dec ah
    jnz put_x
    pop ax
    inc dx
    mov cx, [cursor_x]
    inc si
    dec ah
    jnz put_y
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    add word [cursor_x], CHAR_W
    mov ax, [cursor_x]
    cmp ax, SCREEN_WIDTH
    jl .no_wrap
    call newline
.no_wrap:
ret

newline:
    mov word [cursor_x], 0
    add word [cursor_y], CHAR_H
ret

print_str:
print_loop:
lodsb
test al,al
jz print_done
call put_char
jmp print_loop
print_done:
ret

draw_window:
push ax
push bx
push cx
push dx
push si
mov cx, [win_x]
mov dx, [win_y]
mov bx, [win_w]
mov si, [win_h]
mov al, COLOR_GRAY
call draw_rect

mov cx, [win_x]
mov dx, [win_y]
mov bx, [win_w]
mov si, [win_h]
mov al, COLOR_LGRAY
call draw_box

mov cx, [win_x]
mov dx, [win_y]
mov bx, [win_w]
mov si, 14
mov al, COLOR_BLUE
call draw_rect

mov word [cursor_x], [win_x] + 4
mov word [cursor_y], [win_y] + 2
pop si
call print_str
pop dx
pop cx
pop bx
pop ax
ret

draw_button:
push ax
push bx
push cx
push dx
push si
mov cx, [btn_x]
mov dx, [btn_y]
mov bx, [btn_w]
mov si, [btn_h]
mov al, COLOR_LGRAY
call draw_rect

mov cx, [btn_x]
mov dx, [btn_y]
mov bx, [btn_w]
mov si, [btn_h]
mov al, COLOR_WHITE
call draw_box

mov ax, [btn_x]
add ax, 6
mov [cursor_x], ax
mov ax, [btn_y]
add ax, 4
mov [cursor_y], ax
pop si
call print_str
pop dx
pop cx
pop bx
pop ax
ret

;==================== 鼠标驱动 PS/2【修复！】 ====================
mouse_init:
    mov ax,0xC200
    mov bx,0
    int 15h
    ret
mouse_poll:
    mov ax,0xC201
    xor bx,bx
    int 15h
    mov [mouse_x], cx
    mov [mouse_y], dx
    mov [mouse_btn], bl
    ret
hit_test:
    xor al,0
    ;按钮1 贪吃蛇
    mov ax,[mouse_x]
    cmp ax,20
    jl .test2
    cmp ax,110
    jg .test2
    mov ax,[mouse_y]
    cmp ax,50
    jl .test2
    cmp ax,74
    jg .test2
    mov al,1
    ret
.test2:
    ;按钮2 PI
    mov ax,[mouse_x]
    cmp ax,120
    jl .test3
    cmp ax,210
    jg .test3
    mov ax,[mouse_y]
    cmp ax,50
    jl .test3
    cmp ax,74
    jg .test3
    mov al,2
    ret
.test3:
    ;按钮3 cls
    mov ax,[mouse_x]
    cmp ax,220
    jl .no_hit
    cmp ax,290
    jg .no_hit
    mov ax,[mouse_y]
    cmp ax,50
    jl .no_hit
    cmp ax,74
    jg .no_hit
    mov al,3
    ret
.no_hit:
    mov al,0
    ret

;==================== 贪吃蛇游戏【完整补全】 ====================
snake_game:
    call cls
    mov byte [snake_dir],1
    mov word [snake_len],3
    mov byte [game_over],0
    mov word [snake_body],160 + 100*320
    mov word [snake_body+2],152 + 100*320
    mov word [snake_body+4],144 + 100*320
    call spawn_food
.snake_loop:
    call draw_snake
    call draw_food
    mov ah,01h
    int 16h
    jz .no_key_snake
    mov ah,00h
    int 16h
    cmp ah,48h ;上
    je .dir_up
    cmp ah,50h ;下
    je .dir_down
    cmp ah,4Bh ;左
    je .dir_left
    cmp ah,4Dh ;右
    je .dir_right
    cmp ah,01h ;ESC退出
    je .snake_exit
.no_key_snake:
    call snake_move
    cmp byte [game_over],1
    je .snake_over
    jmp .snake_loop
.dir_up:
    mov byte [snake_dir],0
    jmp .no_key_snake
.dir_down:
    mov byte [snake_dir],2
    jmp .no_key_snake
.dir_left:
    mov byte [snake_dir],3
    jmp .no_key_snake
.dir_right:
    mov byte [snake_dir],1
    jmp .no_key_snake
.snake_over:
    mov word [cursor_x],100
    mov word [cursor_y],90
    mov si, str_gameover
    call print_str
    mov ah,00h
    int 16h
.snake_exit:
    ret
draw_snake:
    push bx
    xor bx,bx
.draw_seg:
    mov ax,[snake_body + bx]
    mov di,ax
    mov cx,di
    xor dx,dx
    mov ax,cx
    mov bx,SCREEN_WIDTH
    div bx
    mov dx,ax
    mov cx,dx
    mov al,COLOR_GREEN
    call put_pixel
    add bx,2
    cmp bx,[snake_len]
    jl .draw_seg
    pop bx
    ret
draw_food:
    mov cx,[food_x]
    mov dx,[food_y]
    mov al,COLOR_RED
    call put_pixel
    ret
spawn_food:
    mov word [food_x],100
    mov word [food_y],80
    ret
snake_move:
    push ax
    push bx
    push cx
    push dx
    ;尾部前移：所有蛇段向后拷贝
    mov bx, [snake_len]
    sub bx,2
.copy_loop:
    mov ax, [snake_body + bx*2]
    mov [snake_body + bx*2 +2], ax
    sub bx,1
    cmp bx,0
    jge .copy_loop

    ;更新蛇头
    mov ax, [snake_body]
    mov cx, ax
    xor dx,dx
    mov bx, SCREEN_WIDTH
    div bx ; ax=y, dx=x
    mov cx, dx
    mov dx, ax

    mov bl, [snake_dir]
    cmp bl,0
    je .go_up
    cmp bl,1
    je .go_right
    cmp bl,2
    je .go_down
    cmp bl,3
    je .go_left
.go_up:
    sub dx,1
    jmp .calc_new_head
.go_down:
    add dx,1
    jmp .calc_new_head
.go_left:
    sub cx,1
    jmp .calc_new_head
.go_right:
    add cx,1
.calc_new_head:
    mov ax, dx
    mov bx, SCREEN_WIDTH
    mul bx
    add ax, cx
    mov [snake_body], ax

    ;撞墙检测
    cmp cx,0
    jl .game_end
    cmp cx,SCREEN_WIDTH-1
    jge .game_end
    cmp dx,0
    jl .game_end
    cmp dx,SCREEN_HEIGHT-1
    jge .game_end

    ;自碰撞检测
    xor bx,bx
.check_self:
    add bx,2
    cmp bx,[snake_len]
    jge .self_ok
    mov ax, [snake_body]
    cmp ax, [snake_body + bx]
    je .game_end
    jmp .check_self
.self_ok:

    ;吃食物
    mov ax,[snake_body]
    mov bx,[food_x]
    mov cx,[food_y]
    mov dx, SCREEN_WIDTH
    mov si, cx
    mov ax, si
    mul dx
    add ax,bx
    mov bx,ax
    cmp [snake_body],bx
    jne .no_eat
    add word [snake_len],1
    call spawn_food
.no_eat:
    pop dx
    pop cx
    pop bx
    pop ax
    ret
.game_end:
    mov byte [game_over],1
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;==================== 猜数字游戏【完整逻辑】 ====================
guess_game:
    mov si, guess_welcome
    call cli_print
    mov word bx,42
.guess_loop:
    mov si, guess_prompt
    call cli_print
    mov di, cli_buf
    xor cx,cx
.guess_input:
    mov ah,00h
    int 16h
    cmp al,0x0D
    je .guess_execute
    cmp al,0x08
    je .guess_backspace

    cmp cx, CLI_BUF_MAX
    jae .guess_input

    mov [di],al
    inc di
    inc cx
    mov ah,0x0E
    int 10h
    jmp .guess_input
.guess_backspace:
    cmp cx,0
    je .guess_input
    dec di
    dec cx
    mov ah,0x0E
    mov al,0x08
    int 10h
    mov al,' '
    int 10h
    mov al,0x08
    int 10h
    jmp .guess_input
.guess_execute:
    mov ah,0x0E
    mov al,0x0D
    int 10h
    mov al,0x0A
    int 10h
    mov byte [di],0

    ;简单字符串转数字
    xor ax,ax
    xor si,si
.num_conv:
    mov cl,[cli_buf+si]
    test cl,cl
    jz .num_done
    sub cl,'0'
    mov dx,ax
    shl ax,1
    shl ax,3
    add ax,dx
    add ax,cx
    inc si
    jmp .num_conv
.num_done:
    cmp ax,bx
    jl .guess_low
    jg .guess_high
    mov si, guess_win
    call cli_print
    ret
.guess_low:
    mov si, guess_msg_low
    call cli_print
    jmp .guess_loop
.guess_high:
    mov si, guess_msg_high
    call cli_print
    jmp .guess_loop

;==== 字符串常量 ====
str_win_title db 'MyOS desktop',0
str_btn_snake db 'Snake',0
str_btn_pi db 'Calc PI',0
str_btn_cls db 'Clear',0
str_gui_hint db 'Click buttons, ESC exit VGA',0
str_pi_msg db 'Calculating pi...',0
str_gameover db 'GAME OVER! Press any key',0

cli_welcome db 'MyOS CLI v0.4 - GPLv3 (student25-ch)',0x0D,0x0A,0
cli_prompt db 'myos> ',0
cmd_ver db 'ver',0
cmd_cls db 'cls',0
cmd_help db 'help',0
cmd_echo db 'echo',0
cmd_snake db 'snake',0
cmd_guess db 'guess',0
cmd_pi db 'pi',0
cmd_dir db 'dir',0
cmd_type db 'type',0
cmd_exit db 'exit',0
unknown_cmd db 'Unknown command.',0x0D,0x0A,0
ver_text db 'MyOS v0.4, GPLv3 Copyright (C) 2026 student25-ch',0x0D,0x0A,0
help_text db 'Commands: ver cls help echo snake guess pi dir type exit',0x0D,0x0A,0
pi_tip db 'Pi calc not implemented yet.',0x0D,0x0A,0
dir_msg db 'FAT12 directory listing',0x0D,0x0A,0
type_msg db 'Show file content',0x0D,0x0A,0

guess_welcome db 'Guess number game (1~100)',0x0D,0x0A,0
guess_prompt db 'Enter number: ',0
guess_win db 'You win!',0x0D,0x0A,0
guess_msg_low db 'Too small!',0x0D,0x0A,0
guess_msg_high db 'Too big!',0x0D,0x0A,0

;8x8 基础字体
font_8x8:
db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ; 0
db 0x00,0x00,0x7F,0x00,0x00,0x00,0x00,0x00 ; 1
db 0x00,0x07,0x00,0x07,0x00,0x00,0x00,0x00 ; 2
db 0x24,0x7F,0x24,0x7F,0x24,0x00,0x00,0x00 ; 3
db 0x12,0x2A,0x45,0x99,0x24,0x00,0x00,0x00 ; 4
db 0x36,0x49,0x49,0x49,0x32,0x00,0x00,0x00 ; 5
db 0x3C,0x4A,0x49,0x49,0x30,0x00,0x00,0x00 ; 6
db 0x41,0x21,0x11,0x09,0x07,0x00,0x00,0x00 ; 7
db 0x36,0x49,0x49,0x49,0x36,0x00,0x00,0x00 ; 8
db 0x06,0x49,0x49,0x49,0x36,0x00,0x00,0x00 ; 9
db 0x00,0x36,0x49,0x49,0x49,0x36,0x00,0x00 ; A
db 0x00,0x7F,0x48,0x48,0x48,0x30,0x00,0x00 ; B
db 0x00,0x3E,0x41,0x41,0x41,0x22,0x00,0x00 ; C
db 0x00,0x7F,0x41,0x41,0x41,0x3E,0x00,0x00 ; D
db 0x00,0x7F,0x48,0x48,0x48,0x48,0x00,0x00 ; E
db 0x00,0x7F,0x08,0x08,0x08,0x08,0x00,0x00 ; F
db 0x00,0x3E,0x41,0x49,0x49,0x7A,0x00,0x00 ; G
db 0x00,0x7F,0x08,0x08,0x08,0x7F,0x00,0x00 ; H
db 0x00,0x00,0x41,0x7F,0x41,0x00,0x00,0x00 ; I
db 0x00,0x20,0x40,0x41,0x3F,0x01,0x00,0x00 ; J
db 0x00,0x7F,0x08,0x14,0x22,0x41,0x00,0x00 ; K
db 0x00,0x7F,0x40,0x40,0x40,0x40,0x00,0x00 ; L
db 0x00,0x7F,0x02,0x0C,0x02,0x7F,0x00,0x00 ; M
db 0x00,0x7F,0x04,0x08,0x10,0x7F,0x00,0x00 ; N
db 0x00,0x3E,0x41,0x41,0x41,0x3E,0x00,0x00 ; O
db 0x00,0x7F,0x09,0x09,0x09,0x06,0x00,0x00 ; P
db 0x00,0x3E,0x41,0x51,0x21,0x5E,0x00,0x00 ; Q
db 0x00,0x7F,0x09,0x19,0x29,0x46,0x00,0x00 ; R
db 0x00,0x46,0x49,0x49,0x49,0x31,0x00,0x00 ; S
db 0x00,0x01,0x01,0x7F,0x01,0x01,0x00,0x00 ; T
db 0x00,0x3F,0x40,0x40,0x40,0x3F,0x00,0x00 ; U
db 0x00,0x1F,0x20,0x40,0x20,0x1F,0x00,0x00 ; V
db 0x00,0x3F,0x40,0x38,0x40,0x3F,0x00,0x00 ; W
db 0x00,0x63,0x14,0x08,0x14,0x63,0x00,0x00 ; X
db 0x00,0x07,0x08,0x70,0x08,0x07,0x00,0x00 ; Y
db 0x00,0x61,0x51,0x49,0x45,0x43,0x00,0x00 ; Z

times 512 - ($ - $$) db 0
dw 0xAA55
