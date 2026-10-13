{-|
Module       : PiqEvaluation
Description  : Evaluates piq expressions and compiles piq programs into
               primitive Python pen-plotter commands.

**YOU WILL EDIT THIS FILE.**

Every place you need to fill in is marked

    -- TODO (Part N): ...

and currently stops with an error message saying which TODO it is. Work
through the parts in the order given in ASSIGNMENT.md. Everything that is
not marked TODO is provided and already works: read it, but you should not
need to change it.
-}

module PiqEvaluation where

import           PiqAST
import           Python

import qualified Data.Map as Map


--------------------------------------------------------------------------------
-- Environments (Part 1, and Part 5)
--
-- An environment associates each variable name with its current value.
-- We use Data.Map, a lookup table. Like every Haskell value it is immutable:
-- "updating" an environment builds a new environment and leaves the old one
-- unchanged.
--
-- The only Data.Map functions you need are:
--
--     Map.empty                  an empty table
--     Map.insert key value table a new table with key bound to value
--     Map.lookup key table       Just value, or Nothing if key is not there
--     Map.delete key table       a new table without key
--
-- The helpers below are the only code that uses Data.Map directly. The rest
-- of the compiler uses these helpers.
--------------------------------------------------------------------------------

-- | Maps variable names to their values
type Env = Map.Map Name Double


-- | An environment with no variables in it  (PROVIDED)
emptyEnv :: Env
emptyEnv = Map.empty


-- | Looks up the value of a variable. Using a variable that has never been
--   assigned is an error in the piq program: stop with the message
--
--       undefined variable: <name>
--
--   for example  error ("undefined variable: " ++ name)
lookupVar :: Name -> Env -> Double
lookupVar name env =
    -- TODO (Part 1): use Map.lookup and a case expression on its result
    --   (Just value, or Nothing).
    let x = Map.lookup name env in 
        case x of 
            Nothing -> error ("undefined variable: " ++ name)
            Just value -> value


-- | Returns a new environment in which the variable has the given value,
--   whether or not the variable already had a value.  (PROVIDED)
assignVar :: Name -> Double -> Env -> Env
assignVar name value env = Map.insert name value env


-- | The variable's current value, if it has one, or Nothing if it has none.
--   Used to remember a value before it is temporarily replaced, so that
--   restoreVar can put it back.
saveVar :: Name -> Env -> Maybe Double
saveVar name env =
    -- TODO (Part 5): this is one Data.Map function.
    Map.lookup name env 
        


-- | Puts back what saveVar remembered: if there was an old value, the
--   variable gets that value again; if there was none (Nothing), the
--   variable is removed from the environment entirely.
restoreVar :: Name -> Maybe Double -> Env -> Env
restoreVar name saved env =
    -- TODO (Part 5): pattern-match on `saved` (Just value / Nothing).
    case saved of
        Nothing ->  Map.delete name env
        Just value -> Map.insert name value env 


--------------------------------------------------------------------------------
-- Procedure environments (Part 6)  (ALL PROVIDED)
--
-- A procedure environment maps procedure names to their definitions. It is
-- built once, from all of the program's definitions, and never changes while
-- the program is compiled.
--------------------------------------------------------------------------------

-- | Maps procedure names to their definitions
type ProcEnv = Map.Map Name ProcDef


-- | A procedure environment with no procedures in it
emptyProcEnv :: ProcEnv
emptyProcEnv = Map.empty


-- | Builds the procedure environment for a program's definitions. Defining
--   two procedures with the same name is an error.
makeProcEnv :: [ProcDef] -> ProcEnv
makeProcEnv [] = emptyProcEnv
makeProcEnv (ProcDef name params body : defs)
    | Map.member name rest = error ("duplicate procedure: " ++ name)
    | otherwise            = Map.insert name (ProcDef name params body) rest
    where rest = makeProcEnv defs


