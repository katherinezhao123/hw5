module LoopSpec where

import PiqAST
import PiqEvaluation
import TestUtilities
import Test.Hspec


-----------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------

-- | Compiles statements starting from the given environment
run :: Env -> [Stmt] -> (Env, [String])
run env stmts = compileStmts emptyProcEnv env stmts

-- | The code for statements, starting with no variables
codeOf :: [Stmt] -> [String]
codeOf stmts = snd (run emptyEnv stmts)

-- | The environment after statements, starting with no variables
envAfter :: [Stmt] -> Env
envAfter stmts = fst (run emptyEnv stmts)

-- | Adds one to a variable: name = name + 1
increment :: Name -> Stmt
increment name = Assign name (Add (Var name) (Num 1))

-----------------------------------------------------------------------------------------
-- Specs
-----------------------------------------------------------------------------------------

helperSpec :: Spec
helperSpec = do
    it "saveVar finds an existing variable's value" $
        saveVar "x" (makeEnv [("x", 10)]) `shouldBe` Just 10
    it "saveVar finds nothing for a missing variable" $
        saveVar "z" (makeEnv [("x", 10)]) `shouldBe` Nothing
    it "restoreVar with a saved value puts that value back" $
        lookupVar "x" (restoreVar "x" (Just 10) (makeEnv [("x", 99)])) `shouldBe` 10
    it "restoreVar with nothing saved removes the variable" $
        restoreVar "z" Nothing (makeEnv [("x", 1), ("z", 5)]) `shouldBe` makeEnv [("x", 1)]
    it "toLoopBound accepts a whole number" $
        toLoopBound 5 `shouldBe` 5
    it "toLoopBound accepts a negative whole number" $
        toLoopBound (-2) `shouldBe` (-2)
    it "toLoopBound rejects 2.5" $
        toLoopBound 2.5 `shouldCrashWith` "non-integral loop bound: 2.5"


basicSpec :: Spec
basicSpec = do
    it "constant bounds: runs the body once for each value, in order" $
        codeOf [For "i" (Num 1) (Num 3) [Square (Var "i")]]
            `shouldBe` squareCode 1 ++ squareCode 2 ++ squareCode 3

    it "expression bounds: from (n - 1) to (n * 2) with n = 2 runs for 1, 2, 3, 4" $
        codeOf [ Assign "n" (Num 2)
               , For "i" (Sub (Var "n") (Num 1)) (Mul (Var "n") (Num 2)) [Dot] ]
            `shouldBe` concat (replicate 4 dotCode)

    it "the loop variable can be used in a shape's size" $
        codeOf [For "i" (Num 1) (Num 2) [Circle (Mul (Var "i") (Num 10))]]
            `shouldBe` circleCode 10 ++ circleCode 20

    it "the loop variable can be used in a movement" $
        codeOf [For "i" (Num 1) (Num 4) [Move Rt (Var "i")]]
            `shouldBe` concatMap (moveCode Rt) [1, 2, 3, 4]

    it "a loop moves the pen by the total of its body's moves" $
        netDisplacement (codeOf [For "i" (Num 1) (Num 4) [Line Up (Var "i"), Square (Num 5)]])
            `shouldBeNear` (0, 10)

    it "start equal to end: runs exactly once" $
        codeOf [For "i" (Num 7) (Num 7) [Square (Var "i")]] `shouldBe` squareCode 7

    it "negative bounds: from -2 to 2 runs five times" $
        penDowns (codeOf [For "i" (Num (-2)) (Num 2) [Dot]]) `shouldBe` 5

    it "whole-number bounds computed by division are fine: to (10 / 2)" $
        penDowns (codeOf [For "i" (Num 1) (Div (Num 10) (Num 2)) [Dot]]) `shouldBe` 5

    it "the whole loop ends with the pen up" $
        codeOf [For "i" (Num 1) (Num 3) [Line Rt (Var "i"), Dot]] `shouldSatisfy` endsPenUp


zeroIterationSpec :: Spec
zeroIterationSpec = do
    it "start after end: the body never runs and there is no code" $
        codeOf [For "i" (Num 5) (Num 1) [Square (Var "i")]] `shouldBe` []

    it "start after end: the environment is unchanged" $
        fst (run (makeEnv [("x", 1)]) [For "i" (Num 5) (Num 1) [Assign "x" (Num 99)]])
            `shouldBe` makeEnv [("x", 1)]

    it "start after end: errors in the body never happen, because it never runs" $
        codeOf [For "i" (Num 1) (Num 0) [Square (Var "undefinedVariable")]] `shouldBe` []


boundsSpec :: Spec
boundsSpec = do
    it "a non-integral start is an error" $
        codeOf [For "i" (Num 1.5) (Num 3) [Dot]] `shouldCrashWith` "non-integral loop bound: 1.5"

    it "a non-integral end is an error" $
        codeOf [For "i" (Num 1) (Num 2.5) [Dot]] `shouldCrashWith` "non-integral loop bound: 2.5"

    it "a non-integral end computed by an expression is an error" $
        codeOf [For "i" (Num 1) (Div (Num 5) (Num 2)) [Dot]] `shouldCrashWith` "non-integral loop bound: 2.5"

    it "a non-integral bound is an error even when the loop would run zero times" $
        codeOf [For "i" (Num 3) (Num 0.5) [Dot]] `shouldCrashWith` "non-integral loop bound: 0.5"

    it "an undefined variable in a bound is an error" $
        codeOf [For "i" (Num 1) (Var "n") [Dot]] `shouldCrashWith` "undefined variable: n"

    it "the bounds are evaluated once: changing n in the body doesn't change the count" $
        envAfter [ Assign "n" (Num 3), Assign "count" (Num 0)
                 , For "i" (Num 1) (Var "n") [increment "n", increment "count"] ]
            `shouldBe` makeEnv [("n", 6), ("count", 3)]

    it "assigning to the loop variable in the body doesn't change the iterations" $
        penDowns (codeOf [For "i" (Num 1) (Num 3) [Assign "i" (Mul (Var "i") (Num 10)), Dot]])
            `shouldBe` 3


