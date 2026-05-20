.global main

.section .data
	msg_op1:	.asciz "Type the first operand:\n"
	msg_opt:	.asciz "Type the operator (+, -, *, /, ^, r):\n"
	msg_op2:	.asciz "Type the second operand:\n"
	msg_cont:	.asciz "Continue? (y/n)"

	fmt_opn_in:		.asciz "%lf"
	fmt_char_in:	.asciz " %c"
	fmt_result: 	.asciz "-> %g\n"

	msg_div_zero:	.asciz "Error: Division by zero not allowed\n"
    msg_neg_sqrt:   .asciz  "Error: Negative squre root not allowed\n"

    const_one:      .double 1.0

.section .bss
	.comm	op1,	8
	.comm	op2,	8
	.comm	opt,	1

.section .text
// ========== OPERATIONS ========== //
op_sum:
    push %rbp
    mov %rsp, %rbp
    addsd %xmm1, %xmm0
	mov %rbp, %rsp
    pop %rbp
    ret

op_subtraction:
    push %rbp
    mov %rsp, %rbp
    subsd %xmm1, %xmm0
	mov %rbp, %rsp
    pop %rbp
    ret

op_mult:
    push %rbp
    mov %rsp, %rbp
    mulsd %xmm1, %xmm0
	mov %rbp, %rsp
    pop %rbp
    ret

op_div:
    push %rbp
    mov %rsp, %rbp

	// Verifies division by zero
    xorpd %xmm2, %xmm2
    ucomisd %xmm2, %xmm1
    jne .div_allowed

    lea msg_div_zero(%rip), %rdi
    xor %rax, %rax
    call printf
    xor %rax, %rax
    jmp .div_finish

	.div_allowed:
		divsd %xmm1, %xmm0
		mov $1, %rax

	.div_finish:
		mov %rbp, %rsp
		pop %rbp
		ret

op_pow:
    push %rbp
    mov %rsp, %rbp

    # Converts exponent to integer
    cvttsd2si %xmm1, %rcx

    movsd const_one(%rip), %xmm1
    test %rcx, %rcx
    jz .pow_finish

.pow_loop:
    mulsd %xmm0, %xmm1
    dec %rcx
    jnz .pow_loop

.pow_finish:
    movsd %xmm1, %xmm0

    pop %rbp
    ret

op_sqrt:
    push %rbp
    mov %rsp, %rbp

	// Verifies negative square root
    xorpd %xmm1, %xmm1
    ucomisd %xmm0, %xmm1
    jbe .sqrt_allowed

    lea msg_neg_sqrt(%rip), %rdi
    xor %rax, %rax
    call printf
    xor %rax, %rax
    jmp .sqrt_finish

	.sqrt_allowed:
		sqrtsd  %xmm0, %xmm0
		mov     $1, %rax

	.sqrt_finish:
		pop     %rbp
		ret

// ========== MAIN FUNCTIONS ========== //
show_result:
    push %rbp
    mov %rsp, %rbp
    lea fmt_result(%rip), %rdi
	call printf
	mov %rbp, %rsp
	pop %rbp
	ret

// Asks for the 2nd operand
read_op2:
	push %rbp
	mov %rsp, %rbp

	lea msg_op2(%rip), %rdi
	xor %rax, %rax
	call printf

	lea fmt_opn_in(%rip), %rdi
	lea op2(%rip), %rsi
	xor %rax, %rax
	call scanf

	mov %rbp, %rsp
	pop %rbp
	ret

main:
	sub $8, %rsp

.main_loop:

	// Asks for the 1st operand
	lea msg_op1(%rip), %rdi
	xor %rax, %rax
	call printf

	lea fmt_opn_in(%rip), %rdi
	lea op1(%rip), %rsi
	xor %rax, %rax
	call scanf

	// Asks for the operator
	lea msg_opt(%rip), %rdi
	xor %rax, %rax
	call printf

	lea fmt_char_in(%rip), %rdi
	lea opt(%rip), %rsi
	xor %rax, %rax
	call scanf

	mov opt(%rip), %eax

	// Comparations
	cmpb $'+', %al
	je .case_sum
	cmpb $'-', %al
	je .case_subtraction
	cmpb $'*', %al
	je .case_multplication
	cmpb $'/', %al
	je .case_division
	cmpb $'^', %al
	je .case_pow
	cmpb $'r', %al
	je .case_sqrt

# Asks if the user wants to repeat or finish
.main_repeat:
    lea msg_cont(%rip), %rdi
    xor %rax, %rax
    call printf

    lea fmt_char_in(%rip), %rdi
    lea opt(%rip), %rsi
    xor %rax, %rax
    call scanf

	mov opt(%rip), %eax
    cmpb $'y', %al
    je .main_loop

	add $8, %rsp
	xor %rax, %rax
	ret

// ========== CASES ========== //
.case_sum:
	call read_op2
    movsd op1(%rip), %xmm0
    movsd op2(%rip), %xmm1
    call op_sum
    call show_result
    jmp .main_repeat

.case_subtraction:
	call read_op2
    movsd op1(%rip), %xmm0
    movsd op2(%rip), %xmm1
    call op_subtraction
    call show_result
    jmp .main_repeat

.case_multplication:
    call read_op2
    movsd op1(%rip), %xmm0
    movsd op2(%rip), %xmm1
    call op_mult
    call show_result
    jmp .main_repeat

.case_division:
    call read_op2
    movsd op1(%rip), %xmm0
    movsd op2(%rip), %xmm1
    call op_div
    test %rax, %rax
    jz .main_repeat
    call show_result
    jmp .main_repeat

.case_pow:
    call    read_op2
    movsd   op1(%rip), %xmm0
    movsd   op2(%rip), %xmm1
    call    op_pow
    call    show_result
    jmp     .main_repeat

.case_sqrt:
    movsd   op1(%rip), %xmm0
    call    op_sqrt
    test    %rax, %rax
    jz      .main_repeat
    call    show_result
    jmp     .main_repeat
