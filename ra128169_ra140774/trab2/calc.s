.section .bss
    .lcomm vars, 208            # 26 letras * 8 bytes = 208 bytes

    .lcomm func_param, 26
    .lcomm func_body, 6656       # 26 funções * 256 bytes por função.

.section .text
.global _start

.extern line
.extern read_line
.extern print_long
.extern my_strlen
.extern contains_equal

# void handle_func_definition(const char *line, int len)
# Processa entrada tipo: "f(x)=x+1" Salva o corpo "x+1" na memória da função 'f'.
handle_func_definition:
    pushq   %rbp
    movq    %rsp, %rbp

    # line[0] é o nome da função
    movzbq  (%rdi), %rcx        # %rcx = caractere da função
    subq    $'a', %rcx          # Subtrai 'a' para virar índice (0 a 25)

    # line[2] é o nome do parâmetro
    movzbq  2(%rdi), %rdx       # %rdx = parâmetro

    # Salva o parâmetro na array func_param
    leaq    func_param(%rip), %r8
    movb    %dl, (%r8, %rcx)

    # Calcula endereço de destino do corpo da função: func_body + (índice * 256)
    movq    %rcx, %r9
    imulq   $256, %r9
    leaq    func_body(%rip), %r8
    addq    %r8, %r9            # %r9 agora aponta para onde a expressão será guardada

    movq    $5, %r10            # %r10 = índice de origem (começa no 5, pulando "f(x)=")
    xorq    %r11, %r11          # %r11 = índice de destino (começa no 0)
    
.L_copy_loop:                   # Loop para copiar o corpo da função
    cmpq    %rsi, %r10          # Verifica se chegou no fim da string (%rsi tem o tamanho)
    jge     .L_copy_end
    movb    (%rdi, %r10), %r8b  # Lê caractere da string original
    movb    %r8b, (%r9, %r11)   # Escreve no buffer da função
    incq    %r10
    incq    %r11
    jmp     .L_copy_loop

.L_copy_end:
    movb    $0, (%r9, %r11)     # Terminador nulo no fim do corpo da função
    leave
    ret


# long read_term(const char *line, int *pos, int end)
# Parseia e avalia um termo: pode ser um NÚMERO (123),  uma VARIÁVEL (a) ou uma CHAMADA DE FUNÇÃO (f(5)). Retorna o valor numérico desse termo em %rax. Atualiza o ponteiro de posição (*pos) para saber onde parou.
read_term:
    pushq   %rbp
    movq    %rsp, %rbp

    pushq   %r12
    pushq   %r13
    pushq   %r14
    pushq   %r15
    pushq   %rbx
    subq    $24, %rsp           # Espaço na pilha para variáveis locais

    # Guarda os argumentos na pilha para acesso fácil
    movq    %rdi, -48(%rbp)     # -48 = const char *line
    movq    %rsi, -56(%rbp)     # -56 = int *pos (ponteiro para índice atual)
    movq    %rdx, -64(%rbp)     # -64 = int end (tamanho da linha)

    movslq  (%rsi), %rcx        # %rcx = valor atual do índice (desreferenciando o ponteiro pos)
    cmpq    %rdx, %rcx
    jge     .L_ret_zero         # Se já passou do final, retorna 0

    movzbq  (%rdi, %rcx), %rbx  # %rbx = caractere atual

    # --- VERIFICA SE É NÚMERO ---
    cmpb    $'0', %bl
    jl      .L_check_letter     # Se for menor que '0', verifica se é letra
    cmpb    $'9', %bl
    jg      .L_check_letter     # Se for maior que '9', verifica se é letra

    # É um número. Vamos converter enquanto for dígito
    xorq    %rax, %rax          # Acumulador do número
.L_num_loop:
    movq    -64(%rbp), %rdx
    cmpq    %rdx, %rcx
    jge     .L_num_end          # Acabou a string

    movq    -48(%rbp), %rdi
    movzbq  (%rdi, %rcx), %r8
    cmpb    $'0', %r8b
    jl      .L_num_end          # Não é mais número
    cmpb    $'9', %r8b
    jg      .L_num_end          # Não é mais número

    imulq   $10, %rax           # valor = valor * 10
    subb    $'0', %r8b          # transforma ASCII em inteiro
    addq    %r8, %rax           # valor += dígito
    incq    %rcx                # avança índice
    jmp     .L_num_loop
.L_num_end:
    movq    -56(%rbp), %rsi
    movl    %ecx, (%rsi)        # Atualiza o *pos
    jmp     .L_rt_end           # Terminou de ler número


    # --- VERIFICA SE É LETRA (Variável ou Função) ---