scopeSpec :: Spec
scopeSpec = do
    it "assignments to other variables persist across iterations and after the loop" $
        envAfter [Assign "x" (Num 0), For "i" (Num 1) (Num 4) [increment "x"]]
            `shouldBe` makeEnv [("x", 4)]

    it "a running total over the loop variable: 1 + 2 + 3 + 4 + 5" $
        envAfter [ Assign "total" (Num 0)
                 , For "i" (Num 1) (Num 5) [Assign "total" (Add (Var "total") (Var "i"))] ]
            `shouldBe` makeEnv [("total", 15)]

    it "a new loop variable disappears after the loop" $
        envAfter [For "i" (Num 1) (Num 3) [Dot]] `shouldBe` emptyEnv

    it "using a new loop variable after the loop is an error" $
        codeOf [For "i" (Num 1) (Num 3) [Dot], Square (Var "i")] `shouldCrashWith` "undefined variable: i"

    it "an existing variable used as the loop variable gets its old value back" $
        envAfter [Assign "i" (Num 100), For "i" (Num 1) (Num 3) [Dot]]
            `shouldBe` makeEnv [("i", 100)]

    it "inside the loop, the loop variable hides the outer one" $
        codeOf [Assign "i" (Num 100), For "i" (Num 1) (Num 2) [Square (Var "i")], Square (Var "i")]
            `shouldBe` squareCode 1 ++ squareCode 2 ++ squareCode 100

    it "a variable first assigned inside the body still exists after the loop" $
        envAfter [For "i" (Num 1) (Num 3) [Assign "last" (Var "i")]]
            `shouldBe` makeEnv [("last", 3)]


nestingSpec :: Spec
nestingSpec = do
    it "two nested loops run the inner body (outer count) * (inner count) times" $
        penDowns (codeOf [For "i" (Num 1) (Num 2) [For "j" (Num 1) (Num 3) [Dot]]])
            `shouldBe` 6

    it "the inner loop can use the outer loop's variable" $
        codeOf [For "i" (Num 1) (Num 2) [For "j" (Num 1) (Num 2) [Square (Mul (Var "i") (Var "j"))]]]
            `shouldBe` concatMap squareCode [1, 2, 2, 4]

    it "the inner loop's bounds can depend on the outer loop variable (a triangle)" $
        penDowns (codeOf [For "i" (Num 1) (Num 4) [For "j" (Num 1) (Var "i") [Dot]]])
            `shouldBe` 10

    it "three nested loops run the innermost body 2 * 3 * 4 = 24 times" $
        envAfter [ Assign "count" (Num 0)
                 , For "i" (Num 1) (Num 2)
                     [ For "j" (Num 1) (Num 3)
                         [ For "k" (Num 1) (Num 4) [increment "count"] ] ] ]
            `shouldBe` makeEnv [("count", 24)]

    it "three nested loops see every combination of i, j, k exactly once" $
        -- Adding i*100 + j*10 + k for every combination:
        -- 12 * (1+2)*100 + 8 * (1+2+3)*10 + 6 * (1+2+3+4) = 3600 + 480 + 60 = 4140
        envAfter [ Assign "sum" (Num 0)
                 , For "i" (Num 1) (Num 2)
                     [ For "j" (Num 1) (Num 3)
                         [ For "k" (Num 1) (Num 4)
                             [ Assign "sum" (Add (Var "sum")
                                  (Add (Mul (Var "i") (Num 100))
                                       (Add (Mul (Var "j") (Num 10)) (Var "k")))) ] ] ] ]
            `shouldBe` makeEnv [("sum", 4140)]

    it "three nested loops draw in the right order" $
        codeOf [ For "i" (Num 1) (Num 2)
                   [ For "j" (Num 1) (Num 2)
                       [ For "k" (Num 1) (Num 2)
                           [ Square (Add (Mul (Var "i") (Num 100)) (Add (Mul (Var "j") (Num 10)) (Var "k"))) ] ] ] ]
            `shouldBe` concatMap squareCode [111, 112, 121, 122, 211, 212, 221, 222]

    it "after three nested loops, all three loop variables are gone" $
        envAfter [For "i" (Num 1) (Num 2) [For "j" (Num 1) (Num 2) [For "k" (Num 1) (Num 2) [Dot]]]]
            `shouldBe` emptyEnv

    it "nested loops that reuse the same variable name: the inner one shadows the outer" $
        codeOf [For "i" (Num 1) (Num 2) [For "i" (Num 5) (Num 6) [Square (Var "i")], Circle (Var "i")]]
            `shouldBe` squareCode 5 ++ squareCode 6 ++ circleCode 1
                    ++ squareCode 5 ++ squareCode 6 ++ circleCode 2


spec :: Spec
spec = describe "Part 5: loops" $ do
    describe "Step 5.1: loop helpers" helperSpec
    describe "Step 5.2: basic loops" basicSpec
    describe "Step 5.3: loops that run zero times" zeroIterationSpec
    describe "Step 5.4: loop bounds" boundsSpec
    describe "Step 5.5: loop variable scope" scopeSpec
    describe "Step 5.6: nested loops" nestingSpec
