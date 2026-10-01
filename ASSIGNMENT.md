# Assignment: the piq compiler (abstract syntax → Python → pen plotter)

In this assignment you will write a **compiler** in Haskell. It translates programs in a tiny drawing language
called **piq** into Python programs that drive a real pen plotter (a Bantam Tools NextDraw).

You will not write a parser this week. Instead, you will write piq programs directly as Haskell values: their
**abstract syntax**. For example, this piq program

```
x = 20
square x
move right 30
circle x / 2
```

is written this week as the Haskell value

```haskell
Program [] [ Assign "x" (Num 20)
           , Square (Var "x")
           , Move Rt (Num 30)
           , Circle (Div (Var "x") (Num 2)) ]
```

and your compiler turns it into lines of Python like `pen_up()`, `pen_down()`, and `move_rel(-10.0, -10.0)`.
The provided infrastructure wraps those lines into a runnable Python program, which can draw a **preview picture**
on your computer, or drive the **real plotter**.

```
    AST (a Haskell value)
        |
        |  YOUR WORK: evaluate expressions, compile statements
        v
    [String]  (lines of Python: pen_up(), pen_down(), move_rel(dx, dy))
        |
        |  PROVIDED: wrap into a complete Python program
        v
    python/<name>.py  ──>  preview picture  python/<name>.png
                     └──>  the real pen plotter (in the lab)
```

The work is split into **many small steps**. After every step there is a **Check your work** box that tells you
exactly what to type and exactly what you should see. Don't move on until the check passes.

---

