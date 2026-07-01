.section .rodata
    fmt_in:  .string "%255s"
    fmt_out: .string "%ld\n"

.section .bss
    .lcomm line, 256
    .lcomm vars, 208
    
    # NOVAS ÁREAS DE MEMÓRIA (Etapa 4)
    .lcomm func_param, 26        # 26 caracteres (o parâmetro de cada função)
    .lcomm func_body, 6656       # Array 2D: 26 * 256 bytes (6656 bytes)
    .lcomm func_defined, 26      # Booleano (1 byte cada) indicando se existe

.section .text
.global main

# ========================================================
# bool contains_equal(const char *line, int len)
# ========================================================
contains_equal:
    xorq    %rax, %rax          # Retorno falso por padrão
    xorq    %rcx, %rcx          # rcx = 0 (índice)
.L_ce_loop:
    cmpq    %rsi, %rcx          # if (i >= len) break
    jge     .L_ce_end
    cmpb    $'=', (%rdi, %rcx)  # if (line[i] == '=')
    je      .L_ce_true
    incq    %rcx
    jmp     .L_ce_loop
.L_ce_true:
    movq    $1, %rax            # Retorna 1 (true)
.L_ce_end:
    ret


# ========================================================
# void handle_func_definition(const char *line, int len)
# ========================================================
handle_func_definition:
    pushq   %rbp
    movq    %rsp, %rbp
    
    # %rdi = line, %rsi = len

    # func_name = line[0]
    movzbq  (%rdi), %rcx
    subq    $'a', %rcx          # %rcx = índice da função (0-25)

    # param_name = line[2]
    movzbq  2(%rdi), %rdx
    
    # func_param[index] = param_name
    leaq    func_param(%rip), %r8
    movb    %dl, (%r8, %rcx)
    
    # func_defined[index] = true (1)
    leaq    func_defined(%rip), %r8
    movb    $1, (%r8, %rcx)

    # Calcular o offset em func_body (index * 256)
    movq    %rcx, %r9
    imulq   $256, %r9           # %r9 = deslocamento base da string
    leaq    func_body(%rip), %r8
    addq    %r8, %r9            # %r9 = endereço de func_body[index][0]

    # Copiar o corpo da função (de line[5] em diante)
    movq    $5, %r10            # src_idx = 5
    xorq    %r11, %r11          # dst_idx = 0
.L_copy_loop:
    cmpq    %rsi, %r10          # if (src_idx >= len) break
    jge     .L_copy_end
    
    movb    (%rdi, %r10), %r8b  # Pega o byte de line[src_idx]
    movb    %r8b, (%r9, %r11)   # Salva em func_body[dst_idx]
    
    incq    %r10
    incq    %r11
    jmp     .L_copy_loop

.L_copy_end:
    movb    $0, (%r9, %r11)     # Null-terminate ('\0') no final do corpo

    leave
    ret


# ========================================================
# long read_term(const char *line, int *pos, int end)
# ========================================================
# ========================================================
# long read_term(const char *line, int *pos, int end)
# (VERSÃO FINAL - ETAPA 5)
# ========================================================
read_term:
    pushq   %rbp
    movq    %rsp, %rbp
    
    # Vamos salvar os registradores protegidos, pois faremos chamadas recursivas
    pushq   %r12
    pushq   %r13
    pushq   %r14
    pushq   %r15
    pushq   %rbx
    # Alinhando a pilha para 16 bytes (5 pushes = 40 bytes + 24 = 64 bytes)
    subq    $24, %rsp

    # Guardando os argumentos originais na nossa pilha local
    movq    %rdi, -48(%rbp)     # -48 = line
    movq    %rsi, -56(%rbp)     # -56 = pos (ponteiro)
    movq    %rdx, -64(%rbp)     # -64 = end

    movslq  (%rsi), %rcx        # rcx = *pos
    cmpq    %rdx, %rcx
    jge     .L_ret_zero

    movzbq  (%rdi, %rcx), %rbx  # rbx = char atual (c)

    # Verifica se é número ('0' a '9')
    cmpb    $'0', %bl
    jl      .L_check_letter
    cmpb    $'9', %bl
    jg      .L_check_letter

    # --- MODO NÚMERO (Original) ---
    xorq    %rax, %rax
