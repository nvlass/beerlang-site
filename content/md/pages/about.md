{:title "About"
 :layout :page
 :page-index 5
 :navbar? true}

## About Beerlang

Beerlang is an open-source LISP-family language implemented in C.

### Design goals

- **Clojure syntax** — proven, minimal, great for macros
- **Cache-efficient VM** — stack-based bytecode designed to fit in L2/L3 cache
- **Cooperative multitasking** — lightweight tasks without preemption overhead
- **Compile everything** — no separate interpreter; REPL and files share the same path
- **Distributed actors** — `beer.hive` for Erlang-style multi-node computing

### Source

The source is available on [GitHub](https://github.com/nvlass/beerlang) under the MIT license.

### Name

The name is a nod to hops — the ingredient that gives beer its character — and to the
`beer.hive` distributed actor system inspired by how a hive of bees coordinates work.
