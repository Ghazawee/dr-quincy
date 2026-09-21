# dr-quine notes

These notes explain the Assembly and formatted-output ideas used in this project.
The Assembly files use NASM syntax for 64-bit Linux (ELF64) and the System V
AMD64 calling convention.

## What a `.s` file becomes

The build has two separate stages:

1. NASM reads `Colleen.s` and translates Assembly instructions into machine-code
   bytes inside `Colleen.o`.
2. `cc` links `Colleen.o` with the C standard library and creates the executable
   `Colleen`.

`cc` is used at the second stage even though the source is Assembly. In this
project it acts as the linker driver and brings in libc, where `printf` exists.
NASM performs the actual Assembly step.

## Sections and declarations

```asm
section .data
msg db "...", 0
```

`.data` is for initialized data. `db` means â€œdefine bytesâ€. The characters in
the quoted string are stored as bytes, and the final `0` adds a NUL byte. C
library string functions use that NUL byte to know where a string ends.

```asm
section .text
```

`.text` contains executable instructions. The operating system maps this area
as code when the program is loaded.

```asm
global main
extern printf
```

`global main` exports the `main` label so the linker can find the program's
entry function. `extern printf` tells NASM that `printf` is supplied by another
object/library; it does not define `printf` in this file.

Labels such as `main:`, `function:`, and `msg` are names for addresses. A label
does not itself execute an instruction. Execution reaches a code label by
falling through to it or by jumping/calling it.

## Registers used here

Registers are tiny, very fast storage locations inside the CPU. The names used
by this program are:

| Register | Use in this project |
| --- | --- |
| `rax` | Function return value; its low byte `al` is also used for variadic calls |
| `rsp` | Current stack pointer |
| `rbp` | A preserved register commonly used as a stack-frame base |
| `rdi` | First function argument |
| `rsi` | Second function argument |
| `rdx` | Third function argument |
| `rcx` | Fourth function argument |
| `r8` | Fifth function argument |
| `r9` | Sixth function argument |
| `rip` | CPU instruction pointer; it holds the address of the next instruction |

For integer and pointer arguments on Linux x86-64, the first six arguments go
in `rdi`, `rsi`, `rdx`, `rcx`, `r8`, and `r9`. The first argument is the format
string for `printf`, so the format pointer goes in `rdi`; the values used by
the format string start in `rsi`.

The names are different views of the same register. `rax` is 64 bits, `eax` is
its low 32 bits, and `al` is its low 8 bits. Writing a 32-bit register such as
`eax` automatically clears the upper 32 bits of its 64-bit register. Therefore:

```asm
xor eax, eax
```

sets all of `rax` to zero, including `al`. XOR returns zero when both operands
are identical, so XORing `eax` with itself is a compact way to clear it.

`mov esi, 10` is enough for the integer value `10`; writing `esi` also clears
the unused upper half of `rsi`. A pointer, however, must use the full 64-bit
register. This is why the address instruction uses `rdx`, not `edx`:

```asm
lea rdx, [rel msg]
```

Using `edx` would keep only 32 address bits and could turn a valid 64-bit
pointer into an invalid address.

## The stack and function calls

The stack is memory managed by `rsp`. On x86-64 the stack grows toward lower
addresses:

```asm
push rbp
```

decreases `rsp` and stores the old `rbp` value at the new top of the stack.
This preserves the caller's `rbp` value. In this project we do not create a
full frame with `mov rbp, rsp`; we only save and restore `rbp` and use the push
to keep the call stack correctly aligned.

```asm
pop rbp
```

reads the saved value from the top of the stack, puts it back into `rbp`, and
increases `rsp`. It must be `pop rbp`, not `pop rsp`: changing `rsp` would move
the stack away from the saved return address and could make `ret` jump to an
invalid location.

```asm
call function
```

pushes the address of the instruction after the call onto the stack, then
jumps to `function`. The called function eventually returns with:

```asm
ret
```

`ret` takes that saved address from the stack and puts it into `rip`, continuing
execution after the original `call`.

The `push rbp`/`pop rbp` pairs also matter for stack alignment. The System V
AMD64 ABI requires the stack to be aligned before a call. Saving `rbp` changes
the stack by eight bytes, and each `call` temporarily pushes another eight-byte
return address. The pairs are balanced before each function returns.

