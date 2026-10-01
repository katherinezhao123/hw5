module CircleSpec where

import PiqAST
import PiqEvaluation
import TestUtilities
import Test.Hspec


-- | The code for a circle with the given radius
circleOf :: Double -> [String]
circleOf radius = codeFor emptyEnv (Circle (Num radius))

-- | Every end point of every drawn segment
drawnPoints :: [String] -> [Point]
drawnPoints code = concatMap (\(p, q) -> [p, q]) (drawnSegments code)

-- | Length of a segment
segmentLength :: Segment -> Double
segmentLength ((x1, y1), (x2, y2)) = sqrt ((x2 - x1) ^ (2 :: Int) + (y2 - y1) ^ (2 :: Int))

-- | True if each drawn segment starts where the previous one ended, and the
--   last one ends where the first one started
closedPath :: [Segment] -> Bool
closedPath []       = False
closedPath segments =
    and (zipWith connects segments (drop 1 segments ++ take 1 segments))
    where connects (_, end) (start, _) = roundPoint end == roundPoint start


spec :: Spec
spec = describe "Part 3: circles" $ do

    describe "Step 3.1: the circle's shape" $ do
        it "uses circleSegments (36) straight segments" $
            length (drawnSegments (circleOf 10)) `shouldBe` circleSegments
        it "every point it draws through is one radius from the center (radius 10)" $
            map distanceFromOrigin (drawnPoints (circleOf 10))
                `shouldSatisfy` all (\d -> abs (d - 10) < 1e-9)
        it "every point it draws through is one radius from the center (radius 73.5)" $
            map distanceFromOrigin (drawnPoints (circleOf 73.5))
                `shouldSatisfy` all (\d -> abs (d - 73.5) < 1e-9)
        it "all segments are the same length (a regular 36-sided polygon)" $
            map segmentLength (drawnSegments (circleOf 10))
                `shouldSatisfy` all (\len -> abs (len - 2 * 10 * sin (pi / 36)) < 1e-9)
        it "the drawn path is one closed loop" $
            drawnSegments (circleOf 10) `shouldSatisfy` closedPath
        it "draws it in one stroke (lowers the pen once)" $
            penDowns (circleOf 10) `shouldBe` 1

    describe "Step 3.2: the circle statement" $ do
        it "returns to the center" $
            netDisplacement (circleOf 10) `shouldBeNear` (0, 0)
        it "returns to the center for a fractional radius" $
            netDisplacement (circleOf 0.3) `shouldBeNear` (0, 0)
        it "ends with the pen up" $
            circleOf 10 `shouldSatisfy` endsPenUp
        it "evaluates its radius as an expression" $
            codeFor (makeEnv [("r", 8)]) (Circle (Div (Var "r") (Num 2))) `shouldBe` circleOf 4
        it "does not change the environment" $
            fst (compileStmt emptyProcEnv (makeEnv [("r", 8)]) (Circle (Var "r")))
                `shouldBe` makeEnv [("r", 8)]
        it "an undefined variable in the radius is an error" $
            codeFor emptyEnv (Circle (Var "r")) `shouldCrashWith` "undefined variable: r"
