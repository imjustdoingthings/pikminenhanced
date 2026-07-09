--//Constants
ColorCollideTable = {
"models/pikmin/pikmin_collision.mdl",
"models/pikmin/pikmin_collision.mdl",
"models/pikmin/pikmin_collision.mdl",
"models/pikmin/pikmin_collisionp.mdl",
"models/pikmin/pikmin_collisionw.mdl",
"models/pikmin/pikmin_collision.mdl",
"models/pikmin/pikmin_collisionw.mdl",
"models/pikmin/pikmin_collisionp.mdl",
"models/pikmin/pikmin_collision.mdl",
}

ColorModelTable = {
"models/pikmin/pikmin_red1.mdl",
"models/pikmin/pikmin_red2.mdl",
"models/pikmin/pikmin_red3.mdl",
"models/pikmin/pikmin_yellow1.mdl",
"models/pikmin/pikmin_yellow2.mdl",
"models/pikmin/pikmin_yellow3.mdl",
"models/pikmin/pikmin_blue1.mdl",
"models/pikmin/pikmin_blue2.mdl",
"models/pikmin/pikmin_blue3.mdl",
"models/pikmin/pikmin_purple1.mdl",
"models/pikmin/pikmin_purple2.mdl",
"models/pikmin/pikmin_purple3.mdl",
"models/pikmin/pikmin_white1.mdl",
"models/pikmin/pikmin_white2.mdl",
"models/pikmin/pikmin_white3.mdl",
"models/pikmin/pikmin_green1.mdl",
"models/pikmin/pikmin_green2.mdl",
"models/pikmin/pikmin_green3.mdl",
"models/pikmin/pikmin_pink1.mdl",
"models/pikmin/pikmin_pink2.mdl",
"models/pikmin/pikmin_pink3.mdl",
"models/pikmin/pikmin_rock1.mdl",
"models/pikmin/pikmin_rock2.mdl",
"models/pikmin/pikmin_rock3.mdl",
"models/pikmin/pikmin_puffmin1.mdl",
"models/pikmin/pikmin_puffmin2.mdl",
"models/pikmin/pikmin_puffmin3.mdl",
}

PikHealth = {
24,
18,
28,
40,
12,
18,
12,
40,
24
}

PikDamage = {
15,
10,
10,
20,
10,
10,
10,
20,
15
}

PikSpeed = {
	700,
	700,
	700,
	600,
	1000,
	700,
	700,
	600,
	700
}

--converting real pikmin damage to more source-appropriate damage
PikDamageDivider = 6

PikTypes = 9

PikDefaultTypeNames = {
"Red",
"Yellow",
"Blue",
"Purple",
"White",
"Bulbmin",
"Winged",
"Rock",
"Mushroom"
}

DeathColorVectors = {
Vector(255,10,10),
Vector(255,255,10),
Vector(10,10,255),
Vector(150,10,150),
Vector(250,250,250),
Vector(0,0,0),
Vector(255,105,180),
Vector(100,100,100),
Vector(120,50,160)
}

FlowerColorVectors = {
Vector(255, 255, 255),
Vector(255, 255, 255),
Vector(255, 255, 255),
Vector(220, 100, 150),
Vector(220, 100, 150),
Vector(255, 255, 255),
Vector(255, 255, 255),
Vector(220, 100, 150),
Vector(180, 100, 220),
}

BaseShadowParams = {
	secondstoarrive = .2,
	maxangular = 5000,
	maxangulardamp = 10000,
	maxspeed = 0,
	maxspeeddamp = 0,
	dampfactor = 0.8,
	teleportdistance = 0,
}

--props that can be carried to any available onion
PikiCarryOnionList = {
"models/pikmin/pellet_1.mdl",
"models/pikmin/pellet_5.mdl",
"models/pikmin/pellet_10.mdl",
"models/pikmin/pellet_20.mdl"
}

--(MinWeight,MaxPiki)
PikiCarryDict = {
["models/pikmin/pellet_1.mdl"] = {1,2},
["models/pikmin/pellet_5.mdl"] = {5,10},
["models/pikmin/pellet_10.mdl"] = {10,20},
["models/pikmin/pellet_20.mdl"] = {20,40},
}

PikiFueDict = {
["models/pikmin/pellet_1.mdl"] = 1,
["models/pikmin/pellet_5.mdl"] = 5,
["models/pikmin/pellet_10.mdl"] = 10,
["models/pikmin/pellet_20.mdl"] = 20,
}

--multiply the count by 2 based on matching skin
PikiFueSDict = {
["models/pikmin/pellet_1.mdl"] = true,
["models/pikmin/pellet_5.mdl"] = true,
["models/pikmin/pellet_10.mdl"] = true,
["models/pikmin/pellet_20.mdl"] = true,
}

PikiSoundBurn = {
"pikmin/burn1.wav",
"pikmin/burn2.wav",
"pikmin/burn3.wav",
"pikmin/burn4.wav",
}

PikiSoundGas = {
"pikmin/poison1.wav",
"pikmin/poison2.wav",
"pikmin/poison3.wav",
}