## Addressing `msg`

```asm
lea rdi, [rel msg]
```

`lea` means â€œload effective addressâ€. It places the address of `msg` in `rdi`;
it does not load the characters stored at `msg`.

`rel` requests RIP-relative addressing. The resulting instruction means â€œfind
`msg` relative to the current instruction addressâ€, which works correctly when
the executable is loaded at a different address. The brackets describe a
memory-address calculation; `lea` receives the calculated address rather than
the data at that address.

```asm
call printf wrt ..plt
```

`printf` is external, so the final address is resolved by the linker. `wrt ..plt`
tells NASM to call the ELF Procedure Linkage Table entry. The PLT is the normal
ELF mechanism for calling a function supplied by a shared library such as
libc. It is not a second function written in this project.

## Why `xor eax, eax` is before `printf`

`printf` is variadic: after its required format pointer, it accepts a variable
number of arguments. Under the System V AMD64 ABI, the low byte `al` tells a
variadic function how many vector/SSE registers contain floating-point
arguments. This program passes only integers and pointers, so `al` must be
zero before calling `printf`.

```asm
xor eax, eax
call printf wrt ..plt
```

The `xor` before the call sets `al` to zero. The later `xor eax, eax` makes the
Assembly function's integer return value zero, equivalent to returning `0` in
C. `main` also returns through `rax`; its final value is zero in this program.

## Positional `printf` conversions

The format string in `msg` contains text such as:

```text
%1$c
%2$s
%3$c
%4$c
```

The `printf` format syntax is `%argument_number$conversion`:

| Conversion | Meaning |
| --- | --- |
| `%1$c` | Use variadic argument 1 as an integer character value |
| `%2$s` | Use variadic argument 2 as a pointer to a NUL-terminated string |
| `%3$c` | Use variadic argument 3 as an integer character value |
| `%4$c` | Use variadic argument 4 as an integer character value |

The number is one-based and counts arguments after the format pointer. It is
not an Assembly variable and it is not substituted by NASM. `printf` interprets
it at runtime.

The Assembly call prepares the arguments like this:

```asm
lea rdi, [rel msg]      ; printf format: argument before the variadic ones
mov esi, 10             ; variadic argument 1: newline (`%1$c`)
lea rdx, [rel msg]      ; variadic argument 2: the source string (`%2$s`)
mov rcx, 34             ; variadic argument 3: double quote (`%3$c`)
mov r8, 9               ; variadic argument 4: tab (`%4$c`)
call function
```

`function` calls `printf` without changing those argument registers, so
`printf` receives the same mapping. The output reconstructs the source:

- `10` creates line breaks.
- `34` creates `"` characters around the embedded source string.
- `9` creates tab indentation.
- The pointer to `msg` inserts the format string inside its own definition.

The same positional argument must not be used as incompatible types. For
example, using `%2$s` and `%2$c` for the same argument is invalid: one use says
the value is a pointer, while the other says it is an integer. A variadic
library function has no ordinary type metadata to repair that contradiction;
it can read the wrong number/interpretation of bytes, causing corrupted output
or a segmentation fault. That is why the string argument uses `%2$s` and the
tab uses `%4$c`.

## `printf`, `fprintf`, and `snprintf`

All three functions interpret their format string using the same conversion
rules, including `%d`, `%c`, `%s`, and positional forms such as `%1$c`.

### `printf`

```c
printf(format, arguments...);
```

`printf` formats its result and writes it to standard output, normally the
terminal. It does not automatically write a file.

### `fprintf`

```c
fprintf(stream, format, arguments...);
```

`fprintf` is the file/stream version of `printf`. Its first argument is a
`FILE *`, such as the pointer returned by `fopen`; its second argument is the
format string. In Grace and Sully, `fprintf` writes the reconstructed source
into the generated file.

### `snprintf`

```c
snprintf(destination, capacity, format, arguments...);
```

`snprintf` formats into a character array instead of directly printing. The
capacity prevents it from writing past the destination buffer. If the formatted
result does not fit, it writes a truncated NUL-terminated string when the
capacity is nonzero.

