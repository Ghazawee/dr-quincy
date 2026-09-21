# Dr Quine Assembly Cheat Sheet

This is the fast study sheet for ASM/Colleen.s, ASM/Grace.s, and ASM/Sully.s.

## 1. Rules to memorize

1. Registers hold bit patterns. The same bits may represent an integer, character code, pointer, or address.
2. Square brackets mean memory access.
3. lea calculates an address. It does not read the bytes at that address.
4. call pushes a return address and jumps. ret reads that address and jumps back.
5. The first six integer or pointer arguments use rdi, rsi, rdx, rcx, r8, and r9.
6. r10 is caller-saved scratch storage. A function call may overwrite it.
7. Clear eax before these variadic C library calls with xor eax, eax.

## 2. Register sizes

| Name | Size | Project use |
|---|---:|---|
| rax | 64 bits | Return value and temporary |
| eax | Low 32 bits of rax | Integer result and counter values |
| rbp | 64 bits | Stable stack-frame anchor |
| rsp | 64 bits | Current top of the stack |
| r10 | 64 bits | Temporary stack-argument copy |
| r10d | Low 32 bits of r10 | 32-bit counter view |

Writing a 32-bit register clears the upper half:

~~~asm
mov r10d, 4
~~~

Afterward, r10 equals 0x0000000000000004.

## 3. byte, word, dword, qword

| Keyword | Bits | Bytes |
|---|---:|---:|
| byte | 8 | 1 |
| word | 16 | 2 |
| dword | 32 | 4 |
| qword | 64 | 8 |

dword means doubleword. It is an operand-size description, not a C type.

~~~asm
mov dword [rbp - 4], 5
~~~

Meaning:

~~~text
mov       copy a value
dword     copy 4 bytes
[rbp-4]   memory at address rbp-4
5         immediate value
~~~

NASM needs dword because a bare memory destination does not specify whether the operation is 1, 2, 4, or 8 bytes.

~~~asm
mov [rbp - 4], eax     ; size inferred from eax: 4 bytes
mov [rbp - 16], rax    ; size inferred from rax: 8 bytes
dec dword [rbp - 4]    ; size required because memory has no register
~~~

## 4. mov, brackets, and lea

~~~text
mov rax, rbx       copy the value in rbx
mov rax, [rbx]     read memory at the address in rbx
mov [rbx], rax     write rax into memory at the address in rbx
lea rax, [label]   put the address of label into rax
~~~

Sully uses:

~~~asm
lea rsi, [rel source]
~~~

because fprintf needs a pointer to the source text.

This is different:

~~~asm
mov rsi, [rel source]
~~~

It reads the first 8 bytes stored inside source and treats those text bytes as a numeric value. That is not the address of the string and can cause a crash.

## 5. Stack frame trace

Sully starts with:

~~~asm
push rbp
mov rbp, rsp
sub rsp, 32
~~~

Illustrative addresses:

~~~text
entry:
    rsp = 0x7ff8
    [rsp] = return address

push rbp:
    rsp = 0x7ff0
    [0x7ff0] = caller's old rbp

mov rbp, rsp:
    rbp = 0x7ff0
    rsp = 0x7ff0

sub rsp, 32:
    rbp = 0x7ff0
    rsp = 0x7fd0
    32 bytes are owned by this function
~~~

Current Sully layout:

~~~text
[rbp + 8]    return address
[rbp + 0]    saved old rbp
[rbp - 4]    4-byte counter
[rbp - 16]   8-byte FILE pointer
[rbp - 32]   current rsp, outgoing argument area
~~~

The epilogue:

~~~asm
mov rsp, rbp
pop rbp
ret
~~~

First, mov rsp, rbp discards the local area. Then pop rbp loads the saved old rbp from memory and increases rsp by 8. Finally ret consumes the return address.

## 6. Argument locations

~~~text
argument 1  -> rdi
argument 2  -> rsi
argument 3  -> rdx
argument 4  -> rcx
argument 5  -> r8
argument 6  -> r9
argument 7  -> [rsp]
argument 8  -> [rsp + 8]
argument 9  -> [rsp + 16]
argument 10 -> [rsp + 24]
~~~

