-- Services
local Players = game:GetService("Players")

-- Modules & Assets
local Config = require(script.Parent.Config)
local Assets = script.Parent.Assets

-- Game State
local ServerConfig = {
	Turn = 1,
	Players = {},
	Grid = {},
	GameEnded = false,
	Winner = nil,
	LastActivity = nil,
}

-- Core Game Flow

local function GameStart()
	SetUp()
end

local function GameEnd()
	ServerConfig.GameEnded = true
	task.wait(5)
	CleanUp()
	GameStart()
end

-- Player Handling

local function CheckPlayer(player)
	for i, v in pairs(ServerConfig.Players) do
		if v == player.UserId then
			return i
		end
	end

	for i = 1, Config.Players do
		if ServerConfig.Players[i] == nil then
			ServerConfig.Players[i] = player.UserId
			return i
		end
	end

	return false
end

-- Win Logic

local function CheckDirection(startX, startY, dirX, dirY, player)
	local count = 0
	local winLength = Config.WinLength
	local winningTiles = {}

	for i = -winLength, winLength do
		local x = startX + dirX * i
		local y = startY + dirY * i

		if ServerConfig.Grid[x] and ServerConfig.Grid[x][y] == player then
			count += 1
			table.insert(winningTiles, {x, y})

			if count >= winLength then
				for _, coord in ipairs(winningTiles) do
					local tileName = coord[1] .. "_" .. coord[2]
					local tile = Assets:FindFirstChild(tileName)
					if tile then
						tile.Color = Color3.fromRGB(0, 255, 0)
					end
				end
				return true
			end
		else
			count = 0
			winningTiles = {}
		end
	end

	return false
end

local function CheckWin(x, y, player)
	return
		CheckDirection(x, y, 1, 0, player) or
		CheckDirection(x, y, 0, 1, player) or
		CheckDirection(x, y, 1, 1, player) or
		CheckDirection(x, y, 1, -1, player)
end

local function CheckDraw()
	for x = 1, Config.BoardSize do
		for y = 1, Config.BoardSize do
			if ServerConfig.Grid[x][y] == 0 then
				return false
			end
		end
	end

	for x = 1, Config.BoardSize do
		for y = 1, Config.BoardSize do
			Assets:FindFirstChild(x .. "_" .. y).Color =
				Color3.new(1, 0.933333, 0.00784314)
		end
	end

	return true
end

-- Turn Handling

local function AttemptTurn(player, x, y)
	if ServerConfig.GameEnded then return end

	local PlayerIndex = CheckPlayer(player)
	if not PlayerIndex then return end
	if ServerConfig.Turn ~= PlayerIndex then return end
	if not ServerConfig.Grid[x] or not ServerConfig.Grid[x][y] then return end
	if ServerConfig.Grid[x][y] ~= 0 then return end

	ServerConfig.Grid[x][y] = PlayerIndex
	ServerConfig.LastActivity = os.time()

	Assets:FindFirstChild(x .. "_" .. y).Decal.Texture =
		"rbxassetid://" .. Config.Symbols["Player" .. PlayerIndex]

	if CheckWin(x, y, PlayerIndex) then
		ServerConfig.Winner = PlayerIndex
		Assets.Base.BillboardGui.TextLabel.Text =
			"Player " .. PlayerIndex .. " wins!"
		GameEnd()
		return
	end

	if CheckDraw() then
		Assets.Base.BillboardGui.TextLabel.Text = "Draw!"
		GameEnd()
		return
	end

	ServerConfig.Turn = (ServerConfig.Turn % Config.Players) + 1
	Assets.Base.BillboardGui.TextLabel.Text =
		"Player " .. ServerConfig.Turn .. "'s turn"
end

-- Setup & Cleanup

function CleanUp()
	Assets.Base.BillboardGui:Destroy()

	for _, v in pairs(Assets:GetChildren()) do
		if v.Name == "Base" then continue end
		v:Destroy()
	end
end

function SetUp()
	ServerConfig = {
		Turn = 1,
		Players = {},
		Grid = {},
		GameEnded = false,
		Winner = nil,
		LastActivity = nil,
	}

	if Config.StartingPlayer == "Random" then
		ServerConfig.Turn = math.random(1, Config.Players)
	else
		ServerConfig.Turn = Config.StartingPlayer
	end

	local base = Assets.Base

	-- Billboard UI
	local BillboardGui = Instance.new("BillboardGui", base)
	BillboardGui.AlwaysOnTop = true
	BillboardGui.StudsOffset = Vector3.new(0, 5, 0)
	BillboardGui.Size = UDim2.new(3, 0, 1, 0)

	local TextLabel = Instance.new("TextLabel", BillboardGui)
	TextLabel.TextScaled = true
	TextLabel.BackgroundTransparency = 1
	TextLabel.Text = "Waiting for Player..."
	TextLabel.Size = UDim2.new(1, 0, 1, 0)
	TextLabel.TextColor3 = Color3.new(1, 1, 1)

	local UIStroke = Instance.new("UIStroke", TextLabel)
	UIStroke.Color = Color3.new(0, 0, 0)
	UIStroke.Thickness = 1

	-- Board Generation
	local N = Config.BoardSize
	local boardX = base.Size.X
	local boardZ = base.Size.Z
	local gapX = boardX / 20
	local gapZ = boardZ / 20

	local tileSizeX = (boardX - gapX * (N + 1)) / N
	local tileSizeZ = (boardZ - gapZ * (N + 1)) / N

	local originCF = base.CFrame
	local startOffset = CFrame.new(
		-boardX/2 + gapX + tileSizeX/2,
		base.Size.Y/2 + 0.03,
		-boardZ/2 + gapZ + tileSizeZ/2
	)

	for x = 1, N do
		ServerConfig.Grid[x] = {}

		for y = 1, N do
			ServerConfig.Grid[x][y] = 0

			local tile = Instance.new("Part")
			tile.TopSurface = "Smooth"
			tile.Anchored = true
			tile.Name = x .. "_" .. y
			tile.Size = Vector3.new(tileSizeX, 0.05, tileSizeZ)
			tile.Color = Color3.new(1, 1, 1)

			local decal = Instance.new("Decal", tile)
			decal.Face = "Top"

			local clickdetector = Instance.new("ClickDetector", tile)
			clickdetector.MouseClick:Connect(function(player)
				AttemptTurn(player, x, y)
			end)

			local offset = CFrame.new(
				(x - 1) * (tileSizeX + gapX),
				0,
				(y - 1) * (tileSizeZ + gapZ)
			)

			tile.CFrame = originCF * startOffset * offset
			tile.Parent = Assets
		end
	end
end

-- Inactivity Reset Loop

task.spawn(function()
	while true do
		task.wait(Config.PlayerTimeout)

		if ServerConfig.GameEnded then continue end
		if not ServerConfig.LastActivity then continue end

		if os.time() - ServerConfig.LastActivity >= Config.PlayerTimeout then
			Assets.Base.BillboardGui.TextLabel.Text =
				"Game reset due to inactivity"

			for x = 1, Config.BoardSize do
				for y = 1, Config.BoardSize do
					local tile = Assets:FindFirstChild(x .. "_" .. y)
					if tile then
						tile.Color = Color3.fromRGB(255, 0, 0)
					end
				end
			end

			GameEnd()
		end
	end
end)

-- Start Game
GameStart()
