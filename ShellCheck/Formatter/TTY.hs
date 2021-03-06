{-
    Copyright 2012-2015 Vidar Holen

    This file is part of ShellCheck.
    http://www.vidarholen.net/contents/shellcheck

    ShellCheck is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    ShellCheck is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
-}
module ShellCheck.Formatter.TTY (format) where

import ShellCheck.Interface
import ShellCheck.Formatter.Format

import Data.List
import GHC.Exts
import System.Info
import System.IO

format :: IO Formatter
format = return Formatter {
    header = return (),
    footer = return (),
    onFailure = outputError,
    onResult = outputResult
}

colorForLevel level = 
    case level of
        "error"   -> 31 -- red
        "warning" -> 33 -- yellow
        "info"    -> 32 -- green
        "style"   -> 32 -- green
        "message" -> 1 -- bold
        "source"  -> 0 -- none
        otherwise -> 0 -- none
    
outputError file error = do
    color <- getColorFunc
    hPutStrLn stderr $ color "error" $ file ++ ": " ++ error

outputResult result contents = do
    color <- getColorFunc
    let comments = crComments result
    let fileLines = lines contents
    let lineCount = fromIntegral $ length fileLines
    let groups = groupWith lineNo comments
    mapM_ (\x -> do
        let lineNum = lineNo (head x)
        let line = if lineNum < 1 || lineNum > lineCount
                        then ""
                        else fileLines !! fromIntegral (lineNum - 1)
        putStrLn ""
        putStrLn $ color "message" $
           "In " ++ crFilename result ++" line " ++ show lineNum ++ ":"
        putStrLn (color "source" line)
        mapM_ (\c -> putStrLn (color (severityText c) $ cuteIndent c)) x
        putStrLn ""
      ) groups

cuteIndent :: PositionedComment -> String
cuteIndent comment =
    replicate (fromIntegral $ colNo comment - 1) ' ' ++
        "^-- " ++ code (codeNo comment) ++ ": " ++ messageText comment

code code = "SC" ++ show code

getColorFunc = do
    term <- hIsTerminalDevice stdout
    let windows = "mingw" `isPrefixOf` os
    return $ if term && not windows then colorComment else const id
  where
    colorComment level comment =
        ansi (colorForLevel level) ++ comment ++ clear
    clear = ansi 0
    ansi n = "\x1B[" ++ show n ++ "m"
