{-# LANGUAGE OverloadedStrings #-}

import System.IO (hSetBuffering, stdout, BufferMode(LineBuffering), isEOF)
import System.Process (readProcess)
import System.Exit (exitSuccess)
import Data.Char (isHexDigit, isAlphaNum, toLower)
import Data.List (intercalate)
import Data.Aeson (Value(..), Array, object, (.=), decode, encode)
import qualified Data.Aeson.KeyMap as KM
import qualified Data.ByteString.Char8 as BS
import qualified Data.ByteString.Lazy.Char8 as BSL
import qualified Data.Text as T
import Data.Vector ((!?), fromList)

main :: IO ()
main = do
    hSetBuffering stdout LineBuffering
    eventLoop

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
      handleReq vec = do
        let reqId   = vec !? 0
            payload = vec !? 1
        case (reqId, payload) of
            (Just msgId, Just (Object obj)) -> case KM.lookup "cmd" obj of
                Just (String "variableToUUIDInit") -> do
                    let varName = extractVarName (KM.lookup "line" obj)
                    let style   = extractStyle (KM.lookup "style" obj)
                    rawUuid <- readProcess "uuidgen" [] ""
                    let codeLines = formatUUID style varName (trim rawUuid)
                    let response =
                            Array (fromList
                                    [msgId,
                                        object ["status" .= ("ok" :: T.Text),
                                        "lines" .= codeLines]])
                    BSL.putStrLn (encode response)
                    eventLoop

                Just (String "shutdown") -> do
                    let response =
                            Array (fromList
                                    [msgId,
                                     object ["status" .= ("ok" :: T.Text)]])
                    BSL.putStrLn (encode response)
                    exitSuccess

                _ -> respondError msgId "Unknown command" >> eventLoop
            _ -> respondError Null "Invalid format" >> eventLoop

respondError :: Value -> String -> IO ()
respondError msgId err = do
    let response =
            Array (fromList
                    [msgId,
                     object ["status" .= ("error" :: T.Text),
                     "message" .= err]])
    BSL.putStrLn (encode response)

extractVarName :: Maybe Value -> String
extractVarName (Just (String txt)) =
    let cleaned = filter (\c -> isAlphaNum c || c == '_') (T.unpack txt)
    in if null cleaned then "uuid_var" else cleaned
extractVarName _ = "uuid_var"

extractStyle :: Maybe Value -> String
extractStyle (Just (String txt)) = T.unpack txt
extractStyle _                   = "c_array"

trim :: String -> String
trim = filter (`notElem` ['\r', '\n'])

-- Dispatch code generation based on target style
formatUUID :: String -> String -> String -> [String]
formatUUID "rcpr" varName rawUuid =
    let hexOnly = filter isHexDigit rawUuid
        bytes   = map (\p -> "0x" ++ map toLower p) (groupTwo hexOnly)
        (r1, r2) = splitAt 8 bytes
    in [ "rcpr_uuid " ++ varName ++ " = { .data = {"
       , "    " ++ intercalate ", " r1 ++ ","
       , "    " ++ intercalate ", " r2 ++ " } };"
       ]

formatUUID "java" varName rawUuid =
    [ "UUID " ++ varName ++ " = UUID.fromString(\""
      ++ map toLower rawUuid ++ "\");" ]

formatUUID _ varName rawUuid = -- Default: "c_array"
    let hexOnly = filter isHexDigit rawUuid
        bytes   = map (\p -> "0x" ++ map toLower p) (groupTwo hexOnly)
        (r1, r2) = splitAt 8 bytes
    in [ "uint8_t " ++ varName ++ "[16] = {"
       , "    " ++ intercalate ", " r1 ++ ","
       , "    " ++ intercalate ", " r2 ++ " };"
       ]

groupTwo :: String -> [String]
groupTwo [] = []
groupTwo (a:b:rest) = [a,b] : groupTwo rest
groupTwo [a] = [[a]]
