The code is not quite yet in a fully documented state.

# Lean
This codebase was forked from prior published work.
All code relevant to this submission should be in the `Etch/StreamFusion` subdirectory.
The files `Stream.lean` and `Examples/Benchmarks.lean` might be most interesting to browse.

To run benchmarks, install Lean and then

```
lake exec eg
```

# Rust

Run

```
cargo bench
```

# Morphic

Code was compiled with commit d692f4cdd8b7379e85ce6b750d6e8ad9d86e3932 of https://github.com/morphic-lang/morphic.

Building the Morphic compiler is not totally straightforward; we include this code (see `stream.mor`) for reading purposes.
