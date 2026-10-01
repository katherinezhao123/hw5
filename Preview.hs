{-|
Module       : Preview
Description  : Turns piq statements and programs (written as abstract syntax)
               into Python files and preview pictures, from GHCI.

**PROVIDED: DO NOT EDIT.** You do not need to read how this works.

Run these from GHCI, started in the repository's top folder (`ghci Preview.hs`).

Parts 0-3 (before compileStmts exists), for lists of drawing statements:

    > showStmts [Dot, Square (Num 20)]            -- print the Python lines
    > previewStmts "shapes" [Dot, Square (Num 20)] -- python/shapes.py + .png

    Each statement is compiled on its own, starting with no variables, so
    these work for drawing statements whose sizes are numbers.

Part 4 on, for whole programs:

    > showProgram (Program [] [Assign "x" (Num 20), Square (Var "x")])
    > previewProgram "square20" (Program [] [Square (Num 20)])
    > emitProgram "square20" (Program [] [Square (Num 20)])  -- only the .py

The picture is drawn by the mock plotter (no hardware). It needs Python 3 with
matplotlib. If your Python is not called `python3`, set PIQ_PYTHON, e.g.
    PIQ_PYTHON=/path/to/python ghci Preview.hs
-}

module Preview where

import PiqAST
import PiqEvaluation (compileProgram, compileStmt, emptyEnv, emptyProcEnv)
import Python        (emitPython)

import System.Directory   (makeAbsolute)
import System.Environment (lookupEnv)
import System.Exit        (ExitCode(..))
import System.IO          (hFlush, stdout)
import System.Process     (rawSystem)


--------------------------------------------------------------------------------
-- Parts 0-3: lists of drawing statements
--------------------------------------------------------------------------------

-- | Compiles each statement on its own (starting with no variables) and
--   joins the code. This is enough for drawing statements, which never change
--   the environment; compileStmts (Part 4) does it properly.
compileEach :: [Stmt] -> [String]
compileEach stmts = concatMap (\stmt -> snd (compileStmt emptyProcEnv emptyEnv stmt)) stmts


-- | Prints the Python lines for a list of drawing statements, one per line.
showStmts :: [Stmt] -> IO ()
showStmts stmts = mapM_ putStrLn (compileEach stmts)


-- | Writes python/<name>.py for a list of drawing statements, and draws it
--   into python/<name>.png
previewStmts :: String -> [Stmt] -> IO ()
previewStmts name stmts = writeAndDraw name (compileEach stmts)


--------------------------------------------------------------------------------
-- Part 4 on: whole programs
--------------------------------------------------------------------------------

-- | Prints the Python lines that a program compiles to, one per line.
showProgram :: Program -> IO ()
showProgram program = mapM_ putStrLn (compileProgram program)


-- | Compiles a program and writes the runnable Python file python/<name>.py
emitProgram :: String -> Program -> IO ()
emitProgram name program = writePython name (compileProgram program)


-- | Compiles a program, writes python/<name>.py, and draws it into
--   python/<name>.png
previewProgram :: String -> Program -> IO ()
previewProgram name program = writeAndDraw name (compileProgram program)


--------------------------------------------------------------------------------
-- Writing and drawing
--------------------------------------------------------------------------------

-- | Writes python/<name>.py containing the given lines of drawing code
writePython :: String -> [String] -> IO ()
writePython name code =
    do runtime <- makeAbsolute "python"
       emitPython runtime ("python/" ++ name ++ ".py") code


-- | Writes python/<name>.py, then runs it with the mock plotter to draw
--   python/<name>.png
writeAndDraw :: String -> [String] -> IO ()
writeAndDraw name code =
    do writePython name code
       python  <- pythonInterpreter
       pyFile  <- makeAbsolute ("python/" ++ name ++ ".py")
       pngFile <- makeAbsolute ("python/" ++ name ++ ".png")
       hFlush stdout
       exitCode <- rawSystem python [pyFile, "--nowindow", "--out", pngFile]
       case exitCode of
           ExitSuccess   -> putStrLn ("Preview: python/" ++ name ++ ".png")
           ExitFailure _ -> putStrLn ("Could not draw the preview with " ++ python
                                      ++ ". Is matplotlib installed? (See README.md.)")


-- | The Python interpreter to use: $PIQ_PYTHON if set, otherwise python3
pythonInterpreter :: IO FilePath
pythonInterpreter =
    do fromEnvironment <- lookupEnv "PIQ_PYTHON"
       case fromEnvironment of
           Just python -> return python
           Nothing     -> return "python3"
