NAME = Colleen Grace Sully

ASM = nasm
ASMFLAGS = -f elf64
CC = cc

all: $(NAME)

Colleen: Colleen.o
	$(CC) $< -o $@

Grace: Grace.o
	$(CC) $< -o $@

Sully: Sully.o
	$(CC) $< -o $@

%.o: %.s
	$(ASM) $(ASMFLAGS) $< -o $@

clean:
	rm -f *.o output Grace_kid.s Sully_*.s

fclean: clean
	rm -f $(NAME) Sully_*

re: fclean all

.PHONY: all clean fclean re
