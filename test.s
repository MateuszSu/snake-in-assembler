#
# Defines
#
BOARD_HEIGHT = 25
BOARD_WIDTH  = 50

DELTA_TIME = 150000 # us

#
# Direction->key map
#
NONE  = 0
LEFT  = 'a'
RIGHT = 'd'
UP    = 'w'
DOWN  = 's'

.data

#
# buffers
#
board_buffer:
    .fill BOARD_WIDTH, 1, ' '
board_buffer_up_down:
    .fill BOARD_WIDTH, 1, '_'

snake_directions:
    .fill BOARD_WIDTH * BOARD_HEIGHT, 1, NONE

#
# Strings
#
snake_element_str:
    .asciz "x"

snake_str:
    .asciz " "

fruit_str:
    .asciz "o"

move_cursor_format:
    .asciz "\033[%d;%dH"

clear_screen_format:
    .asciz "\033[H\033[2J"

points_format:
    .asciz "Punkty: %d"

#
# Snake variables
#
head_x:
    .long 10
head_y:
    .long 10

tail_x:         # Values not important
    .long 0     # Will be calculated in runtime
tail_y:         #
    .long 0     #

fruit_x:
    .long 3
fruit_y:
    .long 10

points:
    .long 0


.bss
#
# Structure to control console modes
#
termios:
    .lcomm c_iflag 4    # input mode flags
    .lcomm c_oflag 4    # output mode flags
    .lcomm c_cflag 4    # control mode flags
    .lcomm c_lflag 4    # local mode flags
    .lcomm c_line  1    # line discipline
    .lcomm c_cc    19   # control characters

.lcomm current_key 1
.lcomm last_key    1

.globl main
.text

main:
    pushq %rbp
    movq  %rsp, %rbp

    call initialize
    pushq %rax

    movl head_x, %edi
    movl head_y, %esi
    call move_cursor

    call get_starting_direction
    movb %al, (current_key)
    movb %al, (last_key)

    call print_fruit
main_loop:
    call get_current_key
    movb (current_key), %dil
    call is_valid_key
    cmpb $0, %al
    jne current_key_valid

current_key_invalid:
    movb (last_key), %al
    movb %al, (current_key)
    jmp direction_check

current_key_valid:
    movb (current_key), %al
    movb %al, (last_key)

direction_check:
    call move_snake

    cmpb $LEFT, (current_key)
    je   left
    cmpb $RIGHT, (current_key)
    je   right
    cmpb $UP, (current_key)
    je   up

down:
    add $1, (head_y)
    movb $UP, (snake_directions)
    jmp next

up:
    sub $1, (head_y)
    movb $DOWN, (snake_directions)
    jmp next

right:
    add $1, (head_x)
    movb $LEFT, (snake_directions)
    jmp next

left:
    sub $1, (head_x)
    movb $RIGHT, (snake_directions)

next:
    call print_head
    call check_fruit
    call print_points
    call check_collision
    cmpb $1, %al
    je end_game

    pushq %rbp              # Wait for DELTA_TIME microseconds
    movq %rsp, %rbp         #
    movq $DELTA_TIME, %rdi  #
    call usleep             #
    movq %rbp, %rsp         #
    popq %rbp               #

    jmp main_loop

end_game:
    popq (c_lflag)
    movl $16, %eax      # syscall: SYS_ioctl
    xor  %edi, %edi     # fd: STDIN_FILENO
    movl $0x5402, %esi  # TCSETS
    movq $termios, %rdx # data
    syscall

    movl $0, %edi
    movl $BOARD_HEIGHT + 2, %esi
    call move_cursor

    leave
    ret

#
# Initialization of buffers and console
# return: c_lflag before initialization
#
initialize:
    pushq %rbp
    movq  %rsp, %rbp

    call prepare_board_buffer
    call prepare_snake
    call clear_screen
    call print_buffer
    call print_snake_first


    movl $16, %eax      # syscall: SYS_ioctl
    xor  %edi, %edi     # fd: STDIN_FILENO
    movl $0x5401, %esi  # TCGETS
    movq $termios, %rdx # data
    syscall

    pushq (c_lflag)

    andb $0b11110101, (c_lflag) # clear ICANON and ECHO

    movl $16, %eax      # syscall: SYS_ioctl
    xor  %edi, %edi     # fd: STDIN_FILENO
    movl $0x5402, %esi  # TCSETS
    movq $termios, %rdx # data
    syscall

    popq %rax

    leave
    ret

