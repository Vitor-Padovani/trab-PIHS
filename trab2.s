    # --- SEÇÃO DE DADOS (Strings estáticas e constantes) ---
    .section .rodata
fmt_echo:
    .string "Lido (%d bytes): %s\n"   # Usaremos isso apenas para testar a Etapa 1

    # --- SEÇÃO BSS (Variáveis não inicializadas) ---
    .section .bss
    .align 32
line:
    .space 256                      # char line[MAX_LINE]

    # --- SEÇÃO DE TEXTO (Código) ---
    .text
    .globl main
    .type main, @function

main:
    # Prólogo da função main
    pushq   %rbp
    movq    %rsp, %rbp
    
    # Vamos precisar do stdin. O gcc linka isso externamente.
    # No x86_64 linux, 'stdin' é acessado via RIP-relative.

.L_main_loop:
    # Chama fgets(line, 256, stdin)
    leaq    line(%rip), %rdi        # 1º arg: buffer (line)
    movl    $256, %esi              # 2º arg: tamanho (256)
    movq    stdin(%rip), %rdx       # 3º arg: ponteiro FILE *stdin
    call    fgets@PLT               # Chamada à libc

    # Se fgets retornar 0 (NULL), fim do arquivo (Ctrl+D)
    testq   %rax, %rax
    jz      .L_main_end

    # Chama strlen(line)
    leaq    line(%rip), %rdi
    call    strlen@PLT
    movl    %eax, %r12d             # %r12d = len (vamos usar r12 pois é callee-saved)

.L_strip_newline:
    # while (len > 0 && (line[len - 1] == '\n' || line[len - 1] == '\r'))
    testl   %r12d, %r12d
    jle     .L_check_empty          # se len <= 0, sai do loop de strip

    leaq    line(%rip), %rbx        # %rbx = base de line
    movl    %r12d, %ecx
    decl    %ecx                    # len - 1
    movsbl  (%rbx, %rcx, 1), %edx   # %edx = line[len - 1]

    cmpl    $10, %edx               # é '\n'?
    je      .L_do_strip
    cmpl    $13, %edx               # é '\r'?
    je      .L_do_strip
    jmp     .L_check_empty          # se não for nenhum, terminou de limpar

.L_do_strip:
    # line[--len] = '\0'
    decl    %r12d                   # len--
    movb    $0, (%rbx, %r12, 1)     # line[len] = '\0'
    jmp     .L_strip_newline        # repete o loop

.L_check_empty:
    # if (len == 0) continue;
    testl   %r12d, %r12d
    jz      .L_main_loop

    # --- TEMPORÁRIO PARA ETAPA 1 ---
    # Imprime: "Lido (len bytes): line"
    leaq    fmt_echo(%rip), %rdi    # 1º arg: formato
    movl    %r12d, %esi             # 2º arg: len
    leaq    line(%rip), %rdx        # 3º arg: line
    movl    $0, %eax                # 0 argumentos float para printf
    call    printf@PLT

    jmp     .L_main_loop            # Volta para o início do while

.L_main_end:
    # Epílogo da função main
    movl    $0, %eax                # return 0
    popq    %rbp
    ret