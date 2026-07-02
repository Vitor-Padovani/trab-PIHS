.global main

.section .data
	msg_op1:	.asciz "Type the first operand:\n"
	msg_opt:	.asciz "Type the operator (+, -, *, /, ^, r, !, l, a, i):\n"
	msg_op2:	.asciz "Type the second operand:\n"
	msg_cont:	.asciz "Continue? (y/n)"

	fmt_opn_in:		.asciz "%lf"
	fmt_char_in:	.asciz " %c"
	fmt_result: 	.asciz "-> %g\n"
	fmt_int_uns:	.asciz "-> %llu\n"
	
	msg_div_zero:	.asciz	"Error: Division by zero not allowed\n"
    msg_neg_sqrt:   .asciz	"Error: Negative square root not allowed\n"
	msg_neg_fat:	.asciz	"Error: Cannot do factorial of a negative number\n"
	msg_frac_fat:	.asciz	"Error: Cannot do factorial of a fractional number\n"
	msg_neg_arr:	.asciz	"Error: Cannot do permutation when one of the operands is negative\n"
	msg_frac_arr:	.asciz	"Error: Cannot do permutation when one of the operands is fractional\n"
	msg_inv_zero:	.asciz	"Error: Cannot do the inversion of zero\n"

    const_one:      .double 1.0

.section .bss
	.comm	op1,	8
	.comm	op2,	8
	.comm	opt,	1
	#.comm	teste,	10

.section .text
// ========== OPERATIONS ========== //
op_pow:
    push %rbp
    mov %rsp, %rbp

    # Converts exponent to integer
    cvttsd2si %xmm1, %rcx

    movsd const_one, %xmm1
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
    jbe sqrt_allowed

    lea msg_neg_sqrt, %rdi
    xor %rax, %rax
    call printf
    xor %rax, %rax
    jmp sqrt_finish

sqrt_allowed:
	sqrtsd	%xmm0, %xmm0
	mov		$1, %rax

sqrt_finish:
		pop     %rbp
		ret

// ========== MAIN FUNCTIONS ========== //
main:
	sub $8, %rsp

main_loop:
	// Asks for the 1st operand
	lea msg_op1, %rdi
	call printf

	lea fmt_opn_in, %rdi
	lea op1, %rsi
	call scanf

	movsd op1, %xmm0

	// Asks for the operator
	lea msg_opt, %rdi
	call printf

	lea fmt_char_in, %rdi
	lea opt, %rsi
	call scanf

	movzbq opt, %rax

	// Comparisons
	cmpb $'+', %al
	je case_sum
	cmpb $'-', %al
	je case_subtraction
	cmpb $'*', %al
	je case_multplication
	cmpb $'/', %al
	je case_division
	cmpb $'^', %al
	je case_pow
	cmpb $'r', %al
	je case_sqrt
	cmpb $'!', %al
	je case_fat	
	cmpb $'l', %al
	je	case_log
	cmpb $'a', %al
	je case_arr
	cmpb $'i', %al
	je case_inv


// Asks for the 2nd operand
read_op2:
	push %rbp
	mov %rsp, %rbp

	lea msg_op2, %rdi
	call printf

	lea fmt_opn_in, %rdi
	lea op2, %rsi
	call scanf

	mov %rbp, %rsp
	pop %rbp
	ret

show_result:
    push %rbp
    mov %rsp, %rbp

    lea fmt_result, %rdi
	call printf

	mov %rbp, %rsp
	pop %rbp
	ret

# Asks if the user wants to repeat or finish
main_repeat:
    lea msg_cont, %rdi
    call printf

    lea fmt_char_in, %rdi
    lea opt, %rsi
    call scanf

	mov opt, %rax
    cmpb $'y', %al
    je main_loop

	add $8, %rsp
	xor %rax, %rax
	ret

load_2_operands_to_xmm:
	push %rbp
	mov %rsp, %rbp

	movsd op1, %xmm0
	movsd op2, %xmm1

	mov %rbp, %rsp
	pop %rbp
	ret

verify_op1_neg:
	push %rbp
	mov %rsp, %rbp

	xorpd	%xmm2, %xmm2
	ucomisd	%xmm2, %xmm0

	mov %rbp, %rsp
	pop %rbp
	ret

