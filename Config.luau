local Assets = script.Parent.Assets
local Config = {}

Config.GameName = "Tic Tac Toe"
Config.Players = 2
Config.PlayerTimeout = 10

Config.BoardSize = 6
Config.WinLength = 6

Config.StartingPlayer = 1 -- "Random", "1", "2", etc

Config.Symbols = {
	Player1 = "90688714647512", --Use roblox Decal Id
	Player2 = "71567445433112",
}




return Config
