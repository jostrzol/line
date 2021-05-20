C = gcc
CFLAGS = -m32 -c -std=c99 -g

ASM = nasm
ASMFLAGS = -felf32 -g -F dwarf

LFLAGS = -m32

SRC = main.c line.asm
OBJ = main.o line.o

EXEC = line

all: $(EXEC)

$(EXEC): $(OBJ)
	$(C) $(LFLAGS) -o $@ $(OBJ)

main.o: main.c
	$(C) $(CFLAGS) main.c

line.o: line.asm
	$(ASM) $(ASMFLAGS) line.asm

clean:
	rm -rf $(OBJ) $(EXEC)