-- | Looks up a procedure's definition. Calling a procedure that was never
--   defined is an error in the piq program.
lookupProc :: Name -> ProcEnv -> ProcDef
lookupProc name procs =
    case Map.lookup name procs of
        Just def -> def
        Nothing  -> error ("unknown procedure: " ++ name)


--------------------------------------------------------------------------------
-- Expression evaluation (Part 1)
--------------------------------------------------------------------------------

-- | Evaluates an expression, using the environment for the values of its
--   variables. This is like the arithmetic evaluator you wrote before, plus
--   one new kind of expression: a variable.
eval :: Env -> Expr -> Double
eval _   (Num n)     = n          -- PROVIDED: a number evaluates to itself
eval env (Var name)  =
    -- TODO (Part 1): a variable evaluates to its value in the environment.
    lookupVar name env
eval env (Add e1 e2) =
    -- TODO (Part 1): evaluate both sides (recursively), then add.
    eval env e1 + eval env e2   
eval env (Sub e1 e2) =
    -- TODO (Part 1)
    eval env e1 - eval env e2 
eval env (Mul e1 e2) =
    -- TODO (Part 1)
    eval env e1 * eval env e2
eval env (Div e1 e2) 
    | divisor == 0 = error ("division by zero")
    | divisor /= 0 = eval env e1 / divisor
    where divisor = eval env e2


--------------------------------------------------------------------------------
-- Compiling statements (Parts 2-6)
--
-- The compiler turns each statement into a list of lines of Python code,
-- built with the three helpers from Python.hs:
--
--     penUp            "pen_up()"
--     penDown          "pen_down()"
--     moveRel dx dy    "move_rel(dx, dy)"   travel dx mm right, dy mm up
--
-- It keeps one promise about the pen:
--
--     Between statements, the pen is always up.
--
-- So every statement that lowers the pen raises it again before it ends.
-- Some pen_up() calls are redundant (a move always raises the pen first, even
-- though it is already up). That is fine: it keeps each statement's code
-- self-contained.
--
-- Coordinates are in millimetres, with positive x to the right and positive
-- y toward the TOP of the page.
--------------------------------------------------------------------------------

-- | Compiles a whole program: builds the procedure environment from the
--   definitions, then compiles the statements starting with no variables.
--   (PROVIDED)
compileProgram :: Program -> [String]
compileProgram (Program defs stmts) =
    -- `seq` builds the whole procedure environment first, so that a duplicate
    -- procedure name is reported even if that procedure is never called.
    procs `seq` snd (compileStmts procs emptyEnv stmts)
    where procs = makeProcEnv defs


-- | Compiles one statement. Returns the environment AFTER the statement, and
--   the Python code for the statement.
--
--   * Drawing statements produce code and leave the environment unchanged.
--   * An assignment changes the environment and produces no code.
--   * The procedure environment is only needed for calls (Part 6); until
--     then, just pass it along or ignore it.
compileStmt :: ProcEnv -> Env -> Stmt -> (Env, [String])
compileStmt _ env Dot = (env, dotCode)               -- PROVIDED: an example

compileStmt _ env (Move dir distance) =
    -- TODO (Part 2): evaluate the distance, and use moveCode.
    let x = eval env distance
    in (env, moveCode dir x)

compileStmt _ env (Line dir distance) =
    -- TODO (Part 2)
    let x = eval env distance
    in (env, lineCode dir x)

compileStmt _ env (Square side) =
    -- TODO (Part 2)
    let x = eval env side
    in (env, squareCode x)

compileStmt _ env (Rectangle wid ht) =
    -- TODO (Part 2)
    let x = eval env wid 
        y = eval env ht 
    in (env, rectangleCode x y)

compileStmt _ env (Circle radius) =
    -- TODO (Part 3)
    let x = eval env radius 
    in (env, circleCode x)

