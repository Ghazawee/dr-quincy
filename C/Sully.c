#include <stdio.h>
#include <stdlib.h>

#ifndef CHILD
# define CHILD 0
#endif

int main() {
	int i = 5;
	char FileName[32];
	char command[128];
	FILE *fptr;

	i -= CHILD;
	if (i < 0)
		return (0);
	snprintf(FileName, sizeof(FileName), "Sully_%d.c", i);
	fptr = fopen(FileName, "w");
	if (!fptr)
		return (1);
	char *s = "#include <stdio.h>%1$c#include <stdlib.h>%1$c%1$c#ifndef CHILD%1$c# define CHILD 0%1$c#endif%1$c%1$cint main() {%1$c%2$cint i = %5$d;%1$c%2$cchar FileName[32];%1$c%2$cchar command[128];%1$c%2$cFILE *fptr;%1$c%1$c%2$ci -= CHILD;%1$c%2$cif (i < 0)%1$c%2$c%2$creturn (0);%1$c%2$csnprintf(FileName, sizeof(FileName), %3$cSully_%%d.c%3$c, i);%1$c%2$cfptr = fopen(FileName, %3$cw%3$c);%1$c%2$cif (!fptr)%1$c%2$c%2$creturn (1);%1$c%2$cchar *s = %3$c%4$s%3$c;%1$c%2$cfprintf(fptr, s, 10, 9, 34, s, i);%1$c%2$cfclose(fptr);%1$c%2$csnprintf(command, sizeof(command), %3$ccc -Wall -Wextra -Werror -DCHILD=1 Sully_%%d.c -o Sully_%%d && ./Sully_%%d%3$c, i, i, i);%1$c%2$cif (system(command) != 0)%1$c%2$c%2$creturn (1);%1$c%2$creturn (0);%1$c%1$c}%1$c";
	fprintf(fptr, s, 10, 9, 34, s, i);
	fclose(fptr);
	snprintf(command, sizeof(command), "cc -Wall -Wextra -Werror -DCHILD=1 Sully_%d.c -o Sully_%d && ./Sully_%d", i, i, i);
	if (system(command) != 0)
		return (1);
	return (0);

}
