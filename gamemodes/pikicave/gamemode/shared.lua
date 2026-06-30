GM.Name = "Treasure Hunt"
GM.Author = "jasherton"

DeriveGamemode("sandbox")

function GM:Initialize()
	
end

--before player has fully loaded
function GM:PlayerInitialSpawn(player,trans)
	player:SetModel(player_manager.TranslatePlayerModel(player:GetInfo("cl_playermodel")))
	player:SetPlayerColor(Vector(player:GetInfo("cl_playercolor")))
	player:SetSkin(player:GetInfo("cl_playerskin"))
end

--called every spawn
function GM:PlayerSpawn(player,trans)
	player:SetModel(player_manager.TranslatePlayerModel(player:GetInfo("cl_playermodel")))
	player:SetPlayerColor(Vector(player:GetInfo("cl_playercolor")))
	player:SetSkin(player:GetInfo("cl_playerskin"))
	player_manager.SetPlayerClass(player,"player_sandbox")
	player:Give("olimar_gun",true)
end

function GM:CanPlayerSuicide(player)
	return false
end

function GM:DoPlayerDeath(player,attacker,dmg)
	self.BaseClass:DoPlayerDeath(player,attacker,dmg)
end

function GM:PlayerDeath(player,inflictor,attacker)
	--self.BaseClass:PlayerDeath(player,inflictor,attacker)
end

function GM:ContextMenuEnabled()
	return false
end

function GM:SpawnMenuEnabled()
	return false
end

function GM:SpawnMenuOpen()
	return false
end

--//Clientside Functions
function GM:OnContextMenuOpen()
	--create special menu here
end

function GM:ContextMenuOpen()
	return false
end

function GM:ScoreboardShow()
	--create scoreboard here
	return true
end

function GM:ScoreboardHide()
end