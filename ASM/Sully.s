section .bss
filename resb 32
command resb 256

section .data
first_source db "Sully_5.s", 0
write_mode db "w", 0
filename_format db "Sully_%d.s", 0
command_format db "p=Sully_%d; nasm -f elf64 $p.s -o $p.o && cc $p.o -o $p && rm -f $p.o && ./$p", 0
source db "section .bss%1$cfilename resb 32%1$ccommand resb 256%1$c%1$csection .data%1$cfirst_source db %3$cSully_5.s%3$c, 0%1$cwrite_mode db %3$cw%3$c, 0%1$cfilename_format db %3$cSully_%%d.s%3$c, 0%1$ccommand_format db %3$cp=Sully_%%d; nasm -f elf64 $p.s -o $p.o && cc $p.o -o $p && rm -f $p.o && ./$p%3$c, 0%1$csource db %3$c%2$s%3$c, 0%1$c%1$csection .text%1$c%1$cglobal main%1$cextern access%1$cextern snprintf%1$cextern fopen%1$cextern fprintf%1$cextern fclose%1$cextern system%1$c%1$cmain:%1$c%4$cpush rbp%1$c%4$cmov rbp, rsp%1$c%4$csub rsp, 32%1$c%1$c%4$cmov dword [rbp - 4], %5$d%1$c%4$clea rdi, [rel first_source]%1$c%4$cxor esi, esi%1$c%4$ccall access wrt ..plt%1$c%4$ctest eax, eax%1$c%4$cjnz .not_child%1$c%4$cdec dword [rbp - 4]%1$c%1$c.not_child:%1$c%4$ccmp dword [rbp - 4], 0%1$c%4$cjl .done%1$c%1$c%4$clea rdi, [rel filename]%1$c%4$cmov esi, 32%1$c%4$clea rdx, [rel filename_format]%1$c%4$cmov ecx, [rbp - 4]%1$c%4$cxor eax, eax%1$c%4$ccall snprintf wrt ..plt%1$c%4$ctest eax, eax%1$c%4$cjs .error%1$c%4$ccmp eax, 32%1$c%4$cjae .error%1$c%1$c%4$clea rdi, [rel filename]%1$c%4$clea rsi, [rel write_mode]%1$c%4$ccall fopen wrt ..plt%1$c%4$ctest rax, rax%1$c%4$cjz .error%1$c%4$cmov [rbp - 16], rax%1$c%1$c%4$cmov rdi, [rbp - 16]%1$c%4$clea rsi, [rel source]%1$c%4$cmov edx, 10%1$c%4$clea rcx, [rel source]%1$c%4$cmov r8d, 34%1$c%4$cmov r9d, 9%1$c%4$cmov r10d, [rbp - 4]%1$c%4$cmov [rsp], r10%1$c%4$cxor eax, eax%1$c%4$ccall fprintf wrt ..plt%1$c%4$ctest eax, eax%1$c%4$cjs .write_error%1$c%1$c%4$cmov rdi, [rbp - 16]%1$c%4$ccall fclose wrt ..plt%1$c%4$ctest eax, eax%1$c%4$cjnz .error%1$c%1$c%4$clea rdi, [rel command]%1$c%4$cmov esi, 256%1$c%4$clea rdx, [rel command_format]%1$c%4$cmov ecx, [rbp - 4]%1$c%4$cxor eax, eax%1$c%4$ccall snprintf wrt ..plt%1$c%4$ctest eax, eax%1$c%4$cjs .error%1$c%4$ccmp eax, 256%1$c%4$cjae .error%1$c%1$c%4$clea rdi, [rel command]%1$c%4$ccall system wrt ..plt%1$c%4$ctest eax, eax%1$c%4$cjnz .error%1$c%1$c.done:%1$c%4$cxor eax, eax%1$c%4$cmov rsp, rbp%1$c%4$cpop rbp%1$c%4$cret%1$c%1$c.write_error:%1$c%4$cmov rdi, [rbp - 16]%1$c%4$ccall fclose wrt ..plt%1$c%1$c.error:%1$c%4$cmov eax, 1%1$c%4$cmov rsp, rbp%1$c%4$cpop rbp%1$c%4$cret%1$c", 0

section .text

global main
extern access
extern snprintf
extern fopen
extern fprintf
extern fclose
extern system

main:
	push rbp
	mov rbp, rsp
	sub rsp, 32

	mov dword [rbp - 4], 5
	lea rdi, [rel first_source]
	xor esi, esi
	call access wrt ..plt
	test eax, eax
	jnz .not_child
	dec dword [rbp - 4]

.not_child:
	cmp dword [rbp - 4], 0
	jl .done

	lea rdi, [rel filename]
	mov esi, 32
	lea rdx, [rel filename_format]
	mov ecx, [rbp - 4]
	xor eax, eax
	call snprintf wrt ..plt
	test eax, eax
	js .error
	cmp eax, 32
	jae .error

	lea rdi, [rel filename]
	lea rsi, [rel write_mode]
	call fopen wrt ..plt
	test rax, rax
	jz .error
	mov [rbp - 16], rax

	mov rdi, [rbp - 16]
	lea rsi, [rel source]
	mov edx, 10
	lea rcx, [rel source]
	mov r8d, 34
	mov r9d, 9
	mov r10d, [rbp - 4]
	mov [rsp], r10
	xor eax, eax
	call fprintf wrt ..plt
	test eax, eax
	js .write_error

	mov rdi, [rbp - 16]
	call fclose wrt ..plt
	test eax, eax
	jnz .error

	lea rdi, [rel command]
	mov esi, 256
	lea rdx, [rel command_format]
	mov ecx, [rbp - 4]
	xor eax, eax
	call snprintf wrt ..plt
	test eax, eax
	js .error
	cmp eax, 256
	jae .error

	lea rdi, [rel command]
	call system wrt ..plt
	test eax, eax
	jnz .error

.done:
	xor eax, eax
	mov rsp, rbp
	pop rbp
	ret

.write_error:
	mov rdi, [rbp - 16]
	call fclose wrt ..plt

.error:
	mov eax, 1
	mov rsp, rbp
	pop rbp
	ret