#
# Fill board buffer with initial values
#
prepare_board_buffer:
    movb $'|', (board_buffer)
    movb $'|', (board_buffer + BOARD_WIDTH - 3)
    movb $'\n', (board_buffer + BOARD_WIDTH - 2)
    movb $0, (board_buffer + BOARD_WIDTH - 1)

    movb $'\n', (board_buffer_up_down + BOARD_WIDTH - 2)
    movb $0, (board_buffer_up_down + BOARD_WIDTH - 1)

    ret

#
# Fill snake directions with initial values
#
prepare_snake:
    movb $RIGHT, (snake_directions)
    movb $RIGHT, (snake_directions + 1)
    movb $RIGHT, (snake_directions + 2)
    movb $RIGHT, (snake_directions + 3)

    ret

#
# Prints board_buffer to standard output
#
print_buffer:
    movq $board_buffer_up_down, %rdi
    xor  %eax, %eax

    call printf
    movq $BOARD_HEIGHT, %rbx
    subq $2, %rbx

print_buffer_loop:
    movq $board_buffer, %rdi
    xor  %eax, %eax

    call printf

    dec  %rbx
    cmpq $0, %rbx
    jne print_buffer_loop

    movq $board_buffer_up_down, %rdi
    xor  %eax, %eax

    call printf

    ret

#
# Print entire snake with hardcoded initial state
#
print_snake_first:
    pushq   %rbp
    movq    %rsp, %rbp

    pushq head_x
    pushq head_y

    movl head_x, %edi
    movl head_y, %esi

    call move_cursor

    movq $snake_element_str, %rdi
    xor  %eax, %eax
    call printf

    movq $snake_directions, %rbx

print_snake_first_loop:
    popq %rsi
    popq %rdi

    inc %rdi
    movl %esi, (tail_y)
    movl %edi, (tail_x)

    pushq %rdi
    pushq %rsi

    call move_cursor
    movq $snake_element_str, %rdi
    xor  %eax, %eax
    call printf

    inc %rbx
    cmpb $NONE, (%rbx)

    jne print_snake_first_loop

    leave
    ret

#
# Print head of snake
#
print_head:
    movl head_x, %edi
    movl head_y, %esi

    call move_cursor

    movq $snake_element_str, %rdi
    xor  %eax, %eax
    call printf
    call flush_stdout

    ret

#
# Fill tail of snake with space
#
erase_tail:
    movl tail_x, %edi
    movl tail_y, %esi

    call move_cursor

    movq $snake_str, %rdi
    xor  %eax, %eax
    call printf
    call flush_stdout

    ret

#
# Checks if snake ate a fruit and if so
# enlarge the snake and generate new fruit
#
check_fruit:
    movl fruit_x, %eax
    movl fruit_y, %ebx

    cmpl %eax, head_x
    jne check_fruit_not_equal
    cmpl %ebx, head_y
    jne check_fruit_not_equal

    addl $1, (points)
    call enlarge_snake

    call generate_fruit_coords
    call print_fruit

check_fruit_not_equal:
    ret

print_fruit:
    movl fruit_x, %edi
    movl fruit_y, %esi

    call move_cursor

    movq $fruit_str, %rdi
    xor  %eax, %eax
    call printf
    call flush_stdout

    ret

#
# Generates new cooridanated for a fruit and saves them to fruit_x and fruit_y
#
generate_fruit_coords:
    call generate_random
    movl $BOARD_WIDTH, %esi
    sub  $4, %esi
    movl $2, %r8d
    cltd
    idivl %esi
    leal (%rdx,%r8), %eax
    movl %eax, fruit_x

    call generate_random
    movl %edx, %eax
    movl $BOARD_HEIGHT, %esi
    sub  $2, %esi
    movl $2, %r8d
    cltd
    idivl %esi
    leal (%rdx,%r8), %eax
    movl %eax, fruit_y

    movl fruit_x, %edi
    movl fruit_y, %esi
    cmpl %edi, head_x
    jne is_in_snake_check
    cmpl %esi, head_y
    je generate_fruit_coords

