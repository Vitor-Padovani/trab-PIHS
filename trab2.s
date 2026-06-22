.file "calc.s"

    # --- SEÇÃO DE DADOS ---
    .section .rodata
fmt_out:
    .string "%ld\n"                 # Formato para imprimir o resultado final (long)

    # --- SEÇÃO BSS ---
    .section .bss
    .align 32
line:
    .space 256                      # char line[MAX_LINE]

    # --- SEÇÃO DE TEXTO ---
    .text

# -------------------------------------------------------------
# long read_term(const char *line, int *pos, int end)
# %rdi = line
# %rsi = pos (ponteiro para int)
# %edx = end (int)
# -------------------------------------------------------------
    .type read_term, @function
read_term:
    pushq   %rbp
    movq    %rsp, %rbp
    
    movl    (%rsi), %ecx            # %ecx = *pos
    
    # Se *pos >= end, não fazemos nada (segurança)
    cmpl    %edx, %ecx
    jge     .L_rt_not_number
    
    # char c = line[*pos];
    movsbl  (%rdi, %rcx, 1), %r8d   # %r8d = c
    
    # if (c >= '0' && c <= '9')
    cmpl    $48, %r8d               # 48 = '0' na tabela ASCII
    jl      .L_rt_not_number
    cmpl    $57, %r8d               # 57 = '9' na tabela ASCII
    jg      .L_rt_not_number
    
    # É um número! long num = 0;
    xorl    %eax, %eax              # %rax = 0
    
.L_rt_digit_loop:
    # while (*pos < end)
    cmpl    %edx, %ecx
    jge     .L_rt_digit_end
    
    # c = line[*pos]
    movsbl  (%rdi, %rcx, 1), %r8d
    
    # if (c >= '0' && c <= '9')
    cmpl    $48, %r8d
    jl      .L_rt_digit_end
    cmpl    $57, %r8d
    jg      .L_rt_digit_end
    
    # num = num * 10
    imulq   $10, %rax, %rax
    
    # num = num + (c - '0')
    subl    $48, %r8d               # c - '0'
    movslq  %r8d, %r9               # converte o valor 32-bits para 64-bits
    addq    %r9, %rax               # num += ...
    
    # (*pos)++
    incl    %ecx
    jmp     .L_rt_digit_loop
    
.L_rt_digit_end:
    movl    %ecx, (%rsi)            # atualiza o valor na memória: *pos = ecx
    popq    %rbp
    ret                             # retorna %rax (num)

.L_rt_not_number:
    # (*pos)++ e retorna 0
    incl    %ecx
    movl    %ecx, (%rsi)
    xorl    %eax, %eax              # return 0
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
    
    # Precisamos alocar espaço na pilha para 'int pos'
    # para podermos passar o endereço (&pos) para read_term.
    subq    $16, %rsp               # Aloca 16 bytes (mantém pilha alinhada)
    
    # int pos = start;
    movl    %esi, -4(%rbp)
    
    # Chamada: read_term(line, &pos, end);
    # %rdi já contém 'line'
    leaq    -4(%rbp), %rsi          # %rsi = &pos
    # %rdx já contém 'end'
    call    read_term
    
    # O retorno de read_term está em %rax.
    # Na Etapa 2, simplesmente retornamos esse valor como sendo o resultado final da expressão.
    leave                           # Restaura a pilha (equivale a movq %rbp,%rsp; popq %rbp)
    ret


# -------------------------------------------------------------
# main
# -------------------------------------------------------------
    .globl main
    .type main, @function
main:
    pushq   %rbp
    movq    %rsp, %rbp

.L_main_loop:
    # fgets(line, 256, stdin)
    leaq    line(%rip), %rdi
    movl    $256, %esi
    movq    stdin(%rip), %rdx
    call    fgets@PLT

    testq   %rax, %rax
    jz      .L_main_end

    # strlen(line)
    leaq    line(%rip), %rdi
    call    strlen@PLT
    movl    %eax, %r12d             # %r12d = len

.L_strip_newline:
    testl   %r12d, %r12d
    jle     .L_check_empty

    leaq    line(%rip), %rbx
    movl    %r12d, %ecx
    decl    %ecx
    movsbl  (%rbx, %rcx, 1), %edx

    cmpl    $10, %edx               # '\n'
    je      .L_do_strip
    cmpl    $13, %edx               # '\r'
    je      .L_do_strip
    jmp     .L_check_empty

.L_do_strip:
    decl    %r12d
    movb    $0, (%rbx, %r12, 1)
    jmp     .L_strip_newline

.L_check_empty:
    testl   %r12d, %r12d
    jz      .L_main_loop

    # --- AGORA CHAMAMOS A CALCULADORA ---
    # long result = eval_expr(line, 0, len);
    leaq    line(%rip), %rdi        # 1º arg: line
    movl    $0, %esi                # 2º arg: start = 0
    movl    %r12d, %edx             # 3º arg: end = len
    call    eval_expr

    # printf("%ld\n", result);
    leaq    fmt_out(%rip), %rdi     # 1º arg: formato de print
    movq    %rax, %rsi              # 2º arg: o resultado (veio em rax de eval_expr)
    movl    $0, %eax                # 0 floats
    call    printf@PLT

    jmp     .L_main_loop

.L_main_end:
    movl    $0, %eax
    popq    %rbp
    ret