verify_op2_neg:
	push	%rbp
	mov		%rsp, %rbp

	xorpd	%xmm2, %xmm2
	ucomisd	%xmm2, %xmm0

	mov %rbp, %rsp
	pop %rbp
	ret

verify_op1_frac:
	push	%rbp
	mov		%rsp, %rbp

	cvttsd2si	%xmm0, %rbx
	cvtsi2sd	%rbx, %xmm2
	ucomisd		%xmm0, %xmm2

	mov		%rbp, %rsp
	pop		%rbp
	ret

verify_op2_frac:
	push	%rbp
	mov		%rsp, %rbp

	cvttsd2si	%xmm1, %rbx
	cvtsi2sd	%rbx, %xmm2
	ucomisd		%xmm1, %xmm2

	mov		%rbp, %rsp
	pop		%rbp
	ret
// ========== CASES ========== //
case_sum:
	call read_op2
	call load_2_operands_to_xmm
    addsd %xmm1, %xmm0
    call show_result
    jmp main_repeat

case_subtraction:
	call read_op2
	call load_2_operands_to_xmm
    subsd %xmm1, %xmm0
    call show_result
    jmp main_repeat

case_multplication:
    call	read_op2
	call	load_2_operands_to_xmm
	mulsd	%xmm1, %xmm0
    call	show_result
    jmp		main_repeat

case_division:
    call	read_op2
	call	load_2_operands_to_xmm
    ptest	%xmm1, %xmm1
	jnz		op_div
	lea		msg_div_zero, %rdi
	call	printf
	jmp		main_repeat

op_div:
	divsd	%xmm1, %xmm0	
    call	show_result
    jmp		main_repeat

case_pow:
    call    read_op2
	call	load_2_operands_to_xmm
	call	op_pow
	
	/*fldl	op1
	fldl	op2

	fyl2x

	sub		$2, %rsp
	fstcw	(%rsp)
	movw	(%rsp), %ax
	add		$2, %rsp

	orw		$0x200, %ax

	frndint
	fldl	const_one
	fscale

	f2xm1
	sub		$8, %rsp	
	fstpl	(%rsp)
	movsd	(%rsp), %xmm0
	add		$8, %rsp
	*/
	call	show_result
    jmp     main_repeat

case_sqrt:
    movsd   op1, %xmm0
    call    op_sqrt
    test    %rax, %rax
    jz      main_repeat
    call    show_result
    jmp     main_repeat

case_fat:
	movsd op1, %xmm0
	call op_fat

	lea fmt_int_uns, %rdi
	mov %rax, %rsi
	call printf
	jmp main_repeat


op_fat:
	push %rbp
	mov %rsp, %rbp

	call	verify_op1_neg
	jb		neg_fat

	call	verify_op1_frac
	jnz		frac_fat

	mov		$1, %rax
	test	%rbx, %rbx
	jz		fat_end

fat_calc:
	cmpq	$1, %rbx
	jz		fat_end
	mulq	%rbx
	subq	$1, %rbx
	jmp		fat_calc

neg_fat:
	lea		msg_neg_fat, %rdi
	call	printf 
	jmp		main_repeat

frac_fat:
	lea		msg_frac_fat, %rdi
	call	printf
	jmp		main_repeat

fat_end:

	mov %rbp, %rsp
	pop %rbp
	ret
case_log:
	jmp main_repeat

case_arr:
	call read_op2
	call load_2_operands_to_xmm
	
	call verify_op1_neg
	jb neg_arr

	call verify_op1_frac
	jnz frac_arr

	call verify_op2_neg
	jb neg_arr

	call verify_op2_frac
	jnz	frac_arr

	call op_arr

	jmp main_loop

neg_arr:
	lea msg_neg_arr, %rdi
	call printf
	jmp main_repeat

frac_arr:
	lea msg_frac_arr, %rdi
	call printf
	jmp main_repeat


op_arr:
	push %rbp
	mov %rsp, %rbp

	call op_fat

case_inv:
	movsd op1, %xmm0

	ptest %xmm0, %xmm0
	jz inv_zero
	
	movsd const_one, %xmm1
	divsd %xmm0, %xmm1
	movsd %xmm1, %xmm0
	call show_result
	jmp main_repeat
	
inv_zero:
	lea msg_inv_zero, %rdi
	call printf
	jmp main_repeat
	