{:title "Quick Start"
 :layout :page
 :page-index 2
 :navbar? true
 :description "Get up and running with Beerlang in minutes."}

## Setup

1. **Clone and build:**
   ```bash
   git clone https://github.com/nvlass/beerlang.git
   cd beerlang
   make
   ```

2. **Start the REPL:**
   ```bash
   ./bl.sh           # with rlwrap (line editing + history)
   ./bin/beerlang     # or directly
   ```

3. **Run a script:**
   ```bash
   ./bin/beerlang my_script.beer
   ```

## Your first session

```clojure
user:1> (+ 1 2 3)
6

user:2> (defn greet [name] (str "Hello, " name "!"))
#<function greet>

user:3> (greet "world")
"Hello, world!"

user:4> (map inc [1 2 3])
(2 3 4)

user:5> (->> (range 1 11) (filter odd?) (reduce +))
25
```

## Defining functions

```clojure
;; Simple function
(defn square [x] (* x x))

;; Multi-arity
(defn greet
  ([name] (greet name "Hello"))
  ([name greeting] (str greeting ", " name "!")))

;; Destructuring
(let [[a b & rest] [1 2 3 4 5]]
  (println a b rest))  ; prints: 1 2 (3 4 5)
```

## Data structures

```clojure
;; Vectors
[1 2 3]
(conj [1 2] 3)          ; => [1 2 3]

;; Maps
{:name "Alice" :age 30}
(assoc {:a 1} :b 2)     ; => {:a 1 :b 2}
(:name {:name "Alice"}) ; => "Alice"

;; Lists
'(1 2 3)
(cons 0 '(1 2 3))       ; => (0 1 2 3)
```

## Project management

Beerlang has built-in project management — no external tools required.

```bash
beer new myproject    # create a new project
cd myproject
beer run              # calls (-main) in the :main namespace
beer build            # create a distributable tar
beer repl             # start a project REPL (src/ and lib/ on load path)
```

A project is defined by a `beer.edn` file:

```clojure
{:name "myproject"
 :version "0.1.0"
 :paths ["src" "lib"]
 :dependencies []
 :main myproject.core}
```

> **Note:** The CLI subcommand interface is experimental and may change.

## Namespaces and libraries

```clojure
;; Create a namespace (in a file: mylib/utils.beer)
(ns mylib.utils)
(defn double [x] (* x 2))

;; Use it from another file or the REPL
(require 'mylib.utils :as 'u)
(u/double 21)  ; => 42
```

Set `BEERPATH` to tell beerlang where to find libraries:

```bash
export BEERPATH=/path/to/libs:lib
```

Libraries can also be distributed as `.tar` files — place a tar in any `BEERPATH` directory and its `.beer` files are available to `require`.

## Concurrency

```clojure
;; Spawn a task
(def t (spawn (do (yield) 42)))
(await t)  ; => 42

;; Channels
(let [c (chan)]
  (spawn (>! c "hello"))
  (println (<! c)))  ; prints: hello
```

## Atoms

Atoms provide thread-safe mutable state. Use `@` (deref) to read, `swap!` to update.

```clojure
(def counter (atom 0))
(swap! counter inc)        ; => 1
(swap! counter + 10)       ; => 11
@counter                   ; => 11
(reset! counter 0)         ; => 0
(compare-and-set! counter 0 42)  ; => true
@counter                   ; => 42
```

## Actors

The `beer.hive` library provides Erlang-inspired message-passing actors.

```clojure
(require 'beer.hive :as 'hive)

(def pid (hive/spawn-actor
  (fn [state msg]
    (cond
      (= (:type msg) :inc)  {:state (update state :n inc)}
      (= (:type msg) :get)  {:state state :reply (:n state)}))
  {:n 0}))

(hive/send pid {:type :inc})
(hive/send pid {:type :inc})
(hive/ask pid {:type :get})  ; => 2

(hive/stop pid)
```

## JSON

```clojure
(require 'beer.json :as 'json)

(json/parse "{\"name\": \"Beerlang\", \"version\": 1}")
; => {"name" "Beerlang" "version" 1}

(json/emit {:langs ["beerlang" "clojure"] :count 2})
; => "{\"langs\":[\"beerlang\",\"clojure\"],\"count\":2}"
```

## Exception handling

```clojure
(try
  (throw (ex-info "oops" {:code 42}))
  (catch e
    (println "Caught:" (:message e)))
  (finally
    (println "cleanup")))
```

## File I/O

```clojure
;; Read/write files
(spit "out.txt" "hello")
(slurp "out.txt")        ; => "hello"

;; Streams
(with-open [f (open "data.txt" :read)]
  (println (read-line f)))
```

## Shell execution

```clojure
(require 'beer.shell :as 'shell)
(let [result (shell/exec "ls" "-la")]
  (println (:out result))
  (println "exit code:" (:exit result)))
```

## Running tests

```clojure
(ns mylib.test
  (:require [beer.test :as t]))

(t/deftest addition-test
  (t/is (= 4 (+ 2 2)))
  (t/is (= 0 (+ -1 1))))

(t/run-tests)
```

## Development tools

```bash
make          # Build
make test     # Run unit tests (C) + smoke tests (shell)
make debug    # Debug build (-g -O0)
make repl     # Start REPL
make clean    # Clean build artifacts

beer --help   # Show all CLI commands
```

## Next steps

- [API Reference](/api/) — complete list of functions and macros
- [Examples](/examples/) — annotated example programs
