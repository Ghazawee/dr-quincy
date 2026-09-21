# Dr Quine Assembly Guide

This guide explains the assembly code in Colleen, Grace, and Sully from zero. It focuses on the concepts needed for these exercises.

## 1. Build pipeline

NASM translates assembly source into an ELF64 object file. The C compiler driver links that object file with the C library.

~~~text
.s source -> nasm -f elf64 -> .o object file -> cc -> executable
~~~

A quine reproduces its own source without opening the source file. The programs store a format-string model of themselves and supply the special values needed to reconstruct the source.

## 2. NASM sections and directives

### .data

.data contains initialized bytes.

~~~asm
section .data
source db "text", 0
~~~

db means define bytes. The final zero is the NUL terminator expected by C string functions.

### .bss

.bss reserves uninitialized storage.

~~~asm
section .bss
filename resb 32
command  resb 256
~~~

resb 32 reserves 32 bytes. This is storage, not an instruction that runs later.

### .text

.text contains executable instructions.

~~~asm
section .text
global main
extern printf
~~~

global main exports main for the linker. extern printf tells NASM that printf exists outside this source file.

## 3. Operand sizes

~~~text
byte   = 8 bits  = 1 byte
word   = 16 bits = 2 bytes
dword  = 32 bits = 4 bytes
qword  = 64 bits = 8 bytes
~~~

dword means doubleword. It is an operand-size description, not a C type.

~~~asm
mov dword [rbp - 4], 5
~~~

Breakdown:

~~~text
mov       copy a value
dword     copy 4 bytes
[rbp-4]   memory at the address rbp-4
5         immediate value
~~~

NASM needs dword because a memory destination does not reveal its width. The assembler cannot know whether the programmer wants a byte, word, dword, or qword operation.

These sizes can be inferred from registers:

~~~asm
mov [rbp - 4], eax     ; eax makes this a 4-byte store
mov [rbp - 16], rax    ; rax makes this an 8-byte store
~~~

Memory-only arithmetic needs an explicit size:

~~~asm
dec dword [rbp - 4]
~~~

dec [rbp-4] is ambiguous.

### resb, resd, and resq

~~~asm
resb 8    ; reserve 8 bytes
resd 1    ; reserve 1 doubleword, 4 bytes
resq 1    ; reserve 1 quadword, 8 bytes
~~~

resb 8 is valid for one 64-bit pointer. resq 1 is clearer because it communicates the intended 8-byte object. resb 16 is also valid, but 8 bytes are unused.

## 4. Registers

rax is 64 bits and eax is its low 32-bit portion. r10 is 64 bits and r10d is its low 32-bit portion.

Writing a 32-bit register clears the upper half:

~~~asm
mov r10d, 4
~~~

After this:

~~~text
r10d = 0x00000004
r10  = 0x0000000000000004
~~~

This lets Sully load the 32-bit counter through r10d and store the zero-extended 64-bit value through r10.

### xor eax, eax

~~~asm
xor eax, eax
~~~

Each bit XORed with itself becomes zero. Therefore every bit in eax becomes zero. Writing eax also clears the upper half of rax, so the complete rax register becomes zero.

These exercises clear eax before variadic C library calls because the System V ABI uses al to describe floating-point vector arguments. These calls use no floating-point arguments.

## 5. Memory operands

Assume:

~~~text
rbx = 0x5000
~~~

Then:

~~~asm
mov rax, rbx
~~~

copies the number 0x5000.

~~~asm
mov rax, [rbx]
~~~

reads the bytes stored at address 0x5000.

~~~asm
mov [rbx], rax
~~~

writes rax to address 0x5000.

Square brackets mean dereference an address.

### lea

~~~asm
lea rdx, [rel source]
~~~

calculates the address of source and puts that address in rdx. It does not read source.

~~~asm
mov rdx, [rel source]
~~~

reads the first 8 bytes stored inside source. If source begins with text such as section, those character bytes become a large number, not a pointer to the string. A library call receiving that as a pointer may crash.

This is why Sully uses:

~~~asm
lea rsi, [rel source]    ; pass address of the source bytes
mov rdi, [rbp - 16]     ; retrieve the FILE pointer value
~~~

### rel and wrt ..plt

rel forms a position-relative reference to a label.

~~~asm
lea rdi, [rel filename]
~~~

wrt ..plt asks NASM to make an external function call through the position-independent procedure linkage table.

~~~asm
call snprintf wrt ..plt
~~~

## 6. Stack and function frames

The stack stores return addresses, saved registers, local variables, and extra arguments. On x86-64 it grows toward lower addresses.

### call

Conceptually:

