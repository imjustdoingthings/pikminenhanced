AddCSLuaFile("autorun/sh_pikmin.lua")
AddCSLuaFile("autorun/client/cl_pikmin.lua")
AddCSLuaFile("pikmin_sandbox_cl.lua")
include("autorun/sh_pikmin.lua")

PFVEC = Vector(1,0,0)
PRVEC = Vector(0,-1,0)

PIKIONIONDATA = {}
PIKIONIONDATASTRINGS = {}

util.AddNetworkString("PikiMasterOnionGo")

function ReadPikiOnionData(id)
	if file.Exists("onion"..id..".txt","DATA") then
	local dat = file.Read("onion"..id..".txt","DATA")
	PIKIONIONDATASTRINGS[id] = dat
	if #dat ~= 0 then
		local ntab = {}
		for _,val in ipairs(string.Split(dat," ")) do table.insert(ntab,tonumber(val)) end
		PIKIONIONDATA[id] = ntab
	else
		PIKIONIONDATA[id] = {}
	end
	end
end

function SetPikiOnionData(id,t)
	if #t == 0 then
		if (PIKIONIONDATA[id] and #PIKIONIONDATA[id] ~= 0) or not PIKIONIONDATA[id] then
			PIKIONIONDATASTRINGS[id] = ""
			PIKIONIONDATA[id] = {}
			file.Write("onion"..id..".txt","")
		end
		return
	end
	local dat = ""
	for k,v in ipairs(t) do
		dat = dat .. v .. " "
	end
	dat = string.sub(dat,1,#dat-1)
	if PIKIONIONDATASTRINGS[id] ~= dat then
		file.Write("onion"..id..".txt",dat)
	end
	PIKIONIONDATASTRINGS[id] = dat
	PIKIONIONDATA[id] = t
end

for i=0, 8 do
	ReadPikiOnionData(i)
end

--//Precaching
for k,v in ipairs(file.Find("sound/pikmin/*","GAME")) do
	resource.AddFile("sound/pikmin/" .. v)
	util.PrecacheSound(v)
end

for k,v in ipairs(file.Find("models/pikmin/*","GAME")) do
	resource.AddFile("models/pikmin/" .. v)
	util.PrecacheModel("models/pikmin/" .. v)
end

for k,v in ipairs(file.Find("models/weapons/v_olimar.*","GAME")) do
	resource.AddFile("models/weapons/" .. v)
	util.PrecacheModel("weapons/" .. v)
end
for k,v in ipairs(file.Find("models/weapons/w_olimar.*","GAME")) do
	resource.AddFile("models/weapons/" .. v)
	util.PrecacheModel("weapons/" .. v)
end

for k,v in ipairs(file.Find("materials/models/pikmin/*","GAME")) do
	resource.AddFile("materials/models/pikmin/" .. v)
end

for k,v in ipairs(file.Find("materials/pikmin/*","GAME")) do
	resource.AddFile("materials/pikmin/" .. v)
end

resource.AddFile("materials/VGUI/entities/pikmin.vtf")
resource.AddFile("materials/VGUI/entities/pikmin.vmt")

resource.AddFile("materials/weapons/pikmincommand.vtf")
resource.AddFile("materials/weapons/pikmincommand.vmt")

--//Functions
function PikminCreateServer(ply,args)
	if #ents.FindByClass("pikmin")+#ents.FindByClass("pikmin_sprout") > PikiMaxField then return false end
	local color,level = args.color or 1,args.level or 0
	local ent = ents.Create("pikmin")
	ent.Olimar = ply
	if not ply then ent.Dismissed = true end
	ent.Color = color
	ent.Level = level
	ent:SetModel(ColorCollideTable[ent.Color])
	ent:SetPos(args.pos or ply:GetPos() + ply:GetForward() * -32 + ply:GetRight() * math.Rand(-50, 50) + vector_up*(color == 7 and 75 or 30))
	if color == 7 and ply then ent:SetAngles(Angle(25, ply:EyeAngles().y, 0)) end
	ent:SetMoveCollide(MOVECOLLIDE_FLY_SLIDE)
	ent:Spawn()
	ent:Activate()
	return ent
end

function PikminCreateSproutServer(onion,pos,color)
	if #ents.FindByClass("pikmin")+#ents.FindByClass("pikmin_sprout") >= PikiMaxField then return false end
	local ent = ents.Create("pikmin_sprout")
	ent.Color = color or onion.Color or 1
	ent:SetPos(pos)
	local angle = (ent:GetPos()-onion:GetPos()):Angle()
	ent:SetAngles(Angle(0,angle.Y,0))
	ent:Spawn()
	ent:Activate()
	return true
end

local PluckSoundClassic = "pikmin/pikmin_pluck.wav"
local function GetPluckSound()
	if cvars.Bool("pik_classicpluck") then return PluckSoundClassic end
	return PikiSoundPluck[math.random(1, #PikiSoundPluck)]
end
function PikminCreate(ply,cmd,args)
	if cvars.Bool("pik_admin") and IsValid(ply) and not ply:IsAdmin() then
		ply:ChatPrint("Pikmin spawning is restricted to admins!")
		return
	end
	if not args[1] then return end
	local qty = tonumber(args[3]) or 1
	
	ply.PikminSpawnCooldown = ply.PikminSpawnCooldown or 0
	if CurTime() < ply.PikminSpawnCooldown then return end
	ply.PikminSpawnCooldown = CurTime() + (qty * 0.005)
	
	if qty > 1 then undo.Create("Pikmin ("..qty..")") end
	
	local currentPikminCount = #ents.FindByClass("pikmin") + #ents.FindByClass("pikmin_sprout")
	local tr = util.QuickTrace(ply:GetShootPos(), ply:GetAimVector() * 400, ply)
	local spawnBase = tr.Hit and tr.HitPos or (ply:GetShootPos() + ply:GetAimVector() * 200)
	
	local firstEnt = nil
	for i = 1, qty do
		if currentPikminCount >= PikiMaxField then break end
		currentPikminCount = currentPikminCount + 1
		
		local color = 1
		if args[1] == "red" then color = 1
		elseif args[1] == "yellow" then color = 2
		elseif args[1] == "blue" then color = 3
		elseif args[1] == "purple" then color = 4
		elseif args[1] == "white" then color = 5
		elseif args[1] == "bulbmin" then color = 6
		elseif args[1] == "pink" then color = 7
		elseif args[1] == "rock" then color = 8
		elseif args[1] == "mushroom" then color = 9
		elseif args[1] == "random" then local c = {1,2,3,4,5,7,8} color = c[math.random(1,#c)]
		end
		
		local ent = ents.Create("pikmin")
		if args[2] == "bud" then
			ent.Level = 1
		elseif args[2] == "flower" then
			ent.Level = 2
		end
		
		ent.Olimar = ply
		ent.Color = color
		local angle = i * 2.39996
		local radius = math.sqrt(i) * 25
		local offset = Vector(math.cos(angle) * radius, math.sin(angle) * radius, 0)
		ent:SetPos(spawnBase + offset + vector_up*(color == 7 and math.Rand(60, 90) or math.Rand(20, 60)))
		if color == 7 then ent:SetAngles(Angle(25, ply:EyeAngles().y, 0)) end
		ent:Spawn()
		ent:Activate()
		
		if not firstEnt then firstEnt = ent end
		
		if qty == 1 then
			undo.Create("#pikminf"..ent.Color)
		end
		undo.AddEntity(ent)
	end
	
	if IsValid(firstEnt) then
		firstEnt:EmitSound(args[1] == "mushroom" and "pikmin/infected.wav" or GetPluckSound())
	end
	
	if qty >= 1 then
		undo.SetPlayer(ply)
		undo.Finish()
	end
end

function PikminCreateSprout(ply,cmd,args)
	local tr = util.QuickTrace(ply:GetShootPos(), ply:GetAimVector() * 10000, ents.GetAll())
	if not (tr.Hit and tr.HitPos) then return end
	if not args[1] then return end
	
	local qty = tonumber(args[3]) or 1
	
	ply.PikminSpawnCooldown = ply.PikminSpawnCooldown or 0
	if CurTime() < ply.PikminSpawnCooldown then return end
	ply.PikminSpawnCooldown = CurTime() + (qty * 0.005)
	
	if qty > 1 then undo.Create("Pikmin Sprout ("..qty..")") end
	
	local currentPikminCount = #ents.FindByClass("pikmin") + #ents.FindByClass("pikmin_sprout")
	
	for i = 1, qty do
		if currentPikminCount >= PikiMaxField then break end
		currentPikminCount = currentPikminCount + 1
		
		local color = 1
		if args[1] == "red" then color = 1
		elseif args[1] == "yellow" then color = 2
		elseif args[1] == "blue" then color = 3
		elseif args[1] == "purple" then color = 4
		elseif args[1] == "white" then color = 5
		elseif args[1] == "bulbmin" then color = 6
		elseif args[1] == "pink" then color = 7
		elseif args[1] == "rock" then color = 8
		elseif args[1] == "mushroom" then color = 9
		elseif args[1] == "random" then local c = {1,2,3,4,5,7,8} color = c[math.random(1,#c)]
		end
		
		local ent = ents.Create("pikmin_sprout")
		ent.Color = color
		ent.Planted = true
		-- Scatter sprouts using a golden spiral pattern to prevent collision overlapping
		local angle = i * 2.39996
		local radius = math.sqrt(i) * 20
		local offset = Vector(math.cos(angle) * radius, math.sin(angle) * radius, 0)
		if qty == 1 then offset = Vector(0,0,0) end
		ent:SetPos(tr.HitPos + tr.HitNormal*-12 + offset)
		local angleYaw = (ent:GetPos()-ply:GetPos()):Angle()
		ent:SetAngles(Angle(0,angleYaw.Y,0))
		ent:Spawn()
		ent:Activate()
		
		if qty == 1 then
			undo.Create("#pikminf"..ent.Color)
		end
		undo.AddEntity(ent)
	end
	
	if qty >= 1 then
		undo.SetPlayer(ply)
		undo.Finish()
	end
end

function PikminPlayerFunc(ply,cmd,args)
	if #ents.FindByClass("pikmin")+#ents.FindByClass("pikmin_sprout") >= PikiMaxField then return end
	if not args[1] then return end
	local color = 1
	if args[1] == "red" then color = 1
	elseif args[1] == "yellow" then color = 2
	elseif args[1] == "blue" then color = 3
	elseif args[1] == "purple" then color = 4
	elseif args[1] == "white" then color = 5
	elseif args[1] == "bulbmin" then color = 6
	elseif args[1] == "pink" then color = 7
	elseif args[1] == "rock" then color = 8
	elseif args[1] == "mushroom" then color = 9
	elseif args[1] == "random" then local c = {1,2,3,4,5,7,8} color = c[math.random(1,#c)]
	end
	
	local ent = ents.Create("pikmin_player")
	if args[2] == "bud" then
		ent.Level = 1
	elseif args[2] == "flower" then
		ent.Level = 2
	end
	
	ent.Olimar = ply
	ent.Color = color
	ent:EmitSound(color == 9 and "pikmin/infected.wav" or GetPluckSound())
	ent:Spawn()
	ent:Activate()
end

function PikminCreateOnion(ply,cmd,args)
	local tr = util.QuickTrace(ply:GetShootPos(), ply:GetAimVector() * 10000, ply)
	if not (tr.Hit and tr.HitPos) then return end
	if not args[1] then return end
	
	local type = #args > 1 and tonumber(args[1]) or 0
	local index = #args > 1 and tonumber(args[2]) or tonumber(args[1]) or 0
	
	local entClass = "pikmin_onion"
	if type == 1 then entClass = "pikmin_onion_p3"
	elseif type == 2 then entClass = "pikmin_onion_master" end
	
	local ent = ents.Create(entClass)
	if type == 1 then
		ent:SetModel("models/pikmin/onion_new.mdl")
		ent:SetSkin(math.Clamp(index,0,4))
	elseif type == 2 then
		ent:SetModel("models/pikmin/onion_large.mdl")
	else
		ent.Skin = math.Clamp(index,0,2)
	end
	
	local offset = type == 2 and 180 or type == 1 and 140 or 30
	ent:SetPos(tr.HitPos + tr.HitNormal * offset)
	local angle = (ply:GetPos()-ent:GetPos()):Angle()
	ent:SetAngles(Angle(0,angle.Y,0))
	ent:Spawn()
	ent:Activate()
	undo.Create(type == 2 and "#pikmin_onion_master" or type == 1 and "#pikmin_onion_p3" or "#pikmin_onion"..index)

	undo.AddEntity(ent)
	undo.SetPlayer(ply)
	undo.Finish()
end

function PikminCreateBud(ply,cmd,args)
	local tr = util.QuickTrace(ply:GetShootPos(), ply:GetAimVector() * 10000, ents.GetAll())
	if not (tr.Hit and tr.HitPos) then return end
	local ent = ents.Create("pikmin_bud")
	ent.Color = tonumber(args[1]) or 1
	ent:SetPos(tr.HitPos)
	ent:Spawn()
	ent:Activate()
	undo.Create("#pikmin_bud")
		undo.AddEntity(ent)
		undo.SetPlayer(ply)
	undo.Finish()
end

local function PikminCallFunc(ply,cmd,args)
	local tr = util.QuickTrace(ply:GetShootPos(), (ply:GetAimVector() * 500), ply)
	if IsValid(tr.Entity) and (tr.Entity:GetClass() == "pikmin_onion" or tr.Entity:GetClass() == "pikmin_onion_p3" or tr.Entity:GetClass() == "pikmin_onion_master") then
		tr.Entity:Call(ply,tonumber(args[1]) or 0,tonumber(args[2]) or 0,tonumber(args[3]))
	end
end

local function PikiWeaponSkinFunc(ply,cmd,args)
	if not args[1] then return end
	local num = tonumber(args[1])
	if not num then return end
	if SERVER then
		ply:SetNWInt("pikiskin",num)
		local wep = ply:GetWeapon("olimar_gun")
		if IsValid(wep) and wep.LastSkin ~= num then
			wep.LastSkin = num
			wep:SetSkin(num)
			wep:UpdateWhistle(num)
		end
	end
end

net.Receive("PikiMasterOnionGo", function(len, ply)
	local onion = net.ReadEntity()
	if not IsValid(onion) or onion:GetClass() ~= "pikmin_onion_master" then return end
	if onion:GetPos():DistToSqr(ply:GetPos()) > 1000000 then return end -- Anti-cheat distance check
	
	local count = net.ReadInt(8)
	for i = 1, count do
		local color = net.ReadInt(8)
		local callVal = net.ReadInt(32)
		local sendVal = net.ReadInt(32)
		onion:Call(ply, callVal, sendVal, color)
	end
end)

local ConfigLUT = {"pikidis","piknd","pikipluck","pikfire","pikzap"}
local function PikiPluckSwitchFunc(ply,cmd,args)
	if not args[1] or not args[2] then return end
	local num = tonumber(args[1])
	if not num then return end
	ply:SetNWBool(ConfigLUT[num],args[2] == "1" and true or false)
end

--Reset all onion data
local function PikiOnionReset(ply,cmd,args)
	SetPikiOnionData(0,{})
	SetPikiOnionData(1,{})
	SetPikiOnionData(2,{})
	for _,v in ipairs(ents.FindByClass("pikmin_onion")) do
		v.PikiList = PIKIONIONDATA[v.Skin] and table.Copy(PIKIONIONDATA[v.Skin])
	end
end

--//Commands
concommand.Add("pikmin_create",PikminCreate)
concommand.Add("pikmin_creates",PikminCreateSprout)
concommand.Add("pikmin_createo",PikminCreateOnion)
concommand.Add("pikmin_createb",PikminCreateBud)
concommand.Add("pikmin_createp",PikminPlayerFunc)
concommand.Add("pikmin_call",PikminCallFunc)
concommand.Add("pikmin_skinw",PikiWeaponSkinFunc)
concommand.Add("pikmin_config",PikiPluckSwitchFunc)
concommand.Add("pikmin_oreset",PikiOnionReset)

--Hack to fix duplicator/save stack overflow
--(https://github.com/Facepunch/garrysmod/blob/master/garrysmod/lua/includes/modules/duplicator.lua)
duplicator.GetAllConstrainedEntitiesAndConstraints = function(ent,EntTable,ConstraintTable)
	if ( !IsValid( ent ) && !ent:IsWorld() ) then return end
	
	-- Translate the class name
	local classname = ent:GetClass()
	if classname == "pikmin" then EntTable[ent:EntIndex()] = ent return end
	if ( ent.ClassOverride ) then classname = ent.ClassOverride end

	-- Is the entity in the dupe whitelist?
	if ( !duplicator.IsAllowed( classname ) && !ent:IsWorld() ) then
		-- MsgN( "duplicator: ", classname, " isn't allowed to be duplicated!" )
		return
	end

	-- Entity doesn't want to be duplicated.
	if ( ent.DoNotDuplicate ) then return end

	if ( !ent:IsWorld() ) then EntTable[ ent:EntIndex() ] = ent end

	if ( !constraint.HasConstraints( ent ) ) then return end

	local ConTable = constraint.GetTable( ent )

	for key, constr in pairs( ConTable ) do

		local index = constr.Constraint:GetCreationID()

		if ( !ConstraintTable[ index ] ) then

			-- Add constraint to the constraints table
			ConstraintTable[ index ] = constr

			-- Run the Function for any ents attached to this constraint
			for _, ConstrainedEnt in pairs( constr.Entity ) do

				if ( !ConstrainedEnt.Entity:IsWorld() ) then

					duplicator.GetAllConstrainedEntitiesAndConstraints( ConstrainedEnt.Entity, EntTable, ConstraintTable )

				end

			end

		end
	end

	return EntTable, ConstraintTable
end

--//Hooks
hook.Add("PreGamemodeLoaded","PikiGMPreLoad",function()
	if GAMEMODE.FolderName == "sandbox" then include("pikmin_sandbox_sv.lua") end
end)

hook.Add("EntityKeyValue","PikiKeyValue",function(ent,key,value)
	if ent:GetClass() == "func_breakable" then
		if key == "material" then ent.Breakable = value == "1" end
	end
end)

hook.Add("EntityRemoved","PikminVanishFix",function(obj)
	if obj.CarrySound then obj.CarrySound:Stop() end
	for _,v in ipairs(obj:GetChildren()) do
		if v:GetClass() == "pikmin" then
			v.Attacking = false
			v.AttackTarget = nil
			local quickpos = v:GetPos() + Vector(0, 0, 8)
			v:SetParent()
			v:SetPos(quickpos)
		end
	end
end)

hook.Add("PostCleanupMap","PikiClean",function()
	if PikiAuto == 1 and #ents.FindByClass("pikmin_logic") == 0 then
		ents.Create("pikmin_logic"):Spawn()
	end
end)

hook.Add("PlayerDeath","PikiClientDeath",function(ply)
	local cval = table.KeyFromValue(OrimaModel,ply:GetModel())
	local pk = ply:GetNWBool("ispikmin",false)
	if pk or cval then ply:GetRagdollEntity():Remove() end
	if cval and not pk then
		local mdl = ply:GetModel()
		local rag = ents.Create("prop_ragdoll")
		rag:SetCollisionGroup(COLLISION_GROUP_WORLD)
		rag:SetModel(string.sub(mdl,1,#mdl-4).."_r.mdl")
		rag:SetBodygroup(1,ply:GetBodygroup(1))
		rag:SetPos(ply:GetPos()+Vector(0,0,10))
		rag:SetAngles(ply:GetAngles())
		rag:Spawn()
		for i = 1, rag:GetPhysicsObjectCount() do
			local bone = rag:GetPhysicsObjectNum(i)
			if IsValid(bone) then
				bone:ApplyForceOffset(ply:GetVelocity(), ply:GetPos())
				bone:AddVelocity(ply:GetVelocity())
			end
		end
		rag:Activate()
		ply.PikRag = rag
		ply:Spectate(OBS_MODE_CHASE)
		ply:SpectateEntity(rag)
		net.Start("RagColorPly")
		net.WriteEntity(ply)
		net.WriteInt(rag:EntIndex(),32)
		net.Broadcast()
	end
	ply:ConCommand("pikmin_menu 0")
end)

hook.Add("PlayerSpawn","PikiPlayerSpawn",function(ply)
	if IsValid(ply.PikRag) then ply.PikRag:Remove() ply.PikRag = nil end
end)

hook.Add("PlayerDisconnected", "PikiPlayerLeave", function(ply)
	if IsValid(ply.PikRag) then ply.PikRag:Remove() ply.PikRag = nil end
end)

hook.Add("EntityTakeDamage","PikiDamage",function(ent,dmg)
	if ent:IsPlayer() and ent:GetNWBool("ispikmin") then return true end
	local inflict = dmg:GetInflictor()
	local IsPoison = dmg:IsDamageType(DMG_POISON) and IsValid(inflict) and (inflict:GetClass() == "pikmin_gas" or inflict:GetClass() == "pikmin")
	local IsFire = dmg:IsDamageType(DMG_BURN)
	local IsZap = dmg:IsDamageType(DMG_SHOCK)
	if (IsFire or IsPoison or IsZap) and ent:IsPlayer() and IsValid(ent:GetActiveWeapon()) and ent:GetActiveWeapon():GetClass() == "olimar_gun" then
		if IsPoison then return true end
		if IsFire and ent:GetNWBool("pikfire",false) then return true end
		if IsZap and ent:GetNWBool("pikzap",false) then return true end
	end
	if ent:IsPlayer() and ent:Alive() and IsPoison then
		if math.random(1,2) == 1 then ent:EmitSound("ambient/voices/cough" .. math.random(1,4) .. ".wav") end
	end
end)

hook.Add("InitPostEntity","InitPiki",function()
	if PikiAuto == 1 then ents.Create("pikmin_logic"):Spawn() end
end)

--//Old Hooks
local function DontToolMe(ply, tr, tool)
	if tool ~= "duplicator" then return true end
	if IsValid(tr.Entity) and (tr.Entity:GetClass() == "pikmin_onion" or tr.Entity:GetClass() == "pikmin" or tr.Entity:GetClass() == "pikmin_model" or tr.Entity:GetClass() == "pikmin_fire") then
		return false
	end
	return true
end
hook.Add("CanTool", "DontDupeOnions", DontToolMe)

local function DontPickMeUp(ply, ent)
	if IsValid(ent) and ent:GetClass() == "pikmin_onion" then
		return false
	end
	return true
end
hook.Add("GravGunPickupAllowed", "DontPickupOnions", DontPickMeUp)

local function PikGravPunt(ply, ent)
	if (ent:GetClass() == "pikmin") then
		ply:EmitSound("pikmin/pikmin_throw.wav")
		ent.Thrown = true
	end
end
hook.Add("GravGunPunt", "ThrowAnimOnPunt", PikGravPunt)

local function PikDontHitPlayer(ply,ent) --Pikmin are charging me! :(
	if IsValid(ent) and ent:GetClass() == "pikmin" then return false end
	return GAMEMODE:PlayerShouldTakeDamage(ply,ent)
end
hook.Add("PlayerShouldTakeDamage", "OMGPIKMINDONTHURTMEH", PikDontHitPlayer)

-- find all Pikmin currently attached to an entity
local function GetLatchedPikmin(ent)
	local latched = {}
	for _, v in ipairs(ents.FindByClass("pikmin")) do
		if v.Attacking and v:GetParent() == ent then
			table.insert(latched, v)
		end
	end
	return latched
end

local ShakeOffSounds = { "pikmin/shakeoff1.wav", "pikmin/shakeoff2.wav" }

-- left-click repeatedly to shake off latched Pikmin
hook.Add("KeyPress", "PikminPlayerShakeOff", function(ply, key)
	if not cvars.Bool("pik_shakeoff") then return end
	if key ~= IN_ATTACK then return end
	if (ply.NextShakeOff or 0) > CurTime() then return end
	local latched = GetLatchedPikmin(ply)
	if #latched == 0 then return end
	ply.NextShakeOff = CurTime() + 0.55
	for _, pik in ipairs(latched) do
		pik:ShakeOff()
	end
	ply:EmitSound(ShakeOffSounds[math.random(#ShakeOffSounds)], 80, 100)
end)

-- 35% chance per damage event to shake off one random latched Pikmin
hook.Add("EntityTakeDamage", "PikminNPCShakeOff", function(ent, dmgInfo)
	if not cvars.Bool("pik_shakeoff") then return end
	if not ent:IsNPC() then return end
	
	local latched = GetLatchedPikmin(ent)
	if #latched == 0 then return end
	
	-- 3% chance to shake off ALL latched Pikmin at once (big body shake)
	if math.random() <= 0.03 then
		for _, victim in ipairs(latched) do
			if IsValid(victim) then
				victim:ShakeOff()
			end
		end
		ent:EmitSound(ShakeOffSounds[math.random(#ShakeOffSounds)], 85, 95)
		return
	end
	
	-- Standard 12% chance to shake off ONE random latched Pikmin
	if math.random() <= 0.12 then
		local victim = latched[math.random(#latched)]
		victim:ShakeOff()
		ent:EmitSound(ShakeOffSounds[math.random(#ShakeOffSounds)], 80, 100)
	end
end)

-- NPCs treat Pikmin as higher-priority enemies than players
hook.Add("OnEntityCreated", "PikminNPCTargetPriority", function(ent)
	if not cvars.Bool("pik_npc_target_pikmin") then return end
	timer.Simple(0.2, function() -- 0.2s delay (hopefully) ensures entity is fully initialized before altering relationships
		if not IsValid(ent) then return end
		if ent:IsNPC() then
			-- NPCs give Pikmin a high priority of 99
			ent:AddRelationship("pikmin D_HT 99")
			ent.PikminRelationshipSet = true
		elseif ent:GetClass() == "pikmin" then
			for _, npc in ipairs(ents.GetAll()) do
				if IsValid(npc) and npc:IsNPC() then
					npc:AddRelationship("pikmin D_HT 99")
					npc.PikminRelationshipSet = true
				end
			end
		end
	end)
end)

-- Force-update NPC target schedules
timer.Create("PikminNPCTargetForceUpdate", 0.25, 0, function()
	if not cvars.Bool("pik_npc_target_pikmin") then return end
	
	local piks = ents.FindByClass("pikmin")
	if #piks == 0 then return end
	
	for _, npc in ipairs(ents.GetAll()) do
		if IsValid(npc) and npc:IsNPC() and npc:Health() > 0 then
			-- check if the NPC is targeting the player/Olimar or is hostile to them
			local isHostile = false
			for _, ply in ipairs(player.GetAll()) do
				if IsValid(ply) and (npc:Disposition(ply) == D_HT or npc:Disposition(ply) == D_FR) then
					isHostile = true
					break
				end
			end
			
			if isHostile then
				-- Apply class relationship if not set yet
				if not npc.PikminRelationshipSet then
					npc:AddRelationship("pikmin D_HT 99")
					npc.PikminRelationshipSet = true
				end

				local closestPik = nil
				local minDist = 1000 -- max detection distance
				local npcPos = npc:GetPos()
				
				for _, pik in ipairs(piks) do
					if IsValid(pik) and not pik.Dead then
						local dist = npcPos:Distance(pik:GetPos())
						if dist < minDist then
							minDist = dist
							closestPik = pik
						end
					end
				end
				
				if closestPik then
					local currentEnemy = npc:GetEnemy()
					if currentEnemy ~= closestPik then
						-- re-prioritize Pikmin
						if not IsValid(currentEnemy) or currentEnemy:IsPlayer() or (currentEnemy:GetClass() == "pikmin" and minDist < npcPos:Distance(currentEnemy:GetPos()) - 50) then
							npc:SetEnemy(closestPik)
							npc:UpdateEnemyMemory(closestPik, closestPik:GetPos())
						end
					end
				end
			end
		end
	end
end)

--// carry property persistence
duplicator.RegisterEntityModifier("PikminCarry", function(ply, ent, data)
	if not IsValid(ent) then return end
	if data.iscarry then
		ent.DidWeight = true
		ent.IsCarry = true
		ent:SetNWBool("iscarry", true)
		ent:SetNWInt("pikiweight", data.pikiweight)
		ent:SetNWInt("pikimax", data.pikimax)
		timer.Simple(0.1, function()
			if IsValid(ent) and IsValid(ent:GetPhysicsObject()) then
				ent:GetPhysicsObject():SetMass(data.pikiweight * 50)
			end
		end)
	end
end)

--// auto-carry hook
hook.Add("OnEntityCreated", "PikminAutoCarryAll", function(ent)
	timer.Simple(0, function()
		if not IsValid(ent) or ent:GetClass() ~= "prop_physics" then return end
		if not cvars.Bool("pik_carry_all") then return end
		
		-- skip overwrites on entities with custom values
		if ent.IsCarry then return end
		
		local phys = ent:GetPhysicsObject()
		if not IsValid(phys) then return end
		
		if not ent.LastMass then ent.LastMass = phys:GetMass() end
		local autovalue = math.max(1, math.floor(phys:GetMass() / 50))
		local autovalue2 = autovalue * 2
		local dictInfo = PikiCarryDict[ent:GetModel()]
		if dictInfo then autovalue, autovalue2 = dictInfo[1], dictInfo[2] end
		
		ent.DidWeight = true
		phys:SetMass(autovalue * 50)
		ent:SetNWInt("pikiweight", autovalue)
		ent:SetNWInt("pikimax", autovalue2)
		ent:SetNWBool("iscarry", true)
		ent.IsCarry = true
		ent.PikMove = ent:GetNWInt("weight") >= autovalue
		
		-- store modifier so the auto-carry values persist on save/dupe
		duplicator.StoreEntityModifier(ent, "PikminCarry", {
			iscarry = true,
			pikiweight = autovalue,
			pikimax = autovalue2
		})
	end)
end)

--// NPC carry system
local function SolidifyAndPrepareRagdoll(maxHp, ragdoll)
	if not IsValid(ragdoll) or ragdoll.PikminCarcassPrepared then return end
	ragdoll.PikminCarcassPrepared = true
	
	-- enable collisions with players, props, and physics
	ragdoll:SetCollisionGroup(COLLISION_GROUP_NONE)
	
	-- weld all physics objects of the ragdoll to the root physics object (index 0)
	-- this solidifies the ragdoll so it moves as a single solid body without floppy limbs, just like make statue does in the C menu
	local physCount = ragdoll:GetPhysicsObjectCount()
	if physCount > 1 then
		for i = 1, physCount - 1 do
			local physBone = ragdoll:GetPhysicsObjectNum(i)
			if IsValid(physBone) then
				constraint.Weld(ragdoll, ragdoll, 0, i, 0, true, false)
			end
		end
	end
	
	-- calculate carry weight and sprouts based on NPC health
	local weight = math.max(1, math.floor(maxHp / 15))
	local maxCarriers = weight * 2
	local sprouts = math.max(1, math.floor(maxHp / 15))
	
	-- wake up all physics bones, enable motion, and clear pickup restrictions
	for i = 0, physCount - 1 do
		local physBone = ragdoll:GetPhysicsObjectNum(i)
		if IsValid(physBone) then
			physBone:Wake()
			physBone:EnableMotion(true)
			physBone:ClearGameFlag(FVPHYSICS_NO_PLAYER_PICKUP) -- Allow player physgun/gravity gun pickup!
			
			if i == 0 then
				physBone:SetMass(weight * 50)
			end
		end
	end
	
	-- recalculates due to new collision rules
	ragdoll:CollisionRulesChanged()
	
	-- set network variables so our HUD and movement loops recognize it
	ragdoll.DidWeight = true
	ragdoll.PikiSproutsCount = sprouts
	ragdoll:SetNWInt("pikiweight", weight)
	ragdoll:SetNWInt("pikimax", maxCarriers)
	ragdoll:SetNWBool("iscarry", true)
	ragdoll.IsCarry = true
	
	-- Also store in duplicator so it persists!
	duplicator.StoreEntityModifier(ragdoll, "PikminCarry", {
		iscarry = true,
		pikiweight = weight,
		pikimax = maxCarriers
	})
end

hook.Add("OnNPCKilled", "PikminPropifyKilled", function(npc, attacker, inflictor)
	local byPikmin = false
	if IsValid(attacker) and attacker:GetClass() == "pikmin" then byPikmin = true end
	if IsValid(inflictor) and inflictor:GetClass() == "pikmin" then byPikmin = true end
	
	if byPikmin then
		npc.PikminKilledBy = true
		local model = npc:GetModel()
		local pos = npc:GetPos()
		local ang = npc:GetAngles()
		local skin = npc:GetSkin()
		local maxHp = npc:GetMaxHealth()
		
		-- spawn our own server-side ragdoll carcass immediately!
		local rag = ents.Create("prop_ragdoll")
		if IsValid(rag) then
			rag:SetModel(model)
			rag:SetPos(pos + Vector(0, 0, 8)) -- slightly lift to prevent getting stuck in ground
			rag:SetAngles(ang)
			rag:SetSkin(skin)
			
			-- Copy bodygroups
			for i = 0, npc:GetNumBodyGroups() - 1 do
				rag:SetBodygroup(i, npc:GetBodygroup(i))
			end
			
			rag:Spawn()
			
			-- Solidify and configure carry parameters
			SolidifyAndPrepareRagdoll(maxHp, rag)
		end
		
		-- remove the NPC immediately to prevent any default client/server ragdoll from spawning
		npc:Remove()
	end
end)

hook.Add("CreateEntityRagdoll", "PikminReplaceRagdoll", function(owner, ragdoll)
	if IsValid(owner) and owner.PikminKilledBy then
		if IsValid(ragdoll) then
			timer.Simple(0, function()
				if IsValid(ragdoll) then
					ragdoll:Remove()
				end
			end)
		end
	end
end)