.section .bss
    .lcomm line, 256             # Buffer para armazenar a linha digitada pelo usuário
    .lcomm outbuf, 32            # Buffer para converter o número inteiro em string para impressão

.section .text

.global line
.global read_line
.global print_long
.global my_strlen
.global contains_equal

# long read_line(void)
# Lê entrada do teclado (stdin) usando syscall read. Substitui o '\n' por '\0' (terminador nulo). Retorno: %rax = tamanho da linha lida, ou -1 se EOF
read_line:
    xorq    %rax, %rax          # syscall 0: sys_read
    xorq    %rdi, %rdi          # fd = 0 (stdin / teclado)
    leaq    line(%rip), %rsi
    movq    $256, %rdx
    syscall

    cmpq    $0, %rax            # Verifica quantos bytes foram lidos
    jle     .L_rl_eof           # Se for 0 ou negativo, é Fim de Arquivo (EOF) ou erro

    movq    %rax, %rcx
    leaq    line(%rip), %r9
    xorq    %r10, %r10          # %r10 = 0

.L_rl_scan:                     # Procura o caracter de nova linha '\n'
    cmpq    %rcx, %r10          # Verifica se já olhamos todos os bytes lidos
    jge     .L_rl_no_newline 
    movzbq  (%r9, %r10), %r8    # Lê o byte em line[i] e estende para 64 bits em %r8
    cmpb    $'\n', %r8b
    je      .L_rl_found
    incq    %r10                # r10++
    jmp     .L_rl_scan

.L_rl_found:
    movb    $0, (%r9, %r10)     # Substitui '\n' por '\0'
    movq    %r10, %rax          # Retorna o tamanho da string
    ret

.L_rl_no_newline:
    movb    $0, (%r9, %rcx)     # Se não tinha \n, bota o '\0'
    movq    %rcx, %rax
    ret

.L_rl_eof:
    movq    $-1, %rax
    ret


# void print_long(long value)
# Converte um número (%rdi) em texto e imprime na tela.
print_long:
    pushq   %rbx                # Salva %rbx
    leaq    outbuf(%rip), %rsi  # %rsi = ponteiro para outbuf
    addq    $30, %rsi           # Vai para o FINAL do buffer (escrevemos de trás pra frente)
    movb    $'\n', (%rsi)       # Coloca a quebra de linha no final do buffer
    decq    %rsi                # Volta um byte

    movq    %rdi, %rax          # %rax = valor a ser impresso
    xorq    %r8, %r8            # %r8 será nossa flag de sinal (0 = positivo, 1 = negativo)
    
    testq   %rax, %rax          # Testa se o número é negativo
    jns     .L_pl_conv          # Se for positivo (Jump if Not Sign), jump
    movq    $1, %r8             # Seta flag de negativo = 1
    negq    %rax                # Transforma o número em positivo (complemento de 2)

.L_pl_conv:
    movq    $10, %rbx           # %rbx = divisor (10) para extrair os dígitos decimais
    testq   %rax, %rax          # Testa se o número é zero
    jnz     .L_pl_loop          # Se não for zero, vai pro loop de conversão
    
    # Caso especial: o número é exatamente 0
    movb    $'0', (%rsi)        # Escreve o caractere '0'
    decq    %rsi
    jmp     .L_pl_sign          # Vai para verificação de sinal

.L_pl_loop:                     # Loop de conversão Número -> String
    testq   %rax, %rax          # Chegamos a zero?
    jz      .L_pl_sign          # Se sim, acabou de extrair os dígitos
    xorq    %rdx, %rdx          # Zera %rdx para a divisão
    divq    %rbx                # Divide %rdx:%rax por 10. Quociente vai pra %rax, Resto pra %rdx
    addb    $'0', %dl           # Converte o resto (dígito 0-9) no caractere ASCII '0'-'9'
    movb    %dl, (%rsi)         # Guarda o caractere no buffer
    decq    %rsi                # Anda para trás no buffer
    jmp     .L_pl_loop          # Repete

.L_pl_sign:
    testq   %r8, %r8            # Verifica se era negativo
    jz      .L_pl_write         # Se positivo, pula
    movb    $'-', (%rsi)        # Adiciona o sinal de '-' na frente
    decq    %rsi

.L_pl_write:
    incq    %rsi                # %rsi foi decrementado a mais, então voltamos 1 pra apontar pro início válido
    leaq    outbuf(%rip), %rdi  # %rdi = base original do buffer
    addq    $31, %rdi           # Aponta pro final do buffer
    subq    %rsi, %rdi          # Calcula o tamanho da string a ser impressa (final - início)

    # Prepara syscall write(1, rsi, rdi)
    movq    %rdi, %rdx          # %rdx = tamanho
    movq    %rsi, %rsi          # %rsi = ponteiro para o início da string
    movq    $1, %rdi            # %rdi = fd 1 (stdout / tela)
    movq    $1, %rax            # syscall 1: sys_write
    syscall

    popq    %rbx
    ret


# bool contains_equal(const char *line, int len)
# Procura o caractere '=' dentro da string. Retorna 1 se achar, 0 se não achar.
contains_equal:
    movl    %esi, %ecx          # %rcx = tamanho da string (para usar com instrução de repetição)
    movb    $'=', %al
    testq   %rcx, %rcx          # Se tamanho for 0, retona falso
    jz      .L_ce_false

    # Repeat while not equal -> Scan string byte
    repne   scasb               # Scaneia a string em %rdi procurando '%al'. Decrementa %rcx.
    
    jne     .L_ce_false         # Se terminou e não achou, pula para falso
    movq    $1, %rax            # Achou, retorna 1
    ret
.L_ce_false:
    xorq    %rax, %rax          # Não achou, retorna 0
    ret


# long my_strlen(const char *s)
# Calcula o tamanho de uma string até encontrar '\0'.
my_strlen:
    xorq    %rax, %rax          # ACC = 0
.L_sl_loop:
    cmpb    $0, (%rdi, %rax)    # Caractere em s[rax] é zero?
    je      .L_sl_done
    incq    %rax
    jmp     .L_sl_loop
.L_sl_done:
    ret