PikiSoundIdle = {
"pikmin/idle1.wav",
"pikmin/idle2.wav",
"pikmin/idle3.wav",
"pikmin/idle4.wav",
"pikmin/idle5.wav",
}

PikiSoundPluck = {
"pikmin/pikmin_pluck1.wav",
"pikmin/pikmin_pluck2.wav",
"pikmin/pikmin_pluck3.wav",
}

DisbandColors = {
	Color(255, 150, 150, 255),
	Color(255, 255, 150, 255),
	Color(150, 150, 255, 255),
	Color(225, 150, 225, 255),
	Color(255, 255, 255, 255),
	Color(0,255,0,255),
	Color(255, 105, 180, 255),
	Color(150, 150, 150, 255),
	Color(180, 100, 220, 255),
}

OrimaModel = {"models/player/orima.mdl","models/player/louie.mdl","models/player/chacho.mdl"}
OrimaLightMultX = {36,36,33}
PoisonMat = Material("particles/smokey")
DisbandLight = Material("pikmin/disband_light")
GlowLight = Material("pikmin/glow")
RayLight = Material("pikmin/ray")

PikiOnionP3Colors = {1, 3, 2, 7, 8} -- Red, Blue, Yellow, Winged, Rock
PikiOnionP3Models = {
	"models/pikmin/onion_new.mdl",
	"models/pikmin/onion_large.mdl"
}

PikiMaxField = 100
PikiAuto = 0
PikiDisband = 1

--//Physics Fix
--sv_crazyphysics_defuse 0
--sv_crazyphysics_remove 0
--sv_crazyphysics_warning 0

--//Functions
local ViewEntity = nil
local function PikiRagViewFunc(ply,pos,angles,fov,znear,zfar)
	if not IsValid(ViewEntity) then return end
	pos = ViewEntity:GetPos() + Vector(0,0,30)
	local pushLook = -angles:Forward()*100
	local trace = util.QuickTrace(pos,pushLook,ents.GetAll())
	local view = {
		origin = trace.HitWorld and trace.HitPos+trace.HitNormal*5 or pos+pushLook,
		angles = angles,
		fov = fov,
		drawviewer = true,
	}
	return view
end

--//Networking
if SERVER then
	util.AddNetworkString("RagColorPly")
	util.AddNetworkString("PikiMasterOnionMenu")
else
	net.Receive("RagColorPly",function()
		local ply = net.ReadEntity()
		local ragIdx = net.ReadInt(32)
		local rag = Entity(ragIdx)
		if not IsValid(rag) then
			local hookname = "pkrg"..ragIdx
			hook.Add("Think",hookname,function()
				rag = Entity(ragIdx)
				if IsValid(rag) then
					rag.GetPlayerColor = function() return ply:GetPlayerColor() end
					hook.Remove("Think",hookname)
				end
			end)
			return
		end
		rag.GetPlayerColor = function() return ply:GetPlayerColor() end
	end)
end

--//CVars
CreateConVar("pik_auto",tostring(PikiAuto),{FCVAR_REPLICATED, FCVAR_ARCHIVE},"use special Pikmin logic (might cause lag)")
CreateConVar("pik_field",tostring(PikiMaxField),{FCVAR_REPLICATED, FCVAR_ARCHIVE},"Maximum Pikmin")
CreateConVar("pik_drops",0,{FCVAR_REPLICATED, FCVAR_ARCHIVE},"Enable NPC Drops")
CreateConVar("pik_idle","1",{FCVAR_REPLICATED, FCVAR_ARCHIVE},"Play Pikmin idle sounds")
CreateConVar("pik_classicpluck","0",{FCVAR_REPLICATED, FCVAR_ARCHIVE},"Use classic Pikmin spawn sounds")
CreateConVar("pik_admin","1",{FCVAR_REPLICATED, FCVAR_ARCHIVE},"Restrict Pikmin entities to admins")
CreateConVar("pik_disband","1",{FCVAR_REPLICATED, FCVAR_ARCHIVE},"enable Pikmin grouping on disband")
CreateConVar("pik_white_poisongas","1",{FCVAR_REPLICATED, FCVAR_ARCHIVE},"Enable White Pikmin poison gas on death")


local PikminAdminRestrictedClasses = {
	["pikmin"] = true,
	["pikmin_bud"] = true,
	["pikmin_nectar"] = true,
	["pikmin_onion"] = true,
	["pikmin_onion_master"] = true,
	["pikmin_onion_p3"] = true,
	["pikmin_sprout"] = true,
	["bulbmin"] = true
}