Its return value is the number of characters that would have been produced,
not counting the final NUL byte. Therefore, a return value greater than or equal
to the capacity means truncation occurred.

Sully uses it for values that change on each generation:

```c
snprintf(FileName, sizeof(FileName), "Sully_%d.c", i);
snprintf(command, sizeof(command), "cc ... Sully_%d ...", i);
```

`%d` is replaced by the current counter. `sizeof(FileName)` is the total byte
capacity of that local array, so it lets `snprintf` enforce the boundary.

## Escaping a percent sign in a self-string

When a source string is itself passed to a formatting function, every percent
sequence inside that source string is interpreted during formatting. To make a
literal percent sign appear in the generated source, write `%%` in the format
string.

For example, the generated C source must contain:

```c
"Sully_%d.c"
```

but the outer self-string must contain:

```c
"Sully_%%d.c"
```

The first `%` of `%%` escapes the second one, so the formatting function emits
one literal `%` and does not try to consume another argument for it.

## Makefile variables used for Assembly

```make
ASM = nasm
ASMFLAGS = -f elf64
CC = cc
```

`ASM` names the assembler, and `ASMFLAGS` contains assembler options. `-f elf64`
selects 64-bit ELF object output for Linux. `CC` names the compiler driver used
to link the object file with libc.

`CFLAGS` such as `-Wall -Wextra -Werror` are intended for compiling C source
files. They are not needed to assemble `.s` files. The Assembly Makefile uses
`nasm` for the source-to-object step and `cc` only for the object-to-executable
link step.

The pattern rule:

```make
%.o: %.s
	$(ASM) $(ASMFLAGS) $< -o $@
```

means that any `.o` file can be built from the matching `.s` file. `$<` means
the first prerequisite (`Colleen.s`, for example), and `$@` means the target
being built (`Colleen.o`).

## Linker warning about `.note.GNU-stack`

If NASM does not emit a `.note.GNU-stack` section, the linker may warn that the
object implies an executable stack. This is a security/deprecation warning; it
does not mean that the generated quine output is wrong. The program can still
compile and run. Adding the note is a normal way to declare that the program
does not need an executable stack, but it is separate from the self-reproducing
logic.

## Tomorrow's remaining work: Grace and Sully

The PDF's mandatory requirements are different for these two programs:

| Program | Assembly-specific constraints |
| --- | --- |
| Grace | One entry point only, exactly three macros or the closest assembler equivalent, exactly one comment, and write the source to `Grace_kid.s` |
| Sully | Start with an integer equal to `5`, decrement it before the check, create `Sully_X.s`, compile it, and execute the generated program only while `X >= 0` |

The following sections describe the concepts and build order without giving a
finished submission file.

## Important: Grace's macro and the Assembly entry point

The PDF places the â€œthe program will run by calling a macroâ€ requirement under
Grace's **C** requirements. That is why the C version has no separately written
`main`: the macro invocation expands into the `main` definition.

The Assembly requirements are listed separately. They require an entry point,
exactly three macros (or the closest assembler equivalent), one comment, and no
extra user-written routines. Because the current build links with `cc`, the
linker needs a symbol named `main` unless a different startup arrangement is
used. Therefore, an Assembly Grace still needs a `main` entry point somehow.

There are two ways to arrange that:

1. Write `global main` and `main:` directly, then use the three macros for
   constants such as newline, quote, and indentation. This satisfies the
   Assembly bullet list literally; its entry point is the `main` label.
2. Define one NASM macro whose expansion contains the `main:` entry point and
   its body, invoke that macro once, and use the other two macros for constants.
   In this design the macro invocation generates `main`; it does not make a
   runtime `call main`.

For the second design, the important distinction is:

```asm
%macro GRACE 0
main:
    ; entry-point instructions go here
%endmacro

GRACE
```

NASM expands `GRACE` before assembly. The CPU never calls a macro and does not
know that one existed. The expansion simply leaves a normal `main` label and
instructions for the linker. If using this design, count the `%macro` as one
macro and make sure the total remains exactly three. Do not accidentally add a
fourth convenience macro.