.L_num_loop:
    movq    -64(%rbp), %rdx
    cmpq    %rdx, %rcx
    jge     .L_num_end

    movq    -48(%rbp), %rdi
    movzbq  (%rdi, %rcx), %r8
    cmpb    $'0', %r8b
    jl      .L_num_end
    cmpb    $'9', %r8b
    jg      .L_num_end

    imulq   $10, %rax
    subb    $'0', %r8b
    addq    %r8, %rax
    incq    %rcx
    jmp     .L_num_loop
.L_num_end:
    movq    -56(%rbp), %rsi
    movl    %ecx, (%rsi)        # Atualiza *pos
    jmp     .L_rt_end


.L_check_letter:
    # Verifica se é letra ('a' a 'z')
    cmpb    $'a', %bl
    jl      .L_ret_zero
    cmpb    $'z', %bl
    jg      .L_ret_zero

    # É uma letra! Salva o índice em %rbx
    subq    $'a', %rbx          
    
    # Verifica se o PRÓXIMO caractere é um '('
    movq    %rcx, %r8
    incq    %r8                 # r8 = *pos + 1
    movq    -64(%rbp), %rdx
    cmpq    %rdx, %r8
    jge     .L_is_var           # Se passou do fim, com certeza é variável

    movq    -48(%rbp), %rdi
    movzbq  (%rdi, %r8), %r9
    cmpb    $'(', %r9b
    jne     .L_is_var           # Se não é '(', é variável

    # =======================================================
    # MODO CHAMADA DE FUNÇÃO (Ex: f(10+20))
    # =======================================================
    addq    $2, %rcx            # *pos += 2 (pula a letra e o '(' )
    movq    %rcx, %r12          # r12 = arg_start
    movq    $1, %r13            # r13 = depth (profundidade dos parênteses)

.L_depth_loop:
    cmpq    $0, %r13
    jle     .L_depth_done
    movzbq  (%rdi, %rcx), %r9
    cmpb    $'(', %r9b
    jne     .L_chk_close
    incq    %r13                # depth++
    jmp     .L_depth_adv
.L_chk_close:
    cmpb    $')', %r9b
    jne     .L_depth_adv
    decq    %r13                # depth--
.L_depth_adv:
    cmpq    $0, %r13
    jle     .L_depth_loop       # Se depth zerou, não incrementa o pos, deixa pro loop quebrar
    incq    %rcx
    jmp     .L_depth_loop

.L_depth_done:
    movq    %rcx, %r14          # r14 = arg_end
    incq    %rcx                # (*pos)++ (Pula o ')' final)
    
    # Grava o *pos na memória ANTES de chamar eval_expr, 
    # pro eval_expr não se perder!
    movq    -56(%rbp), %rsi
    movl    %ecx, (%rsi)

    # 1. Avalia o argumento: arg_value = eval_expr(line, arg_start, arg_end)
    movq    -48(%rbp), %rdi
    movq    %r12, %rsi
    movq    %r14, %rdx
    call    eval_expr
    movq    %rax, %r15          # r15 = arg_value

    # 2. Descobre quem é o parâmetro da função: param = func_param[name]
    leaq    func_param(%rip), %rdi
    movzbq  (%rdi, %rbx), %r12
    subq    $'a', %r12          # r12 = param index ('x' - 'a')

    # 3. Pega o corpo da função: body = func_body[name]
    movq    %rbx, %r13
    imulq   $256, %r13
    leaq    func_body(%rip), %r14
    addq    %r13, %r14          # r14 = ponteiro para a string do corpo

    # 4. BACKUP NA PILHA: saved = vars[param]
    leaq    vars(%rip), %rdi
    movq    (%rdi, %r12, 8), %r13 # r13 = backup do valor da variável

    # 5. INJETA O ARGUMENTO: vars[param] = arg_value
    movq    %r15, (%rdi, %r12, 8)

    # 6. AVALIA O CORPO: result = eval_expr(body, 0, strlen(body))
    movq    %r14, %rdi
    call    strlen
    movq    %rax, %rdx          # end = strlen
    movq    %r14, %rdi          # line = body
    xor    %esi, %esi          # start = 0
    call    eval_expr
    movq    %rax, %r15          # r15 = result (resposta da função)

    # 7. RESTAURA O BACKUP: vars[param] = saved
    leaq    vars(%rip), %rdi
    movq    %r13, (%rdi, %r12, 8)

    movq    %r15, %rax          # Retorna o resultado
    jmp     .L_rt_end


