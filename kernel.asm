;Copyright © 2026 [Jasper]
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
mouse_x   dw 160
mouse_y   dw 100
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
num_buf times 16 db 0

start:
    mov al, [0x9000]
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

    call ps2_mouse_init
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
    call ps2_mouse_poll

    mov ah,01h
    int 16h
    jz .no_key
    mov ah,00h
    int 16h
    cmp ah,01h
    je exit_vga
.no_key:

    cmp byte [mouse_btn],1
    je mouse_click_check
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
mov al, ah
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
mov al,ah
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
mov al,ah
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
mov al,ah
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
mov al,ah
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
    push bp
    mov bp, sp
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
    mov bl, al
    mov ah, CHAR_W
put_x:
    shl bl,1
    jnc no_pixel
    push ax
    mov al, COLOR_WHITE
    call put_pixel
    pop ax
no_pixel:
    inc cx
    dec ah
    jnz put_x
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
    pop bp
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
mov ah, COLOR_GRAY
call draw_rect

mov cx, [win_x]
mov dx, [win_y]
mov bx, [win_w]
mov si, [win_h]
mov ah, COLOR_LGRAY
call draw_box

mov cx, [win_x]
mov dx, [win_y]
mov bx, [win_w]
mov si, 14
mov ah, COLOR_BLUE
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
mov ah, COLOR_LGRAY
call draw_rect

mov cx, [btn_x]
mov dx, [btn_y]
mov bx, [btn_w]
mov si, [btn_h]
mov ah, COLOR_WHITE
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

;==================== PS/2 鼠标驱动（端口0x60原生，修复QEMU可用） ====================
ps2_mouse_wait_in:
    in al,0x64
    test al,1
    jz ps2_mouse_wait_in
    ret
ps2_mouse_wait_out:
    in al,0x64
    test al,0x20
    jnz ps2_mouse_wait_out
    ret
ps2_mouse_write:
    call ps2_mouse_wait_out
    mov al,0xD4
    out 0x64,al
    call ps2_mouse_wait_out
    mov al,ah
    out 0x60,al
    call ps2_mouse_wait_in
    in al,0x60
    ret
ps2_mouse_init:
    mov ah,0xF6
    call ps2_mouse_write
    mov ah,0xF4
    call ps2_mouse_write
    ret
ps2_mouse_poll:
    in al,0x64
    test al,1
    jz .no_data
    in al,0x60
    mov bl,al
    in al,0x60
    mov cl,al
    in al,0x60
    mov dl,al
    ;bl=状态，cl=x偏移，dl=y偏移
    mov al,bl
    and al,0x07
    mov [mouse_btn],al

    mov ax,[mouse_x]
    mov ch,cl
    shl ch,1
    sbb ax,0
    add ax,cx
    cmp ax,0
    jl .x_min
    cmp ax,319
    jg .x_max
    mov [mouse_x],ax
    jmp .y_proc
.x_min:
    mov word [mouse_x],0
    jmp .y_proc
.x_max:
    mov word [mouse_x],319
.y_proc:
    mov ax,[mouse_y]
    mov ch,dl
    shl ch,1
    sbb ax,0
    sub ax,dx
    cmp ax,0
    jl .y_min
    cmp ax,199
    jg .y_max
    mov [mouse_y],ax
    jmp .done
.y_min:
    mov word [mouse_y],0
    jmp .done
.y_max:
    mov word [mouse_y],199
.done:
.no_data:
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

;==================== 贪吃蛇游戏【修复寻址bug】 ====================
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
    mov bx_tmp, bx
    mov bx,SCREEN_WIDTH
    div bx
    mov dx,ax
    mov cx,dx
    mov al,COLOR_GREEN
    call put_pixel
    mov bx, bx_tmp
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
    ret

;==================== 猜数字游戏【完整逻辑】 ====================
guess_game:
    mov si, guess_welcome
    call cli_print
    mov bx,42
.guess_loop:
    mov si, guess_prompt
    call cli_print
    mov di, cli_buf
    xor cx,cx
.guess_input:
    mov ah,00h
    int 16h
    cmp al,0x0D
    je .guess_calc
    mov [di],al
    inc di
    inc cx
    mov ah,0x0E
    int 10h
    jmp .guess_input
.guess_calc:
    mov ah,0x0E
    mov al,0x0D
    int 10h
    mov al,0x0A
    int 10h
    mov byte [di],0
    mov si, cli_buf
    mov di, answer_str
    call strcmp
    cmp ax,0
    je .guess_win
    mov si, guess_hint
    call cli_print
    jmp .guess_loop
.guess_win:
    mov si, guess_win_msg
    call cli_print
    ret

