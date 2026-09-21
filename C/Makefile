NAME = Colleen Grace Sully

CC = cc
CFLAGS = -Wall -Wextra -Werror

all: $(NAME)

Colleen: Colleen.c
	$(CC) $(CFLAGS) $< -o $@

Grace: Grace.c
	$(CC) $(CFLAGS) $< -o $@

Sully: Sully.c
	$(CC) $(CFLAGS) $< -o $@

clean:
	rm -f Grace_kid.c Sully_*.c

fclean: clean
	rm -f $(NAME) Sully_*

re: fclean all

.PHONY: all clean fclean re
