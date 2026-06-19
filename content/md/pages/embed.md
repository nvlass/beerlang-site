{:title "Embed & FFI"
 :layout :page
 :page-index 5
 :navbar? true
 :toc true
 :description "Embedding Beerlang in C applications via libbeerlang, and calling C libraries from Beerlang via beer.ffi."}

## Embedding Beerlang in C

`libbeerlang` is a static library that lets you embed the full Beerlang runtime
inside any C application — expose a scripting layer, run policy code, or drive
automation without spawning a subprocess.

### Build the library

```bash
git clone https://github.com/nvlass/beerlang.git
cd beerlang
make libbeerlang          # → build/libbeerlang.a
```

### Link your application

```bash
gcc -Ibeerlang/include myapp.c \
    -Lbeerlang/build -lbeerlang \
    -lm -lpthread -o myapp
```

### The API (`include/beer.h`)

```c
#include "beer.h"

/* Initialise the runtime (call once). */
void beer_init(void);

/* Evaluate a source string; result written to *out_val.
 * Returns 0 on success, non-zero on error.
 * error_out (if non-NULL) receives a malloc'd error string on failure. */
int beer_run_source(const char* source,
                    BeerValue*  out_val,
                    char**      error_out);

/* Call a named function in the current namespace.
 * argc/argv are Beerlang values constructed via the helpers below. */
BeerValue beer_call(const char* fn_name, int argc, BeerValue* argv);

/* Value constructors */
BeerValue beer_int(int64_t n);
BeerValue beer_float(double d);
BeerValue beer_string(const char* s);
BeerValue beer_bool(int b);      /* 0 → false, non-zero → true */
BeerValue beer_nil(void);

/* Value accessors */
int       beer_is_nil(BeerValue v);
int       beer_is_bool(BeerValue v);
int       beer_is_int(BeerValue v);
int       beer_is_float(BeerValue v);
int       beer_is_string(BeerValue v);
int64_t   beer_to_int(BeerValue v);
double    beer_to_float(BeerValue v);
const char* beer_to_string(BeerValue v);   /* valid until next GC cycle */

/* Shut down the runtime and free all resources. */
void beer_shutdown(void);
```

### Minimal example

```c
#include <stdio.h>
#include "beer.h"

int main(void) {
    beer_init();

    BeerValue result;
    char*     err = NULL;

    if (beer_run_source("(+ 1 2)", &result, &err) == 0) {
        printf("result: %lld\n", beer_to_int(result));   /* → 3 */
    } else {
        fprintf(stderr, "error: %s\n", err);
        free(err);
    }

    beer_shutdown();
    return 0;
}
```

Build and run the bundled demo:

```bash
make embed          # → bin/embed
./bin/embed
```

### Registering native functions

You can expose C functions to Beerlang scripts:

```c
#include "beer.h"
#include "native.h"
#include "namespace.h"
#include "symbol.h"

static Value my_add(VM* vm, int argc, Value* argv) {
    (void)vm;
    if (argc != 2 || !is_fixnum(argv[0]) || !is_fixnum(argv[1]))
        return VALUE_NIL;
    return make_fixnum(untag_fixnum(argv[0]) + untag_fixnum(argv[1]));
}

/* Call after beer_init(), before running any scripts. */
void register_my_natives(void) {
    Namespace* ns = namespace_registry_get_or_create(
        global_namespace_registry, "myapp");
    Value sym = symbol_intern("add");
    Value fn  = native_function_new(2, my_add, "add");
    namespace_define(ns, sym, fn);
    object_release(fn);
}
```

Then from Beerlang:

```clojure
(myapp/add 3 4)   ;=> 7
```

---

## Calling C from Beerlang (CFFI)

