C = gcc
CFLAGS = -m32 -c -std=c99 -g

ASM = nasm
ASMFLAGS = -felf32 -g -F dwarf

LFLAGS = -m32

SRC = main.c line.asm
OBJ = main.o line.o

EXEC = line

all: 32

32: $(EXEC)

$(EXEC): $(OBJ)
	$(C) $(LFLAGS) -o $@ $(OBJ)

main.o: main.c
	$(C) $(CFLAGS) main.c

line.o: line.asm
	$(ASM) $(ASMFLAGS) line.asm

CFLAGS64 = -m64 -c -std=c99 -g
ASMFLAGS64 = -felf64 -g -F dwarf
LFLAGS64 = -m64

SRC64 = main.c line-64.asm
OBJ64 = main-64.o line-64.o

EXEC64 = line-64

64: $(EXEC64)

$(EXEC64): $(OBJ64)
	$(C) $(LFLAGS64) -o $@ $(OBJ64)

main-64.o: main.c
	$(C) $(CFLAGS64) -o main-64.o main.c

line-64.o: line-64.asm
	$(ASM) $(ASMFLAGS64) line-64.asm

clean:
	rm -rf $(OBJ) $(EXEC) $(OBJ64) $(EXEC64)