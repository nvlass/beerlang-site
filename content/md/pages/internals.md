{:title "Internals"
 :layout :page
 :page-index 7
 :navbar? true
 :toc true
 :description "Bytecode metaprogramming, VM instruction set, and internals for those who want to go deeper."}

Beerlang compiles everything to bytecode before execution — REPL input, scripts, and macro expansions all go through the same path. This page is for hackers who want to see what the compiler produces, manipulate it from beerlang itself, and understand the instruction set underneath.

## Bytecode as Data

`disasm` and `asm` are native functions that bridge the gap between running code and beerlang data structures. A function is not a black box — you can pull it apart, inspect it, transform it, and reassemble it.

```clojure
(defn add [a b] (+ a b))

(disasm add)
;=> {:arity 2
;    :constants [+]
;    :code [[:ENTER 1]
;           [:LOAD_SELF] [:STORE_LOCAL 2]
;           [:LOAD_LOCAL 0]
;           [:LOAD_LOCAL 1]
;           [:LOAD_VAR 0]        ; load + from constants[0]
;           [:TAIL_CALL 2]
;           [:RETURN]]}
```

The map has three keys:

- **`:arity`** — number of fixed parameters (`-1` for variadic)
- **`:constants`** — values the code refers to by index (function names, strings, etc.)
- **`:code`** — sequence of `[opcode-keyword operand ...]` tuples

`asm` turns a map back into a callable function:

```clojure
(def sq (asm (disasm (fn [x] (* x x)))))
(sq 9)   ;=> 81
```

---

## Examples

### Inspecting what the compiler generates

The compiler makes choices you might not expect. Here's what a simple `if` looks like:

```clojure
(disasm (fn [x] (if (> x 0) :pos :neg)))
;=> {:arity 1
;    :constants [>]
;    :code [[:ENTER 1] [:LOAD_SELF] [:STORE_LOCAL 1]
;           [:LOAD_LOCAL 0]
;           [:PUSH_INT 0]
;           [:LOAD_VAR 0]          ; load >
;           [:CALL 2]
;           [:JUMP_IF_FALSE :L0]   ; branch on result — does NOT pop the test value
;           [:POP]                 ; pop test value (true branch)
;           [:PUSH_CONST 1]        ; :pos
;           [:JUMP :L1]
;           [:LABEL :L0]
;           [:POP]                 ; pop test value (false branch)
;           [:PUSH_CONST 2]        ; :neg
;           [:LABEL :L1]
;           [:RETURN]]}
```

`JUMP_IF_FALSE` peeks at the stack without consuming it — the branches each start with a `POP`.

And here's the same function with tail-call optimization visible:

```clojure
(defn fact [n]
  (if (< n 2) 1 (* n (fact (- n 1)))))

(disasm fact)
;=> {:arity 1
;    :constants [< - *]
;    :code [[:ENTER 1] [:LOAD_SELF] [:STORE_LOCAL 1]
;           [:LOAD_LOCAL 0] [:PUSH_INT 2] [:LOAD_VAR 0] [:CALL 2]
;           [:JUMP_IF_FALSE :L0]
;           [:POP] [:PUSH_INT 1] [:JUMP :L1]
;           [:LABEL :L0]
;           [:POP]
;           [:LOAD_LOCAL 0]
;           [:LOAD_LOCAL 0] [:PUSH_INT 1] [:LOAD_VAR 1] [:CALL 2]
;           [:LOAD_LOCAL 1] [:CALL 1]   ; recursive call — (fact (- n 1))
;           [:LOAD_VAR 2] [:TAIL_CALL 2] ; tail call for the outer * — reuses frame
;           [:LABEL :L1]
;           [:RETURN]]}
```

Closures capture values at call time. `LOAD_CLOSURE` reads from the closed-over environment:

```clojure
(defn make-adder [n] (fn [x] (+ n x)))
(def add5 (make-adder 5))

(disasm add5)
;=> {:arity 1
;    :constants [+]
;    :code [[:ENTER 0]
;           [:LOAD_CLOSURE 0]    ; load captured n
;           [:LOAD_LOCAL 0]      ; load x
;           [:LOAD_VAR 0]        ; load +
;           [:TAIL_CALL 2]
;           [:RETURN]]}
```