compileStmt _ env (Assign name expr) =
    -- TODO (Part 4): the new environment has `name` bound to the value of
    --   `expr` (evaluated in the CURRENT environment). There is no code.
    --   Wrap your result as   forceValue value (newEnv, [])   -- see below.
    let value = eval env expr 
        newEnv = Map.insert name value env
    in forceValue value (newEnv, [])

compileStmt procs env (For var from to body) =
    -- TODO (Part 5): see ASSIGNMENT.md. You will use toLoopBound, saveVar,
    --   compileLoop and restoreVar.
    let start = toLoopBound (eval env from)
        end = toLoopBound (eval env to)
        saved = saveVar var env
        (newEnv, code) = compileLoop procs var [start..end] env body
   in (restoreVar var saved newEnv, code)
   


compileStmt procs env (Call name args) =
    -- TODO (Part 6): see ASSIGNMENT.md. You will use lookupProc, eval,
    --   bindParams, compileStmts and forceValues.
    --   Recursive procedure calls are invalid piq programs; the compiler does
    --   not check for them.
    let ProcDef _ params body = lookupProc name procs 
        values = map (eval env) args 
        localEnv = bindParams params values env 
        (newEnv, code) = compileStmts procs localEnv body 
    in if length params /= length args then error ("procedure " ++ name ++ " expects " ++ show (length params)++ " arguments, got " ++ show (length args))
        else forceValues values (env,code)


-- | Compiles a sequence of statements, one after another. Each statement is
--   compiled in the environment left by the statement before it. Returns the
--   environment after the last statement, and all of the code in order.
compileStmts :: ProcEnv -> Env -> [Stmt] -> (Env, [String])
compileStmts _     env []             = (env, [])     -- PROVIDED
compileStmts procs env (stmt : stmts) =
    -- TODO (Part 4): compile `stmt`, then compile `stmts` in the environment
    --   that `stmt` produced. Use a `where` clause with two tuple patterns.
   (env2, code1 ++code2)
   where 
    (env1, code1) = compileStmt procs env stmt
    (env2,code2) = compileStmts procs env1 stmts


-- | Compiles a loop body once for each value of the loop variable, in order.
--   Each iteration starts from the environment the previous iteration left,
--   with the loop variable set to the next value. An empty list of values
--   compiles the body zero times.
compileLoop :: ProcEnv -> Name -> [Int] -> Env -> [Stmt] -> (Env, [String])
compileLoop _ _ [] env _ = (env, [])
compileLoop procs var (v :values) env body =
    (env3, code1 ++ code2)
    where 
        env1 = assignVar var (fromIntegral v) env
        (env2 , code1) = compileStmts procs env1 body
        (env3, code2) = compileLoop procs var values env2 body
    -- TODO (Part 5): recursion on the list of values, a lot like compileStmts.
    


-- | Checks that a loop bound is a whole number and converts it to an Int.
--   A bound such as 2.5 is an error:
--
--       non-integral loop bound: 2.5
--
--   Hint: `round` turns a Double into an Int; `fromIntegral` turns it back.
--   Use `show bound` for the number in the message.
toLoopBound :: Double -> Int
toLoopBound bound =
    -- TODO (Part 5)
    let x = round bound in
        if fromIntegral x == bound then fromIntegral x
        else error ("non-integral loop bound: " ++ show bound)


-- | Binds each parameter name to the matching argument value, in order,
--   starting from the given environment.
bindParams :: [Name] -> [Double] -> Env -> Env
bindParams [] [] env = env
bindParams (p:params) (v: values) env =
    -- TODO (Part 6): recursion on both lists at once.
    bindParams params values (assignVar p v env)
    


--------------------------------------------------------------------------------
-- Forcing values  (PROVIDED)
--
-- Haskell is lazy: a value is not computed until something needs it. If
-- `x = 1 / 0` put an unevaluated `1 / 0` into the environment, the error
-- would only appear if some later statement used x, and not at all if none
-- did. We want every invalid piq program to be reported, so assignments and
-- calls compute their values right away with these helpers.
--------------------------------------------------------------------------------

