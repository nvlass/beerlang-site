{:title "Beerlang"
 :layout :main
 :page-index 0
 :navbar? false
 :home? true}

## A Clojure-flavoured LISP with cooperative multitasking

Beerlang is a LISP-family language that combines Clojure's elegant syntax with a
cache-efficient stack VM, cooperative multitasking, and a distributed actor system.

```clojure
(defn hello [name]
  (println (str "Hello, " name "!")))

(hello "world")
```

- **Clojure syntax** — S-expressions, keywords, vectors, maps, destructuring
- **Compile everything** — REPL expressions compile to bytecode, same path as files
- **Cooperative tasks** — `spawn`, `await`, channels for lightweight concurrency
- **Distributed actors** — `beer.hive` brings Erlang-style message passing over TCP
- **No JVM** — small native binary, fast startup

[Get started →](/install/)
