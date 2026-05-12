.global main

.section .data
	msg_op1:	.asciz "Type the first operand:\n"
	msg_opt:	.asciz "Type the operator (+, -):\n"
	msg_op2:	.asciz "Type the second operand:\n"
	msg_cont:	.asciz "Continue? (y/n)"

	fmt_opn_in:		.asciz "%lf"
	fmt_char_in:	.asciz " %c"
	fmt_result: 	.asciz "-> %g\n"

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

// TODO add more

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

