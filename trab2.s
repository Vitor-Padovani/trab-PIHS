.section .rodata
fmt_in:  .string "%255s"
fmt_out: .string "%ld\n"

    .section .bss
    # Equivalente a: char line[MAX_LINE];
    .lcomm line, 256

    .section .text
    .global main

# ========================================================
# long read_term(const char *line, int *pos, int end)
# ========================================================
read_term:
    pushq   %rbp
    movq    %rsp, %rbp
    
    # Argumentos que chegam:
    # %rdi = line
    # %rsi = pos (ponteiro para int)
    # %rdx = end (tamanho da string)

    xorq    %rax, %rax          # num = 0 (resultado)
    movslq  (%rsi), %rcx        # %rcx = *pos (carrega o valor do ponteiro pos)

.L_read_term_loop:
    cmpq    %rdx, %rcx          # if (*pos >= end)
    jge     .L_read_term_end    # sai do loop

    movzbq  (%rdi, %rcx), %r8   # %r8 = line[*pos] (carrega 1 byte)

    # Verifica se '0' <= c <= '9'
    cmpb    $'0', %r8b
    jl      .L_read_term_end
    cmpb    $'9', %r8b
    jg      .L_read_term_end

    # num = num * 10
    imulq   $10, %rax
    # c = c - '0'
    subb    $'0', %r8b
    # num = num + c
    addq    %r8, %rax
    
    incq    %rcx                # (*pos)++
    jmp     .L_read_term_loop

.L_read_term_end:
    movl    %ecx, (%rsi)        # Atualiza a variavel pos original (*pos = %rcx)
    
    popq    %rbp
    ret


# ========================================================
# long eval_expr(const char *line, int start, int end)
# ========================================================
eval_expr:
    pushq   %rbp
    movq    %rsp, %rbp
    # Aloca espaco na pilha para a variavel local 'pos' e mantem o alinhamento de 16 bytes
    subq    $16, %rsp           

    # Argumentos que chegam:
    # %rdi = line
    # %rsi = start
    # %rdx = end

    # int pos = start;
    movl    %esi, -4(%rbp)      # Salva 'start' no espaco reservado para 'pos'

    # Preparando chamada para read_term(line, &pos, end)
    # %rdi ja contem 'line'
    leaq    -4(%rbp), %rsi      # %rsi recebe o endereco de 'pos'
    # %rdx ja contem 'end'
    
    call    read_term           # O retorno (num) estara em %rax

    # Como eh a etapa 1, nao temos loop de soma/subtracao.
    # Apenas retornamos o primeiro termo lido.
    
    leave                       # leave eh equivalente a: movq %rbp, %rsp; popq %rbp
    ret


# ========================================================
# int main(void)
# ========================================================
main:
    pushq   %rbp
    movq    %rsp, %rbp
    subq    $16, %rsp           # Alinhamento de pilha para chamadas da libc

.L_main_loop:
    # scanf("%255s", line)
    leaq    fmt_in(%rip), %rdi
    leaq    line(%rip), %rsi
    xorl    %eax, %eax          # %eax = 0 (exigencia para funcoes variadicas sem floats)
    call    scanf@PLT

    # Verifica o retorno do scanf (deve ser 1)
    cmpl    $1, %eax
    jne     .L_main_end

    # Vamos calcular o tamanho da string (equivalente a strlen(line))
    leaq    line(%rip), %rdi
    call    strlen@PLT          # %rax = len
    movq    %rax, %rdx          # %rdx = end (len)

    # Chama eval_expr(line, 0, len)
    leaq    line(%rip), %rdi    # %rdi = line
    xorl    %esi, %esi          # %rsi = start = 0
    # %rdx ja eh len
    call    eval_expr           # %rax = result

    # printf("%ld\n", result)
    leaq    fmt_out(%rip), %rdi
    movq    %rax, %rsi
    xorl    %eax, %eax
    call    printf@PLT

    jmp     .L_main_loop        # Volta para ler a proxima linha

.L_main_end:
    movl    $0, %eax            # return 0
    leave
    ret