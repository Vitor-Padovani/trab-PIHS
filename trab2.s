.file "calc.s"

    # --- SEÇÃO DE DADOS ---
    .section .rodata
fmt_out:
    .string "%ld\n"

    # --- SEÇÃO BSS ---
    .section .bss
    .align 32
line:
    .space 256

    # --- SEÇÃO DE TEXTO ---
    .text

# -------------------------------------------------------------
# long read_term(const char *line, int *pos, int end)
# (Idêntico à Etapa 2)
# -------------------------------------------------------------
    .type read_term, @function
read_term:
    pushq   %rbp
    movq    %rsp, %rbp
    
    movl    (%rsi), %ecx
    cmpl    %edx, %ecx
    jge     .L_rt_not_number
    
    movsbl  (%rdi, %rcx, 1), %r8d
    
    cmpl    $48, %r8d
    jl      .L_rt_not_number
    cmpl    $57, %r8d
    jg      .L_rt_not_number
    
    xorl    %eax, %eax
    
.L_rt_digit_loop:
    cmpl    %edx, %ecx
    jge     .L_rt_digit_end
    
    movsbl  (%rdi, %rcx, 1), %r8d
    cmpl    $48, %r8d
    jl      .L_rt_digit_end
    cmpl    $57, %r8d
    jg      .L_rt_digit_end
    
    imulq   $10, %rax, %rax
    subl    $48, %r8d
    movslq  %r8d, %r9
    addq    %r9, %rax
    incl    %ecx
    jmp     .L_rt_digit_loop
    
.L_rt_digit_end:
    movl    %ecx, (%rsi)
    popq    %rbp
    ret

.L_rt_not_number:
    incl    %ecx
    movl    %ecx, (%rsi)
    xorl    %eax, %eax
    popq    %rbp
    ret


# -------------------------------------------------------------
# long eval_expr(const char *line, int start, int end)
# %rdi = line
# %esi = start (int)
# %edx = end (int)
# -------------------------------------------------------------
    .type eval_expr, @function
eval_expr:
    pushq   %rbp
    movq    %rsp, %rbp
    
    # Alocamos 48 bytes na pilha para manter alinhamento (múltiplo de 16)
    # e guardar registradores callee-saved e a variável local 'pos'.
    subq    $48, %rsp
    
    # Salvando os registradores que precisamos preservar
    movq    %r12, -8(%rbp)      # result
    movq    %r13, -16(%rbp)     # sign
    movq    %r14, -24(%rbp)     # line pointer
    movq    %r15, -32(%rbp)     # end
    
    movq    %rdi, %r14          # Guarda line em %r14
    movl    %edx, %r15d         # Guarda end em %r15d
    movl    %esi, -36(%rbp)     # Variavel local pos = start na pilha

    xorq    %r12, %r12          # result = 0
    movl    $1, %r13d           # sign = 1

.L_eval_loop:
    # while (pos < end)
    movl    -36(%rbp), %eax
    cmpl    %r15d, %eax
    jge     .L_eval_end         # Se pos >= end, sai do loop

    # long term = read_term(line, &pos, end);
    movq    %r14, %rdi          # 1º arg: line
    leaq    -36(%rbp), %rsi     # 2º arg: endereço de pos
    movl    %r15d, %edx         # 3º arg: end
    call    read_term

    # result += sign * term;
    # O term retornado por read_term está em %rax
    movslq  %r13d, %rcx         # %rcx = sign (convertido para 64 bits)
    imulq   %rcx, %rax          # %rax = sign * term
    addq    %rax, %r12          # result += rax

    # if (pos < end)
    movl    -36(%rbp), %eax
    cmpl    %r15d, %eax
    jge     .L_eval_loop        # Volta pro while se atingiu o fim

    # if (line[pos] == '+') ou '-'
    movslq  %eax, %rcx          # índice para 64-bits
    movsbl  (%r14, %rcx, 1), %edi # %edi = line[pos]

    cmpl    $43, %edi           # é '+' ? (43 em ASCII)
    je      .L_eval_plus
    cmpl    $45, %edi           # é '-' ? (45 em ASCII)
    je      .L_eval_minus
    
    # Se não for nenhum dos dois (ex: espaço), o read_term da 
    # próxima iteração lidará pulando esse caractere.
    jmp     .L_eval_loop

.L_eval_plus:
    movl    $1, %r13d           # sign = 1
    incl    -36(%rbp)           # pos++
    jmp     .L_eval_loop

.L_eval_minus:
    movl    $-1, %r13d          # sign = -1
    incl    -36(%rbp)           # pos++
    jmp     .L_eval_loop

.L_eval_end:
    movq    %r12, %rax          # Retorna result em %rax

    # Restaura os registradores originais
    movq    -8(%rbp), %r12
    movq    -16(%rbp), %r13
    movq    -24(%rbp), %r14
    movq    -32(%rbp), %r15
    
    leave                       # Libera a pilha
    ret

# -------------------------------------------------------------
# main
# (Idêntico à Etapa 2)
# -------------------------------------------------------------
    .globl main
    .type main, @function
main:
    pushq   %rbp
    movq    %rsp, %rbp

.L_main_loop:
    leaq    line(%rip), %rdi
    movl    $256, %esi
    movq    stdin(%rip), %rdx
    call    fgets@PLT

    testq   %rax, %rax
    jz      .L_main_end

    leaq    line(%rip), %rdi
    call    strlen@PLT
    movl    %eax, %r12d

.L_strip_newline:
    testl   %r12d, %r12d
    jle     .L_check_empty

    leaq    line(%rip), %rbx
    movl    %r12d, %ecx
    decl    %ecx
    movsbl  (%rbx, %rcx, 1), %edx

    cmpl    $10, %edx
    je      .L_do_strip
    cmpl    $13, %edx
    je      .L_do_strip
    jmp     .L_check_empty

.L_do_strip:
    decl    %r12d
    movb    $0, (%rbx, %r12, 1)
    jmp     .L_strip_newline

.L_check_empty:
    testl   %r12d, %r12d
    jz      .L_main_loop

    # result = eval_expr(line, 0, len)
    leaq    line(%rip), %rdi
    movl    $0, %esi
    movl    %r12d, %edx
    call    eval_expr

    # printf("%ld\n", result)
    leaq    fmt_out(%rip), %rdi
    movq    %rax, %rsi
    movl    $0, %eax
    call    printf@PLT

    jmp     .L_main_loop

.L_main_end:
    movl    $0, %eax
    popq    %rbp
    ret