The `%` characters in `%macro`, `%endmacro`, and `%define` are literal text in
the generated source. If the outer `fprintf` format string must emit them, use
`%%macro`, `%%endmacro`, and `%%define` inside that outer format string. This is
different from a conversion such as `%1$c`, which the outer `fprintf` is meant
to interpret.

## NASM macros for Grace

NASM has a preprocessor. A `%define` creates a text substitution before the
assembler processes instructions:

```asm
%define NEWLINE 10
%define QUOTE 34
%define MODE_W 9

mov esi, NEWLINE
```

The preprocessor changes the last line conceptually into `mov esi, 10`; the
CPU never sees the name `NEWLINE`. These three `%define` lines are a simple
choice for Grace's required â€œexactly three macrosâ€. Do not add helper `%define`
lines for convenience, because the subject says exactly three.

The definitions also have to appear in the source reproduced by the program.
Writing `%define` inside the `msg db "..."` string does not execute it or create
another macro; it is merely text that `fprintf` later writes into `Grace_kid.s`.

If you choose the direct-`main` design, three `%define` constants are a simple
way to reach the exact macro count. If you choose the macro-generated-entry
design, one `%macro` for the entry point plus two `%define` constants reaches
the same count. Choose one design before building the self-string, because the
macro lines and their position must also be reproduced exactly.

Grace has no counter and therefore does not need dynamic `%d` output. A useful
mapping can stay within the first three variadic arguments:

```text
%1$c = newline
%2$c = quote
%3$s = source string
```

The exact names and layout are yours to choose. The important part is that every
placeholder's type matches the register value supplied to `fprintf`.

## File-writing calls needed by Grace

Grace must create a file; printing to standard output is not enough. The libc
functions have these C signatures:

```c
FILE *fopen(const char *path, const char *mode);
int   fprintf(FILE *stream, const char *format, ...);
int   fclose(FILE *stream);
```

Their Assembly argument registers are:

| Call | `rdi` | `rsi` | `rdx` | `rcx` | Return in `rax` |
| --- | --- | --- | --- | --- | --- |
| `fopen` | path | mode | â€” | â€” | `FILE *`, or `NULL` on failure |
| `fprintf` | `FILE *` | format/source | first variadic value | second variadic value | number written, or negative on error |
| `fclose` | `FILE *` | â€” | â€” | â€” | zero on success |

For example, the beginning of the operation is conceptually:

```asm
lea rdi, [rel filename]       ; path: "Grace_kid.s"
lea rsi, [rel write_mode]     ; mode: "w"
call fopen wrt ..plt
test rax, rax                 ; did fopen return NULL?
jz .error
```

`test rax, rax` performs a bitwise AND only to set CPU flags; it does not store
the result. A NULL pointer is zero, so `jz .error` jumps when opening failed.
After a successful `fopen`, the `FILE *` in `rax` must be saved before calling
other functions, because `rax` is caller-saved and later calls may overwrite it.

## Saving a value in a stack-local slot

One way to save the `FILE *` without creating another routine is to create a
small stack frame:

```asm
push rbp
mov rbp, rsp
sub rsp, 16

mov [rbp - 8], rax       ; save the FILE * returned by fopen
mov rdi, [rbp - 8]       ; restore it as fprintf's stream argument
```

`[rbp - 8]` means memory eight bytes below the saved frame pointer. The slot is
large enough for a 64-bit pointer. Reserving 16 bytes keeps the stack aligned
for libc calls; do not subtract an arbitrary one-byte or four-byte amount just
because the local value itself is small.

After `fprintf`, load the same pointer into `rdi` and call `fclose`. At every
failure path, return a nonzero value and restore the stack before `ret`.

Grace's direct build order is:

1. Decide the exact three `%define` lines, one comment, and one entry label.
2. Put the complete source text into `msg`, including the three definitions and
   comment.
3. Add filename/mode data.
4. In the one entry point, open `Grace_kid.s` and check the returned pointer.
5. Save the pointer, call `fprintf` with the source and its reproduction
   arguments, close the file, return zero.
6. Assemble, link, run, and compare `Grace.s` with `Grace_kid.s`.

No user-written helper label such as `write_file:` should be added to Grace.
Calls to external libc functions are necessary library calls, not extra
routines defined in your Assembly source.