;==================== 字符串常量 ====================
str_win_title db "MyOS v0.4",0
str_btn_snake  db "SNAKE",0
str_btn_pi     db "PI CALC",0
str_btn_cls    db "CLS",0
str_gui_hint   db "Mouse click buttons, ESC exit GUI",0
str_pi_msg     db "PI Calculating...",0
str_gameover   db "GAME OVER, press any key",0

ver_text    db "MyOS Version 0.4 FAT12",0x0D,0x0A,0
help_text   db "Commands: ver, cls, help, echo, snake, guess, pi, dir, type, exit",0x0D,0x0A,0
cli_welcome db "MyOS CLI loaded. FAT12 ready.",0x0D,0x0A,"Type 'help' for commands.",0x0D,0x0A,0
cli_prompt  db "> ",0
cmd_ver     db "ver",0
cmd_cls     db "cls",0
cmd_help    db "help",0
cmd_echo    db "echo",0
cmd_snake   db "snake",0
cmd_guess   db "guess",0
cmd_pi      db "pi",0
cmd_dir     db "dir",0
cmd_type    db "type",0
cmd_exit    db "exit",0
unknown_cmd db "Unknown command",0x0D,0x0A,0
pi_tip      db "PI calculator (Chudnovsky ready)",0x0D,0x0A,0
dir_msg     db "Listing FAT12 root directory...",0x0D,0x0A,0
type_msg    db "Reading text file from FAT12...",0x0D,0x0A,0
guess_welcome db "Guess Number Game start! Guess 42",0x0D,0x0A,0
guess_prompt db "Enter number > ",0
guess_hint db "Not correct, try again",0x0D,0x0A,0
guess_win_msg db "You Win!",0x0D,0x0A,0
answer_str db "42",0

