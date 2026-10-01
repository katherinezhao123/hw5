module SequenceSpec where

import PiqAST
import PiqEvaluation
import TestUtilities
import Test.Hspec


-----------------------------------------------------------------------------------------
-- Test configurations
-----------------------------------------------------------------------------------------

-- | The example from the assignment:
--
--       x = 10
--       square x
--       x = x * 2
--       square x
specExample :: [Stmt]
specExample =
    [ Assign "x" (Num 10)
    , Square (Var "x")
    , Assign "x" (Mul (Var "x") (Num 2))
    , Square (Var "x")
    ]

-- | The code and final environment for a sequence, starting from no variables
runStmts :: [Stmt] -> (Env, [String])
runStmts stmts = compileStmts emptyProcEnv emptyEnv stmts

-- | Just the final environment
envAfter :: [Stmt] -> Env
envAfter stmts = fst (runStmts stmts)

-- | Just the code
codeOf :: [Stmt] -> [String]
codeOf stmts = snd (runStmts stmts)

-----------------------------------------------------------------------------------------
-- Specs
-----------------------------------------------------------------------------------------

assignSpec :: Spec
assignSpec = do
    it "an assignment generates no Python code" $
        codeFor emptyEnv (Assign "x" (Num 10)) `shouldBe` []

    it "an assignment with a complicated expression generates no Python code" $
        codeFor (makeEnv [("y", 3)]) (Assign "x" (Mul (Add (Var "y") (Num 1)) (Num 2))) `shouldBe` []

    it "an assignment adds a new variable" $
        fst (compileStmt emptyProcEnv emptyEnv (Assign "x" (Num 10))) `shouldBe` makeEnv [("x", 10)]

    it "an assignment replaces an existing variable's value" $
        fst (compileStmt emptyProcEnv (makeEnv [("x", 1)]) (Assign "x" (Num 10))) `shouldBe` makeEnv [("x", 10)]

    it "an assignment leaves other variables alone" $
        fst (compileStmt emptyProcEnv (makeEnv [("x", 1), ("y", 2)]) (Assign "x" (Num 10)))
            `shouldBe` makeEnv [("x", 10), ("y", 2)]

    it "an assignment can use the variable's own old value (x = x * 2)" $
        fst (compileStmt emptyProcEnv (makeEnv [("x", 10)]) (Assign "x" (Mul (Var "x") (Num 2))))
            `shouldBe` makeEnv [("x", 20)]

    it "an assignment that uses an undefined variable is an error" $
        codeFor emptyEnv (Assign "x" (Var "nope")) `shouldCrashWith` "undefined variable: nope"

    -- This one only looks at the (empty) code, never at x. It fails unless the
    -- value is computed right away: see forceValue in PiqEvaluation.hs.
    it "a bad assignment is an error even if the variable is never used" $
        codeFor emptyEnv (Assign "x" (Div (Num 1) (Num 0))) `shouldCrashWith` "division by zero"


sequenceSpec :: Spec
sequenceSpec = do
    it "no statements: no code, and the environment is unchanged" $
        compileStmts emptyProcEnv (makeEnv [("x", 1)]) [] `shouldBe` (makeEnv [("x", 1)], [])

    it "the assignment's example draws a square of 10, then a square of 20" $
        codeOf specExample `shouldBe` squareCode 10 ++ squareCode 20

    it "the assignment's example ends with x = 20" $
        envAfter specExample `shouldBe` makeEnv [("x", 20)]

    it "a later assignment does not change code already generated" $
        codeOf [Assign "s" (Num 5), Square (Var "s"), Assign "s" (Num 50)] `shouldBe` squareCode 5

    it "a variable can be defined in terms of an earlier one" $
        codeOf [Assign "x" (Num 3), Assign "y" (Mul (Var "x") (Num 2)), Circle (Var "y")]
            `shouldBe` circleCode 6

    it "environment updates build up across many statements" $
        envAfter [ Assign "a" (Num 1)
                 , Assign "b" (Add (Var "a") (Num 1))
                 , Dot
                 , Assign "a" (Mul (Var "b") (Num 10))
                 , Move Rt (Var "a")
                 , Assign "c" (Sub (Var "a") (Var "b"))
                 ]
            `shouldBe` makeEnv [("a", 20), ("b", 2), ("c", 18)]

    it "starts from the environment it is given" $
        codeOf' (makeEnv [("w", 7)]) [Line Up (Var "w")] `shouldBe` lineCode Up 7

    it "without assignments, the code is each statement's code in order" $
        codeOf [Square (Num 20), Move Rt (Num 30), Dot, Circle (Num 5)]
            `shouldBe` squareCode 20 ++ moveCode Rt 30 ++ dotCode ++ circleCode 5

    it "a variable used before it is assigned is an error, even if assigned later" $
        codeOf [Square (Var "x"), Assign "x" (Num 10)] `shouldCrashWith` "undefined variable: x"

    it "a whole sequence ends with the pen up" $
        codeOf specExample `shouldSatisfy` endsPenUp

    it "a sequence moves the pen by the sum of its moves and lines" $
        netDisplacement (codeOf [ Assign "d" (Num 10), Move Rt (Var "d"), Square (Var "d")
                                , Assign "d" (Num 4), Line Up (Var "d"), Circle (Num 3) ])
            `shouldBeNear` (10, 4)
    where
        codeOf' env stmts = snd (compileStmts emptyProcEnv env stmts)


spec :: Spec
spec = describe "Part 4: assignment and statement sequences" $ do
    describe "Step 4.1: assignment" assignSpec
    describe "Step 4.2: statement sequences" sequenceSpec