.L_check_letter:
    cmpb    $'a', %bl
    jl      .L_ret_zero
    cmpb    $'z', %bl
    jg      .L_ret_zero

    subq    $'a', %rbx          # %rbx agora é o índice da letra (0-25)

    movq    %rcx, %r8
    incq    %r8                 # Olha o próximo caractere
    movq    -64(%rbp), %rdx
    cmpq    %rdx, %r8
    jge     .L_is_var           # Se acabou a string, é variável

    movq    -48(%rbp), %rdi
    movzbq  (%rdi, %r8), %r9
    cmpb    $'(', %r9b
    jne     .L_is_var           # Se o próximo não é '(', então é só uma variável simples

    # --- É UMA CHAMADA DE FUNÇÃO (ex: f(10)) ---
    addq    $2, %rcx             # Pula a letra e o '(' -> aponta pro início do argumento (o '1' do 10)

    xorq    %r15, %r15           # %r15 = valor do argumento lido
.L_parse_arg:
    movzbq  (%rdi, %rcx), %r9
    cmpb    $')', %r9b
    je      .L_arg_done          # Achou o parêntese de fechamento
    imulq   $10, %r15
    subb    $'0', %r9b
    movzbq  %r9b, %r9
    addq    %r9, %r15
    incq    %rcx
    jmp     .L_parse_arg

.L_arg_done:
    incq    %rcx                 # Pula o ')'
    movq    -56(%rbp), %rsi
    movl    %ecx, (%rsi)         # Atualiza o *pos de leitura

    # Descobre qual é a letra que é usada como parâmetro desta função (ex: se for f(x), pega o 'x')
    leaq    func_param(%rip), %rdi
    movzbq  (%rdi, %rbx), %r12   # %r12 = letra do parâmetro
    subq    $'a', %r12           # Transforma em índice (0-25)

    # Localiza a string do corpo da função
    movq    %rbx, %r13
    imulq   $256, %r13
    leaq    func_body(%rip), %r14
    addq    %r13, %r14           # %r14 = ponteiro para a string do corpo

    # Salva o valor antigo da variável parâmetro.
    # Se o parâmetro é 'x', salva o valor global de 'x' para não estragar por exemplo
    leaq    vars(%rip), %rdi
    movq    (%rdi, %r12, 8), %r13 # %r13 = valor antigo de 'x'

    # Substitui 'x' pelo valor do argumento
    movq    %r15, (%rdi, %r12, 8)

    # Calcula o tamanho do corpo da função para passar ao avaliador
    movq    %r14, %rdi
    call    my_strlen
    movq    %rax, %rdx           # %rdx = tamanho da string da função
    
    # Chama o avaliador recursivamente para resolver a função
    movq    %r14, %rdi           # string = corpo da função
    xor     %esi, %esi           # pos = 0
    call    eval_expr
    movq    %rax, %r15           # %r15 = resultado do cálculo da função

    # RESTAURA o valor antigo da variável que foi usada como parâmetro
    leaq    vars(%rip), %rdi
    movq    %r13, (%rdi, %r12, 8)

    movq    %r15, %rax           # Move resultado para %rax
    jmp     .L_rt_end


    # --- É UMA VARIÁVEL ---
.L_is_var:
    leaq    vars(%rip), %rdi
    movq    (%rdi, %rbx, 8), %rax # Acessa vars[letra * 8 bytes] e joga no %rax
    incq    %rcx
    movq    -56(%rbp), %rsi
    movl    %ecx, (%rsi)          # Atualiza *pos
    jmp     .L_rt_end


.L_ret_zero:
    incq    %rcx
    movq    -56(%rbp), %rsi
    movl    %ecx, (%rsi)
    xorq    %rax, %rax            # Retorna 0 em caso de lixo ou fim

.L_rt_end:
    addq    $24, %rsp             # Limpa espaço alocado na pilha
    popq    %rbx
    popq    %r15
    popq    %r14
    popq    %r13
    popq    %r12
    leave                         # Desfaz o stack frame (movq %rbp, %rsp; popq %rbp)
    ret


# long eval_expr(const char *line, int start, int end)
# Avalia uma expressão inteira contendo somas e subtrações.
eval_expr:
    pushq   %rbp
    movq    %rsp, %rbp

    pushq   %r12
    pushq   %r13
    pushq   %r14
    pushq   %r15
    subq    $16, %rsp

    movq    %rdi, %r14          # %r14 = ponteiro para string
    movq    %rdx, %r15          # %r15 = tamanho da string (end)
    movl    %esi, -36(%rbp)     # -36(%rbp) = variável 'start' (índice atual, usado como ponteiro)

    xorq    %r12, %r12          # %r12 = ACUMULADOR
    movq    $1, %r13            # %r13 = SINAL ATUAL (+1 ou -1)