.L_is_var:
    # --- MODO VARIÁVEL (Ex: a) ---
    leaq    vars(%rip), %rdi
    movq    (%rdi, %rbx, 8), %rax
    incq    %rcx
    movq    -56(%rbp), %rsi
    movl    %ecx, (%rsi)
    jmp     .L_rt_end


.L_ret_zero:
    # Fallback (lixo na string)
    incq    %rcx
    movq    -56(%rbp), %rsi
    movl    %ecx, (%rsi)
    xorq    %rax, %rax

.L_rt_end:
    # Desfaz o frame de pilha restaurando tudo
    addq    $24, %rsp
    popq    %rbx
    popq    %r15
    popq    %r14
    popq    %r13
    popq    %r12
    leave
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
    
    pushq   %rbx
    subq    $8, %rsp            # alinhamento (16 bytes)

    movq    %rdi, %rbx          # salva line em rbx

    # --- chamada correta: eval_expr(line, 2, len) ---
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
    # Salvar r12 (callee-saved) pois o usaremos para proteger o 'len'
    pushq   %r12
    subq    $8, %rsp

.L_main_loop:
    leaq    fmt_in(%rip), %rdi
    leaq    line(%rip), %rsi
    xor    %eax, %eax
    call    scanf

    cmpl    $1, %eax
    jne     .L_main_end

    leaq    line(%rip), %rdi
    call    strlen
    movq    %rax, %r12          # r12 = len (salvo de forma segura!)

    # if (len <= 1)
    cmpq    $1, %r12
    jle     .L_eval_mode

    # Verifica line[1] == '('
    leaq    line(%rip), %rdi
    cmpb    $'(', 1(%rdi)
    je      .L_func_logic

    # Verifica line[1] == '='
    cmpb    $'=', 1(%rdi)
    je      .L_var_logic

    jmp     .L_eval_mode

.L_func_logic:
    # Chama contains_equal(line, len)
    leaq    line(%rip), %rdi
    movq    %r12, %rsi
    call    contains_equal
    testq   %rax, %rax          # rax == 0 ?
    jz      .L_eval_mode        # Nao tem '=' , avalia (ex: f(10))

    # É uma definição de função! (ex: f(x)=x+10)
    leaq    line(%rip), %rdi
    movq    %r12, %rsi
    call    handle_func_definition
    jmp     .L_main_loop

.L_var_logic:
    # É uma atribuição de variável
    leaq    line(%rip), %rdi
    movq    %r12, %rsi
    call    handle_var_assignment
    jmp     .L_main_loop

.L_eval_mode:
    # Modo Cálculo
    leaq    line(%rip), %rdi
    xor    %esi, %esi
    movq    %r12, %rdx
    call    eval_expr

    leaq    fmt_out(%rip), %rdi
    movq    %rax, %rsi
    xor    %eax, %eax
    call    printf

    jmp     .L_main_loop

.L_main_end:
    movl    $0, %eax
    addq    $8, %rsp
    popq    %r12
    leave
    ret
