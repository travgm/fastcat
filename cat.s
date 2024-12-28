#------------------------------------------------------------------------------
# cat.s - A minimal fast cat
#
# Author: Travis Montoya (trav@hexproof.sh)
# The do whatever you like with this file license
#------------------------------------------------------------------------------
.set STDOUT,      1
.set O_RDONLY,    0

.set __NR_read,   0
.set __NR_write,  1
.set __NR_open,   2
.set __NR_close,  3
.set __NR_exit,   60

.set READ_BUFFER, 2048
    
    .section .data

error_msg:
    .asciz "no input file specified\n"
invalid_argv:
    .asciz "specify a single input file\n"

.align 8
in_buffer:
    .space READ_BUFFER + 1, 0x0

    .globl _start
    .section .text

_start:
    mov  (%rsp), %rbx
    cmp  $2, %rbx
    jne  .L_invalid_argv

    xor  %rdi, %rdi
    mov  16(%rsp), %rdi
    mov  $O_RDONLY, %rsi
    xor  %rdx, %rdx
    mov  $__NR_open, %rax
    syscall
    cmp  $0, %rax
    je   .L_open_error

    mov  %rax, %r12
read_loop:
    mov  %r12, %rdi
    lea  in_buffer, %rsi
    mov  $READ_BUFFER, %rdx
    mov  $__NR_read, %rax
    syscall

    test  %rax, %rax
    jle  .L_program_exit

    mov  %rax, %rcx
    movb $0, in_buffer(%rcx)
    lea  in_buffer, %rdi
    call print_str

    jmp  read_loop
.L_invalid_argv:
    lea  invalid_argv, %rdi
    call print_str
    jmp  .L_program_exit
.L_open_error:
    lea  error_msg, %rdi
    call print_str
.L_program_exit:
    xor  %rdi, %rdi
    mov  $__NR_exit, %rax
    syscall

print_str:
    # Print a string to STDOUT = 1
    # %rdi holds the address of the string
    #
    # We need to find the length of the string first and then print using
    # syscall __NR_write (sys_write) 
    push   %rcx
    push   %rax
    push   %rdx

    xor    %rcx, %rcx
.L_strlen:
    movb   (%rdi, %rcx), %al
    test   %al, %al
    jz     .L_write
    inc    %rcx
    jmp    .L_strlen
.L_write:
    # At this point %rcx holds the length of the null terminated string
    mov    %rcx, %rdx
    mov    %rdi, %rsi
    mov    $STDOUT, %rdi
    mov    $__NR_write, %rax
    syscall

    pop    %rdx
    pop    %rax
    pop    %rcx
    ret