-- | Computes the value, then returns the result.
forceValue :: Double -> result -> result
forceValue value result = value `seq` result


-- | Computes every value in the list, then returns the result.
forceValues :: [Double] -> result -> result
forceValues []               result = result
forceValues (value : values) result = value `seq` forceValues values result


--------------------------------------------------------------------------------
-- Code for each kind of drawing statement (Parts 2 and 3)
--------------------------------------------------------------------------------

-- | How far a trip of the given distance in the given direction travels,
--   as (dx, dy). Remember: positive dy is UP the page.
offset :: Direction -> Double -> (Double, Double)
offset Rt distance = (distance, 0)                   -- PROVIDED: an example
offset Lt distance =
    -- TODO (Part 2)
    (-distance, 0)
offset Up distance =
    -- TODO (Part 2)
    (0, distance)
offset Dn distance =
    -- TODO (Part 2)
    (0, -distance)


-- | A dot: touch the pen to the paper at the current position.  (PROVIDED)
dotCode :: [String]
dotCode = [penDown, penUp]


-- | Travel without drawing: raise the pen, then move by the offset.
moveCode :: Direction -> Double -> [String]
moveCode dir distance =
    -- TODO (Part 2): two lines of Python.
    let (x, y) = offset dir distance
    in [penUp, moveRel x y]


-- | Draw a line: lower the pen, move by the offset, raise the pen. The
--   current position ends up at the far end of the line.
lineCode :: Direction -> Double -> [String]
lineCode dir distance =
    -- TODO (Part 2): three lines of Python.
    let (x ,y) = offset dir distance
    in [penDown, moveRel x y, penUp]



-- | A square with the given side length, CENTERED on the current position.
--   It must end where it started (the center), with the pen up, and draw
--   the whole outline in one stroke (a single pen_down).
--
--   Think in three stages:
--     1. travel to one corner with the pen up,
--     2. draw the four sides,
--     3. travel back to the center with the pen up.
squareCode :: Double -> [String]
squareCode side =
    -- TODO (Part 2)
    let (x, y) = offset Up side 
        (a, b) = offset Dn side
        (c,d ) = offset Lt side
        (e,f) = offset Rt side
    in [penUp, moveRel ((-side)/ 2) ((-side)/2), penDown, moveRel x y, moveRel e f, moveRel a b , moveRel c d, penUp, moveRel (side/2) (side/2) ]


-- | A rectangle with the given width and height, centered on the current
--   position. Just like a square, except that the sides differ.
rectangleCode :: Double -> Double -> [String]
rectangleCode wid ht =
    -- TODO (Part 2)
    let (x, y) = offset Up ht 
        (a, b) = offset Dn ht
        (c, d) = offset Lt wid 
        (e, f) = offset Rt wid
    in [penUp, moveRel ((-wid)/ 2) ((-ht)/2), penDown, moveRel x y, moveRel e f, moveRel a b, moveRel c d, penUp, moveRel (wid/2) (ht /2) ]


-- | How many straight segments make up a circle.  (PROVIDED)
circleSegments :: Int
circleSegments = 36


-- | A circle with the given radius, centered on the current position,
--   approximated by circleSegments straight segments. ASSIGNMENT.md, Part 3,
--   explains the geometry and gives the formulas.
circleCode :: Double -> [String]
circleCode radius =
    -- TODO (Part 3)
    [penUp, moveRel radius 0, penDown] ++
    map step [0 .. circleSegments -1 ] ++ [penUp, moveRel (-radius) 0]
    where 
        step k =
            let thetak = 2 * pi * fromIntegral k / fromIntegral circleSegments
                thetak1 = 2 * pi * fromIntegral (k+1) / fromIntegral circleSegments
                xtheta = radius * cos thetak
                ytheta = radius * sin thetak
                xtheta1 = radius * cos thetak1
                ytheta1 = radius * sin thetak1
            in moveRel (xtheta1 - xtheta) (ytheta1-ytheta)
    