## Sully's counter and conditional jumps

The original Sully execution must create `Sully_5.s`, while generated children
must decrement. The program uses the existence of `Sully_5.s` as a child marker:

```asm
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
```

`access` returns zero when `Sully_5.s` exists. `test eax, eax` sets the zero
flag from that result. `jnz .not_child` skips the decrement when the marker is
missing, which is the original execution. When the marker exists, execution
falls through to `dec` and the child counter decreases by one.

`dec` subtracts one. `cmp left, right` internally computes `left - right` and
sets flags without storing the subtraction result. `jl` means signed less-than.
The original keeps `5`, generated children use `4, 3, 2, 1, 0`, and the
program stops after zero becomes `-1`.

The counter is stored in memory because ordinary caller-saved registers such as
`r10`/`r11` may be changed by `snprintf`, `fprintf`, or `system`. Before each
call, load the current integer from `[rbp - 4]` into the required argument
register. A 32-bit slot is enough for this counter.

## Buffers in `.bss`

Sully needs writable arrays for its changing filename and shell command. They
can be reserved without initial contents:

```asm
section .bss
filename resb 32
command  resb 128
```

`resb N` reserves `N` bytes. Unlike `.data`, `.bss` does not store the initial
zero bytes in the object file; the loader supplies zeroed memory. `snprintf`
will write the NUL-terminated text into these buffers.

The sizes must be large enough for the longest generated strings. If
`snprintf` returns a value greater than or equal to the capacity, truncation
occurred and the command or filename is unsafe to use.

## `snprintf` in Sully's Assembly

The relevant signature is:

```c
int snprintf(char *destination, size_t capacity,
             const char *format, ...);
```

The register mapping is:

```asm
rdi = destination buffer
rsi = destination capacity
rdx = format string
rcx = first value replacing a format conversion
xor eax, eax              ; no floating-point variadic arguments
call snprintf wrt ..plt
```

For a filename, the conceptual call is:

```text
format: "Sully_%d.s"
value:  current counter
```

For the compile/run command, the format can contain the counter several times,
for example conceptually:

```text
"nasm -f elf64 Sully_%d.s -o Sully_%d.o && cc Sully_%d.o -o Sully_%d && ./Sully_%d"
```

Supply the same counter as each corresponding variadic argument. `&&` makes
the shell run the next command only if the previous command succeeded. Pass
the finished command buffer to:

```asm
lea rdi, [rel command]
call system wrt ..plt
```

Check `system`'s return value before reporting success. If compilation fails,
the generated program must not be treated as successfully executed.

## Sully's self-string and the changing integer

Sully's source text must contain the integer value in a place that changes in
each generated source. One possible source-level design is a comment such as:

```asm
; counter = 5
```

The embedded format string would represent the changing number with `%d`, and
the `fprintf` call would supply the current counter. Because `fprintf` itself
interprets percent signs, a percent sign that must appear literally in the
generated source has to be doubled in the outer string:

```text
outer self-string:  "Sully_%%d.s"
generated source:   "Sully_%d.s"
```

The same two-level reasoning applies to every `%` appearing inside the source
being reproduced. First ask what the generated `.s` file must contain; then
escape any percent sign that the outer formatting call must emit literally.

## `fprintf` argument positions in Assembly

For Sully, the first two registers are occupied by the stream and format:

```asm
rdi = FILE *stream
rsi = source format string
rdx = variadic argument 1
rcx = variadic argument 2
r8  = variadic argument 3
r9  = variadic argument 4
```

The fifth and later variadic integer/pointer arguments are passed on the stack.
To keep the first version understandable, design the self-string with at most
four dynamic variadic values. For example, newline, quote, source pointer, and
counter fit in `rdx`, `rcx`, `r8`, and `r9`. If you choose a fifth value, stop
and account for the required stack-passed argument before calling `fprintf`;
do not put it in another random register.

Inside the format string, the positions count only the values after the format
pointer. If the four values above are newline, quote, source, and counter,
then `%1$c`, `%2$c`, `%3$s`, and `%4$d` refer to them in that order. The stream
in `rdi` and format pointer in `rsi` are not position 1 or position 2.

