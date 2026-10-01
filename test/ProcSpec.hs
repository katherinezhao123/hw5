module ProcSpec where

import PiqAST
import PiqEvaluation
import TestUtilities
import Test.Hspec


-----------------------------------------------------------------------------------------
-- Test configurations: procedures used by the tests below
-----------------------------------------------------------------------------------------

-- | define star() { dot; move right 5; dot }
star :: ProcDef
star = ProcDef "star" [] [Dot, Move Rt (Num 5), Dot]

-- | define ring(r) { circle r }
ring :: ProcDef
ring = ProcDef "ring" ["r"] [Circle (Var "r")]

-- | define box(size, gap) { square size; move right (size + gap) }
box :: ProcDef
box = ProcDef "box" ["size", "gap"] [Square (Var "size"), Move Rt (Add (Var "size") (Var "gap"))]

-- | define foo(x) { x = x + 100; square x }      (the spec's shadowing example)
foo :: ProcDef
foo = ProcDef "foo" ["x"] [Assign "x" (Add (Var "x") (Num 100)), Square (Var "x")]

-- | define row(n) { for i from 1 to n { ring(i * 2) } }     (a loop, and a call)
row :: ProcDef
row = ProcDef "row" ["n"] [For "i" (Num 1) (Var "n") [Call "ring" [Mul (Var "i") (Num 2)]]]

-- | define useScale(s) { square (s * scale) }    (reads the caller's `scale`)
useScale :: ProcDef
useScale = ProcDef "useScale" ["s"] [Square (Mul (Var "s") (Var "scale"))]

-- | define pair(a, b) { square a; circle b }
pair :: ProcDef
pair = ProcDef "pair" ["a", "b"] [Square (Var "a"), Circle (Var "b")]

-- | define setTemp(v) { temp = v; dot }         (assigns a new local variable)
setTemp :: ProcDef
setTemp = ProcDef "setTemp" ["v"] [Assign "temp" (Var "v"), Dot]

-- | define ignore(unused) { dot }               (never uses its parameter)
ignore :: ProcDef
ignore = ProcDef "ignore" ["unused"] [Dot]

-- | Every procedure above
allProcs :: [ProcDef]
allProcs = [star, ring, box, foo, row, useScale, pair, setTemp, ignore]

-- | The procedure environment for the tests
procs :: ProcEnv
procs = makeProcEnv allProcs

-----------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------

-- | Compiles statements with the test procedures, starting from the given environment
run :: Env -> [Stmt] -> (Env, [String])
run env stmts = compileStmts procs env stmts

-- | The code for statements, with the test procedures and no variables
codeOf :: [Stmt] -> [String]
codeOf stmts = snd (run emptyEnv stmts)

-- | The environment after statements, with the test procedures and no variables
envAfter :: [Stmt] -> Env
envAfter stmts = fst (run emptyEnv stmts)

-----------------------------------------------------------------------------------------
-- Specs
-----------------------------------------------------------------------------------------

bindSpec :: Spec
bindSpec = do
    it "bindParams with no parameters leaves the environment alone" $
        bindParams [] [] (makeEnv [("x", 1)]) `shouldBe` makeEnv [("x", 1)]
    it "bindParams binds each parameter to its value, in order" $
        bindParams ["a", "b"] [1, 2] emptyEnv `shouldBe` makeEnv [("a", 1), ("b", 2)]
    it "a parameter replaces a variable with the same name" $
        bindParams ["x"] [5] (makeEnv [("x", 1), ("y", 2)]) `shouldBe` makeEnv [("x", 5), ("y", 2)]


callSpec :: Spec
callSpec = do
    it "zero arguments: star() draws its body" $
        codeOf [Call "star" []] `shouldBe` dotCode ++ moveCode Rt 5 ++ dotCode

    it "one argument: ring(7) draws a circle of radius 7" $
        codeOf [Call "ring" [Num 7]] `shouldBe` circleCode 7

    it "several arguments are matched to parameters in order" $
        codeOf [Call "box" [Num 20, Num 5]] `shouldBe` squareCode 20 ++ moveCode Rt 25

    it "arguments can be expressions" $
        codeOf [Assign "n" (Num 3), Call "box" [Mul (Var "n") (Num 10), Sub (Var "n") (Num 1)]]
            `shouldBe` squareCode 30 ++ moveCode Rt 32

    it "calling a procedure twice generates its code twice" $
        codeOf [Call "ring" [Num 1], Call "ring" [Num 2]] `shouldBe` circleCode 1 ++ circleCode 2

    it "a call's code appears exactly where the call is" $
        codeOf [Dot, Call "ring" [Num 3], Square (Num 4)] `shouldBe` dotCode ++ circleCode 3 ++ squareCode 4

    it "all arguments are evaluated in the caller's environment before binding: pair(b, a)" $
        -- If `a` were bound to 2 first, the second argument would then see a = 2.
        codeOf [Assign "a" (Num 1), Assign "b" (Num 2), Call "pair" [Var "b", Var "a"]]
            `shouldBe` squareCode 2 ++ circleCode 1

    it "a procedure containing a loop" $
        codeOf [Call "row" [Num 3]] `shouldBe` circleCode 2 ++ circleCode 4 ++ circleCode 6

    it "a procedure calling another (nonrecursive) procedure" $
        codeOf [Call "row" [Num 2]] `shouldBe` snd (run emptyEnv [Call "ring" [Num 2], Call "ring" [Num 4]])

    it "a call inside a loop, with the loop variable as an argument" $
        codeOf [For "i" (Num 1) (Num 3) [Call "ring" [Var "i"]]]
            `shouldBe` circleCode 1 ++ circleCode 2 ++ circleCode 3

    it "a call ends with the pen up" $
        codeOf [Call "box" [Num 20, Num 5]] `shouldSatisfy` endsPenUp


scopeSpec :: Spec
scopeSpec = do
    it "the spec's example: foo(20) draws a square of 120, then square x draws 10" $
        codeOf [Assign "x" (Num 10), Call "foo" [Num 20], Square (Var "x")]
            `shouldBe` squareCode 120 ++ squareCode 10

    it "a parameter hides a caller variable with the same name" $
        codeOf [Assign "r" (Num 100), Call "ring" [Num 5]] `shouldBe` circleCode 5

    it "the caller's variable is unchanged after the call" $
        envAfter [Assign "x" (Num 10), Call "foo" [Num 20]] `shouldBe` makeEnv [("x", 10)]

    it "a call never changes the caller's environment" $
        fst (compileStmt procs (makeEnv [("x", 1), ("size", 2)]) (Call "box" [Num 20, Num 5]))
            `shouldBe` makeEnv [("x", 1), ("size", 2)]

    it "parameters do not exist after the call" $
        envAfter [Call "box" [Num 20, Num 5]] `shouldBe` emptyEnv

    it "local assignments work inside the procedure but do not escape it" $
        envAfter [Call "setTemp" [Num 7]] `shouldBe` emptyEnv

    it "using a procedure's local variable after the call is an error" $
        codeOf [Call "setTemp" [Num 7], Square (Var "temp")] `shouldCrashWith` "undefined variable: temp"

    it "the body can read caller variables that no parameter hides" $
        codeOf [Assign "scale" (Num 3), Call "useScale" [Num 4]] `shouldBe` squareCode 12

    it "the body sees the caller's current value, not an earlier one" $
        codeOf [ Assign "scale" (Num 1), Call "useScale" [Num 4]
               , Assign "scale" (Num 2), Call "useScale" [Num 4] ]
            `shouldBe` squareCode 4 ++ squareCode 8

    it "a loop variable inside a procedure is still restored" $
        envAfter [Assign "i" (Num 100), Call "row" [Num 2]] `shouldBe` makeEnv [("i", 100)]


errorSpec :: Spec
errorSpec = do
    it "calling an unknown procedure is an error" $
        codeOf [Call "nope" []] `shouldCrashWith` "unknown procedure: nope"

    it "too many arguments is an error" $
        codeOf [Call "ring" [Num 1, Num 2]] `shouldCrashWith` "procedure ring expects 1 arguments, got 2"

    it "too few arguments is an error" $
        codeOf [Call "box" [Num 1]] `shouldCrashWith` "procedure box expects 2 arguments, got 1"

    it "arguments to a zero-parameter procedure is an error" $
        codeOf [Call "star" [Num 1]] `shouldCrashWith` "procedure star expects 0 arguments, got 1"

    it "an undefined variable in an argument is an error" $
        codeOf [Call "ring" [Var "missing"]] `shouldCrashWith` "undefined variable: missing"

    it "a bad argument is an error even if the procedure never uses it" $
        codeOf [Call "ignore" [Div (Num 1) (Num 0)]] `shouldCrashWith` "division by zero"

    it "a procedure using a variable that the caller never defined is an error" $
        codeOf [Call "useScale" [Num 4]] `shouldCrashWith` "undefined variable: scale"


programSpec :: Spec
programSpec = do
    it "a program with no procedures compiles like its statements" $
        compileProgram (Program [] [Square (Num 5), Dot]) `shouldBe` squareCode 5 ++ dotCode

    it "defining a procedure generates no code by itself" $
        compileProgram (Program [ring, box] []) `shouldBe` []

    it "a program with procedures and calls" $
        compileProgram (Program [ring, row] [Call "row" [Num 1], Call "ring" [Num 9]])
            `shouldBe` circleCode 2 ++ circleCode 9

    it "a procedure can call one defined after it" $
        compileProgram (Program [row, ring] [Call "row" [Num 1]]) `shouldBe` circleCode 2

    it "the program starts with no variables" $
        compileProgram (Program [] [Square (Var "x")]) `shouldCrashWith` "undefined variable: x"

    it "two procedures with the same name is an error" $
        compileProgram (Program [ring, ProcDef "ring" [] [Dot]] [Dot]) `shouldCrashWith` "duplicate procedure: ring"

    it "lookupProc finds a definition" $
        lookupProc "box" procs `shouldBe` box

    it "makeProcEnv of no definitions is empty" $
        makeProcEnv [] `shouldBe` emptyProcEnv


spec :: Spec
spec = describe "Part 6: procedures" $ do
    describe "Step 6.1: binding parameters" bindSpec
    describe "Step 6.2: procedure calls" callSpec
    describe "Step 6.3: procedure scope" scopeSpec
    describe "Step 6.4: procedure errors" errorSpec
    describe "Step 6.5: whole programs" programSpec
