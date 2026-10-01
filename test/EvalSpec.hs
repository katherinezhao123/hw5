module EvalSpec where

import PiqAST
import PiqEvaluation
import TestUtilities
import Test.Hspec


-- | The environment used by most of these tests: x = 10, y = 4, half = 0.5
testEnv :: Env
testEnv = makeEnv [("x", 10), ("y", 4), ("half", 0.5)]

-- | Checks that an expression evaluates to the expected value in testEnv
evalsTo :: Expr -> Double -> Spec
evalsTo expr expected =
    it (show expr ++ " evaluates to " ++ show expected) $
        eval testEnv expr `shouldBe` expected


spec :: Spec
spec = describe "Part 1: expressions and environments" $ do

    describe "Step 1.1: numbers" $ do
        evalsTo (Num 3)    3
        evalsTo (Num (-2.5)) (-2.5)

    describe "Step 1.2: variables" $ do
        it "lookupVar finds a variable's value" $
            lookupVar "x" testEnv `shouldBe` 10
        it "lookupVar finds the value after assignVar changes it" $
            lookupVar "x" (assignVar "x" 99 testEnv) `shouldBe` 99
        it "lookupVar on a missing variable is an error" $
            lookupVar "nope" testEnv `shouldCrashWith` "undefined variable: nope"
        evalsTo (Var "x")    10
        evalsTo (Var "half") 0.5

    describe "Step 1.3: addition and subtraction" $ do
        evalsTo (Add (Num 1) (Num 2))                 3
        evalsTo (Sub (Num 1) (Num 2))                 (-1)
        evalsTo (Sub (Sub (Num 10) (Num 3)) (Num 2))  5     -- (10 - 3) - 2
        evalsTo (Sub (Num 10) (Sub (Num 3) (Num 2)))  9     -- 10 - (3 - 2)
        evalsTo (Add (Var "x") (Var "y"))             14
        evalsTo (Sub (Var "x") (Var "x"))             0

    describe "Step 1.4: multiplication and division" $ do
        evalsTo (Mul (Num 3) (Num 4))                           12
        evalsTo (Div (Num 7) (Num 2))                           3.5
        evalsTo (Div (Num 0) (Num 5))                           0
        evalsTo (Add (Num 1) (Mul (Num 2) (Num 3)))             7
        evalsTo (Mul (Var "x") (Num 2))                         20
        evalsTo (Div (Var "x") (Var "y"))                       2.5
        evalsTo (Add (Var "x") (Mul (Var "y") (Var "half")))    12

    describe "Step 1.5: environments are values" $ do
        it "assignVar adds a new variable" $
            lookupVar "z" (assignVar "z" 7 testEnv) `shouldBe` 7
        it "assignVar leaves other variables alone" $
            lookupVar "y" (assignVar "x" 99 testEnv) `shouldBe` 4
        it "assignVar does not change the old environment" $
            let _newEnv = assignVar "x" 99 testEnv
            in  lookupVar "x" testEnv `shouldBe` 10
        it "evaluation sees the updated value" $
            eval (assignVar "x" 1 testEnv) (Add (Var "x") (Num 1)) `shouldBe` 2

    describe "Step 1.6: errors" $ do
        it "an undefined variable is an error" $
            eval testEnv (Var "nope") `shouldCrashWith` "undefined variable: nope"
        it "an undefined variable inside a larger expression is an error" $
            eval testEnv (Add (Num 1) (Mul (Var "x") (Var "q"))) `shouldCrashWith` "undefined variable: q"
        it "every variable is undefined in the empty environment" $
            eval emptyEnv (Var "x") `shouldCrashWith` "undefined variable: x"
        it "dividing by the number zero is an error" $
            eval testEnv (Div (Num 1) (Num 0)) `shouldCrashWith` "division by zero"
        it "dividing by an expression that evaluates to zero is an error" $
            eval testEnv (Div (Var "x") (Sub (Var "y") (Num 4))) `shouldCrashWith` "division by zero"
