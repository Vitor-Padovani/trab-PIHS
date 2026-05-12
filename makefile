# Nome do arquivo fonte (pode passar via linha de comando)
FILE ?= main
SRC = $(FILE).s
OUT = a

# Compilar
build:
	gcc -g $(SRC) -o $(OUT)

# Executar normalmente
run: build
	./$(OUT)

# Executar GDB com comandos automáticos
debug: build
	gdb -ex "set debuginfod enabled off" \
	    -ex "break main" \
	    -ex "run" \
	    -ex "layout regs" \
	    ./$(OUT)

# Limpar arquivos gerados
clean:
	rm -f $(OUT)
