module HWProto where

import IO
import Data.Word
import Miscutils
import Maybe (fromMaybe)

fromRoom :: String -> [ClientInfo] -> [ClientInfo]
fromRoom roomName clients = filter (\cl -> roomName == room cl) clients

-- 'noInfo' clients state command handlers
handleCmd_noInfo :: ClientInfo -> [ClientInfo] -> [RoomInfo] -> [String] -> (ClientInfo, [RoomInfo], [ClientInfo], [String])

handleCmd_noInfo client clients rooms ("NICK":newNick:[]) =
	if not . null $ nick client then
		(client, rooms, [client], ["ERROR", "The nick already chosen"])
	else if haveSameNick then
		(client, rooms, [client], ["WARNING", "Choose another nick"])
	else
		(client{nick = newNick}, rooms, [client], ["NICK", newNick])
	where
		haveSameNick = not . null $ filter (\cl -> newNick == nick cl) clients

handleCmd_noInfo client clients rooms ("PROTO":protoNum:[]) =
	if protocol client > 0 then
		(client, rooms, [client], ["ERROR", "Protocol number already known"])
	else if parsedProto == 0 then
		(client, rooms, [client], ["ERROR", "Bad input"])
	else
		(client{protocol = parsedProto}, rooms, [], [])
	where
		parsedProto = fromMaybe 0 (maybeRead protoNum :: Maybe Word16)


handleCmd_noInfo client _ rooms _ = (client, rooms, [client], ["ERROR", "Bad command or incorrect parameter"])


-- 'noRoom' clients state command handlers
handleCmd_noRoom :: ClientInfo -> [ClientInfo] -> [RoomInfo] -> [String] -> (ClientInfo, [RoomInfo], [ClientInfo], [String])

handleCmd_noRoom client clients rooms ("CREATE":newRoom:roomPassword:[]) =
	if haveSameRoom then
		(client, rooms, [client], ["WARNING", "There's already a room with that name"])
	else
		(client{room = newRoom, isMaster = True}, (RoomInfo newRoom roomPassword):rooms, [client], ["JOIN", newRoom, nick client])
	where
		haveSameRoom = not . null $ filter (\room -> newRoom == name room) rooms

handleCmd_noRoom client clients rooms ("CREATE":newRoom:[]) =
	handleCmd_noRoom client clients rooms ["CREATE", newRoom, ""]

handleCmd_noRoom client clients rooms ("JOIN":roomName:roomPassword:[]) =
	if noRoom then
		(client, rooms, [client], ["WARNING", "There's no room with that name"])
	else
		(client{room = roomName}, rooms, client : fromRoom roomName clients, ["JOIN", roomName, nick client])
	where
		noRoom = null $ filter (\room -> roomName == name room) rooms

handleCmd_noRoom client clients rooms ("JOIN":roomName:[]) =
	handleCmd_noRoom client clients rooms ["JOIN", roomName, ""]

handleCmd_noRoom client _ rooms _ = (client, rooms, [client], ["ERROR", "Bad command or incorrect parameter"])

-- state-independent comman handlers	
handleCmd :: ClientInfo -> [ClientInfo] -> [RoomInfo] -> [String] -> (ClientInfo, [RoomInfo], [ClientInfo], [String])

handleCmd client clients rooms ("QUIT":xs) =
	if null (room client) then
		(client, rooms, [client], ["QUIT"])
	else
		(client, rooms, fromRoom (room client) clients, ["QUIT", nick client])

-- check state and call state-dependent commmand handlers
handleCmd client clients rooms cmd =
	if null (nick client) || protocol client == 0 then
		handleCmd_noInfo client clients rooms cmd
	else
		handleCmd_noRoom client clients rooms cmd