### Counting opcodes

Since `:code` is just a sequence of vectors, any standard sequence operation works on it:

```clojure
(defn opcode-freq [f]
  (reduce (fn [acc instr]
            (let [op (first instr)]
              (assoc acc op (inc (get acc op 0)))))
          {}
          (:code (disasm f))))

(opcode-freq fact)
;=> {:ENTER 1, :LOAD_SELF 1, :STORE_LOCAL 1, :LOAD_LOCAL 4,
;    :PUSH_INT 3, :LOAD_VAR 3, :CALL 3, :JUMP_IF_FALSE 1,
;    :POP 2, :JUMP 1, :TAIL_CALL 1, :LABEL 2, :RETURN 1}
```

### Detecting tail-call optimization

The compiler emits `TAIL_CALL` instead of `CALL` + `RETURN` at tail positions. You can check whether it fired:

```clojure
(defn tail-optimized? [f]
  (some #(= (first %) :TAIL_CALL) (:code (disasm f))))

(tail-optimized? (fn loop [n] (if (= n 0) :done (loop (- n 1)))))
;=> true

(tail-optimized? (fn [n] (* n (+ n 1))))
;=> nil
```

### Hand-writing bytecode

You can construct functions from scratch without the compiler. Here's an identity function assembled by hand:

```clojure
;; (fn [x] x) — load arg 0 and return it
(def my-identity
  (asm {:arity 1
        :constants []
        :code [[:ENTER 0]
               [:LOAD_LOCAL 0]
               [:RETURN]]}))

(my-identity 42)   ;=> 42
(my-identity :ok)  ;=> :ok
```

And a function that always returns the same constant:

```clojure
(def always-pi
  (asm {:arity 0
        :constants [3.141592653589793]
        :code [[:ENTER 0]
               [:PUSH_CONST 0]
               [:RETURN]]}))

(always-pi)   ;=> 3.14159...
```

### Patching a function

`disasm` + `asm` lets you surgically replace parts of a function. Here's a simple constant-folding patch — swap one immediate integer for another:

```clojure
(defn patch-int [f from to]
  (let [d (disasm f)
        patched (into [] (map (fn [instr]
                                (if (= instr [:PUSH_INT from])
                                  [:PUSH_INT to]
                                  instr))
                              (:code d)))]
    (asm (assoc d :code patched))))

(defn add-ten [x] (+ x 10))

(def add-twenty (patch-int add-ten 10 20))
(add-twenty 5)   ;=> 25
```

---

## VM Instruction Set

The VM uses single-byte opcodes with little-endian operands. All currently implemented instructions are listed below.

### Stack Operations

| Opcode | Instruction | Stack effect | Description |
|--------|-------------|--------------|-------------|
| `0x00` | `NOP` | — | No operation |
| `0x01` | `POP` | `a →` | Discard top of stack |
| `0x02` | `DUP` | `a → a a` | Duplicate top |
| `0x03` | `SWAP` | `a b → b a` | Swap top two |
| `0x04` | `OVER` | `a b → a b a` | Copy second to top |

### Constants & Literals

| Opcode | Instruction | Operand | Description |
|--------|-------------|---------|-------------|
| `0x10` | `PUSH_NIL` | — | Push `nil` |
| `0x11` | `PUSH_TRUE` | — | Push `true` |
| `0x12` | `PUSH_FALSE` | — | Push `false` |
| `0x13` | `PUSH_CONST` | `u32` index | Push `constants[index]` |
| `0x14` | `PUSH_INT` | `i64` value | Push 64-bit integer literal |

### Variables & Scope

| Opcode | Instruction | Operand | Description |
|--------|-------------|---------|-------------|
| `0x20` | `LOAD_VAR` | `u16` const_idx | Load from namespace var (symbol at `constants[const_idx]`) |
| `0x21` | `STORE_VAR` | `u16` const_idx | Store top-of-stack to namespace var |
| `0x22` | `LOAD_LOCAL` | `u16` slot | Load local variable slot |
| `0x23` | `STORE_LOCAL` | `u16` slot | Store to local variable slot |
| `0x24` | `LOAD_CLOSURE` | `u16` index | Load from the closure's captured environment |
| `0x25` | `LOAD_SELF` | — | Push the currently-executing function (enables named fn self-recursion) |

