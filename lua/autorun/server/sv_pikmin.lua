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