hook.Add("PlayerSpawnSENT", "PikminAdminRestrict", function(ply, class)
	if PikminAdminRestrictedClasses[class] and cvars.Bool("pik_admin") and not ply:IsAdmin() then
		ply:ChatPrint("This entity is restricted to admins!")
		return false
	end
end)
if SERVER then
	cvars.AddChangeCallback("pik_auto", function(name,ov,nv)
		PikiAuto = math.Clamp(math.floor(tonumber(nv) or 0),0,1)
		if PikiAuto == 1 and #ents.FindByClass("pikmin_logic") == 0 then
			ents.Create("pikmin_logic"):Spawn()
		elseif PikiAuto == 0 then
			local find = ents.FindByClass("pikmin_logic")
			if find[1] then find[1]:Remove() end
		end
	end)
	cvars.AddChangeCallback("pik_field", function(name,ov,nv) PikiMaxField = math.max(0, math.floor(tonumber(nv) or 0)) end)
	cvars.AddChangeCallback("pik_disband", function(name,ov,nv) PikiDisband = math.Clamp(math.floor(tonumber(nv) or 0),0,1) end)
	
	PikiAuto = math.Clamp(math.floor(GetConVar("pik_auto"):GetInt()), 0, 1)
	PikiMaxField = math.max(0, math.floor(GetConVar("pik_field"):GetInt()))
	PikiDisband = math.Clamp(math.floor(GetConVar("pik_disband"):GetInt()), 0, 1)
end

for i=1,PikTypes do
	CreateConVar("pik_damage"..i,tostring(PikDamage[i]),{FCVAR_REPLICATED, FCVAR_ARCHIVE},PikDefaultTypeNames[i].." Damage")
	CreateConVar("pik_health"..i,tostring(PikHealth[i]),{FCVAR_REPLICATED, FCVAR_ARCHIVE},PikDefaultTypeNames[i].." Health")
	CreateConVar("pik_speed"..i,tostring(PikSpeed[i]),{FCVAR_REPLICATED, FCVAR_ARCHIVE},PikDefaultTypeNames[i].." Base Speed")
	if SERVER then
		cvars.AddChangeCallback("pik_damage"..i, function(name,ov,nv)
			nv = math.Clamp(math.floor(tonumber(nv) or 0),0,40)
			PikDamage[i] = nv
			for _,v in ipairs(ents.FindByClass("pikmin")) do
				if v.Color ~= i then continue end
				v.Damage = nv/PikDamageDivider
			end
		end)
		cvars.AddChangeCallback("pik_health"..i, function(name,ov,nv)
			ov = math.Clamp(math.floor(tonumber(ov) or 0),1,100)
			nv = math.Clamp(math.floor(tonumber(nv) or 0),1,100)
			PikHealth[i] = nv
			for _,v in ipairs(ents.FindByClass("pikmin")) do
				if v.Color ~= i then continue end
				if v.PikHP >= ov then v.PikHP = nv end
			end
		end)
		cvars.AddChangeCallback("pik_speed"..i, function(name,ov,nv)
			nv = math.Clamp(math.floor(tonumber(nv) or 0),50,3000)
			PikSpeed[i] = nv
			for _,v in ipairs(ents.FindByClass("pikmin")) do
				if v.Color ~= i then continue end
				v.BaseMoveForce = nv
				v.MoveForce = v.BaseMoveForce + v.Level*(v.Color == 5 and 320 or (v.Color == 4 or v.Color == 8) and 150 or 250)
			end
		end)
	end
end

--//Hooks
local NoPickupList = {
"pikmin_fire",
"pikmin_gas",
"pikmin_wire",
"pikmin_model",
"pikmin_sprout",
"pikmin_bud"
}

hook.Add("PhysgunPickup","PikiPhys",function(ply,ent)
	if ent.PikIgnore or table.KeyFromValue(NoPickupList,ent:GetClass()) then return false end
	return GAMEMODE:PhysgunPickup(ply,ent)
end)

--//Playermodels
player_manager.AddValidModel("Olimar","models/player/orima.mdl")
player_manager.AddValidModel("Louie","models/player/louie.mdl")
player_manager.AddValidModel("The President","models/player/chacho.mdl")

--//Duplicator
duplicator.Allow("pikmin")
duplicator.Allow("pikmin_onion")
duplicator.Allow("pikmin_bud")
duplicator.RegisterEntityClass("pikmin_model", function(ply,data) return end, "Data")
duplicator.RegisterEntityClass("pikmin_logic", function(ply,data) return end, "Data")
duplicator.RegisterEntityClass("pikmin_player", function(ply,data) return end, "Data")
duplicator.RegisterEntityClass("pikmin_bud", function(ply,data)
	data.CurAnim = 1
	data.LastAnim = nil
	data.SpitNext = nil
	local ent = ents.Create("pikmin_bud")
	duplicator.DoGeneric(ent,data)
	if data.CurPiki ~= 0 then
		ent.SpitNext = CurTime()+2 ent.CurPiki = data.CurPiki
	end
	if data.EntityMods and data.EntityMods.PikInfo then
		ent.Cycle = data.EntityMods.PikInfo.Cycle
	end
	ent:Spawn()
	ent:Activate()
	return ent
end, "Data")
duplicator.RegisterEntityClass("pikmin_nectar", function(ply,data)
	data.Debounce = false
	return duplicator.GenericDuplicatorFunction(ply,data)
end, "Data")
duplicator.RegisterEntityClass("pikmin_sprout", function(ply,data)
	local ent = ents.Create("pikmin_sprout")
	duplicator.DoGeneric(ent,data)
	ent.Planted = true
	ent.SaveOnly = true
	ent:Spawn()
	ent:Activate()
	return ent
end, "Data")