.L_eval_loop:
    movslq  -36(%rbp), %rcx
    cmpq    %r15, %rcx
    jge     .L_eval_end         # Se leu toda a string, termina o loop

    # Pega o próximo TERMO (pode ser número, variável ou chamada de função)
    movq    %r14, %rdi          # %rdi = string
    leaq    -36(%rbp), %rsi     # %rsi = ponteiro para índice atual (&start)
    movq    %r15, %rdx          # %rdx = fim
    call    read_term           # Chama o parser de termo (resultado vem em %rax)

    imulq   %r13, %rax          # Multiplica o termo pelo sinal atual (+1 ou -1)
    addq    %rax, %r12          # Adiciona ao Acumulador: Acumulador += (sinal * termo)

    # Verifica o operador que vem a seguir
    movslq  -36(%rbp), %rcx
    cmpq    %r15, %rcx
    jge     .L_eval_loop        # Se acabou a string, tenta rodar o loop de novo

    movzbq  (%r14, %rcx), %r8   # Lê o caractere atual

    cmpb    $'+', %r8b
    jne     .L_check_minus
    movq    $1, %r13            # Se sim, o próximo termo será positivo
    incl    -36(%rbp)           # Avança o ponteiro pulando o '+'
    jmp     .L_eval_loop

.L_check_minus:
    cmpb    $'-', %r8b
    jne     .L_eval_loop        # Se for outro caractere ignora/repete
    movq    $-1, %r13           # Se sim, o próximo termo será negativo
    incl    -36(%rbp)           # Avança o ponteiro pulando o '-'
    jmp     .L_eval_loop

.L_eval_end:
    movq    %r12, %rax          # Joga o Acumulador final no %rax para retorno
    addq    $16, %rsp
    popq    %r15
    popq    %r14
    popq    %r13
    popq    %r12
    leave
    ret


# void handle_var_assignment(const char *line, int len)
# Calcula a expressão à direita e guarda na variável à esquerda.
handle_var_assignment:
    pushq   %rbp
    movq    %rsp, %rbp
    pushq   %rbx
    subq    $8, %rsp

    movq    %rdi, %rbx          # %rbx = ponteiro da string

    # Prepara a chamada para eval_expr
    movq    %rsi, %rdx          # %rdx = tamanho total
    movq    %rbx, %rdi          # %rdi = string
    movl    $2, %esi            # %esi = índice de início (2, pula a letra e o '=')
    call    eval_expr           # Avalia o que está depois do sinal de igual (retorna em %rax)

    movzbq  (%rbx), %rcx        # Lê o nome da variável (ex: 'a') na posição 0
    subq    $'a', %rcx          # Transforma em índice de 0 a 25

    leaq    vars(%rip), %r8
    movq    %rax, (%r8, %rcx, 8) # vars[indice] = %rax

    addq    $8, %rsp
    popq    %rbx
    leave
    ret


_start:
    xorq    %r12, %r12

.L_main_loop:
    call    read_line
    cmpq    $-1, %rax           # EOF
    je      .L_main_end

    movq    %rax, %r12          # %r12 = len

    cmpq    $1, %r12
    jle     .L_eval_mode        # Se a linha tiver 1 ou zero letras, não pode ser "=" nem função. Avalia direto.

    leaq    line(%rip), %rdi
    cmpb    $'(', 1(%rdi)       # O segundo caractere (índice 1) é um '('
    je      .L_func_logic

    cmpb    $'=', 1(%rdi)       # O segundo caractere (índice 1) é um '='
    je      .L_var_logic

    jmp     .L_eval_mode        # Nenhuma das anteriores, é só uma conta matemática.

.L_func_logic:
    # Confirma que é uma declaração de função verificando se tem "=" em algum lugar
    leaq    line(%rip), %rdi
    movq    %r12, %rsi
    call    contains_equal
    testq   %rax, %rax
    jz      .L_eval_mode        # Se era "f(x)+1" (sem igual), é uma conta normal, não declaração.

    leaq    line(%rip), %rdi
    movq    %r12, %rsi
    call    handle_func_definition # Processa "f(x)=..."
    jmp     .L_main_loop        # Volta pro início do loop

.L_var_logic:
    leaq    line(%rip), %rdi
    movq    %r12, %rsi
    call    handle_var_assignment  # Processa "a=..."
    jmp     .L_main_loop        # Volta pro início do loop

.L_eval_mode:
    leaq    line(%rip), %rdi
    xor     %esi, %esi          # Inicia avaliação a partir do índice 0
    movq    %r12, %rdx          # len
    call    eval_expr           # Avalia a expressão

    movq    %rax, %rdi          # Passa o resultado de eval_expr como argumento
    call    print_long

    jmp     .L_main_loop

.L_main_end:
    movq    $60, %rax           # syscall 60: sys_exit
    xorq    %rdi, %rdi
    syscall
