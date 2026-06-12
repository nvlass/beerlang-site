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

---

## Try it in your browser

<div id="beer-repl">
  <div id="beer-repl-output"></div>
  <div id="beer-repl-input-row">
    <span class="beer-prompt">user&gt;</span>
    <input id="beer-repl-input" type="text" autocomplete="off" autocorrect="off"
           spellcheck="false" placeholder="(+ 1 2)" disabled>
    <button id="beer-repl-run" disabled>Run</button>
  </div>
  <div id="beer-repl-status">Loading runtime…</div>
</div>

<style>
#beer-repl {
  background: #1a1a1a;
  border-radius: 6px;
  overflow: hidden;
  font-family: "Inconsolata", "Fira Code", monospace;
  font-size: 13px;
  margin: 1.5em 0;
  border: 1px solid #333;
}
#beer-repl-output {
  min-height: 160px;
  max-height: 320px;
  overflow-y: auto;
  padding: 12px 16px;
  color: #d4d4d4;
  line-height: 1.6;
}
.beer-entry-input  { color: #e8a020; }
.beer-entry-stdout { color: #888; white-space: pre-wrap; }
.beer-entry-value  { color: #6dbf67; }
.beer-entry-error  { color: #e06c75; }
.beer-entry-banner { color: #555; font-size: 12px; margin-bottom: 8px; }
#beer-repl-input-row {
  display: flex;
  align-items: center;
  background: #242424;
  border-top: 1px solid #333;
  padding: 8px 16px;
  gap: 8px;
}
.beer-prompt { color: #e8a020; flex-shrink: 0; }
#beer-repl-input {
  flex: 1;
  background: transparent;
  border: none;
  outline: none;
  color: #d4d4d4;
  font-family: inherit;
  font-size: inherit;
  caret-color: #e8a020;
}
#beer-repl-run {
  background: #e8a020;
  color: #1a1a1a;
  border: none;
  border-radius: 3px;
  padding: 3px 10px;
  font-family: inherit;
  font-weight: bold;
  cursor: pointer;
}
#beer-repl-run:disabled { opacity: 0.4; cursor: default; }
#beer-repl-status {
  background: #242424;
  border-top: 1px solid #222;
  padding: 3px 16px;
  font-size: 11px;
  color: #555;
}
</style>

<script src="/wasm/beerlang.js"></script>
<script>
(function(){
  var outputEl = document.getElementById('beer-repl-output');
  var inputEl  = document.getElementById('beer-repl-input');
  var runBtn   = document.getElementById('beer-repl-run');
  var statusEl = document.getElementById('beer-repl-status');
  var Module, evalFn, freeFn;
  var history = [], histIdx = -1;
  var captured = '';

  function append(cls, text) {
    var d = document.createElement('div');
    d.className = cls;
    d.textContent = text;
    outputEl.appendChild(d);
    outputEl.scrollTop = outputEl.scrollHeight;
  }

  BeerlangModule({ print: function(t){ captured += t + '\n'; },
                   printErr: function(t){ captured += t + '\n'; } })
    .then(function(m) {
      Module = m;
      m.ccall('beer_wasm_init', null, [], []);
      evalFn = m.cwrap('beer_wasm_eval', 'number', ['string']);
      freeFn = m.cwrap('beer_wasm_free', null,     ['number']);
      inputEl.disabled = runBtn.disabled = false;
      statusEl.textContent = 'Ready — try (map inc [1 2 3])';
      append('beer-entry-banner', 'Beerlang REPL — press Enter to evaluate');
      inputEl.focus();
    });

  function run() {
    var src = inputEl.value.trim();
    if (!src || !Module) return;
    history.unshift(src); histIdx = -1;
    inputEl.value = '';
    captured = '';
    append('beer-entry-input', 'user> ' + src);
    setTimeout(function() {
      var ptr = evalFn(src);
      var res = JSON.parse(Module.UTF8ToString(ptr));
      freeFn(ptr);
      var out = captured; captured = '';
      if (out) append('beer-entry-stdout', out.replace(/\n$/, ''));
      if (res.ok) { if (res.value) append('beer-entry-value', '=> ' + res.value); }
      else append('beer-entry-error', res.error);
      statusEl.textContent = res.ok ? 'Ready' : 'Error';
      inputEl.focus();
    }, 0);
  }

  runBtn.addEventListener('click', run);
  inputEl.addEventListener('keydown', function(e) {
    if (e.key === 'Enter') { run(); }
    else if (e.key === 'ArrowUp') { e.preventDefault(); if (histIdx+1 < history.length) inputEl.value = history[++histIdx]; }
    else if (e.key === 'ArrowDown') { e.preventDefault(); histIdx > 0 ? (inputEl.value = history[--histIdx]) : (histIdx=-1, inputEl.value=''); }
  });
})();
</script>