is_in_snake_check:
    call is_in_snake
    cmpb $1, %al
    je generate_fruit_coords

    ret

#
# Generarates random 32-bit random number
#
# return: random 32-bit number
#
generate_random:
    rdtscp
    movl %edx, %edi
    imull $1103515245, %edi, %edi
    addl  $12345, %edi
    imull $1103515245, %edi, %eax
    shrl  $6, %edi
    andl  $2096128, %edi
    addl  $12345, %eax
    movl  %eax, %edx
    imull $1103515245, %eax, %eax
    shrl  $16, %edx
    andl  $1023, %edx
    addl  $12345, %eax
    orl   %edx, %edi
    shrl  $16, %eax
    sall  $10, %edi
    andl  $1023, %eax
    xorl  %edi, %eax
    ret

#
# Checks if snake colided with walls or with itself
#
# return: 0 if snake did not colide, 1 if it colided
#
check_collision:
    call check_walls
    cmpb $1, %al
    je check_collision_end

    movl head_x, %edi
    movl head_y, %esi
    call is_in_snake
check_collision_end:
    ret

#
# Checks if snake colided with walls
#
# return: 0 if snake did not colide, 1 if it colided
#
check_walls:
    cmpl $1, head_x
    je check_walls_true
    movl $BOARD_WIDTH, %ebx
    sub $2, %ebx
    cmpl %ebx, head_x
    je check_walls_true

    cmpl $1, head_y
    je check_walls_true
    movl $BOARD_HEIGHT, %ebx
    sub $0, %ebx
    cmpl %ebx, head_y
    je check_walls_true
check_walls_false:
    xor %eax, %eax
    jmp check_collision_end
check_walls_true:
    movl $1, %eax
check_walls_end:
    ret


#
# Enlarges snake by 1 segment
#
enlarge_snake:
    movq $snake_directions, %rax
    movb (%rax), %bl

enlarge_snake_loop:
    inc %rax

    cmpb $NONE, (%rax)
    je enlarge_snake_end

    movb (%rax), %bl

    jmp enlarge_snake_loop

enlarge_snake_end:
    movb %bl, (%rax)

    cmpb $LEFT, %bl
    je   enlarge_snake_left
    cmpb $RIGHT, %bl
    je   enlarge_snake_right
    cmpb $UP, %bl
    je   enlarge_snake_up

enlarge_snake_down:
    add $1, (tail_y)
    jmp enlarge_snake_end_end

enlarge_snake_up:
    sub $1, (tail_y)
    jmp enlarge_snake_end_end

enlarge_snake_right:
    add $1, (tail_x)
    jmp enlarge_snake_end_end

enlarge_snake_left:
    sub $1, (tail_x)

enlarge_snake_end_end:
    ret


#
# Checks if coordinates are contained in snake segments
#
# argument1: x coordinate
# argument2: y coordinate
# return: 1 if they are contained, 0 if not
#
is_in_snake:
    movq $snake_directions, %rax
    movl (head_x), %ecx
    movl (head_y), %ebx

is_in_snake_loop:
    cmpq $snake_directions, %rax
    je is_in_snake_loop_ok

    cmpl %ecx, %edi
    jne is_in_snake_loop_ok
    cmpl %ebx, %esi
    je is_in_snake_true

is_in_snake_loop_ok:
    cmpb $NONE, (%rax)
    je is_in_snake_false

    cmpb $LEFT, (%rax)
    je   is_in_snake_left
    cmpb $RIGHT, (%rax)
    je   is_in_snake_right
    cmpb $UP, (%rax)
    je   is_in_snake_up

is_in_snake_down:
    inc %ebx
    jmp is_in_snake_continue

