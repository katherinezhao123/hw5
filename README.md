# piq compiler (assignment starter)

**piq** is a tiny drawing language for a pen plotter. In this assignment you write, in Haskell, the compiler that
turns piq programs (written as abstract syntax) into Python programs that draw: first as preview pictures, and in
the lab on a real Bantam Tools NextDraw plotter.

**The full handout is [ASSIGNMENT.md](ASSIGNMENT.md).** Work through it from the top.

## Required software
- **GHC** with `ghci` and `runghc`, and the **hspec** test library (including `hspec-discover`);
- **Python 3 with matplotlib**, for preview pictures (`python3 -c "import matplotlib"` should print nothing).
  If your Python isn't called `python3`, set `PIQ_PYTHON` to its path.

## Quick start
From this folder:
```
make test             # run all the tests (most fail until you implement the TODOs)
ghci Examples.hs      # explore in GHCI; see ASSIGNMENT.md, Part 0
```
Other commands: `make part1` … `make part7` run one part's tests; `make clean` removes generated files.

The file you edit is `PiqEvaluation.hs`. Everything you need to fill in is marked `-- TODO (Part N)`.
