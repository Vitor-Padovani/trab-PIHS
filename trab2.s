.section .rodata
fmt_in:  .string "%255s"
fmt_out: .string "%ld\n"

    .section .bss
    .lcomm line, 256
    .lcomm vars, 208            # Array de 26 longs (26 * 8 = 208 bytes)

    .section .text
    .global main

# ========================================================
# long read_term(const char *line, int *pos, int end)
# ========================================================
read_term:
    pushq   %rbp
    movq    %rsp, %rbp
    
    xorq    %rax, %rax
    movslq  (%rsi), %rcx
    
    cmpq    %rdx, %rcx
    jge     .L_read_term_end
    
    movzbq  (%rdi, %rcx), %r8
    
    # NOVIDADE DA ETAPA 3: Verifica se é uma letra de 'a' a 'z'
    cmpb    $'a', %r8b
    jl      .L_check_digit
    cmpb    $'z', %r8b
    jg      .L_check_digit

    # É uma letra!
    subq    $'a', %r8           # Transforma ASCII no índice (0 a 25)
    leaq    vars(%rip), %r9     # Pega o endereço base de 'vars'
    movq    (%r9, %r8, 8), %rax # rax = vars[indice * 8]
    incq    %rcx                # (*pos)++
    jmp     .L_read_term_end

.L_check_digit:
    # Verifica se eh um digito ('0' a '9')
    cmpb    $'0', %r8b
    jl      .L_not_digit
    cmpb    $'9', %r8b
    jg      .L_not_digit

.L_read_term_loop:
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
    
    incq    %rcx
    jmp     .L_read_term_loop

.L_not_digit:
    incq    %rcx
    xorq    %rax, %rax

.L_read_term_end:
    movl    %ecx, (%rsi)
    popq    %rbp
    ret


# ========================================================
# long eval_expr(const char *line, int start, int end)
# ========================================================
eval_expr:
    pushq   %rbp
    movq    %rsp, %rbp
    
    pushq   %r12
    pushq   %r13
    pushq   %r14
    pushq   %r15
    subq    $16, %rsp

    movq    %rdi, %r14
    movq    %rdx, %r15
    movl    %esi, -36(%rbp)

    xorq    %r12, %r12
    movq    $1, %r13

.L_eval_loop:
    movslq  -36(%rbp), %rcx
    cmpq    %r15, %rcx
    jge     .L_eval_end

    movq    %r14, %rdi
    leaq    -36(%rbp), %rsi
    movq    %r15, %rdx
    call    read_term

    imulq   %r13, %rax
    addq    %rax, %r12

    movslq  -36(%rbp), %rcx
    cmpq    %r15, %rcx
    jge     .L_eval_loop

    movzbq  (%r14, %rcx), %r8

    cmpb    $'+', %r8b
    jne     .L_check_minus
    movq    $1, %r13
    incl    -36(%rbp)
    jmp     .L_eval_loop

.L_check_minus:
    cmpb    $'-', %r8b
    jne     .L_eval_loop
    movq    $-1, %r13
    incl    -36(%rbp)
    jmp     .L_eval_loop

.L_eval_end:
    movq    %r12, %rax
    addq    $16, %rsp
    popq    %r15
    popq    %r14
    popq    %r13
    popq    %r12
    leave
    ret


# ========================================================
# void handle_var_assignment(const char *line, int len)
# ========================================================
handle_var_assignment:
    pushq   %rbp
    movq    %rsp, %rbp
    
    # Salvamos o rbx porque usaremos ele para manter o ponteiro 'line'.
    pushq   %rbx
    subq    $8, %rsp            # Alinhamento de pilha para 16 bytes

    movq    %rdi, %rbx          # Guarda line em %rbx
    
    # Prepara call eval_expr(line, 2, len)
    movq    %rsi, %rdx          # rdx = len
    movq    %rbx, %rdi          # rdi = line
    movl    $2, %esi            # rsi = start = 2
    call    eval_expr

    # --- salvar resultado na variável ---
    movzbq  (%rbx), %rcx        # rcx = line[0]
    subq    $'a', %rcx          # índice 0..25

    leaq    vars(%rip), %r8
    movq    %rax, (%r8, %rcx, 8)

    addq    $8, %rsp
    popq    %rbx
    leave
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
    movq    %rax, %rdx          # %rdx = len

    # Verifica se a linha eh maior que 1 e se o segundo caractere é '='
    cmpq    $1, %rdx
    jle     .L_eval_mode        # Se len <= 1, com certeza é conta simples

    leaq    line(%rip), %rdi
    cmpb    $'=', 1(%rdi)       # Verifica se line[1] == '='
    jne     .L_eval_mode

    # MODO ATRIBUIÇÃO (ex: a=10)
    movq    %rdi, %rdi          # Arg 1: line (redundante mas ilustrativo)
    movq    %rdx, %rsi          # Arg 2: len
    call    handle_var_assignment
    jmp     .L_main_loop        # Volta sem dar printf

.L_eval_mode:
    # MODO CÁLCULO (ex: a+10)
    leaq    line(%rip), %rdi
    xorl    %esi, %esi
    # %rdx ja tem len do strlen
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
