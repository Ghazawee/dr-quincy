#include <stdio.h>

/* This is a comment outside of any function */

void function() {

	return ;

}

int main() {
	/* This is a comment inside of main function */
	char *s = "#include <stdio.h>%1$c%1$c/* This is a comment outside of any function */%1$c%1$cvoid function() {%1$c%1$c%2$creturn ;%1$c%1$c}%1$c%1$cint main() {%1$c%2$c/* This is a comment inside of main function */%1$c%2$cchar *s = %3$c%4$s%3$c;%1$c%2$cfunction();%1$c%2$cprintf(s, 10, 9, 34, s);%1$c%2$creturn (0);%1$c}";
	function();
	printf(s, 10, 9, 34, s);
	return (0);
}