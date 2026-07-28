{-# LANGUAGE OverloadedStrings #-}

import System.IO (hSetBuffering, stdout, BufferMode(LineBuffering), isEOF)
import System.Process (readProcess)
import System.Exit (exitSuccess)
import Data.Char (isHexDigit, isAlphaNum, toLower)
import Data.List (intercalate)
import Data.Maybe (isJust, fromJust, fromMaybe)
import Data.Aeson (Value(..), Array, object, (.=), decode, encode)
import qualified Data.Aeson.KeyMap as KM
import qualified Data.ByteString.Char8 as BS
import qualified Data.ByteString.Lazy.Char8 as BSL
import qualified Data.Text as T
import Data.Vector ((!?), fromList)

-- Set output to line buffering and enter the event loop.
main :: IO ()
main = do
    hSetBuffering stdout LineBuffering
    eventLoop

-- While not EOF, read a JSON line and respond.
eventLoop :: IO ()
eventLoop = do
    eof <- isEOF
    if eof
        then exitSuccess
        else do
            strictline <- BS.getLine
            let line = BSL.fromStrict strictline
            case decode line of
                Just (Array vec) | length vec == 2 -> handleReq vec
                _ -> eventLoop
    where
      -- Decode and dispatch a request from Vim.
      handleReq :: Array -> IO ()
      handleReq vec = do
        let reqId   = vec !? 0
            payload = vec !? 1
        case (reqId, payload) of
            -- decode commands
            (Just msgId, Just (Object obj)) -> case KM.lookup "cmd" obj of
                -- Handle variable to UUID
                Just (String "variableToUUIDInit") -> do
                    let line = KM.lookup "line" obj
                    let varName = extractVarName line
                    let uuid = extractUUID line
                    let style   = extractStyle $ KM.lookup "style" obj
                    codeLines <-
                        if isJust uuid then do
                            pure $ formatUUID style varName $ fromJust uuid
                        else do
                            rawUuid <- readProcess "uuidgen" [] ""
                            pure $ formatUUID style varName $ trim rawUuid
                    let response =
                            Array (fromList
                                    [msgId,
                                        object
                                            [
                                              "status" .= ("ok" :: T.Text),
                                              "lines" .= codeLines]])
                    BSL.putStrLn (encode response)
                    eventLoop
                -- handle shutdown
                Just (String "shutdown") -> do
                    let response =
                            Array (fromList
                                    [msgId,
                                     object ["status" .= ("ok" :: T.Text)]])
                    BSL.putStrLn (encode response)
                    exitSuccess
                -- an unknown command
                _ -> respondError msgId "Unknown command" >> eventLoop
            -- unknown message type.
            _ -> respondError Null "Invalid format" >> eventLoop

-- send an error response
respondError :: Value -> String -> IO ()
respondError msgId err = do
    let response =
            Array (fromList
                    [msgId,
                     object ["status" .= ("error" :: T.Text),
                     "message" .= err]])
    BSL.putStrLn (encode response)

-- return the head of a string list or Nothing
safeHeadWord :: [String] -> Maybe String
safeHeadWord (x : xs) = Just x
safeHeadWord _ = Nothing

-- return the second word of a string list or Nothing
safeSecondWord :: [String] -> Maybe String
safeSecondWord (_:x:_) = Just x
safeSecondWord _ = Nothing

-- Extract the variable name from a line
extractVarName :: Maybe Value -> String
extractVarName (Just (String txt)) =
    let firstWord = fromMaybe "uuid_var" $ safeHeadWord $ words $ T.unpack txt
    in filter (\c -> isAlphaNum c || c == '_') firstWord
extractVarName _ = "uuid_var"

-- Extract an optional UUID from a line
extractUUID :: Maybe Value -> Maybe String
extractUUID (Just (String txt)) = safeSecondWord $ words $ T.unpack txt
extractUUID _ = Nothing

-- Extract the code generation style.
extractStyle :: Maybe Value -> String
extractStyle (Just (String txt)) = T.unpack txt
extractStyle _                   = "c_array"

-- Remove end line bits
trim :: String -> String
trim = filter (`notElem` ['\r', '\n'])

-- Dispatch code generation based on target style
formatUUID :: String -> String -> String -> [String]
-- RCPR style.
formatUUID "rcpr" varName rawUuid =
    let hexOnly = filter isHexDigit rawUuid
        bytes   = map (\p -> "0x" ++ map toLower p) (groupTwo hexOnly)
        (r1, r2) = splitAt 8 bytes
    in [ "rcpr_uuid " ++ varName ++ " = { .data = {"
       , "    " ++ intercalate ", " r1 ++ ","
       , "    " ++ intercalate ", " r2 ++ " } };"
       ]
-- Java style.
formatUUID "java" varName rawUuid =
    [ "UUID " ++ varName ++ " = UUID.fromString(\""
      ++ map toLower rawUuid ++ "\");" ]
-- Default is C style.
formatUUID _ varName rawUuid = -- Default: "c_array"
    let hexOnly = filter isHexDigit rawUuid
        bytes   = map (\p -> "0x" ++ map toLower p) (groupTwo hexOnly)
        (r1, r2) = splitAt 8 bytes
    in [ "uint8_t " ++ varName ++ "[16] = {"
       , "    " ++ intercalate ", " r1 ++ ","
       , "    " ++ intercalate ", " r2 ++ " };"
       ]

-- Build a two character grouping for hex bytes.
groupTwo :: String -> [String]
groupTwo [] = []
groupTwo (a:b:rest) = [a,b] : groupTwo rest
groupTwo [a] = [[a]]
