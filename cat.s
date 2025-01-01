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
.set __NR_readahead, 187 

# Arbitary amount set for reading in the line
.set READ_BUFFER, 8 * 1024 * 1024

.macro scall nr
    mov $\nr, %rax
    syscall
.endm

# ------------ Read only data ------------
    .section .rodata
    .p2align 4
error_msg:
    .asciz "error: invalid input file\n"
invalid_argv:
    .asciz "specify a single input file or none for stdin\n"

# ------------ Uninitialized data ------------
    .section .bss
    .p2align 6, 0x0
in_buffer:
    # Line amount + 1 for null terminator
    .space (8 * 1024 * 1024), 0x0 

# ------------ Text ------------
    .globl _start
    .section .text

_start:
    # Load address of our buffer into %r13 that will be used later for reading lines from
    # either standard input or a file
    lea   in_buffer, %r13

    # %rsp on entry holds argc. Check that we have at least a single argument
    # which needs to be a file name
    mov   (%rsp), %rbx
    cmp   $2, %rbx                      # We compare to 2 because, argv[0] = program name, argv[1] = first argument
    je    .L_read_file
    jg    .L_invalid_argv

    # We default the file descriptor to standard input if no arguments are given
    xor   %r12, %r12
    jmp   1f

.L_read_file:
.p2align 4
    # Attempt to open argv[1], If we are unsuccessful we display an error and quit
    mov   16(%rsp), %rdi
    mov   $O_RDONLY, %rsi
    xor   %rdx, %rdx
    scall  __NR_open
    test  %rax, %rax
    js    .L_open_error
    
    mov   %rax, %r12

    # Attempt to start loading pages from file to page cache
    mov   %r12, %rdi
    xor   %rsi, %rsi
    xor   %rdx, %rdx
    mov   $READ_BUFFER, %r10 
    scall __NR_readahead

    # Loop each line of the file and print it to STDOUT
    # %r12 holds handle to the file
    # %r13 holds the address of the buffer
1:
    prefetchnta (%r13) 
    prefetchnta 64(%r13)
    mov   %r12, %rdi
    mov   %r13, %rsi
    mov   $READ_BUFFER, %rdx
    scall __NR_read

    # %rax contains the number of bytes read, 0 indicates EOF
    test  %rax, %rax
    jle   .L_program_exit

    # NULL terminate buffer and print to STDOUT
    mov   %rax, %rcx
    movb  $0, (%r13, %rcx)
    mov   %r13, %rsi
    call  print_str

    jmp   1b
.L_invalid_argv:
    lea   invalid_argv, %rsi
    mov   $46, %rcx
    call  print_str
    jmp   .L_program_exit
.L_open_error:
    lea   error_msg, %rsi
    mov   $26, %rcx
    call  print_str
.L_program_exit:
    test  %rdi, %rdi
    js    .L_exit
    mov   %r12, %rdi
    scall __NR_close
.L_exit:
    xor   %rdi, %rdi
    scall __NR_exit

# ---------- Utility Functions ----------
print_str:
    # rcx = length of string
    # rdi = address of string
    push  %rax
    push  %rdx

    mov   %rcx, %rdx
    mov   $STDOUT, %rdi
    scall __NR_write

    pop  %rdx
    pop  %rax
    ret