## Sully's complete pseudocode

Use this as the implementation checklist:

```text
enter main and create an aligned stack frame
counter = 5
if Sully_5.s exists:
    counter = counter - 1
if counter < 0:
    return 0

format filename using counter
open filename for writing
if opening failed:
    return 1

format the source with the current counter
write the source with fprintf
close the source file
if writing/closing failed:
    return 1

format the NASM + cc + execute command using counter
run it with system
if the command failed:
    return 1
return 0
```

The generated source must contain the same algorithm. The original creates
`Sully_5.s`; each child detects that marker, decrements, and creates the next
lower source. Test the chain from a clean directory and verify both the source
files and their executables until the `-1` execution stops before creating
another source.

## Detailed Grace entry-point explanation

The current Assembly Grace uses one NASM macro to generate the program entry
point. The macro is expanded by NASM before machine code is produced; the CPU
does not call a macro at runtime.

```asm
%macro GRACE 0
global main
main:
```

`%macro GRACE 0` defines a macro named `GRACE` that accepts zero arguments.
`global main` exports the `main` symbol so the `cc` linker can find it.
`main:` marks the address where the generated entry-point instructions begin.
The `GRACE` line at the end of the source invokes the macro and causes these
lines to appear in the preprocessed Assembly.

### Creating the stack frame

```asm
push rbp
mov rbp, rsp
sub rsp, 16
```

`push rbp` decreases `rsp` by eight bytes and saves the caller's old `rbp` on
the stack. `mov rbp, rsp` makes `rbp` a stable reference point for this
function's local storage. `rsp` can move during calls and stack operations;
`rbp` remains fixed until the function is finished.

`sub rsp, 16` reserves 16 bytes below `rbp`. The program uses the first eight
bytes as a local slot for the `FILE *` returned by `fopen`. The other eight
bytes also keep the stack aligned before libc calls. On the System V AMD64
ABI, the stack must be 16-byte aligned before a call. After `push rbp`,
subtracting a multiple of 16 preserves that alignment.

The relevant layout is:

```text
[rbp + 8]   return address
[rbp + 0]   saved caller rbp
[rbp - 8]   local FILE * slot
[rbp - 16]  remaining reserved space/alignment space
```

### Opening the output file

```asm
lea rdi, [rel FILE_NAME]
lea rsi, [rel MODE]
call fopen wrt ..plt
```

`FILE_NAME` and `MODE` are NASM aliases for the data labels containing
`"Grace_kid.s"` and `"w"`. `lea` loads an address, not the characters stored
at that address. `rel` requests RIP-relative addressing.

The C signature is:

```c
FILE *fopen(const char *path, const char *mode);
```

Under the Linux x86-64 calling convention:

```text
rdi = path address
rsi = mode address
rax = returned FILE * or NULL
```

`call fopen wrt ..plt` calls the external libc function through the ELF
Procedure Linkage Table. When `fopen` returns, its result is in `rax`.

### Checking `fopen`

```asm
test rax, rax
jz .open_error
```

`test rax, rax` performs an AND of `rax` with itself only to set CPU flags; it
does not change `rax`. If `rax` is zero, the Zero Flag is set. If it is not
zero, the Zero Flag is cleared.

`jz` means â€œjump if zeroâ€. Therefore, these two lines mean:

```text
if (rax == 0)
    jump to .open_error;
```

For `fopen`, zero means `NULL`, so the jump handles failure to create/open the
file. If `fopen` succeeds, execution continues with the next instruction.

### Saving the `FILE *`

```asm
mov [rbp - 8], rax
```

The successful `fopen` result is a pointer in `rax`. This instruction stores
that pointer in the local stack slot.

The brackets mean memory access:

```asm
mov [rbp - 8], rax       ; store rax into memory
mov rax, [rbp - 8]       ; load memory into rax
```

The pointer must be saved because later calls to `fprintf` and `fclose` are
allowed to overwrite caller-saved registers, including `rax`.

### Preparing `fprintf`

```asm
mov rdi, [rbp - 8]
lea rsi, [rel source]
mov edx, 10
lea rcx, [rel source]
mov r8d, 34
mov r9d, 9
xor eax, eax
call fprintf wrt ..plt
```

