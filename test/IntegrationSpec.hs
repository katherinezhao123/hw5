module IntegrationSpec where

import PiqAST
import PiqEvaluation
import Examples
import TestUtilities
import Test.Hspec
import Data.List (isInfixOf, isPrefixOf, isSuffixOf)


-- | True if a line is a call to one of the three runtime functions, and a
--   move_rel's two arguments really are numbers
isRuntimeCall :: String -> Bool
isRuntimeCall line =
    line == "pen_up()" || line == "pen_down()" || isMove
    where isMove = "move_rel(" `isPrefixOf` line && ")" `isSuffixOf` line
                   && isNumber dxText && isNumber dyText
          (dxText, afterDx) = break (== ',') (drop (length "move_rel(") line)
          dyText = takeWhile (/= ')') (drop 2 afterDx)
          isNumber text = case (reads text :: [(Double, String)]) of
                              [(_, "")] -> True
                              _         -> False

-- | Every AST constructor the showcase uses somewhere
week1Features :: [String]
week1Features =
    [ "Num ", "Var ", "Add ", "Sub ", "Mul ", "Div "
    , "Assign ", "Dot", "Square ", "Rectangle ", "Circle "
    , "Move ", "Line ", "For ", "Call ", "ProcDef "
    ]


spec :: Spec
spec = describe "Part 7: whole programs" $ do

    describe "Step 7.1: every example program compiles" $
        combineSpecs
            [ it (name ++ ": only pen_up/pen_down/move_rel, draws something, ends with the pen up") $ do
                  let code = compileProgram program
                  code `shouldSatisfy` all isRuntimeCall
                  penDowns code `shouldSatisfy` (> 0)
                  code `shouldSatisfy` endsPenUp
            | (name, program) <- examples ]

    describe "Step 7.2: the showcase" $ do
        let code = compileProgram part7Showcase
        it "uses every language feature" $
            filter (\feature -> not (feature `isInfixOf` show part7Showcase)) week1Features `shouldBe` []
        -- 37 windows (a square and two lines each), 4 buildings, the ground,
        -- a sun (a circle and 4 rays), and 20 stars
        it "lowers the pen 141 times" $
            penDowns code `shouldBe` 141
        -- buildings and the sun return to where they started; the second row
        -- of stars leaves the pen at (-145, 81)
        it "ends at (-145, 81)" $
            netDisplacement code `shouldBeNear` (-145, 81)
        it "a building call returns to where it started" $
            let Program defs _ = part7Showcase
            in  netDisplacement (snd (compileStmt (makeProcEnv defs) emptyEnv (Call "building" [Num 4, Num 2, Num 14])))
                    `shouldBeNear` (0, 0)
        it "leaves only the star settings defined at the end" $
            let Program defs stmts = part7Showcase
            in  fst (compileStmts (makeProcEnv defs) emptyEnv stmts)
                    `shouldBe` makeEnv [("starGap", 25), ("starCount", 10)]

    describe "Step 7.2: other complete programs" $ do
        it "the spiral draws 80 lines" $
            penDowns (compileProgram part7Spiral) `shouldBe` 80
        it "the spiral ends 80 mm left and 80 mm below the start" $
            netDisplacement (compileProgram part7Spiral) `shouldBeNear` (-80, -80)
        it "the tiles lower the pen 72 times" $
            penDowns (compileProgram part7Tiles) `shouldBe` 72
        it "the tiles end 100 mm left and 100 mm below the start" $
            netDisplacement (compileProgram part7Tiles) `shouldBeNear` (-100, -100)
