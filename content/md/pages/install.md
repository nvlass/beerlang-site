{:title "Install"
 :layout :page
 :page-index 1
 :navbar? true
 :description "Install Beerlang — build from source on Linux or macOS."}

## Installing Beerlang

### Requirements

- Linux (x86-64, ARM) or macOS (x86-64, Apple Silicon)
- GCC or Clang
- `make`

### From source

```bash
git clone https://github.com/nvlass/beerlang.git
cd beerlang
make
```

This produces `bin/beerlang`. To start the REPL:

```bash
./bl.sh
```

`bl.sh` sets `BEERPATH` to the bundled standard library and wraps the binary
with `rlwrap` for line editing if available.

### make install

```bash
make install           # installs to /usr/local by default
make install PREFIX=~/.local
```

This copies `bin/beerlang` to `$PREFIX/bin` and the standard library to
`$PREFIX/share/beerlang/lib`, then sets `BEERPATH` automatically.

> **Note:** A one-line install script and pre-built binaries are coming soon.

### Verifying the install

```
$ beerlang
Beerlang v0.1.0
Type (exit) to quit

user:1> (+ 1 2)
3
user:2> (defn greet [n] (str "Hello, " n "!"))
#<fn greet>
user:3> (greet "world")
"Hello, world!"
user:4> (exit)
Goodbye!
```