The C signature is:

```c
int fprintf(FILE *stream, const char *format, ...);
```

Its arguments are arranged as:

```text
rdi = FILE * stream
rsi = format string
rdx = variadic argument 1
rcx = variadic argument 2
r8  = variadic argument 3
r9  = variadic argument 4
```

The current source format string uses:

```text
%1$c = newline
%2$s = source pointer
%3$c = double quote
%4$c = tab
```

Therefore the registers are prepared as follows:

```text
rdi = saved FILE *
rsi = address of source format string
rdx = 10
rcx = address of source
r8  = 34
r9  = 9
```

`mov edx, 10`, `mov r8d, 34`, and `mov r9d, 9` use 32-bit register names
because these are small integer values. Writing a 32-bit register also clears
the upper half of its 64-bit register, so `r8d = 34` results in the complete
64-bit register `r8 = 34`.

The pointer values use 64-bit registers: `rdi`, `rsi`, and `rcx`. A pointer
must not be truncated to a 32-bit register.

`fprintf` is variadic. The System V AMD64 ABI requires `al` to contain the
number of vector registers used for floating-point variadic arguments. This
call has no floating-point arguments, so:

```asm
xor eax, eax
```

sets `al` to zero before the call. `fprintf` then writes the reconstructed
source into the opened file and returns its result in `eax`.

### Checking the `fprintf` result

```asm
test eax, eax
js .write_error
```

`fprintf` returns a nonnegative character count on success and a negative
value on error. `test eax, eax` sets the Sign Flag when the result is negative.
`js` means â€œjump if signâ€, so this branch means:

```text
if (fprintf_result < 0)
    jump to .write_error;
```

This is different from `jz`: `jz` tests whether the result is exactly zero,
while `js` tests whether the sign bit indicates a negative result.

### Closing the file

```asm
mov rdi, [rbp - 8]
call fclose wrt ..plt
test eax, eax
jnz .error
```

`fclose` has the signature:

```c
int fclose(FILE *stream);
```

It receives the saved `FILE *` in `rdi`. It returns zero on success and a
nonzero value on failure.

`test eax, eax` sets the Zero Flag when the return value is zero. `jnz` means
â€œjump if not zeroâ€, so `.error` is reached when `fclose` reports failure.

The three conditional jumps have different meanings because the three libc
operations use different failure conventions:

```text
fopen:   NULL is zero       -> test rax, rax / jz
fprintf: negative is error  -> test eax, eax / js
fclose:  nonzero is error   -> test eax, eax / jnz
```

`jz` and `je` are equivalent names. `jnz` and `jne` are also equivalent names.

### Successful return and cleanup

```asm
xor eax, eax
mov rsp, rbp
pop rbp
ret
```

`xor eax, eax` sets the function return value to zero, equivalent to
`return (0)` in C.

`mov rsp, rbp` discards the 16 bytes reserved by `sub rsp, 16`. `pop rbp`
restores the caller's original `rbp` value and advances `rsp` past the saved
value. `ret` takes the return address from the stack and jumps back to the
caller.

The order matters: the local stack space must be removed and the saved `rbp`
restored before `ret` reads the return address.

### Error paths

```asm
.write_error:
    mov rdi, [rbp - 8]
    call fclose wrt ..plt
```

If `fprintf` fails, the file was opened successfully, so this path closes it
before returning. It then falls through to `.error` instead of using another
unnecessary jump.

```asm
.error:
    mov eax, 1
    mov rsp, rbp
    pop rbp
    ret
```

This returns `1`, indicating failure, after restoring the stack frame.

```asm
.open_error:
    mov eax, 1
    mov rsp, rbp
    pop rbp
    ret
```

This path is separate because `fopen` failed and there is no valid `FILE *` to
close. It also returns `1`.

The labels beginning with `.` are local branch destinations inside `main`; they
are not additional functions and are not reached with `call`. The full control
flow is:

```text
open file
if NULL -> .open_error -> return 1
write source
if negative -> .write_error -> close -> .error -> return 1
close file
if nonzero -> .error -> return 1
otherwise -> return 0
```