### Arithmetic

| Opcode | Instruction | Stack effect | Description |
|--------|-------------|--------------|-------------|
| `0x30` | `ADD` | `a b → (a+b)` | |
| `0x31` | `SUB` | `a b → (a-b)` | |
| `0x32` | `MUL` | `a b → (a*b)` | |
| `0x33` | `DIV` | `a b → (a/b)` | |
| `0x35` | `NEG` | `a → -a` | Negate |
| `0x36` | `INC` | `a → (a+1)` | Increment |
| `0x37` | `DEC` | `a → (a-1)` | Decrement |

`mod` and `rem` are native functions, not opcodes.

### Comparison

| Opcode | Instruction | Stack effect | Description |
|--------|-------------|--------------|-------------|
| `0x40` | `EQ` | `a b → bool` | Structural equality (cross-type, `[1 2] = '(1 2)`) |
| `0x42` | `LT` | `a b → bool` | Less than |
| `0x44` | `GT` | `a b → bool` | Greater than |

`<=` and `>=` are native functions.

### Control Flow

| Opcode | Instruction | Operand | Description |
|--------|-------------|---------|-------------|
| `0x60` | `JUMP` | `i32` offset | Unconditional relative jump |
| `0x61` | `JUMP_IF_FALSE` | `i32` offset | Jump if top is `false`/`nil` — **peeks, does not pop** |
| `0x63` | `CALL` | `u16` n_args | Call function with n args |
| `0x64` | `TAIL_CALL` | `u16` n_args | Tail call — reuses current frame |
| `0x65` | `RETURN` | — | Return from function |
| `0x67` | `ENTER` | `u16` n_locals | Function prologue — allocate local variable slots |
| `0x6F` | `HALT` | — | Stop VM execution |

`JUMP_IF_FALSE` peeks at the stack — the value remains and must be explicitly `POP`'d by whichever branch runs.

### Exception Handling

| Opcode | Instruction | Operand | Description |
|--------|-------------|---------|-------------|
| `0x70` | `PUSH_HANDLER` | `u32` catch_pc | Push an exception handler; `catch_pc` is the absolute PC of the catch block |
| `0x71` | `POP_HANDLER` | — | Remove the top handler (normal exit from `try` block) |
| `0x72` | `THROW` | — | Pop a map value and throw it as an exception |
| `0x73` | `LOAD_EXCEPTION` | — | Push the current exception onto the stack (inside `catch`) |

Only hash maps can be thrown. `(throw {:type :oops :msg "..."})`.

### Functions & Closures

| Opcode | Instruction | Operands | Description |
|--------|-------------|----------|-------------|
| `0x80` | `MAKE_CLOSURE` | `u32` code_offset, `u16` n_locals, `u16` n_closed, `u16` arity, `u16` name_idx | Create a closure. `n_closed` captured values are popped from the stack. |

---

## Operand Encoding

All multi-byte operands are **little-endian**:

| Notation | Size | Notes |
|----------|------|-------|
| `u16` | 2 bytes | Unsigned, e.g. slot index, arg count |
| `u32` | 4 bytes | Unsigned, e.g. constant pool index |
| `i32` | 4 bytes | Signed relative jump offset |
| `i64` | 8 bytes | Signed integer literal for `PUSH_INT` |

Jump offsets are relative to the byte **after** the full instruction (i.e. after the opcode + operand bytes).

---

## Design Notes

**Why stack-based?** The instruction set is deliberately simple — it fits in L2/L3 cache alongside the code it's executing. Stack machines avoid register allocation entirely, which keeps the compiler straightforward.

**Why so few opcodes?** Everything else is a native function. `mod`, `rem`, `<=`, `>=`, collection operations — they're all Beerlang functions called through `CALL`/`TAIL_CALL`. Opcodes are only warranted when measurements prove a critical hot path needs them.

**`TAIL_CALL` vs `CALL`** — The compiler detects tail position automatically. A call in tail position emits `TAIL_CALL` instead of `CALL` + `RETURN`, reusing the current stack frame. This makes tail-recursive functions use constant stack space, and you can verify it fired with `disasm`.