~~~text
rsp = rsp - 8
[rsp] = address of the next instruction
jump to the called function
~~~

### ret

Conceptually:

~~~text
jump to the address at [rsp]
rsp = rsp + 8
~~~

### Sully prologue

~~~asm
push rbp
mov rbp, rsp
sub rsp, 32
~~~

Use illustrative addresses:

~~~text
Entry:
    rsp = 0x7ff8
    [rsp] = return address

After push rbp:
    rsp = 0x7ff0
    [0x7ff0] = caller's old rbp

After mov rbp, rsp:
    rbp = 0x7ff0
    rsp = 0x7ff0
    rbp is now a stable anchor

After sub rsp, 32:
    rbp = 0x7ff0
    rsp = 0x7fd0
    32 bytes are owned by this function
~~~

Current Sully layout:

~~~text
[rbp + 8]    return address
[rbp + 0]    saved old rbp
[rbp - 4]    dword counter
[rbp - 16]   qword FILE pointer
[rbp - 32]   current rsp and outgoing argument slot
~~~

### Epilogue

~~~asm
mov rsp, rbp
pop rbp
ret
~~~

mov rsp, rbp returns rsp to the frame anchor and discards the local area.

pop rbp does two things:

1. Reads the 8 bytes at [rsp] into rbp.
2. Adds 8 to rsp.

It does not pop into rsp. The stack pointer advances because pop removes one stack slot.

ret then consumes the return address. Without mov rsp, rbp, ret could read a local variable or outgoing argument as an address.

## 7. System V AMD64 arguments

The first six integer and pointer arguments use:

~~~text
argument 1 -> rdi
argument 2 -> rsi
argument 3 -> rdx
argument 4 -> rcx
argument 5 -> r8
argument 6 -> r9
~~~

Arguments 7 and later use 8-byte stack slots:

~~~text
argument 7  -> [rsp]
argument 8  -> [rsp + 8]
argument 9  -> [rsp + 16]
argument 10 -> [rsp + 24]
~~~

These offsets are measured immediately before call. Inside the callee, call has pushed the return address, so the first stack argument is at [rsp + 8].

r10 and r11 are scratch registers, not argument number 7 and 8.

### Caller-saved registers

A called function may overwrite:

~~~text
rax, rcx, rdx, rsi, rdi, r8, r9, r10, r11
~~~

Do not keep an important long-lived value only in one of these registers across a library call. Sully stores the durable counter in memory.

## 8. fprintf mapping

Sully's call is conceptually:

~~~text
fprintf(file_pointer, source_format, newline, source, quote, tab, counter)
~~~

Locations:

~~~text
rdi      FILE pointer
rsi      format string
rdx      newline
rcx      source pointer
r8       quote
r9       tab
[rsp]    counter
~~~

The source placeholder %5$d means the fifth value after the format string. It is not the fifth total function argument.

The assembly is:

~~~asm
mov r10d, [rbp - 4]
mov [rsp], r10
xor eax, eax
call fprintf wrt ..plt
~~~

rsp contains an address, so brackets write memory at that address. mov rsp, r10 would replace the stack pointer and destroy the frame.

## 9. Colleen

Colleen stores a format-string model of its own source in .data.

The model uses values such as:

~~~text
%1$c    newline
%2$s    source string itself
%3$c    quote character
%4$c    tab character
~~~

The main routine loads the values and calls the required helper:

~~~asm
lea rdi, [rel msg]
mov esi, 10
lea rdx, [rel msg]
mov rcx, 34
mov r8, 9
call function
~~~

The helper calls printf. The extra function is required by the subject. The comments outside and inside the entry point must be reproduced exactly.

## 10. Grace

Grace uses NASM's preprocessor macro:

~~~asm
%macro GRACE 0
    ; entry logic
%endmacro

GRACE
~~~

The macro body contains the program logic. The final GRACE invocation expands into that logic before NASM assembles the file.

This satisfies the requirement that execution enters through a macro. The program writes Grace_kid.s with fopen, fprintf, and fclose.

The generated file must reproduce the definitions, macro declaration, macro invocation, comments, and instructions.

## 11. Sully

Sully writes a child source file, closes it, assembles it, links it, removes the object file, and executes the child.

### Counter flow

~~~asm
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
~~~

Values:

~~~text
original program: Sully_5.s is absent -> keep 5 -> create Sully_5.s
Sully_5:          Sully_5.s exists -> decrement to 4 -> create Sully_4.s
Sully_4:          decrement to 3 -> create Sully_3.s
Sully_3:          decrement to 2 -> create Sully_2.s
Sully_2:          decrement to 1 -> create Sully_1.s
Sully_1:          decrement to 0 -> create Sully_0.s
Sully_0:          decrement to -1 -> stop
~~~

