.section .rodata
fmt_in:  .string "%255s"
fmt_out: .string "%ld\n"

    .section .bss
    .lcomm line, 256

    .section .text
    .global main

# ========================================================
# long read_term(const char *line, int *pos, int end)
# ========================================================
read_term:
    pushq   %rbp
    movq    %rsp, %rbp
    
    xorq    %rax, %rax          # num = 0
    movslq  (%rsi), %rcx        # %rcx = *pos
    
    # Se chegou no final, sai
    cmpq    %rdx, %rcx
    jge     .L_read_term_end
    
    # Pega o primeiro caractere
    movzbq  (%rdi, %rcx), %r8
    
    # Verifica se eh um digito
    cmpb    $'0', %r8b
    jl      .L_not_digit
    cmpb    $'9', %r8b
    jg      .L_not_digit

.L_read_term_loop:
    # Loop de conversao dos digitos
    cmpq    %rdx, %rcx
    jge     .L_read_term_end

    movzbq  (%rdi, %rcx), %r8
    cmpb    $'0', %r8b
    jl      .L_read_term_end
    cmpb    $'9', %r8b
    jg      .L_read_term_end

    imulq   $10, %rax
    subb    $'0', %r8b
    addq    %r8, %rax
    
    incq    %rcx                # (*pos)++
    jmp     .L_read_term_loop

.L_not_digit:
    # Se nao for digito (ainda nao temos letras da Etapa 3).
    # Comportamento do C: apenas ignora o char invalido e avanca pos.
    incq    %rcx
    xorq    %rax, %rax          # Retorna 0

.L_read_term_end:
    movl    %ecx, (%rsi)        # Salva o *pos atualizado
    popq    %rbp
    ret


# ========================================================
# long eval_expr(const char *line, int start, int end)
# ========================================================
eval_expr:
    pushq   %rbp
    movq    %rsp, %rbp
    
    # Precisamos proteger os registradores que guardam nossos estados vitais!
    pushq   %r12        # %r12 = result
    pushq   %r13        # %r13 = sign
    pushq   %r14        # %r14 = line (ponteiro para string)
    pushq   %r15        # %r15 = end  (tamanho da string)
    
    # Aloca 16 bytes. -36(%rbp) sera o endereco de memoria da nossa variavel 'pos'
    subq    $16, %rsp   

    # Guarda os argumentos recebidos para não perdê-los
    movq    %rdi, %r14          # Guarda line em %r14
    movq    %rdx, %r15          # Guarda end em %r15
    movl    %esi, -36(%rbp)     # Inicia 'pos' com valor de 'start'

    xorq    %r12, %r12          # result = 0
    movq    $1, %r13            # sign = 1

.L_eval_loop:
    # while (pos < end)
    movslq  -36(%rbp), %rcx     # Le a variavel 'pos' da pilha
    cmpq    %r15, %rcx
    jge     .L_eval_end         # Se pos >= end, quebra o loop principal

    # Chama read_term(line, &pos, end)
    movq    %r14, %rdi          # Arg 1: line
    leaq    -36(%rbp), %rsi     # Arg 2: &pos
    movq    %r15, %rdx          # Arg 3: end
    call    read_term           # Retorno vai para %rax (term)

    # result += sign * term
    imulq   %r13, %rax          # Multiplica term por sign (1 ou -1)
    addq    %rax, %r12          # Adiciona ao result geral

    # if (pos < end)
    movslq  -36(%rbp), %rcx
    cmpq    %r15, %rcx
    jge     .L_eval_loop        # Voltar pro inicio (e na verificação vai sair)

    # Identificando o proximo caractere para o proximo ciclo: line[pos]
    movzbq  (%r14, %rcx), %r8   # %r8 = line[pos]

    # Verifica '+'
    cmpb    $'+', %r8b
    jne     .L_check_minus
    movq    $1, %r13            # sign = 1
    incl    -36(%rbp)           # pos++
    jmp     .L_eval_loop

.L_check_minus:
    # Verifica '-'
    cmpb    $'-', %r8b
    jne     .L_eval_loop        # Se for outro char (espaco ou sujeira), so ignora e volta
    movq    $-1, %r13           # sign = -1
    incl    -36(%rbp)           # pos++
    jmp     .L_eval_loop

.L_eval_end:
    movq    %r12, %rax          # Prepara o retorno (result)

    # Restaura o espaco na pilha e registradores (IMPORTANTE: ordem reversa do push)
    addq    $16, %rsp
    popq    %r15
    popq    %r14
    popq    %r13
    popq    %r12
    leave                       # Destroi o frame
    ret


# ========================================================
# int main(void)
# ========================================================
main:
    pushq   %rbp
    movq    %rsp, %rbp
    subq    $16, %rsp

.L_main_loop:
    leaq    fmt_in(%rip), %rdi
    leaq    line(%rip), %rsi
    xorl    %eax, %eax
    call    scanf@PLT

    cmpl    $1, %eax
    jne     .L_main_end

    leaq    line(%rip), %rdi
    call    strlen@PLT
    movq    %rax, %rdx

    leaq    line(%rip), %rdi
    xorl    %esi, %esi
    call    eval_expr

    leaq    fmt_out(%rip), %rdi
    movq    %rax, %rsi
    xorl    %eax, %eax
    call    printf@PLT

    jmp     .L_main_loop

.L_main_end:
    movl    $0, %eax
    leave
    ret