`beer.ffi` lets Beerlang scripts call arbitrary C functions in shared libraries
at runtime, using [libffi](https://github.com/libffi/libffi) for ABI handling.

### Enable at build time

```bash
make CFFI=1           # links -lffi, registers beer.ffi namespace
make CFFI=1 install
```

Without `CFFI=1` the binary has no libffi dependency — `beer.ffi` simply
won't be registered.

### Quick example: calling `sqrt` from libm

```clojure
(ns myscript
  (:require [beer.ffi :as ffi]))

(def libm    (ffi/open "/usr/lib/libm.dylib"))   ; macOS path
(def sqrt-fn (ffi/sym  libm "sqrt"))

(ffi/call sqrt-fn [:double] :double [2.0])   ;=> 1.41421356...

(ffi/close libm)
```

### API reference

#### Library handles

| Function | Signature | Description |
|---|---|---|
| `ffi/open` | `(ffi/open path)` → cpointer | Load a shared library (`dlopen`) |
| `ffi/sym`  | `(ffi/sym handle name)` → cpointer | Look up a symbol (`dlsym`) |
| `ffi/close` | `(ffi/close handle)` → nil | Unload library (`dlclose`) |

#### Calling C functions

```clojure
(ffi/call fn-ptr arg-types ret-type args)
```

- **`fn-ptr`** — a `cpointer` returned by `ffi/sym`
- **`arg-types`** — vector of type keywords (see table below)
- **`ret-type`** — a single type keyword
- **`args`** — vector of Beerlang values, one per arg-type

#### Type keywords

| Keyword | C type | Notes |
|---|---|---|
| `:void` | `void` | Return type only |
| `:bool` | `int` (0/1) | Marshalled to/from `true`/`false` |
| `:int8` `:uint8` | `int8_t` / `uint8_t` | |
| `:int16` `:uint16` | `int16_t` / `uint16_t` | |
| `:int32` `:uint32` | `int32_t` / `uint32_t` | |
| `:int64` `:uint64` | `int64_t` / `uint64_t` | |
| `:float` | `float` | Boxed as Beerlang float (double precision) |
| `:double` | `double` | |
| `:pointer` | `void*` | Passed as/returned as `cpointer` or `nil` |
| `:string` | `char*` | Beerlang string → null-terminated copy for the call |

#### Memory management

```clojure
(def ptr (ffi/malloc 64))          ; allocate 64 zero-initialised bytes

(ffi/cset! ptr :int32  0  42)      ; write int32 at byte offset 0
(ffi/cset! ptr :double 8  3.14)    ; write double at byte offset 8

(ffi/cget  ptr :int32  0)          ;=> 42
(ffi/cget  ptr :double 8)          ;=> 3.14

(ffi/free ptr)                     ; release the memory
```

#### Predicates

```clojure
(ffi/cpointer? x)    ; true if x is a C pointer value
(ffi/cnull?    ptr)  ; true if ptr is nil or points to NULL
```

### Longer example: calling `snprintf`

```clojure
(ns fmt-demo
  (:require [beer.ffi :as ffi]))

(def libc     (ffi/open "libc.dylib"))
(def snprintf (ffi/sym  libc "snprintf"))

(def buf (ffi/malloc 64))

;; snprintf(buf, 64, "%d + %d = %d", 3, 4, 7)
(ffi/call snprintf
          [:pointer :uint64 :string :int32 :int32 :int32]
          :int32
          [buf 64 "%d + %d = %d" 3 4 7])

(println (ffi/cget buf :string 0))   ;=> "3 + 4 = 7"

(ffi/free buf)
(ffi/close libc)
```

### What's coming (Phase 2)

The `def-cfn` and `def-cstruct` macros will make working with C libraries
feel natural:

```clojure
;; Phase 2 preview — not yet available
(def-cfn sqrt "libm" "sqrt" [:double] :double)

(sqrt 2.0)   ;=> 1.41421...

(def-cstruct Point [x :double] [y :double])
(def p (ffi/malloc Point))
(set-point-x! p 3.0)
(set-point-y! p 4.0)
(point-x p)   ;=> 3.0
```
