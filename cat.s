#------------------------------------------------------------------------------
# cat.s - A minimal fast cat
#
# Author: Travis Montoya (trav@hexproof.sh)
# The do whatever you like with this file license
#------------------------------------------------------------------------------
.title            "cat.s"
.version          "1"

# ------------ Constants ------------
.set STDOUT,      1
.set O_RDONLY,    0

.set __NR_read,   0
.set __NR_write,  1
.set __NR_open,   2
.set __NR_close,  3
.set __NR_exit,   60

# Arbitary amount set for reading in the line
.set READ_BUFFER, 2048
    
# ------------ Initialized data ------------
    .section .data

error_msg:
    .asciz "no input file specified\n"
invalid_argv:
    .asciz "specify a single input file\n"

.align 8
in_buffer:
    # Line amount + 1 for null terminator
    .space READ_BUFFER + 1, 0x0

# ------------ Text ------------
    .globl _start
    .section .text

_start:
    # %rsp on entry holds argc. Check that we have at least a single argument
    # which needs to be a file name
    mov  (%rsp), %rbx
    cmp  $2, %rbx                      # We compare to 2 because, argv[0] = program name, argv[1] = first argument
    jne  .L_invalid_argv

    # attempt to open argv[1]
    xor  %rdi, %rdi
    mov  16(%rsp), %rdi
    mov  $O_RDONLY, %rsi
    xor  %rdx, %rdx
    mov  $__NR_open, %rax
    syscall
    test  %rax, %rax
    js   .L_open_error

    mov  %rax, %r12

    # Loop each line of the file and print it to STDOUT
    # %r12 holds handle to the file
1:
    mov  %r12, %rdi
    lea  in_buffer, %rsi
    mov  $READ_BUFFER, %rdx
    mov  $__NR_read, %rax
    syscall

    # %rax contains the number of bytes read, 0 indicates EOF
    test  %rax, %rax
    jle  .L_program_exit

    # NULL terminate buffer and print to STDOUT
    mov  %rax, %rcx
    movb $0, in_buffer(%rcx)
    lea  in_buffer, %rdi
    call print_str

    jmp  1b
.L_invalid_argv:
    lea  invalid_argv, %rdi
    call print_str
    jmp  .L_program_exit
.L_open_error:
    lea  error_msg, %rdi
    call print_str
.L_program_exit:
    test %rdi, %rdi
    js   .L_exit
    mov %r12, %rdi
    mov $__NR_close, %rax
    syscall
.L_exit:
    xor  %rdi, %rdi
    mov  $__NR_exit, %rax
    syscall

# ---------- Utility Functions ----------
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
