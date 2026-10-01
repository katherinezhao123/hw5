module BasicCompileSpec where

import PiqAST
import PiqEvaluation
import TestUtilities
import Test.Hspec


-- | The environment used by these tests: x = 10, w = 30, h = 8
testEnv :: Env
testEnv = makeEnv [("x", 10), ("w", 30), ("h", 8)]

-- | Checks the exact code generated for a statement
compilesTo :: Stmt -> [String] -> Spec
compilesTo stmt expected =
    it (show stmt ++ " compiles to " ++ show expected) $
        codeFor testEnv stmt `shouldBe` expected

-- | The checks every closed shape (square, rectangle) must pass: it draws
--   exactly the expected sides, in one stroke, returns to the center, and
--   ends with the pen up.
closedShapeChecks :: String -> Stmt -> [Segment] -> Spec
closedShapeChecks label stmt sides =
    describe label $ do
        it "draws exactly the four sides, centered on the start" $
            drawnSegments (codeFor testEnv stmt) `shouldSatisfy` sameSegments sides
        it "draws them in one stroke (lowers the pen once)" $
            penDowns (codeFor testEnv stmt) `shouldBe` 1
        it "returns to the center" $
            netDisplacement (codeFor testEnv stmt) `shouldBeNear` (0, 0)
        it "ends with the pen up" $
            codeFor testEnv stmt `shouldSatisfy` endsPenUp


spec :: Spec
spec = describe "Part 2: basic drawing" $ do

    describe "Step 2.1: the provided Dot" $
        Dot `compilesTo` ["pen_down()", "pen_up()"]

    describe "Step 2.2: offsets" $ do
        it "offset Rt 5 is (5, 0)" $ offset Rt 5 `shouldBe` (5, 0)
        it "offset Lt 5 is (-5, 0)" $ offset Lt 5 `shouldBe` (-5, 0)
        it "offset Up 5 is (0, 5)" $ offset Up 5 `shouldBe` (0, 5)
        it "offset Dn 5 is (0, -5)" $ offset Dn 5 `shouldBe` (0, -5)

    describe "Step 2.3: move" $ do
        Move Rt (Num 20)              `compilesTo` ["pen_up()", "move_rel(20.0, 0.0)"]
        Move Lt (Num 20)              `compilesTo` ["pen_up()", "move_rel(-20.0, 0.0)"]
        Move Up (Num 20)              `compilesTo` ["pen_up()", "move_rel(0.0, 20.0)"]
        Move Dn (Num 20)              `compilesTo` ["pen_up()", "move_rel(0.0, -20.0)"]
        Move Rt (Mul (Var "x") (Num 2)) `compilesTo` ["pen_up()", "move_rel(20.0, 0.0)"]
        it "a move never lowers the pen" $
            codeFor testEnv (Move Dn (Num 50)) `shouldSatisfy` drawsNothing
        it "an undefined variable in a distance is an error" $
            codeFor testEnv (Move Up (Var "d")) `shouldCrashWith` "undefined variable: d"

    describe "Step 2.4: line" $ do
        Line Up (Num 10)   `compilesTo` ["pen_down()", "move_rel(0.0, 10.0)", "pen_up()"]
        Line Dn (Num 10)   `compilesTo` ["pen_down()", "move_rel(0.0, -10.0)", "pen_up()"]
        Line Lt (Var "x")  `compilesTo` ["pen_down()", "move_rel(-10.0, 0.0)", "pen_up()"]
        Line Rt (Num 2.5)  `compilesTo` ["pen_down()", "move_rel(2.5, 0.0)", "pen_up()"]
        it "a line leaves the pen at its far end" $
            netDisplacement (codeFor testEnv (Line Lt (Var "w"))) `shouldBeNear` (-30, 0)

    describe "Step 2.5: square" $ do
        closedShapeChecks "square 20"   (Square (Num 20))  (rectangleSides 20 20)
        closedShapeChecks "square x"    (Square (Var "x")) (rectangleSides 10 10)
        closedShapeChecks "square 0.1"  (Square (Num 0.1)) (rectangleSides 0.1 0.1)
        it "an undefined variable in the size is an error" $
            codeFor testEnv (Square (Var "size")) `shouldCrashWith` "undefined variable: size"

    describe "Step 2.6: rectangle" $ do
        closedShapeChecks "rectangle 30 10"  (Rectangle (Num 30) (Num 10))   (rectangleSides 30 10)
        closedShapeChecks "rectangle w h"    (Rectangle (Var "w") (Var "h")) (rectangleSides 30 8)
        it "width and height are not swapped: rectangle 40 10 is wide" $
            drawnSegments (codeFor testEnv (Rectangle (Num 40) (Num 10)))
                `shouldSatisfy` sameSegments (rectangleSides 40 10)

    describe "Step 2.7: drawing leaves the environment alone" $
        it "no drawing statement changes the environment" $
            map (fst . compileStmt emptyProcEnv testEnv)
                [Dot, Square (Num 20), Rectangle (Num 30) (Num 10), Move Rt (Num 5), Line Up (Num 5)]
                `shouldBe` replicate 5 testEnv
