#include <stdio.h>
#define FILE_NAME "Grace_kid.c"
#define String "#include <stdio.h>%1$c#define FILE_NAME %3$cGrace_kid.c%3$c%1$c#define String%2$c%3$c%4$s%3$c%1$c#define GRACE int main(void) {FILE *fptr =fopen(FILE_NAME, %3$cw%3$c); if (!fptr) return (1); fprintf(fptr, String, 10, 32, 34, String); fclose(fptr); return (0); }%1$c%1$c/* This is a comment before Macro invoking */%1$c%1$cGRACE"
#define GRACE int main(void) {FILE *fptr =fopen(FILE_NAME, "w"); if (!fptr) return (1); fprintf(fptr, String, 10, 32, 34, String); fclose(fptr); return (0); }

/* This is a comment before Macro invoking */

GRACE