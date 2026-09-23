# Dr Quine

![Languages](https://img.shields.io/badge/languages-C%20%7C%20x86--64%20ASM-4b8bbe)
![Platform](https://img.shields.io/badge/platform-Linux-lightgrey)
![Assembler](https://img.shields.io/badge/assembler-NASM-red)

> Three self-reproducing programs, implemented in both C and x86-64 Assembly.

## What is a quine?

A **quine** is a program that reproduces its own source code without opening or reading
that source file. The source must therefore contain enough information to describe itself.

The central idea in this project is a self-referential format string:

```text
source = "the whole program, with placeholders - including this string"
print(source, newline, source, quote, tab, ...)
```

The placeholders solve the circular problem: the program stores its structure once, then
inserts newline, quote and tab characters, plus the format string itself, at runtime.

## The project

The [Dr Quine subject](./dr-quine.pdf) asks for three mandatory programs in both `C/`
and `ASM/`. The Assembly implementation targets Linux x86-64 and uses NASM.

| Exercise | Required behaviour | Main constraint |
|---|---|---|
| **Colleen** | Print its complete source to standard output | Include two comments and call an additional function/routine |
| **Grace** | Write an identical copy to `Grace_kid.c` or `Grace_kid.s` | Use exactly three macros and the required comment structure |
| **Sully** | Generate, compile and run `Sully_5` down to `Sully_0` | The integer starts at `5` and decreases in each generated source |

## How the solutions work

### Colleen - print yourself

`Colleen` keeps its source in a format string and passes that string back into `printf`.
The extra C function and Assembly routine perform the required output while satisfying
the subject's structure and comment requirements.

```sh
./Colleen > Colleen_output
diff Colleen.c Colleen_output       # Run inside C/
diff Colleen.s Colleen_output       # Run inside ASM/
```

An empty `diff` result means the output is identical to the source.

### Grace - write a child

`Grace` applies the same self-formatting technique to a file instead of standard output.
In C, three `#define` macros provide the filename, source template and program body. In
Assembly, two `%define` directives plus one `%macro` provide the equivalent three macros.

```sh
./Grace
diff Grace.c Grace_kid.c            # C version
diff Grace.s Grace_kid.s            # Assembly version
```

#### Inspect the expanded Grace macros

The `-E` option stops after preprocessing, so it lets you inspect what the macros become
without assembling, compiling or running the result. For C, `-P` also removes preprocessor
line markers to make the output easier to read:

```sh
cd C
cc -E -P Grace.c > /tmp/grace_c_expanded.c
tail -n 1 /tmp/grace_c_expanded.c

cd ../ASM
nasm -E Grace.s > /tmp/grace_asm_expanded.s
less /tmp/grace_asm_expanded.s
```

The last C line shows `GRACE` expanded into a concrete `int main(void)` body, with
`FILE_NAME` and `String` substituted. The NASM output similarly shows the instructions
produced by the `GRACE` macro invocation. These commands confirm that the macros generate
the program rather than hiding a separately written entry point.

### Sully - reproduce recursively

`Sully` writes a numbered source file, compiles it, and runs the resulting child. Each
source embeds the current counter, so neighbouring generations differ only by that number.

The original and generated programs must behave differently: the original creates
`Sully_5`, while `Sully_5` must decrement and create `Sully_4`. This implementation uses
a **compile-time macro flag** instead of checking whether `Sully_5` already exists:

```c
#ifndef CHILD
# define CHILD 0
#endif

i -= CHILD;
```

The original is compiled normally, so `CHILD` defaults to `0`. Every generated child is
compiled with `-DCHILD=1`, making it subtract one before creating the next generation.
NASM uses the same idea with `%define CHILD 0`, `sub ... CHILD`, and `-DCHILD=1`.

```text
Sully     : 5 - 0 → writes Sully_5
Sully_5   : 5 - 1 → writes Sully_4
Sully_4   : 4 - 1 → writes Sully_3
...
Sully_0   : 0 - 1 → stops without creating Sully_-1
```

This avoids a subtle file-collision bug: even if `Sully_5.c` or `Sully_5.s` already exists,
the original overwrites it and still begins at generation 5.

## Important implementation details

- `printf`/`fprintf` positional placeholders such as `%1$c` and `%2$s` make long quine
  templates easier to control.
- A literal percent sign inside a format string is written as `%%`; this matters for NASM
  directives such as `%define` embedded inside the Assembly source template.
- The Assembly versions follow the System V AMD64 calling convention: integer/pointer
  arguments begin in `rdi`, `rsi`, `rdx`, `rcx`, `r8` and `r9`.
- `eax` is cleared before variadic C-library calls such as `printf` and `fprintf`.
- RIP-relative addresses (`[rel symbol]`) and `wrt ..plt` keep external calls compatible
  with the normal Linux PIE toolchain.
- Generated files are opened with mode `"w"`, so an existing child source is replaced.

## Repository layout

```text
.
├── C/
│   ├── Colleen.c
│   ├── Grace.c
│   ├── Sully.c
│   └── Makefile
├── ASM/
│   ├── Colleen.s
│   ├── Grace.s
│   ├── Sully.s
│   └── Makefile
└── dr-quine.pdf
```

## Build and run

Requirements: Linux, `make`, a C compiler, and NASM.

```sh
# C implementations
cd C
make
./Colleen
./Grace
./Sully

# Assembly implementations
cd ../ASM
make
./Colleen
./Grace
./Sully
```

Run a complete rebuild or remove generated files with:

```sh
make -C C re          # Run these four commands from the repository root
make -C ASM re

make -C C fclean
make -C ASM fclean
```

## The main lesson

Quines are less about printing a very long string and more about separating a program into
two parts: a reusable **description** of the source and a small **mechanism** that injects
that description back into itself. `Colleen`, `Grace` and `Sully` apply that same idea to
standard output, file output and recursive generation respectively.