is_in_snake_up:
    dec %ebx
    jmp is_in_snake_continue

is_in_snake_right:
    inc %ecx
    jmp is_in_snake_continue

is_in_snake_left:
    dec %ecx

is_in_snake_continue:
    inc %rax
    jmp is_in_snake_loop
is_in_snake_true:
    movq $1, %rax
    jmp is_in_snake_end
is_in_snake_false:
    xor %eax, %eax
is_in_snake_end:
    ret


#
# Shift right all snake segments except the last which is not NONE
# and calculate new tail coordinates
#
move_snake:
    pushq %rbp
    movq  %rsp, %rbp

    movq $snake_directions, %rax
    movb (%rax), %bl

    movb %bl, %dil      # %dil is value of the last segment before move

move_snake_loop:
    inc %rax
    xchg %bl, %dl       # move before current segment to last segment
    movb (%rax), %bl    # %bl is current segment

    cmpb $NONE, %bl
    je move_snake_end
    movb %bl, %dil

    movb %dl, (%rax)    # %dl is last segment


    jmp move_snake_loop

move_snake_end:
    pushq %rdi
    call erase_tail
    popq %rdi

    cmpb $LEFT, %dil
    je   move_snake_left
    cmpb $RIGHT, %dil
    je   move_snake_right
    cmpb $UP, %dil
    je   move_snake_up

move_snake_down:
    sub $1, (tail_y)
    jmp move_snake_end_end

move_snake_up:
    add $1, (tail_y)
    jmp move_snake_end_end

move_snake_right:
    sub $1, (tail_x)
    jmp move_snake_end_end

move_snake_left:
    add $1, (tail_x)

move_snake_end_end:
    leave
    ret

#
# Print number of points that player has
#
print_points:
    movl $0, %edi
    movl $BOARD_HEIGHT + 1, %esi
    call move_cursor

    movq $points_format, %rdi
    movl (points), %esi
    xor  %eax, %eax

    call printf
    call flush_stdout
    ret


#
# Waits until player presses valid direction key
#
# returns: first valid direction key
#
get_starting_direction:
    call getchar
    cmpb $RIGHT, %al
    je get_starting_direction
    movb %al, %dil
    call is_valid_key
    cmpb $0, %al
    je get_starting_direction

    movb %dil, %al
    ret

#
# Check if key is 'a' or 'd' or 'w' or 's
#
# argument1: character
# return: 1 if key is one of above or 0 if not
#
is_valid_key:
    cmpb $LEFT, %dil
    je is_valid_key_true
    cmpb $RIGHT, %dil
    je is_valid_key_true
    cmpb $UP, %dil
    je is_valid_key_true
    cmpb $DOWN, %dil
    je is_valid_key_true
    xor %eax, %eax
    ret

is_valid_key_true:
    movq $1, %rax
    ret

#
# If there exist keys in keyboard board_buffer, move last to current_key
#
get_current_key:
    call khbit
    cmpq $0, %rax
    je get_current_key_end
    call getchar

    movb %al, (current_key)

get_current_key_end:
    ret


#
# Utilities
#

#
# Calculate number of characters in keyboard buffer
# return: number of characters in keyboard buffer
#
khbit:
    pushq   %rbp
    movq    %rsp, %rbp

    subq $4, %rsp
    leaq -4(%rbp), %rax
    movq %rax, %rdx
    movl $21531, %esi
    xor  %edi, %edi
    xor  %eax, %eax
    call ioctl
    movl -4(%rbp), %eax

    leave
    ret

#
# Flush standard output stream
#
flush_stdout:
    movq    stdout(%rip), %rax
    movq    %rax, %rdi
    call    fflush
    ret

#
# Clears whole screen
#
clear_screen:
    movq $clear_screen_format, %rdi
    xor  %eax, %eax

    call printf
    call flush_stdout
    ret

#
# Moves cursor to (x, y)
#
# argument 1: x coordinate
# argument 2: y coordinate
#
move_cursor:
    movl %edi, %edx
    movq $move_cursor_format, %rdi
    xor  %eax, %eax

    call printf
    call flush_stdout
    ret