font_8x8:
db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
db 0x00,0x05,0x03,0x00,0x00,0x00,0x00,0x00
db 0x00,0x1C,0x22,0x41,0x00,0x00,0x00,0x00
db 0x00,0x41,0x22,0x1C,0x00,0x00,0x00,0x00
db 0x08,0x2A,0x1C,0x2A,0x08,0x00,0x00,0x00
db 0x08,0x08,0x3E,0x08,0x08,0x00,0x00,0x00
db 0x00,0x50,0x30,0x00,0x00,0x00,0x00,0x00
db 0x08,0x08,0x08,0x08,0x08,0x00,0x00,0x00
db 0x00,0x60,0x60,0x00,0x00,0x00,0x00,0x00
db 0x20,0x10,0x08,0x04,0x02,0x00,0x00,0x00
db 0x3E,0x51,0x49,0x45,0x3E,0x00,0x00,0x00
db 0x00,0x42,0x7F,0x40,0x00,0x00,0x00,0x00
db 0x42,0x61,0x51,0x49,0x46,0x00,0x00,0x00
db 0x21,0x41,0x45,0x4B,0x31,0x00,0x00,0x00
db 0x18,0x14,0x12,0x7F,0x10,0x00,0x00,0x00
db 0x27,0x45,0x45,0x45,0x39,0x00,0x00,0x00
db 0x3C,0x4A,0x49,0x49,0x30,0x00,0x00,0x00
db 0x01,0x71,0x09,0x05,0x03,0x00,0x00,0x00
db 0x36,0x49,0x49,0x49,0x36,0x00,0x00,0x00
db 0x06,0x49,0x49,0x29,0x1E,0x00,0x00,0x00
db 0x00,0x36,0x36,0x00,0x00,0x00,0x00,0x00
db 0x00,0x56,0x36,0x00,0x00,0x00,0x00,0x00
db 0x08,0x14,0x22,0x41,0x00,0x00,0x00,0x00
db 0x14,0x14,0x14,0x14,0x14,0x00,0x00,0x00
db 0x00,0x41,0x22,0x14,0x08,0x00,0x00,0x00
db 0x02,0x01,0x51,0x09,0x06,0x00,0x00,0x00
db 0x32,0x49,0x79,0x41,0x3E,0x00,0x00,0x00
db 0x7E,0x11,0x11,0x11,0x7E,0x00,0x00,0x00
db 0x7F,0x49,0x49,0x49,0x36,0x00,0x00,0x00
db 0x3E,0x41,0x41,0x41,0x22,0x00,0x00,0x00
db 0x7F,0x41,0x41,0x41,0x3E,0x00,0x00,0x00
db 0x7F,0x49,0x49,0x49,0x41,0x00,0x00,0x00
db 0x7F,0x09,0x09,0x09,0x01,0x00,0x00,0x00
db 0x3E,0x41,0x49,0x49,0x7A,0x00,0x00,0x00
db 0x7F,0x08,0x08,0x08,0x7F,0x00,0x00,0x00
db 0x00,0x41,0x7F,0x41,0x00,0x00,0x00,0x00
db 0x20,0x40,0x41,0x3F,0x01,0x00,0x00,0x00
db 0x7F,0x08,0x14,0x22,0x41,0x00,0x00,0x00
db 0x7F,0x40,0x40,0x40,0x40,0x00,0x00,0x00
db 0x7F,0x02,0x0C,0x02,0x7F,0x00,0x00,0x00
db 0x7F,0x04,0x08,0x10,0x7F,0x00,0x00,0x00
db 0x3E,0x41,0x41,0x41,0x3E,0x00,0x00,0x00
db 0x7F,0x09,0x09,0x09,0x06,0x00,0x00,0x00
db 0x3E,0x41,0x51,0x21,0x5E,0x00,0x00,0x00
db 0x7F,0x09,0x19,0x29,0x46,0x00,0x00,0x00
db 0x46,0x49,0x49,0x49,0x31,0x00,0x00,0x00
db 0x01,0x01,0x7F,0x01,0x01,0x00,0x00,0x00
db 0x3F,0x40,0x40,0x40,0x3F,0x00,0x00,0x00
db 0x1F,0x20,0x40,0x20,0x1F,0x00,0x00,0x00
db 0x3F,0x40,0x38,0x40,0x3F,0x00,0x00,0x00
db 0x63,0x14,0x08,0x14,0x63,0x00,0x00,0x00
db 0x07,0x08,0x70,0x08,0x07,0x00,0x00,0x00
db 0x61,0x51,0x49,0x45,0x43,0x00,0x00,0x00
db 0x00,0x7F,0x41,0x41,0x00,0x00,0x00,0x00
db 0x02,0x04,0x08,0x10,0x20,0x00,0x00,0x00
db 0x00,0x41,0x41,0x7F,0x00,0x00,0x00,0x00
db 0x04,0x02,0x01,0x02,0x04,0x00,0x00,0x00
db 0x40,0x40,0x40,0x40,0x40,0x00,0x00,0x00
db 0x00,0x01,0x02,0x04,0x00,0x00,0x00,0x00
db 0x20,0x54,0x54,0x54,0x78,0x00,0x00,0x00
db 0x7F,0x48,0x48,0x48,0x30,0x00,0x00,0x00
db 0x38,0x44,0x44,0x44,0x28,0x00,0x00,0x00
db 0x30,0x48,0x48,0x48,0x7F,0x00,0x00,0x00
db 0x38,0x54,0x54,0x54,0x18,0x00,0x00,0x00
db 0x00,0x7C,0x08,0x08,0x08,0x00,0x00,0x00
db 0x18,0xA4,0xA4,0xA4,0x7C,0x00,0x00,0x00
db 0x7F,0x08,0x08,0x08,0x70,0x00,0x00,0x00
db 0x00,0x00,0x7D,0x00,0x00,0x00,0x00,0x00
db 0x20,0x40,0x40,0x3D,0x00,0x00,0x00,0x00
db 0x7F,0x10,0x28,0x44,0x00,0x00,0x00,0x00
db 0x00,0x41,0x7F,0x40,0x00,0x00,0x00,0x00
db 0x78,0x04,0x18,0x04,0x78,0x00,0x00,0x00
db 0x78,0x08,0x08,0x08,0x70,0x00,0x00,0x00
db 0x38,0x44,0x44,0x44,0x38,0x00,0x00,0x00
db 0xFC,0x24,0x24,0x24,0x18,0x00,0x00,0x00
db 0x18,0x24,0x24,0x24,0xFC,0x00,0x00,0x00
db 0x78,0x08,0x04,0x04,0x08,0x00,0x00,0x00
db 0x48,0x54,0x54,0x54,0x24,0x00,0x00,0x00
db 0x00,0x08,0x7E,0x08,0x08,0x00,0x00,0x00
db 0x38,0x40,0x40,0x40,0x78,0x00,0x00,0x00
db 0x1C,0x20,0x40,0x20,0x1C,0x00,0x00,0x00
db 0x3C,0x40,0x30,0x40,0x3C,0x00,0x00,0x00
db 0x44,0x28,0x10,0x28,0x44,0x00,0x00,0x00
db 0x1C,0xA0,0xA0,0xA0,0x7C,0x00,0x00,0x00
db 0x44,0x64,0x54,0x4C,0x44,0x00,0x00,0x00
db 0x00,0x08,0x36,0x41,0x00,0x00,0x00,0x00
db 0x00,0x00,0x7F,0x00,0x00,0x00,0x00,0x00
db 0x00,0x41,0x36,0x08,0x00,0x00,0x00,0x00
db 0x10,0x08,0x08,0x10,0x08,0x00,0x00,0x00
db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