## Contents
- [Learning goals](#learning-goals)
- [Getting started](#getting-started)
- [The files](#the-files)
- [How to work: GHCI, tests, previews](#how-to-work-ghci-tests-previews)
- [The piq language](#the-piq-language)
- [What the compiler produces](#what-the-compiler-produces)
- [Part 0: orientation](#part-0-orientation)
- [Part 1: expressions and environments](#part-1-expressions-and-environments)
- [Part 2: basic drawing](#part-2-basic-drawing)
- [Part 3: circles](#part-3-circles)
- [Part 4: assignment and statement sequences](#part-4-assignment-and-statement-sequences)
- [Part 5: loops](#part-5-loops)
- [Part 6: procedures](#part-6-procedures)
- [Part 7: whole programs](#part-7-whole-programs)
- [Common pitfalls](#common-pitfalls)
- [Final checklist](#final-checklist)
- [Submitting](#submitting)
- [Appendix: the real plotter](#appendix-the-real-plotter)

---

## Learning goals
By the end of this assignment you will have:

- represented a program as an **abstract syntax tree** (algebraic datatypes);
- written a recursive **evaluator** for arithmetic expressions with **variables**, using an **environment**;
- written a **compiler** that translates each kind of statement into code in another language (Python);
- **threaded an environment** explicitly through a sequence of statements, so that assignments affect later
  statements;
- implemented **loops** with a locally scoped loop variable;
- implemented **procedures** with parameters and local environments;
- watched your compiler's output drawn by a (previewed or physical) pen plotter.

---

## Getting started
You need:

- **GHC** (the Haskell compiler, with `ghci` and `runghc`), with the **hspec** testing library;
- **Python 3 with matplotlib**, for preview pictures. Check with:
  ```
  python3 -c "import matplotlib"
  ```
  No output means it works. If your Python has another name, set `PIQ_PYTHON`, e.g.
  `export PIQ_PYTHON=/usr/local/bin/python3`.

Everything in this handout is run **from the top folder of this repository** (the folder containing this file).

---

## The files
| File | What it is |
|---|---|
| `PiqEvaluation.hs` | **YOU WILL EDIT.** The evaluator and compiler. Every place to fill in is marked `-- TODO (Part N)`. |
| `PiqAST.hs` | **PROVIDED: DO NOT EDIT.** The abstract syntax of piq. Read it first. |
| `Python.hs` | **PROVIDED: DO NOT EDIT.** `penUp`, `penDown`, `moveRel`: the only Python your compiler writes. Also the code that wraps your lines into a complete Python file. |
| `Preview.hs` | **PROVIDED: DO NOT EDIT.** GHCI commands to print your compiled code, write Python files, and draw preview pictures. |
| `python/` | **PROVIDED: DO NOT EDIT.** The Python side: the runtime your generated programs call, and the mock plotter that draws previews. |
| `Makefile` | **PROVIDED.** `make test`, `make part1` … `make part7`, `make clean`. |
| `test/*.hs` | **TESTS.** One module per part (for example `test/EvalSpec.hs` for Part 1). Reading a test is a good way to understand what is wanted. |
| `Examples.hs` | **EXAMPLES.** Example piq programs, as abstract syntax, for each part. `ghci Examples.hs` is also the easiest way to start GHCI: it loads everything. |

---

## How to work: GHCI, tests, previews

### GHCI
Start GHCI like this. It loads every module, so all the names in this handout are available:
```
$ ghci Examples.hs
```
After you edit `PiqEvaluation.hs`, type `:reload` (or `:r`) in GHCI to load your changes. `:quit` leaves.

When something has not been implemented yet, or a piq program has an error, GHCI shows an exception. **The first
line is the message.** The lines after it (`CallStack …`) say where in the code it happened:
```
ghci> eval emptyEnv (Var "x")
*** Exception: TODO (Part 1): eval for Var
CallStack (from HasCallStack):
  error, called at ./PiqEvaluation.hs:138:5 in main:PiqEvaluation
```
A `TODO (Part N): …` message means "this is the part you haven't written yet". It is not a bug.

### Tests
| Command | Runs |
|---|---|
| `make test` | all the tests (the final check) |
| `make part1` … `make part7` | only one part's tests |
| `runghc -itest test/Spec.hs --match "Step 2.3"` | only one step's tests |

Every step below tells you which command to run and exactly what the last line should say, for example
`5 examples, 0 failures`. Before you finish, **tests for later parts will fail**, with `TODO` messages. That's
expected: run the command for the step you're on.

### Previews
The provided `Preview` module writes your compiled code into a Python file and runs it with a **mock plotter**,
which draws a picture instead of moving a real pen:

- `previewStmts "name" [ … ]` for a list of drawing statements (Parts 0–3);
- `previewProgram "name" (Program … )` for a whole program (Part 4 on).

Both write `python/name.py` and `python/name.png`. Open the `.png` with any image viewer. In the picture:

- **blue lines** are drawn with the pen down;
- **pink lines** show where the pen travelled while it was up. The pen starts from the plotter's home corner
  (top left), goes to the centre of the paper where your program begins, and returns home at the end, so there
  are always a few pink lines to and from the corner;
- the **grey dashed box** is the safe area (below), and anything **red** went outside it.

The paper is 17 × 11 inches (about 432 × 279 mm). Your program starts at its centre, and must stay inside
the **safe area**: at least 1 inch from the paper's edges, which means within **190.5 mm left/right and
114.3 mm up/down** of the start. If a drawing leaves the safe area, the preview still works (with a warning, and the
offending moves in red), but the real plotter refuses to draw it.

> **Tests check correctness. Previews let you *see* your drawing. The real plotter is a separate, optional step
> (see the [appendix](#appendix-the-real-plotter)).** Automated tests never need Python or the plotter.

---

## The piq language
Open `PiqAST.hs` and read it alongside this section.

**Expressions** (`Expr`) are arithmetic on numbers (every value in piq is a `Double`):

| Abstract syntax | Meaning |
|---|---|
| `Num 3` | the number 3 |
| `Var "x"` | the value of variable `x` |
| `Add e1 e2`, `Sub e1 e2`, `Mul e1 e2`, `Div e1 e2` | `e1 + e2`, `e1 - e2`, `e1 * e2`, `e1 / e2` |

For example, `Add (Var "x") (Mul (Num 5) (Num 2))` means `x + 5 * 2`. A negative number needs parentheses in
Haskell: `Num (-5)`.

**Directions** (`Direction`) are page-relative: `Lt`, `Rt`, `Up`, `Dn`. "Up" always means toward the top of the
page. There is no turning.

**Statements** (`Stmt`):

| Abstract syntax | Meaning |
|---|---|
| `Assign "x" e` | `x = e`: give variable `x` the value of `e` |
| `Dot` | a dot at the current position |
| `Square s` | a square with side `s`, **centered** on the current position |
| `Rectangle w h` | a `w` × `h` rectangle, centered on the current position |
| `Circle r` | a circle of radius `r`, centered on the current position |
| `Move d n` | travel `n` mm in direction `d` **without** drawing |
| `Line d n` | draw a line `n` mm long in direction `d` |
| `For "i" e1 e2 body` | repeat `body` (a list of statements) for `i` from `e1` to `e2` |
| `Call "f" args` | run procedure `f` with the given argument expressions |

A **program** is `Program defs stmts`: procedure definitions (`ProcDef name params body`), then the statements to
run.

---

## What the compiler produces
Your compiler produces a list of strings, `[String]`, one line of Python each. Only three kinds of line are ever
needed. You don't write the strings yourself; you use the functions from `Python.hs`:

| Haskell (from `Python.hs`) | Python line | Meaning |
|---|---|---|
| `penUp` | `pen_up()` | raise the pen |
| `penDown` | `pen_down()` | lower the pen onto the paper |
| `moveRel dx dy` | `move_rel(dx, dy)` | travel `dx` mm right and `dy` mm up. It **draws if the pen is down**, and doesn't if it's up |

So `moveRel 10 (-5)` means "10 mm right and 5 mm **down**". Positive `dy` is **up** the page.

The rules that give piq its meaning (the "spatial semantics"):

- **There is a current position.** Moves are relative to it, and it changes as the pen travels.
- **Closed shapes** (`Dot`, `Square`, `Rectangle`, `Circle`) are **centered** on the current position, and **leave
  the current position unchanged**: the pen ends exactly where it started. That makes shapes easy to place: move
  to a spot, then draw a shape around it.
- **`Move`** travels without drawing; **`Line`** draws and leaves the pen at the far end. Both change the position.
- **Between statements, the pen is always up.** Every statement that lowers the pen raises it again before it ends.
  This is a promise every statement keeps, so no statement ever has to worry about what came before it. Extra
  `pen_up()` lines are fine.

---

## Part 0: orientation
There is nothing to implement in Part 0. You will look around and make your first picture.

### Step 0.1: the abstract syntax and the three Python functions
Start GHCI with `ghci Examples.hs` and type in some abstract syntax. GHCI shows each value back (numbers are
`Double`s, so `3` shows as `3.0`). Then look at the three Python helpers, which are just strings.

> **✅ Check your work (Step 0.1)**
> <!-- state: 0.0 -->
> ```
> ghci> Num 3
> Num 3.0
> ghci> Add (Num 2) (Num 5)
> Add (Num 2.0) (Num 5.0)
> ghci> Square (Num 20)
> Square (Num 20.0)
> ghci> Move Rt (Num 30)
> Move Rt (Num 30.0)
> ghci> penUp
> "pen_up()"
> ghci> moveRel 10 (-5)
> "move_rel(10.0, -5.0)"
> ```

### Step 0.2: the provided `Dot`, and your first picture
One statement is already compiled for you: `Dot`. Find it in `PiqEvaluation.hs`:
```haskell
compileStmt _ env Dot = (env, dotCode)
dotCode = [penDown, penUp]
```
`compileStmt` returns a **pair**: the environment after the statement (unchanged, for a dot) and the Python lines.
GHCI prints an environment as `fromList [...]`: a list of (name, value) pairs, empty here.

> **✅ Check your work (Step 0.2)**
> <!-- state: 0.0 -->
> ```
> ghci> compileStmt emptyProcEnv emptyEnv Dot
> (fromList [],["pen_down()","pen_up()"])
> ghci> showStmts [Dot, Dot]
> pen_down()
> pen_up()
> pen_down()
> pen_up()
> ghci> previewStmts "dot" [Dot]
> Writing python/dot.py
> [nextdraw_backend] Using MOCK NextDraw (preview only)
> [mock_nextdraw] Saved preview to …/python/dot.png
> Preview: python/dot.png
> ```
> **Drawing check:** open `python/dot.png`. You should see a single blue dot at the centre of the paper, plus pink
> pen-up travel lines to and from the top-left corner. You can also open `python/dot.py` to see the complete
> Python program your code became.
>
> **Test check:**
> <!-- state: 0.0 -->
> ```
> $ runghc -itest test/Spec.hs --match "Step 2.1"
> 1 example, 0 failures
> ```
> **Ready to continue** when you have the picture and this test passes.

---

## Part 1: expressions and environments
You have written an arithmetic evaluator before. This one adds **variables**. To know what `x + 1` means, you need
to know `x`'s value. An **environment** is a lookup table from variable names to values:

```haskell
type Env = Map.Map Name Double
```

`Data.Map` is Haskell's lookup table. You need very little of it, and the comments at the top of
`PiqEvaluation.hs` list the four functions you'll use. Environments are **values**: "changing" one builds a
new one and leaves the old one alone. `emptyEnv` and `assignVar` are provided; read them.

The evaluator has type `eval :: Env -> Expr -> Double`: given the values of the variables, what number does
this expression stand for?

### Step 1.1: numbers
`eval _ (Num n) = n` is provided. A number means itself.

> **✅ Check your work (Step 1.1)**
> <!-- state: 0.0 -->
> ```
> ghci> eval emptyEnv (Num 3)
> 3.0
> ```
> ```
> $ runghc -itest test/Spec.hs --match "Step 1.1"
> 2 examples, 0 failures
> ```

### Step 1.2: variables
**Implement** `lookupVar` and the `Var` case of `eval`.

- `lookupVar name env` returns the variable's value. Use `Map.lookup name env`, which returns `Just value` if the
  variable is there and `Nothing` if it isn't. Handle both with a `case` expression.
- A variable that isn't there is an **error in the piq program**. Stop with exactly this message:
  `error ("undefined variable: " ++ name)`
- `eval` for `Var name` is then one line.

> **✅ Check your work (Step 1.2)**
> <!-- state: 1.2 -->
> ```
> ghci> lookupVar "x" (assignVar "x" 10 emptyEnv)
> 10.0
> ghci> eval (assignVar "x" 10 emptyEnv) (Var "x")
> 10.0
> ghci> lookupVar "x" emptyEnv
> *** Exception: undefined variable: x
> …
> ```
> ```
> $ runghc -itest test/Spec.hs --match "Step 1.2"
> 5 examples, 0 failures
> ```

### Step 1.3: addition and subtraction
**Implement** the `Add` and `Sub` cases. Evaluate both sub-expressions **recursively**, in the same environment,
then combine the results. This is exactly your old evaluator's recursion, with an extra `env` argument passed
along.

> **✅ Check your work (Step 1.3)**
> <!-- state: 1.3 -->
> ```
> ghci> eval emptyEnv (Sub (Num 10) (Sub (Num 3) (Num 2)))
> 9.0
> ghci> eval (assignVar "x" 10 emptyEnv) (Add (Var "x") (Num 5))
> 15.0
> ```
> ```
> $ runghc -itest test/Spec.hs --match "Step 1.3"
> 6 examples, 0 failures
> ```

### Step 1.4: multiplication and division
**Implement** `Mul` and `Div`. Division has a rule: if the divisor **evaluates to** 0, stop with
`error "division by zero"`. Haskell would otherwise quietly produce `Infinity`, which must never reach the plotter.
Note that the divisor might be an expression that happens to be 0, like `2 - 2`, not only the literal `0`.

*Strategy:* a guard (`| … = …`) with a `where` clause naming the divisor's value.

> **✅ Check your work (Step 1.4)**
> <!-- state: 1.4 -->
> ```
> ghci> eval emptyEnv (Add (Num 2) (Mul (Num 3) (Num 4)))
> 14.0
> ghci> eval emptyEnv (Div (Num 7) (Num 2))
> 3.5
> ghci> eval emptyEnv (Div (Num 1) (Sub (Num 2) (Num 2)))
> *** Exception: division by zero
> …
> ```
> ```
> $ runghc -itest test/Spec.hs --match "Step 1.4"
> 7 examples, 0 failures
> ```

### Step 1.5: environments are values
Nothing new to write. These tests check that `assignVar` builds a new environment without changing the old one.
Notice how `eval` always sees exactly the environment you hand it.

> **✅ Check your work (Step 1.5)**
> <!-- state: 1.4 -->
> ```
> $ runghc -itest test/Spec.hs --match "Step 1.5"
> 4 examples, 0 failures
> ```

### Step 1.6: errors
Nothing new to write, if Steps 1.2 and 1.4 are right. These tests check the two error messages, including
errors deep inside larger expressions.

> **✅ Check your work (Step 1.6, and all of Part 1)**
> <!-- state: 1.4 -->
> ```
> $ runghc -itest test/Spec.hs --match "Step 1.6"
> 5 examples, 0 failures
> $ make part1
> 29 examples, 0 failures
> ```
> **Ready to continue** when `make part1` shows `29 examples, 0 failures`.

---

## Part 2: basic drawing
Now the compiler proper. `compileStmt` turns one statement into Python lines:

```haskell
compileStmt :: ProcEnv -> Env -> Stmt -> (Env, [String])
```

It gets a procedure environment (**ignore it until Part 6**), the current variable environment, and a statement.
It returns the environment **after** the statement, and the statement's Python lines. Drawing statements never
change the environment, so for them the first part of the result is just `env`.

Each drawing statement has a small helper that builds its lines from plain numbers (`moveCode`, `squareCode`, …).
`compileStmt` **evaluates** the statement's expressions with `eval` and passes the numbers to the helper. That
keeps "what does this expression mean?" separate from "what lines draw this shape?".

### Step 2.1: the provided Dot
You already saw it in Part 0. Its test passes already.

### Step 2.2: directions
**Implement** the other three cases of `offset :: Direction -> Double -> (Double, Double)`. It says how far a
trip of `distance` mm in a direction travels, as `(dx, dy)`. `offset Rt distance = (distance, 0)` is provided.
Remember that **up is positive y**.

> **✅ Check your work (Step 2.2)**
> <!-- state: 2.2 -->
> ```
> ghci> offset Lt 5
> (-5.0,0.0)
> ghci> offset Up 5
> (0.0,5.0)
> ghci> offset Dn 5
> (0.0,-5.0)
> ```
> ```
> $ runghc -itest test/Spec.hs --match "Step 2.2"
> 4 examples, 0 failures
> ```

### Step 2.3: move
**Implement** `moveCode` and the `Move` case of `compileStmt`.

- A move **raises the pen**, then travels by the offset: exactly two lines, `pen_up()` then `move_rel(dx, dy)`.
  (The pen is already up between statements, so the `pen_up()` is redundant, but it makes the move safe
  regardless.)
- In `compileStmt`, evaluate the distance with `eval env distance` and call `moveCode`.

> **✅ Check your work (Step 2.3)**
> <!-- state: 2.3 -->
> ```
> ghci> moveCode Rt 30
> ["pen_up()","move_rel(30.0, 0.0)"]
> ghci> showStmts [Move Up (Num 15)]
> pen_up()
> move_rel(0.0, 15.0)
> ghci> previewStmts "moves" [Dot, Move Rt (Num 20), Dot, Move Up (Num 20), Dot]
> Writing python/moves.py
> [nextdraw_backend] Using MOCK NextDraw (preview only)
> [mock_nextdraw] Saved preview to …/python/moves.png
> Preview: python/moves.png
> ```
> **Drawing check:** `python/moves.png` shows three dots: at the centre, 20 mm to its right, and 20 mm above that
> one. They're joined only by pink (pen-up) lines, because moves don't draw.
> ```
> $ runghc -itest test/Spec.hs --match "Step 2.3"
> 7 examples, 0 failures
> ```

### Step 2.4: line
**Implement** `lineCode` and the `Line` case: `pen_down()`, the move, `pen_up()`. The pen ends at the far end of
the line; that's the "current position changes" rule.

> **✅ Check your work (Step 2.4)**
> <!-- state: 2.4 -->
> ```
> ghci> lineCode Dn 10
> ["pen_down()","move_rel(0.0, -10.0)","pen_up()"]
> ghci> previewStmts "zigzag" [Line Rt (Num 20), Line Up (Num 20), Line Rt (Num 20), Line Dn (Num 20)]
> Writing python/zigzag.py
> [nextdraw_backend] Using MOCK NextDraw (preview only)
> [mock_nextdraw] Saved preview to …/python/zigzag.png
> Preview: python/zigzag.png
> ```
> **Drawing check:** a blue path from the centre: 20 mm right, 20 mm **up**, 20 mm right, 20 mm down, like a
> square bump. If the bump points down, your `Up`/`Dn` offsets are swapped.
> ```
> $ runghc -itest test/Spec.hs --match "Step 2.4"
> 5 examples, 0 failures
> ```

### Step 2.5: square
**Implement** `squareCode` and the `Square` case. The current position is the **centre** of the square. Think in
three stages:

1. travel to one corner **with the pen up** (half a side left and half a side down reaches the bottom-left corner);
2. lower the pen and draw the four sides (each `side` long), ending back at that corner;
3. raise the pen and travel back to the centre.

The tests check **what is drawn** (exactly the four sides, centred on the start, in one stroke, meaning only
one `pen_down()`), that the pen **ends at the centre**, and that it **ends up**. Any starting corner and either
direction around is fine.

> **✅ Check your work (Step 2.5)**
> <!-- state: 2.5 -->
> ```
> ghci> length (filter (== "pen_down()") (squareCode 20))
> 1
> ghci> take 1 (squareCode 20)
> ["pen_up()"]
> ```
> One stroke, and it starts by raising the pen. Also look at your code with `showStmts [Square (Num 20)]`: you
> should see a pen-up trip to a corner, four sides of 20 mm with the pen down, and a pen-up trip back to the centre.
> Any starting corner, and either direction around, is fine.
> ```
> ghci> previewStmts "squares" [Square (Num 60), Square (Num 40), Square (Num 20), Dot]
> Writing python/squares.py
> [nextdraw_backend] Using MOCK NextDraw (preview only)
> [mock_nextdraw] Saved preview to …/python/squares.png
> Preview: python/squares.png
> ```
> **Drawing check:** three nested squares (60, 40 and 20 mm) sharing one centre, with the dot exactly in the
> middle. If they aren't concentric, a square isn't returning to its centre.
> ```
> $ runghc -itest test/Spec.hs --match "Step 2.5"
> 13 examples, 0 failures
> ```

### Step 2.6: rectangle
**Implement** `rectangleCode` and the `Rectangle` case. It's just like the square, but with half the **width**
across and half the **height** up and down. `Rectangle w h` is `w` wide and `h` tall; don't swap them.

> **✅ Check your work (Step 2.6)**
> <!-- state: 2.6 -->
> ```
> ghci> previewStmts "centred" part2Centred
> Writing python/centred.py
> [nextdraw_backend] Using MOCK NextDraw (preview only)
> [mock_nextdraw] Saved preview to …/python/centred.png
> Preview: python/centred.png
> ```
> **Drawing check:** `part2Centred` (in `Examples.hs`) is three nested squares, a wide 100 × 20 rectangle and a
> tall 20 × 100 one crossing them, and a dot, all sharing one centre.
> ```
> $ runghc -itest test/Spec.hs --match "Step 2.6"
> 9 examples, 0 failures
> ```

### Step 2.7: drawing leaves the environment alone
Nothing new to write: this checks that every drawing statement returns the environment it was given.

> **✅ Check your work (Step 2.7, and all of Part 2)**
> <!-- state: 2.6 -->
> ```
> ghci> fst (compileStmt emptyProcEnv (assignVar "x" 10 emptyEnv) (Square (Var "x")))
> fromList [("x",10.0)]
> ```
> ```
> $ runghc -itest test/Spec.hs --match "Step 2.7"
> 1 example, 0 failures
> $ make part2
> 40 examples, 0 failures
> ```
> More pictures to try: `previewStmts "row" part2Row`, `previewStmts "grid" part2DotGrid`, and
> `previewStmts "staircase" part2Staircase`. **Ready to continue** when `make part2` passes.

---

## Part 3: circles
A plotter can only draw straight lines, so a circle is drawn as a **regular polygon with 36 sides**
(`circleSegments`, provided). At that size nobody can tell the difference.

**The geometry (given to you).** Put the centre of the circle at (0, 0). Number the corners of the polygon
k = 0, 1, …, 36. Corner k is at angle θₖ = 2πk / 36 (in radians), which is the point

```
( r · cos θₖ ,  r · sin θₖ )
```

Corner 0 is the rightmost point of the circle, (r, 0), and corner 36 is the same point again: all the way round.

**The plan for `circleCode r`:**

1. With the pen up, travel from the centre to corner 0: `move_rel(r, 0)`.
2. Lower the pen.
3. For each k from 0 to 35, travel from corner k to corner k + 1. That's a relative move of
   ```
   dx = r·cos θₖ₊₁ − r·cos θₖ          dy = r·sin θₖ₊₁ − r·sin θₖ
   ```
4. Raise the pen and travel back to the centre: `move_rel(-r, 0)`.

**In Haskell:** `cos`, `sin` and `pi` are built in. Step 3 is a good place for `map` over the list
`[0 .. circleSegments - 1]`: write a local helper (in a `where`) that takes k and produces the `moveRel` for
step k. `k` is an `Int`, so use `fromIntegral k` to use it in the angle formula. Computing each step from the two
corners (not by adding up the previous steps) makes the path close exactly.

### Step 3.1: `circleCode` and the `Circle` case
**Implement** both.

> **✅ Check your work (Step 3.1)**
> <!-- state: 3.1 -->
> ```
> ghci> circleSegments
> 36
> ghci> length (filter (== "pen_down()") (circleCode 10))
> 1
> ghci> previewStmts "concentric" part3Concentric
> Writing python/concentric.py
> [nextdraw_backend] Using MOCK NextDraw (preview only)
> [mock_nextdraw] Saved preview to …/python/concentric.png
> Preview: python/concentric.png
> ```
> **Drawing check:** three concentric circles (radius 10, 20, 40 mm) around a dot. At this size you can just see
> the corners of the 36-sided polygons on the biggest one.
> ```
> $ runghc -itest test/Spec.hs --match "Step 3.1"
> 6 examples, 0 failures
> ```

### Step 3.2: circles as statements
Nothing new: this checks that the circle returns to its centre, ends with the pen up, and evaluates its radius.

> **✅ Check your work (Step 3.2, and all of Part 3)**
> <!-- state: 3.1 -->
> ```
> ghci> previewStmts "inscribed" part3Inscribed
> Writing python/inscribed.py
> [nextdraw_backend] Using MOCK NextDraw (preview only)
> [mock_nextdraw] Saved preview to …/python/inscribed.png
> Preview: python/inscribed.png
> ```
> **Drawing check:** on the left, a circle exactly touching all four sides of a square; on the right, a circle
> passing exactly through a square's four corners.
> ```
> $ runghc -itest test/Spec.hs --match "Step 3.2"
> 6 examples, 0 failures
> $ make part3
> 12 examples, 0 failures
> ```

---

## Part 4: assignment and statement sequences
So far every statement has been compiled on its own, starting with no variables. That's what `previewStmts`
does, and it's why it can't handle this:

```
x = 10
square x
```

The square needs to know that `x` is 10, and that knowledge was created by the **previous** statement. This part
makes statements run **in sequence**, passing the environment from each statement to the next.

### Step 4.1: assignment
**Implement** the `Assign` case of `compileStmt`. An assignment produces **no Python**. It returns a new
environment in which the variable has the value of the expression, evaluated in the **current** environment.
(So `x = x * 2` uses the old `x` to compute the new one.)

**Wrap your result with the provided `forceValue`:** `forceValue value (newEnv, [])`. Haskell is lazy: without
this, the value wouldn't be computed until some later statement needed it, and a bad assignment such as
`x = 1 / 0` would never be reported if `x` were never used. One test checks exactly that.

> **✅ Check your work (Step 4.1)**
> <!-- state: 4.1 -->
> ```
> ghci> compileStmt emptyProcEnv emptyEnv (Assign "x" (Num 10))
> (fromList [("x",10.0)],[])
> ghci> compileStmt emptyProcEnv (assignVar "x" 10 emptyEnv) (Assign "x" (Mul (Var "x") (Num 2)))
> (fromList [("x",20.0)],[])
> ```
> And here is the problem Step 4.2 solves: compiled one at a time, the square never sees `x`:
> ```
> ghci> previewStmts "broken" [Assign "x" (Num 10), Square (Var "x")]
> *** Exception: undefined variable: x
> …
> ```
> ```
> $ runghc -itest test/Spec.hs --match "Step 4.1"
> 8 examples, 0 failures
> ```

### Step 4.2: sequences
**Implement** the recursive case of `compileStmts`:

```haskell
compileStmts :: ProcEnv -> Env -> [Stmt] -> (Env, [String])
```

The empty case is provided: no statements, no code, the environment unchanged. For `stmt : stmts`:

```
   env ──[ compile stmt ]──> env after stmt ──[ compile stmts ]──> final env
              │                                      │
       code for stmt                          code for the rest
```

**The invariant: the next statement sees the environment produced by the previous one.** The result pairs the
final environment with all of the code, in order. A `where` clause that names the two recursive results with
**tuple patterns** (for example `(nextEnv, firstCode) = …`) expresses this directly. The environment is passed
along **explicitly**: there's no hidden state.

Now you can use **whole programs**: `showProgram` and `previewProgram` go through the provided `compileProgram`,
which uses your `compileStmts`.

> **✅ Check your work (Step 4.2, and all of Part 4)**
> <!-- state: 4.2 -->
> ```
> ghci> compileStmts emptyProcEnv emptyEnv [Assign "x" (Num 10), Assign "y" (Mul (Var "x") (Num 2))]
> (fromList [("x",10.0),("y",20.0)],[])
> ghci> showProgram (Program [] [Assign "x" (Num 10), Dot])
> pen_down()
> pen_up()
> ghci> previewProgram "doubling" (Program [] part4Doubling)
> Writing python/doubling.py
> [nextdraw_backend] Using MOCK NextDraw (preview only)
> [mock_nextdraw] Saved preview to …/python/doubling.png
> Preview: python/doubling.png
> ```
> **Drawing check:** `part4Doubling` is `x = 10; square x; x = x * 2; square x; x = x * 2; square x`. It shows
> three concentric squares of 10, 20 and 40 mm. Also try `previewProgram "frame" (Program [] part4Frame)`: a
> 120 × 60 frame with a 10 mm inner margin and a line across the middle.
> ```
> $ runghc -itest test/Spec.hs --match "Step 4.2"
> 11 examples, 0 failures
> $ make part4
> 19 examples, 0 failures
> ```

---

## Part 5: loops
`For "i" from to body` repeats `body` once for each whole number from `from` to `to`, **inclusive**, with `i` set
to that number. The rules:

- the bounds are evaluated **once**, before the loop, in the environment from before the loop;
- both bounds must be **whole numbers** (`2.5` is an error);
- if `from` is bigger than `to`, the body runs **zero** times;
- assignments to **other** variables inside the body persist, into later iterations and after the loop;
- the loop variable is **local to the loop**. Afterwards, it gets back whatever value it had before the loop, or
  disappears if it didn't exist.

Why the last rule? A loop shouldn't clobber a variable that happens to share its loop variable's name:
```
i = 100
for i from 1 to 3 { dot }
square i        -- still a 100 mm square
```

### Step 5.1: the loop helpers
**Implement:**

- `saveVar name env`: the variable's value (`Just v`) or `Nothing`. This is exactly one `Data.Map` function.
- `restoreVar name saved env`: put back what `saveVar` found. `Just v` binds the variable to `v`; `Nothing` removes
  it (`Map.delete`). Two equations, one per case.
- `toLoopBound bound`: turn a whole-number `Double` into an `Int`, or stop with
  `error ("non-integral loop bound: " ++ show bound)`. `round` gives the nearest `Int`; the bound is whole exactly
  when turning that back with `fromIntegral` gives the bound again.

> **✅ Check your work (Step 5.1)**
> <!-- state: 5.1 -->
> ```
> ghci> saveVar "x" (assignVar "x" 10 emptyEnv)
> Just 10.0
> ghci> saveVar "y" (assignVar "x" 10 emptyEnv)
> Nothing
> ghci> restoreVar "x" (Just 1) (assignVar "x" 10 emptyEnv)
> fromList [("x",1.0)]
> ghci> restoreVar "x" Nothing (assignVar "x" 10 emptyEnv)
> fromList []
> ghci> toLoopBound 3
> 3
> ghci> toLoopBound 2.5
> *** Exception: non-integral loop bound: 2.5
> …
> ```
> ```
> $ runghc -itest test/Spec.hs --match "Step 5.1"
> 7 examples, 0 failures
> ```

### Step 5.2: `compileLoop` and the `For` case
**Implement `compileLoop procs var values env body`.** It compiles the body once for each value in the list
`values`, in order:

- no values: no code, environment unchanged;
- value `v` followed by the rest: compile the body (with `compileStmts`) in `env` **with `var` set to `v`**, then
  compile the rest of the values starting from the environment the body left. Combine the code.

It is shaped very much like `compileStmts`: the environment flows from one iteration into the next, which is how
`total = total + i` accumulates. (`v` is an `Int`; `assignVar` wants a `Double`, so use `fromIntegral v`.)

**Implement the `For` case** of `compileStmt`:

1. evaluate both bounds and turn them into `Int`s with `toLoopBound`;
2. remember the loop variable's old value with `saveVar`;
3. run `compileLoop` over the list `[start .. end]`. Haskell's `[5 .. 1]` is `[]`, so "zero iterations" is free;
4. return the loop's final environment **with the loop variable restored** (`restoreVar`), and the loop's code.

> **✅ Check your work (Step 5.2)**
> <!-- state: 5.2 -->
> ```
> ghci> fst (compileStmts emptyProcEnv emptyEnv [Assign "total" (Num 0), For "i" (Num 1) (Num 4) [Assign "total" (Add (Var "total") (Var "i"))]])
> fromList [("total",10.0)]
> ghci> showProgram (Program [] [For "i" (Num 1) (Num 3) [Move Rt (Var "i")]])
> pen_up()
> move_rel(1.0, 0.0)
> pen_up()
> move_rel(2.0, 0.0)
> pen_up()
> move_rel(3.0, 0.0)
> ghci> previewProgram "growing" (Program [] part5Growing)
> Writing python/growing.py
> [nextdraw_backend] Using MOCK NextDraw (preview only)
> [mock_nextdraw] Saved preview to …/python/growing.png
> Preview: python/growing.png
> ```
> **Drawing check:** a row of five squares growing from 8 to 40 mm, and above the middle one a target of eight
> concentric circles. Both come from loops.
> ```
> $ runghc -itest test/Spec.hs --match "Step 5.2"
> 9 examples, 0 failures
> ```

### Steps 5.3–5.6: zero iterations, bounds, scope, nesting
Nothing new to write. These tests check the rules above more thoroughly. If one fails, its name says which rule.

> **✅ Check your work (Steps 5.3–5.6, and all of Part 5)**
> <!-- state: 5.2 -->
> ```
> ghci> showProgram (Program [] [For "i" (Num 5) (Num 1) [Dot]])
> ghci> fst (compileStmts emptyProcEnv emptyEnv [Assign "i" (Num 100), For "i" (Num 1) (Num 3) [Dot]])
> fromList [("i",100.0)]
> ghci> fst (compileStmts emptyProcEnv emptyEnv [For "i" (Num 1) (Num 3) [Dot]])
> fromList []
> ```
> The first prints nothing (zero iterations). The second shows the old `i` restored; the third shows a new loop
> variable gone afterwards.
> ```
> $ runghc -itest test/Spec.hs --match "Step 5.3"
> 3 examples, 0 failures
> $ runghc -itest test/Spec.hs --match "Step 5.4"
> 7 examples, 0 failures
> $ runghc -itest test/Spec.hs --match "Step 5.5"
> 7 examples, 0 failures
> $ runghc -itest test/Spec.hs --match "Step 5.6"
> 8 examples, 0 failures
> $ make part5
> 41 examples, 0 failures
> ```
> **Drawing check (three nested loops):** `previewProgram "targets" (Program [] part5Targets)` shows a 3 × 3
> grid of three-ring targets, 35 mm apart.

---

## Part 6: procedures
A procedure is a named, parameterised list of statements, defined at the top of a program:

```haskell
ProcDef "box" ["size", "gap"] [ Square (Var "size"), Move Rt (Add (Var "size") (Var "gap")) ]
```

and called with `Call "box" [Num 20, Num 5]`. The **procedure environment** (`ProcEnv`) maps names to
definitions. It's built for you by `compileProgram` (with `makeProcEnv`), and `lookupProc` finds a definition
(stopping with `unknown procedure: …` if there isn't one). This is the `procs` argument that `compileStmt` has been
passing along all this time.

**What a call means:**

1. look up the procedure;
2. check the number of arguments. If it's wrong, stop with exactly
   `procedure <name> expects <n> arguments, got <m>`, e.g. `procedure box expects 2 arguments, got 1`;
3. evaluate **all** the arguments in the **caller's** environment;
4. make a **local environment**: the caller's environment, with each parameter bound to its argument's value (a
   parameter hides a caller variable of the same name);
5. compile the procedure's body in the local environment;
6. keep only the body's **code**. The caller carries on with **its own, unchanged** environment: nothing the
   procedure assigns escapes.

**Recursion is not allowed.** A procedure that calls itself, directly or through other procedures, is an
invalid piq program. The compiler does not check for this (compiling one never finishes), and no test uses it.

### Step 6.1: binding parameters
**Implement** `bindParams params values env`: bind the first parameter to the first value, the second to the
second, and so on, starting from `env`. Recurse on both lists at once. When they run out, return the environment.

> **✅ Check your work (Step 6.1)**
> <!-- state: 6.1 -->
> ```
> ghci> bindParams ["a", "b"] [1, 2] emptyEnv
> fromList [("a",1.0),("b",2.0)]
> ghci> bindParams ["x"] [5] (assignVar "x" 1 emptyEnv)
> fromList [("x",5.0)]
> ```
> ```
> $ runghc -itest test/Spec.hs --match "Step 6.1"
> 3 examples, 0 failures
> ```

### Step 6.2: calls
**Implement** the `Call` case, following the six steps above. Suggestions:

- use a **guard** for the arity error, and a `where` clause for everything else;
- a `where` clause can take a value apart with a **pattern**. For example, if `p` is a `Program`, then
  `Program defs stmts = p` names both parts. Use the same idea on the `ProcDef` that `lookupProc` returns;
- evaluating a list of arguments in one environment is a job for `map`;
- compile the body with `compileStmts`, and keep only its **code**. When a `where` tuple pattern contains a part you
  don't need, write `_` for it;
- **wrap your final result with the provided `forceValues`**, giving it the list of argument values, for the same
  laziness reason as `forceValue` in Step 4.1 (a bad argument that the procedure never uses must still be
  reported).

Start with a simple procedure before trying procedures that call procedures.

> **✅ Check your work (Step 6.2)**
> <!-- state: 6.2 -->
> ```
> ghci> showProgram (Program [ProcDef "twoDots" [] [Dot, Move Rt (Num 5), Dot]] [Call "twoDots" []])
> pen_down()
> pen_up()
> pen_up()
> move_rel(5.0, 0.0)
> pen_down()
> pen_up()
> ghci> previewProgram "boxes" part6Boxes
> Writing python/boxes.py
> [nextdraw_backend] Using MOCK NextDraw (preview only)
> [mock_nextdraw] Saved preview to …/python/boxes.png
> Preview: python/boxes.png
> ```
> **Drawing check:** `part6Boxes` calls `box(size, gap)` from a loop: five squares growing from 8 to 40 mm, with
> exactly 10 mm between neighbouring edges.
> ```
> $ runghc -itest test/Spec.hs --match "Step 6.2"
> 11 examples, 0 failures
> ```

### Steps 6.3–6.5: scope, errors, whole programs
Nothing new to write. `part6Shadowing` is this program:
```
define foo(x) { x = x + 100; square x }
x = 10
foo(20)
square x
```
Inside `foo`, `x` is the parameter (20), so it draws a square of 120. After the call, the caller's `x` is still 10.

> **✅ Check your work (Steps 6.3–6.5, and all of Part 6)**
> <!-- state: 6.2 -->
> ```
> ghci> fst (compileStmts (makeProcEnv [ProcDef "foo" ["x"] [Assign "x" (Add (Var "x") (Num 100)), Square (Var "x")]]) (assignVar "x" 10 emptyEnv) [Call "foo" [Num 20]])
> fromList [("x",10.0)]
> ghci> compileProgram (Program [] [Call "nope" []])
> *** Exception: unknown procedure: nope
> …
> ghci> compileProgram (Program [ProcDef "ring" ["r"] [Circle (Var "r")]] [Call "ring" [Num 1, Num 2]])
> *** Exception: procedure ring expects 1 arguments, got 2
> …
> ghci> previewProgram "shadowing" part6Shadowing
> Writing python/shadowing.py
> [nextdraw_backend] Using MOCK NextDraw (preview only)
> [mock_nextdraw] Saved preview to …/python/shadowing.png
> Preview: python/shadowing.png
> ```
> **Drawing check:** two concentric squares, 120 mm and 10 mm. Then try
> `previewProgram "flowers" part6Flowers`: `flower` calls `target`, which contains a loop. You should see two
> flowers, each made of five three-ring targets.
> ```
> $ runghc -itest test/Spec.hs --match "Step 6.3"
> 10 examples, 0 failures
> $ runghc -itest test/Spec.hs --match "Step 6.4"
> 7 examples, 0 failures
> $ runghc -itest test/Spec.hs --match "Step 6.5"
> 8 examples, 0 failures
> $ make part6
> 39 examples, 0 failures
> ```

---

## Part 7: whole programs
Nothing new to write: your compiler is complete. Now use it.

### Step 7.1: every example
`Examples.hs` has example programs for every part. Its `main` compiles and previews all 21 of them into
`python/`:

> **✅ Check your work (Step 7.1)**
> <!-- state: 6.2 -->
> ```
> $ runghc Examples.hs
> Writing python/part2_centred.py
> [nextdraw_backend] Using MOCK NextDraw (preview only)
> [mock_nextdraw] Saved preview to …/python/part2_centred.png
> Preview: python/part2_centred.png
> …
> ```
> It ends with `Preview: python/part7_tiles.png`. Look through the pictures in `python/`.
> ```
> $ runghc -itest test/Spec.hs --match "Step 7.1"
> 21 examples, 0 failures
> ```

### Step 7.2: the showcase
`part7Showcase` is a night city that uses **every** feature:

- `window(w)` draws a square with pane lines;
- `building(floors, cols, w)` computes its own size and places its windows with nested loops;
- `sun(r)` draws a circle with rays;
- two rows of stars are drawn with loops of dots.

Read it in `Examples.hs`. It's a real program in your language.

> **✅ Check your work (Step 7.2)**
> <!-- state: 6.2 -->
> ```
> ghci> previewProgram "showcase" part7Showcase
> Writing python/showcase.py
> [nextdraw_backend] Using MOCK NextDraw (preview only)
> [mock_nextdraw] Saved preview to …/python/showcase.png
> Preview: python/showcase.png
> ```
> **Drawing check:** four buildings with four-pane windows standing on a ground line, a sun with four rays at the
> upper right, and two staggered rows of stars across the top.
> ```
> $ runghc -itest test/Spec.hs --match "Step 7.2"
> 9 examples, 0 failures
> $ make part7
> 30 examples, 0 failures
> ```

### Step 7.3: your own drawing
Write your own program as abstract syntax. Add a definition to `Examples.hs` (for example `myDrawing :: Program`),
`:reload`, and use `previewProgram "mine" myDrawing`. Keep it inside the safe area (within 190.5 mm left/right and
114.3 mm up/down of the start): the preview shows anything outside it in red.

### The final check
> **✅ Check your work (everything)**
> <!-- state: 6.2 -->
> ```
> $ make test
> 210 examples, 0 failures
> ```

---

## Common pitfalls
- **"TODO (Part N): …" in a test failure** means a function you haven't written yet is being used. Check the part
  number: tests for later parts are expected to fail until you get there.
- **Forgetting `:reload`** in GHCI after editing `PiqEvaluation.hs`.
- **Up is positive.** `offset Up` must give a positive `dy`. The zigzag preview in Step 2.4 shows it immediately.
- **Numbers are `Double`s.** `3` shows as `3.0`. Write negative literals with parentheses: `Num (-5)`,
  `moveRel 10 (-5)`.
- **A closed shape that doesn't return to its centre** makes everything after it land in the wrong place. The
  nested-squares preview in Step 2.5 shows it immediately.
- **Two `pen_down()`s in one shape:** the tests ask for one continuous stroke per shape.
- **Returning the wrong environment:** drawing statements return the `env` they were given. `Assign` returns the
  new one. A call returns the **caller's** `env`, not the procedure's.
- **Evaluating in the wrong environment:** a loop's bounds and a call's arguments are evaluated in the environment
  from **before** the loop or call.
- **Forgetting `restoreVar`** after a loop: the loop variable leaks out (Step 5.5 tests catch it).
- **Leaving out `forceValue` / `forceValues`:** one test in Step 4.1 and one in Step 6.4 will fail.
- **Error messages must match exactly**, including spaces: `undefined variable: x`, `division by zero`,
  `non-integral loop bound: 2.5`, `procedure f expects 1 arguments, got 2`.

---

## Final checklist
- [ ] `make test` shows `210 examples, 0 failures`.
- [ ] Every `TODO` in `PiqEvaluation.hs` is replaced by your code (`grep -n "TODO (Part" PiqEvaluation.hs` shows only
      the note in the file's header comment).
- [ ] `runghc Examples.hs` draws all 21 pictures, and they look like their descriptions.
- [ ] You didn't edit the provided files (`PiqAST.hs`, `Python.hs`, `Preview.hs`, `python/`, `test/`).

## Submitting
*(Instructions will be provided by your instructor.)*

---

## Appendix: the real plotter
Drawing on the real NextDraw plotter happens **in the lab, with your instructor's setup and permission**. Follow
the course procedure. The basics:

- **Preview first.** Never send a drawing to the plotter that you haven't previewed and checked.
- Make sure it fits: the plotter refuses any drawing that leaves the safe area (190.5 mm left/right and 114.3 mm
  up/down of the start), so check the preview for red first.
- Before plotting, the carriage must be at its **home position** (the top-left corner), because the plotter treats
  its position when it connects as home. The program moves to the centre of the paper by itself.
- The plotter computer has its own Python environment with the NextDraw software. There, a generated program runs
  with `--doplot`:
  ```
  python python/showcase.py --doplot
  ```
  Without `--doplot`, the same file only previews.