`access` checks whether `Sully_5.s` exists. The original program starts in a
clean output directory, so the file is absent and the counter remains 5. Every
generated child sees that marker file and decrements the counter once.

`xor esi, esi` passes zero as the second argument to `access`. Zero is
`F_OK`, meaning that only existence is being checked. `access` returns zero
when the file exists and a nonzero value when it does not.

`test eax, eax` sets the flags from the return value. `jnz .not_child` skips
the decrement when the return value is nonzero, which is the original-program
case. The `.not_child` label is only a jump target, not another function.

`jl` is a signed less-than jump. It allows zero and stops only after a child
decrements zero to `-1`. Therefore `Sully_0.s` is created and executed, but
`Sully_-1.s` is not created.

### snprintf

Sully prepares:

~~~asm
lea rdi, [rel filename]
mov esi, 32
lea rdx, [rel filename_format]
mov ecx, [rbp - 4]
xor eax, eax
call snprintf wrt ..plt
~~~

Arguments:

~~~text
rdi  destination buffer
rsi  destination capacity
rdx  format string
rcx  counter
~~~

The result is checked twice:

~~~asm
test eax, eax
js .error
cmp eax, 32
jae .error
~~~

A negative result means an error. A result greater than or equal to the capacity means the output did not fit and was truncated.

### FILE pointer

fopen returns a FILE pointer in rax:

~~~asm
call fopen wrt ..plt
test rax, rax
jz .error
mov [rbp - 16], rax
~~~

The current code uses [rbp - 16], not [rsp - 8].

With:

~~~text
rbp = 0x7ff0
rsp = 0x7fd0
~~~

the addresses are:

~~~text
[rbp - 16] = [0x7fe0]   inside the allocated frame
[rsp - 8]  = [0x7fc8]   outside the allocated frame
~~~

Do not use mov [filename], rax. filename is a character buffer containing text such as Sully_4.s. That instruction would overwrite the text with binary pointer bytes.

A valid static alternative is:

~~~asm
section .bss
file_ptr resq 1
counter  resd 1

mov [file_ptr], rax
mov dword [counter], 5
dec dword [counter]
~~~

resb 8 would also be valid for file_ptr. resq 1 is clearer for one 8-byte object. resb 4 would be valid for the counter, while resd 1 communicates one 32-bit object.

The current stack-local design keeps the values private to the current invocation. The static design is easier to read at first, but adds mutable static storage. It is a valid alternative, not a requirement.

### Close before compiling

fprintf may buffer output in the C library. fclose flushes the buffered bytes before NASM reads the generated source.

### Command chain

The child command uses &&:

~~~text
nasm -f elf64 Sully_4.s -o Sully_4.o &&
cc Sully_4.o -o Sully_4 &&
rm -f Sully_4.o &&
./Sully_4
~~~

If an earlier command fails, later commands do not run. The result of system is checked.

## 12. Answers to the earlier questions

### Why does the program containing zero still run?

Its parent already created and executed it. `Sully_0` sees that `Sully_5.s`
exists, decrements zero to negative one, jumps to `done`, and returns without
creating `Sully_-1.s`.

### Why does Sully check for `Sully_5.s`?

The original source and a generated child both contain the starting integer 5.
The program therefore needs a way to tell the original execution from a child
execution. Checking for the marker file provides that distinction without
using `argv`, a global counter, or a separate state variable.

### Why is r10 temporary?

r10 is caller-saved. A library function may overwrite it. The durable counter is kept in memory.

### Where does %5$d get its value?

It receives the fifth variadic value. The first four variadic values use rdx, rcx, r8, and r9. The fifth is in the first stack argument slot.

### Why close before compiling?

C output can be buffered. fclose flushes the source before NASM reads it.

### What checks prove snprintf succeeded?

The negative check rejects an error. The capacity check rejects truncation. The return value excludes the final NUL, while the capacity includes room for it.

## 13. Final checklist

### Colleen

- Output exactly matches the source.
- Required helper exists and is called.
- Both comments are reproduced.
- Program returns zero.

### Grace

- Logic is inside a macro.
- Macro is invoked.
- Grace_kid.s is created.
- Generated source matches.

### Sully

- Counter starts at 5.
- Counter decrements before the child name is created.
- Sully_4.s through Sully_0.s are produced by the current implementation.
- Sully_-1.s is not produced.
- Generated source is closed before assembly.
- snprintf and system failures are checked.
- Object files are removed.
- Stack alignment and argument locations are correct.