The stack offsets above are measured immediately before call. Inside the callee, call has pushed the return address, so the first stack argument is at [rsp + 8].

r10 and r11 are scratch registers, not argument number 7 and 8.

## 7. Why mov [rsp], r10?

rsp contains an address. Brackets mean memory at that address.

~~~asm
mov [rsp], r10
~~~

means:

~~~text
store the 8-byte value in r10 into memory at the address in rsp
~~~

This would corrupt the stack:

~~~asm
mov rsp, r10
~~~

because it replaces the stack pointer itself.

The choice of r10 is not caused by rsp being a pointer. Any suitable temporary register could provide the value. r10 is used because it is caller-saved scratch storage. The full r10 is stored because stack argument slots are 8 bytes wide.

## 8. fprintf mapping in Sully

Conceptually:

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

The source placeholder %5$d means the fifth value after the format string. It is the counter in the first stack argument slot.

## 9. Sully counter

~~~text
original: Sully_5.s absent -> keep 5 -> create and run Sully_5
child 5:  Sully_5.s exists -> decrement to 4 -> create and run Sully_4
child 4:  decrement to 3 -> create and run Sully_3
child 3:  decrement to 2 -> create and run Sully_2
child 2:  decrement to 1 -> create and run Sully_1
child 1:  decrement to 0 -> create and run Sully_0
child 0:  decrement to -1 -> stop
~~~

The program containing zero still runs. It detects the marker, decrements to
negative one, and does not create Sully_-1.s.

Assembly decision block:

~~~asm
lea rdi, [rel first_source] ; path: Sully_5.s
xor esi, esi              ; F_OK = 0
call access wrt ..plt     ; eax = 0 if it exists
test eax, eax
jnz .not_child            ; missing marker: keep 5
dec dword [rbp - 4]       ; marker exists: child, decrement
.not_child:
cmp dword [rbp - 4], 0
jl .done
~~~

`.not_child` is only a label. It is not a function and it does not call
anything. `jnz` jumps over `dec` for the original execution.

Use jl, not jle, because zero is valid and only a negative value should stop the chain.

## 10. Storage choices

Current stack-local design:

~~~asm
mov dword [rbp - 4], 5
mov [rbp - 16], rax
~~~

Valid static alternative:

~~~asm
section .bss
file_ptr resq 1
counter  resd 1

mov [file_ptr], rax
mov dword [counter], 5
dec dword [counter]
~~~

resb 8 is also valid for one pointer. resq 1 is clearer because it says one quadword. resb 4 is valid for the counter, while resd 1 is clearer for one doubleword.

Do not use the filename buffer for the FILE pointer:

~~~asm
mov [filename], rax
~~~

filename contains text such as Sully_4.s. This would overwrite the text with binary pointer bytes.

The current code uses [rbp - 16], not [rsp - 8]. After sub rsp, 32:

~~~text
rbp = 0x7ff0
rsp = 0x7fd0

[rbp - 16] = [0x7fe0]   inside the allocated frame
[rsp - 8]  = [0x7fc8]   outside the allocated frame
~~~

## 11. Checks to remember

- fopen returns NULL on failure, so test rax and use jz.
- snprintf returns a negative value on error.
- snprintf returning at least the capacity means truncation occurred.
- fclose before NASM ensures buffered output is flushed.
- && stops the child command when an earlier command fails.
- system's result must be checked.
- Do not trust the counter only in r10 across a function call.
- Keep the stack aligned before calls.

## 12. Exercise checklist

### Colleen

- Exact output equals the source.
- Required helper function exists and is called.
- Both required comments are reproduced.
- Program returns zero.

### Grace

- Logic is inside a NASM macro.
- Macro is invoked.
- Grace_kid.s is created.
- Generated file reproduces the source.
- The macro requirement is satisfied without relying on a normal handwritten main body.

### Sully

- Counter starts at 5.
- Original execution creates Sully_5.s.
- Generated children detect Sully_5.s and then decrement the counter.
- Sully_5.s through Sully_0.s are created.
- Sully_-1.s is not created.
- Generated source is closed before assembly.
- Formatting and child-command errors are checked.
- Temporary object files are removed.
