{:title "Examples"
 :layout :page
 :page-index 4
 :navbar? true
 :description "Annotated Beerlang example programs covering concurrency, actors, HTTP, JSON, and testing."}

All examples are in the [examples/](https://github.com/nvlass/beerlang/tree/main/examples) directory of the repository. Run any of them with:

```bash
BEERPATH=lib ./bin/beerlang examples/<file>.beer
```

---

## Hello World HTTP Server

A minimal HTTP server that returns JSON.

```clojure
(ns hello-server
  (:require [beer.http :as http]
            [beer.json :as json]))

(defn handler [req]
  {:status 200
   :headers {"content-type" "application/json"}
   :body (json/emit {:message "Hello from Beerlang!"
                     :method (:method req)
                     :uri (:uri req)})})

(http/run-server handler {:port 8080})
```

```bash
# Test it
curl http://localhost:8080/
```

---

## JSON REST API

An in-memory CRUD API using `beer.http`, `beer.json`, and atoms for safe concurrent state.

```clojure
(ns json-api
  (:require [beer.http :as http]
            [beer.json :as json]))

(def *store*   (atom {}))
(def *next-id* (atom 1))

(defn next-id! []
  (let [id @*next-id*]
    (swap! *next-id* inc)
    id))

(defn store-put! [item]
  (let [id (next-id!)
        item-with-id (assoc item :id id)]
    (swap! *store* assoc id item-with-id)
    item-with-id))

(defn json-response [status body]
  {:status  status
   :headers {"content-type" "application/json"}
   :body    (json/emit body)})

(defn ok       [body] (json-response 200 body))
(defn created  [body] (json-response 201 body))
(defn not-found [msg] (json-response 404 {:error msg}))
(defn bad-req  [msg]  (json-response 400 {:error msg}))

(defn parse-int [s]
  (try (int (read-string s))
       (catch _ nil)))

(defn handler [req]
  (let [method (:method req)
        uri    (:uri req)]
    (cond
      (and (= method "GET") (= uri "/items"))
      (ok (vec (vals @*store*)))

      (and (= method "POST") (= uri "/items"))
      (let [body (try (json/parse (:body req)) (catch _ nil))]
        (if (map? body)
          (created (store-put! body))
          (bad-req "body must be a JSON object")))

      (and (= method "GET") (str/starts-with? uri "/items/"))
      (let [id (parse-int (subs uri 7))]
        (if-let [item (and id (get @*store* id))]
          (ok item)
          (not-found (str "item " (subs uri 7) " not found"))))

      (and (= method "DELETE") (str/starts-with? uri "/items/"))
      (let [id (parse-int (subs uri 7))]
        (if (and id (do (swap! *store* dissoc id) true))
          (ok {:deleted id})
          (not-found "not found")))

      :else
      (not-found (str "no route for " method " " uri)))))

(println "JSON API listening on http://localhost:8080")
(http/run-server handler {:port 8080})
```

```bash
curl http://localhost:8080/items
curl -X POST http://localhost:8080/items \
     -H 'Content-Type: application/json' \
     -d '{"name":"widget","price":9.99}'
curl http://localhost:8080/items/1
curl -X DELETE http://localhost:8080/items/1
```

---

## Channels

CSP-style communication between cooperative tasks: fan-out and pipeline patterns.

```clojure
(ns channels-example)

;; 1. Basic send / receive
(let [c (chan)]
  (spawn (fn [] (>! c "hello from a task")))
  (println "received:" (<! c)))

;; 2. Buffered channel — sender doesn't block until buffer full
(let [c (chan 3)]
  (>! c 1)
  (>! c 2)
  (>! c 3)
  (println "buffered:" (<! c) (<! c) (<! c)))

;; 3. Fan-out: distribute 16 jobs across 4 workers
(defn make-worker [id jobs results]
  (spawn (fn []
           (loop []
             (let [job (<! jobs)]
               (when job
                 (>! results {:worker id :job job :result (* job job)})
                 (recur)))))))

(let [jobs    (chan 20)
      results (chan 20)]
  (doseq [i (range 4)]
    (make-worker i jobs results))
  (doseq [j (range 16)]
    (>! jobs j))
  (close! jobs)
  (let [total (loop [i 16 acc 0]
                (if (zero? i) acc
                  (recur (dec i) (+ acc (:result (<! results))))))]
    (println "sum of squares 0..15 =" total)))   ;=> 1240

;; 4. Pipeline: source → double → stringify
(defn pipeline-stage [in xf out]
  (spawn (fn []
           (loop []
             (let [v (<! in)]
               (when v (>! out (xf v)) (recur))))
           (close! out))))

(let [source   (chan 10)
      doubled  (chan 10)
      stringed (chan 10)]
  (pipeline-stage source  #(* % 2)      doubled)
  (pipeline-stage doubled #(str "v=" %) stringed)
  (doseq [i (range 5)] (>! source i))
  (close! source)
  (loop []
    (let [v (<! stringed)]
      (when v (println v) (recur)))))
```

---

## Atoms

Thread-safe mutable state. `swap!` is atomic — safe to call from concurrent tasks.

```clojure
(ns atoms-example)

;; Basic usage
(def x (atom 0))
(swap! x inc)
(swap! x + 10)
(println @x)    ;=> 11

;; Atoms hold any value
(def config (atom {:host "localhost" :port 8080 :debug false}))
(swap! config assoc :debug true)
(swap! config update :port inc)
(prn @config)   ;=> {:host "localhost" :port 8081 :debug true}

;; Safe concurrent counter: 100 tasks × 100 increments = 10000
(def counter (atom 0))
(let [tasks (map (fn [_]
                   (spawn (fn []
                            (loop [i 100]
                              (when (pos? i)
                                (swap! counter inc)
                                (recur (dec i)))))))
                 (range 100))]
  (doseq [t tasks] (await t)))
(println @counter)   ;=> 10000

;; compare-and-set! for optimistic lock-free updates
(def flag (atom :idle))
(compare-and-set! flag :idle :running)   ;=> true
(compare-and-set! flag :idle :running)   ;=> false (already :running)
```

---

## Actors

`beer.hive` provides Erlang-style message-passing actors with a registry and supervisors.

```clojure
(ns actors-example
  (:require [beer.hive :as hive]))

;; Actor handlers are pure functions: (state, msg) → new-state
;; Return {:reply val :state s} to respond to ask.
;; Return {:stop final} to stop the actor.

(defn counter-handler [state msg]
  (cond
    (= msg :inc)   (inc state)
    (= msg :dec)   (dec state)
    (= msg :reset) 0
    (= msg :get)   {:reply state :state state}
    (= msg :stop)  {:stop state}
    :else          state))

;; 1. Counter actor
(let [pid (hive/spawn-actor counter-handler 0)]
  (hive/send pid :inc)
  (hive/send pid :inc)
  (hive/send pid :dec)
  (println "counter:" (hive/ask pid :get))     ;=> 1
  (hive/send pid :reset)
  (println "after reset:" (hive/ask pid :get)) ;=> 0
  (hive/stop pid))

;; 2. Named actor registry
(hive/spawn-actor
  (fn [_ msg] (println "[log]" msg) nil)
  nil
  {:name :logger})

(let [pid (hive/whereis :logger)]
  (hive/send pid "hello from named actor"))

;; 3. Key-value store actor
(defn kv-handler [store msg]
  (let [op (get msg :op) key (get msg :key)]
    (cond
      (= op :put) (assoc store key (get msg :val))
      (= op :get) {:reply (get store key) :state store}
      (= op :del) (dissoc store key)
      (= op :all) {:reply store :state store}
      :else store)))

(let [kv (hive/spawn-actor kv-handler {})]
  (hive/send kv {:op :put :key :name :val "Beerlang"})
  (hive/send kv {:op :put :key :version :val "0.1.0"})
  (println "name:" (hive/ask kv {:op :get :key :name}))
  (prn (hive/ask kv {:op :all}))
  (hive/stop kv))

;; 4. Supervisor
(let [sup (hive/supervisor :one-for-one
            [(fn [] (hive/spawn-actor counter-handler 0 {:name :supervised-counter}))])]
  (println "supervisor started with" (count (:children sup)) "child(ren)"))
```

---

## Testing

`beer.test` provides `deftest`, `is`, and `testing` — familiar to anyone who has used `clojure.test`.

```clojure
(ns testing-example
  (:require [beer.test :as t]))

(defn fizzbuzz [n]
  (cond
    (zero? (mod n 15)) "FizzBuzz"
    (zero? (mod n 3))  "Fizz"
    (zero? (mod n 5))  "Buzz"
    :else              (str n)))

(defn factorial [n]
  (loop [i n acc 1]
    (if (<= i 1) acc
      (recur (- i 1) (* acc i)))))

(t/deftest fizzbuzz-test
  (t/testing "multiples of 3"
    (t/is (= "Fizz" (fizzbuzz 3)))
    (t/is (= "Fizz" (fizzbuzz 99))))
  (t/testing "multiples of 15"
    (t/is (= "FizzBuzz" (fizzbuzz 15)))))

(t/deftest factorial-test
  (t/is (= 1   (factorial 1)))
  (t/is (= 120 (factorial 5)))
  (t/is (= 2432902008176640000 (factorial 20))))

(t/deftest exception-test
  (t/testing "throw and catch"
    (let [threw (try
                  (throw {:type :divide-by-zero})
                  false
                  (catch e (= (:type e) :divide-by-zero)))]
      (t/is threw))))

(System/exit (t/run-tests))
```
