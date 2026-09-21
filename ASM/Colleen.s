section .data
msg db "section .data%1$cmsg db %3$c%2$s%3$c, 0%1$c%1$c; this comment is outside of main%1$csection .text%1$c%1$cglobal main%1$cextern printf%1$c%1$cfunction:%1$c%4$cpush rbp%1$c%4$cxor eax, eax%1$c%4$ccall printf wrt ..plt%1$c%4$cxor eax, eax%1$c%4$cpop rbp%1$c%4$cret%1$c%1$cmain:%1$c%4$c; this comment is inside the main%1$c%4$cpush rbp%1$c%1$c%4$clea rdi, [rel msg]%1$c%4$cmov esi, 10%1$c%4$clea rdx, [rel msg]%1$c%4$cmov rcx, 34%1$c%4$cmov r8, 9%1$c%4$ccall function%1$c%1$c%1$c%4$cpop rbp%1$c%4$cret", 0

; this comment is outside of main
section .text

global main
extern printf

function:
	push rbp
	xor eax, eax
	call printf wrt ..plt
	xor eax, eax
	pop rbp
	ret

main:
	; this comment is inside the main
	push rbp

	lea rdi, [rel msg]
	mov esi, 10
	lea rdx, [rel msg]
	mov rcx, 34
	mov r8, 9
	call function


	pop rbp
	ret