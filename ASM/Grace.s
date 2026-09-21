section .data
filename db "Grace_kid.s", 0
write_mode db "w", 0
source db "section .data%1$cfilename db %3$cGrace_kid.s%3$c, 0%1$cwrite_mode db %3$cw%3$c, 0%1$csource db %3$c%2$s%3$c, 0%1$c%1$c%%define FILE_NAME filename%1$c%%define MODE write_mode%1$c%1$csection .text%1$c%1$cextern fopen%1$cextern fprintf%1$cextern fclose%1$c%1$c%%macro GRACE 0%1$cglobal main%1$cmain:%1$c%4$cpush rbp%1$c%4$cmov rbp, rsp%1$c%4$csub rsp, 16%1$c%4$c; this comment inside entrypoint%1$c%4$clea rdi, [rel FILE_NAME]%1$c%4$clea rsi, [rel MODE]%1$c%4$ccall fopen wrt ..plt%1$c%4$ctest rax, rax%1$c%4$cjz .open_error%1$c%1$c%4$cmov [rbp - 8], rax%1$c%1$c%4$cmov rdi, [rbp - 8]%1$c%4$clea rsi, [rel source]%1$c%4$cmov edx, 10%1$c%4$clea rcx, [rel source]%1$c%4$cmov r8d, 34%1$c%4$cmov r9d, 9%1$c%4$cxor eax, eax%1$c%4$ccall fprintf wrt ..plt%1$c%4$ctest eax, eax%1$c%4$cjs .write_error%1$c%1$c%4$cmov rdi, [rbp - 8]%1$c%4$ccall fclose wrt ..plt%1$c%4$ctest eax, eax%1$c%4$cjnz .error%1$c%1$c%4$cxor eax, eax%1$c%4$cmov rsp, rbp%1$c%4$cpop rbp%1$c%4$cret%1$c%1$c.write_error:%1$c%4$cmov rdi, [rbp - 8]%1$c%4$ccall fclose wrt ..plt%1$c%1$c.error:%1$c%4$cmov eax, 1%1$c%4$cmov rsp, rbp%1$c%4$cpop rbp%1$c%4$cret%1$c%1$c.open_error:%1$c%4$cmov eax, 1%1$c%4$cmov rsp, rbp%1$c%4$cpop rbp%1$c%4$cret%1$c%%endmacro%1$cGRACE%1$c", 0

%define FILE_NAME filename
%define MODE write_mode

section .text

extern fopen
extern fprintf
extern fclose

%macro GRACE 0
global main
main:
	push rbp
	mov rbp, rsp
	sub rsp, 16
	; this comment inside entrypoint
	lea rdi, [rel FILE_NAME]
	lea rsi, [rel MODE]
	call fopen wrt ..plt
	test rax, rax
	jz .open_error

	mov [rbp - 8], rax

	mov rdi, [rbp - 8]
	lea rsi, [rel source]
	mov edx, 10
	lea rcx, [rel source]
	mov r8d, 34
	mov r9d, 9
	xor eax, eax
	call fprintf wrt ..plt
	test eax, eax
	js .write_error

	mov rdi, [rbp - 8]
	call fclose wrt ..plt
	test eax, eax
	jnz .error

	xor eax, eax
	mov rsp, rbp
	pop rbp
	ret

.write_error:
	mov rdi, [rbp - 8]
	call fclose wrt ..plt

.error:
	mov eax, 1
	mov rsp, rbp
	pop rbp
	ret

.open_error:
	mov eax, 1
	mov rsp, rbp
	pop rbp
	ret
%endmacro
GRACE
