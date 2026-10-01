module TestUtilities where

-- Helpers used by the tests. PROVIDED: you do not need to change this file,
-- but reading it can help you understand what the tests check.

import PiqAST
import PiqEvaluation
import Test.Hspec
import Control.Exception (evaluate, ErrorCall(..))
import Data.List (isInfixOf, sort, stripPrefix)


-- | Builds an environment from a list of (name, value) pairs
makeEnv :: [(Name, Double)] -> Env
makeEnv pairs = foldr (\(name, value) env -> assignVar name value env) emptyEnv pairs


-- | Combines a list of specs into one spec
combineSpecs :: [Spec] -> Spec
combineSpecs = foldl (>>) (return ())


-- | Expects evaluating the value to crash with an error message that
--   contains the given text. (Computing the length of the value's `show`
--   makes Haskell evaluate every part of it.)
shouldCrashWith :: Show a => a -> String -> Expectation
shouldCrashWith value message =
    evaluate (length (show value)) `shouldThrow` (\(ErrorCall actual) -> message `isInfixOf` actual)


-- | The Python code for a single statement, compiled in the given environment
--   with no procedures
codeFor :: Env -> Stmt -> [String]
codeFor env stmt = snd (compileStmt emptyProcEnv env stmt)


-- | The (dx, dy) of a line of generated code: the arguments of a move_rel
--   line, or (0, 0) for any other line.
moveAmount :: String -> (Double, Double)
moveAmount line =
    case stripPrefix "move_rel(" line of
        Nothing   -> (0, 0)
        Just rest -> (read dxText, read dyText)
            where (dxText, afterDx) = break (== ',') rest
                  dyText            = takeWhile (/= ')') (drop 2 afterDx)


-- | How far the pen ends up from where it started after running the code
netDisplacement :: [String] -> (Double, Double)
netDisplacement code = (sum (map fst moves), sum (map snd moves))
    where moves = map moveAmount code


-- | True if the pen is up at the end of the code: the last pen_up()/pen_down()
--   line is a pen_up(). Code that never mentions the pen leaves it up.
endsPenUp :: [String] -> Bool
endsPenUp code =
    case filter isPenLine code of
        []       -> True
        penLines -> last penLines == "pen_up()"
    where isPenLine line = line == "pen_up()" || line == "pen_down()"


-- | True if the code never lowers the pen
drawsNothing :: [String] -> Bool
drawsNothing code = "pen_down()" `notElem` code


-- | How many times the code lowers the pen
penDowns :: [String] -> Int
penDowns code = length (filter (== "pen_down()") code)


-- | Expects two (dx, dy) pairs to be equal, up to floating-point rounding
shouldBeNear :: (Double, Double) -> (Double, Double) -> Expectation
shouldBeNear actual expected = actual `shouldSatisfy` closeEnough
    where closeEnough (x, y) = abs (x - fst expected) < 1e-9
                            && abs (y - snd expected) < 1e-9


--------------------------------------------------------------------------------
-- What gets drawn
--
-- These follow the pen through the code, starting at (0, 0) with the pen up,
-- and collect the segments drawn while the pen is down. The tests for
-- squares, rectangles and circles use them to check WHAT is drawn, without
-- caring which corner you start from or which way you go around.
--------------------------------------------------------------------------------

type Point   = (Double, Double)
type Segment = (Point, Point)

-- | The segments drawn by the code (while the pen is down)
drawnSegments :: [String] -> [Segment]
drawnSegments code = follow (0, 0) False code
    where
        follow _        _    []                      = []
        follow position _    ("pen_down()" : rest)   = follow position True rest
        follow position _    ("pen_up()"   : rest)   = follow position False rest
        follow (x, y)   down (line : rest)           =
            let (dx, dy) = moveAmount line
                next     = (x + dx, y + dy)
                drawn    = if down && (dx, dy) /= (0, 0) then [((x, y), next)] else []
            in  drawn ++ follow next down rest


-- | Rounds a point to 6 decimal places, so tiny floating-point differences
--   don't matter when comparing
roundPoint :: Point -> Point
roundPoint (x, y) = (roundTo x, roundTo y)
    where roundTo v = fromIntegral (round (v * 1000000) :: Integer) / 1000000


-- | A segment with its two ends in a standard order, so that a segment drawn
--   in either direction compares equal
normalSegment :: Segment -> Segment
normalSegment (p, q) = if a <= b then (a, b) else (b, a)
    where a = roundPoint p
          b = roundPoint q


-- | True if two lists contain the same segments, in any order and direction
sameSegments :: [Segment] -> [Segment] -> Bool
sameSegments xs ys = sort (map normalSegment xs) == sort (map normalSegment ys)


-- | The four sides of a w x h rectangle centered on (0, 0)
rectangleSides :: Double -> Double -> [Segment]
rectangleSides w h =
    [ ((-hw, -hh), ( hw, -hh))
    , (( hw, -hh), ( hw,  hh))
    , (( hw,  hh), (-hw,  hh))
    , ((-hw,  hh), (-hw, -hh))
    ]
    where hw = w / 2
          hh = h / 2


-- | Distance of a point from (0, 0)
distanceFromOrigin :: Point -> Double
distanceFromOrigin (x, y) = sqrt (x * x + y * y)
