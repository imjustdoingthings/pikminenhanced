if (SERVER) then
	AddCSLuaFile("shared.lua")
	SWEP.Weight				= 5
	SWEP.AutoSwitchTo		= false
	SWEP.AutoSwitchFrom		= false
end

if (CLIENT) then
	SWEP.PrintName			= "#olimar_gun"
	SWEP.Slot				= 1
	SWEP.SlotPos			= 1
	SWEP.DrawAmmo			= false
	SWEP.DrawCrosshair		= true
	SWEP.WepSelectIcon = surface.GetTextureID("weapons/pikmincommand")
end

SWEP.SelRadius = 0
SWEP.LastSkin = 0

function SWEP:Initialize()
	self:UpdateWhistle(0)
	self:UpdateHoldType("melee")
end

function SWEP:UpdateHoldType(ht)
	if self.HoldType ~= ht then
		self.HoldType = ht
		self:SetHoldType(ht)
	end
end

function SWEP:UpdateWhistle(skin)
	if self.WhistleSound then self.WhistleSound:Stop() end
	if self.SwarmSound then self.SwarmSound:Stop() end
	self.WhistleSound = CreateSound(self, skin == 2 and "pikmin/whistle2.wav" or skin == 3 and "pikmin/whistle3.wav" or "pikmin/whistle.wav")
	self.SwarmSound = CreateSound(self, skin == 2 and "pikmin/swarm2.wav" or skin == 3 and "pikmin/swarm3.wav" or "pikmin/swarm1.wav")
	if self.Swarm then self.SwarmSound:Play() end
end

function SWEP:PreDrawViewModel(view,wep,ply)
	view:SetSkin(self:GetSkin())
	if not view.GetPlayerColor then view.GetPlayerColor = function() return ply:GetPlayerColor() end end
end

function SWEP:DrawWorldModel(flags)
	if self.Owner:GetNWBool("piknd",false) or table.KeyFromValue(OrimaModel,self.Owner:GetModel()) then self:DrawShadow(false) return end
	if not self.GetPlayerColor then self.GetPlayerColor = function() return self.Owner:GetPlayerColor() end end
	self:DrawShadow(true)
	self:DrawModel(flags)
end

function SWEP:Deploy()
	if (SERVER) then
		local skinID = self.Owner:GetNWInt("pikiskin",0)
		if self.LastSkin ~= skinID then
			self.LastSkin = skinID
			self:SetSkin(skinID)
			self:UpdateWhistle(skinID)
		end
		self:SendWeaponAnim(ACT_VM_DRAW)
		timer.Remove("OlimarGunIdle" .. self:EntIndex())
		timer.Create("OlimarGunIdle" .. self:EntIndex(), 1.2, 1, function() self:SendWeaponAnim(ACT_VM_IDLE) end)
	end
	return true
end

function SWEP:Holster()
	if (SERVER) then
		timer.Remove("OlimarGunIdle" .. self:EntIndex())
		timer.Remove("OlimarGunIdleCharge" .. self:EntIndex())
		if self.Swarm then self.Owner:SetSlowWalkSpeed(self.Owner.SlowSpeed) end
		self.Owner.SwarmVec = nil
		self.Swarm = false
		self.Whistling = false
		self.WhistleSound:Stop()
		self.SwarmSound:Stop()
		self:SendWeaponAnim(ACT_VM_HOLSTER)
	end
	return true
end

function SWEP:OnRemove()
	if self.Swarm then self.Owner:SetSlowWalkSpeed(self.Owner.SlowSpeed) end
	self.Owner.SwarmVec = nil
	self.Swarm = false
	self.Whistling = false
	self.WhistleSound:Stop()
	self.SwarmSound:Stop()
end

function SWEP:PrimaryAttack()
end

function SWEP:SecondaryAttack()
	if self.Whistling then return end
	if self.ChargeTick and CurTime()-self.ChargeTick < 0.5 then return end
	local tr = util.QuickTrace(self.Owner:GetShootPos(), (self.Owner:GetAimVector() * 3000), self.Owner)
	if IsValid(tr.Entity) then
		if tr.Entity.PikIgnore then
			if not tr.Entity:IsNPC() then return end
			tr = util.QuickTrace(self.Owner:GetShootPos(), (self.Owner:GetAimVector() * 3000), {self.Owner,tr.Entity})
			if not IsValid(tr.Entity) then return end
		end
		local class = tr.Entity:GetClass()
		if class == "pikmin" or class == "pikmin_onion" or class == "pikmin_model" or class == "prop_ragdoll" or class == "pikmin_sprout" or class == "pikmin_bud" then return end
		if class == "prop_physics" and not (table.KeyFromValue(PikiCarryOnionList,tr.Entity:GetModel()) or tr.Entity.IsCarry) then return end
		if (class == "pikmin_fire" or class == "pikmin_gas" or class == "pikmin_wire") and tr.Entity:Health() <= 0 then return end
		if string.sub(class,1,4) == "func" and class ~= "func_breakable" then return end
		if tr.Entity.IsCarry and tr.Entity:GetNWInt("pikimax") ~= 0 and tr.Entity:GetNWInt("piki") >= tr.Entity:GetNWInt("pikimax") then return end
		local charged = false
		local chargetype = self.Owner:GetNWEntity("piki")
		if IsValid(chargetype) and chargetype.PikMdl and (chargetype.PikMdl.CurAnim <= 2 or chargetype.PikMdl.CurAnim == chargetype.WingedIdle) then
			self.Owner:SetNWEntity("piki",self.Owner)
			timer.Simple(0,function() chargetype:StopSound(chargetype.Color == 7 and "pikmin/pikmin_pink_grab.wav" or chargetype.Color == 8 and "pikmin/pikmin_rock_grab.wav" or "pikmin/grab.wav") end)
		else
			chargetype = nil
		end
		for _,v in ipairs(ents.FindByClass("pikmin")) do
			if v.Olimar == self.Owner and not v.Carrying and not v.Drinking and not v:IsOnFire() and not v.Drowning and not v.Poison and not v.Attacking and not v.AttackTarget and (chargetype and (v.Color == chargetype.Color and v.Level == chargetype.Level) or not chargetype) then
				charged = true
				v:Charge(tr.Entity)
			end
		end
		if charged then
			self.ChargeTick = CurTime()
			self:SendWeaponAnim(ACT_VM_SECONDARYATTACK)
			self.WhistleSound:Stop()
			self.WhistleSound:Play()
			if timer.Exists("OlimarGunIdleCharge"..self:EntIndex()) then timer.Remove("OlimarGunIdleCharge"..self:EntIndex()) end
			timer.Create("OlimarGunIdleCharge"..self:EntIndex(), 1.45, 1, function() self:SendWeaponAnim(ACT_VM_IDLE) self.WhistleSound:Stop() end)
		end
	end
end

function SWEP:Think()
	if not SERVER then return end
	if self.Swarm then
		local dirX = self.Owner:KeyDown(IN_MOVELEFT) and -1 or self.Owner:KeyDown(IN_MOVERIGHT) and 1 or 0
		local dirZ = self.Owner:KeyDown(IN_BACK) and -1 or self.Owner:KeyDown(IN_FORWARD) and 1 or 0
		if dirX ~= 0 or dirZ ~= 0 then
			local angles = self.Owner:EyeAngles()
			angles:SetUnpacked(0,angles[2],0)
			self.Owner.SwarmVec = (angles:Forward()*dirZ+angles:Right()*dirX):GetNormalized()*250
		else
			self.Owner.SwarmVec = nil
		end
	end
	if self.Whistling then
		local diffTime = CurTime()-self.WhistleTime
		if diffTime > 1.25 then
			self.WhistleSound:Stop()
			self.Whistling = false
			self:SendWeaponAnim(ACT_VM_IDLE)
		end
		local tr = util.QuickTrace(self.Owner:GetShootPos(), self.Owner:GetAimVector() * 750, {self.Owner, self})
		if tr.Hit then
			local whistleRange = 10 + diffTime*150
			local hasPluck = self.Owner:GetNWBool("pikipluck",false)
			if hasPluck then
				for _,v in ipairs(ents.FindByClass("pikmin_sprout")) do
					if v:GetPos():Distance(tr.HitPos) <= whistleRange then
						v:Pluck(self.Owner,true)
					end
				end
			end
			local drownTick = CurTime() + 0.1
			for _,v in ipairs(ents.FindByClass("pikmin")) do
				if v:GetPos():Distance(tr.HitPos) <= whistleRange and self.Owner:GetForward():Dot((self.Owner:GetPos()-v:GetPos()):GetNormalized()) < 0 then
					if v.Olimar == self.Owner then
						if v.AttackTarget and not v.Drinking then
							v:Drop()
						end
						if v.Drowning then
							v.DrownCall = drownTick
						end
					end
					if v.Poison then v.Poison = false end
					if v:IsOnFire() then
						v:Extinguish()
					end
					if v.Carrying and (v.Olimar == self.Owner or v.Dismissed) then
						v:Drop()
					end
					if v.Dismissed and v.Olimar == nil then
						v:Join(self.Owner)
					end
				end
			end
		end
	end
end

local function IsCaptain(ply)
if not ply:Alive() then return end
local wep = ply:GetActiveWeapon()
if not IsValid(wep) then return end
if wep:GetClass() ~= "olimar_gun" then return end
return true
end

if SERVER then
	util.AddNetworkString("PikiVMThrow")
else
	net.Receive("PikiVMThrow",function()
		local ply = net.ReadEntity()
		if IsValid(ply) then ply:SetAnimation(PLAYER_ATTACK1) end
	end)
end

local function PikSWepKeyPress(ply, key)
	if not SERVER then return end
	if not IsCaptain(ply) then return end
	if key == IN_USE and not ply:KeyDown(IN_RELOAD) then
		ply.PikminSwitchCooldown = ply.PikminSwitchCooldown or 0
		if CurTime() < ply.PikminSwitchCooldown then return end
		ply.PikminSwitchCooldown = CurTime() + 0.1
		
		local opos = ply:GetPos()
		local availableColors = {}
		local colorSeen = {}
		local pikminByColor = {}
		local maxDistSqr = 160000 -- 400^2
		for _,v in ipairs(ents.FindByClass("pikmin")) do
			if v.Olimar == ply and not v.Thrown and not v.Carrying and not v.Drinking and not v:IsOnFire() and not v.Attacking and not v.Poison and v:GetPos():DistToSqr(opos) <= maxDistSqr then
				if not colorSeen[v.Color] then
					colorSeen[v.Color] = true
					availableColors[#availableColors + 1] = v.Color
					pikminByColor[v.Color] = {}
				end
				pikminByColor[v.Color][#pikminByColor[v.Color] + 1] = v
			end
		end
		if #availableColors <= 1 then return end
		table.sort(availableColors)
		
		local currentColor = ply:GetNWInt("SelectedPikiColor", 0)
		local nextIdx = 1
		for i, c in ipairs(availableColors) do
			if c == currentColor then
				nextIdx = (i % #availableColors) + 1
				break
			end
		end
		local newColor = availableColors[nextIdx]
		ply:SetNWInt("SelectedPikiColor", newColor)
		ply:EmitSound("pikmin/switch.wav")
		
		local heldPikmin = ply:GetNWEntity("piki")
		if IsValid(heldPikmin) and heldPikmin ~= ply then
			heldPikmin:StopSound(heldPikmin.Color == 7 and "pikmin/pikmin_pink_grab.wav" or heldPikmin.Color == 8 and "pikmin/pikmin_rock_grab.wav" or "pikmin/grab.wav")
		end
		
		local newColorPiki = pikminByColor[newColor]
		if newColorPiki and #newColorPiki > 0 then
			table.sort(newColorPiki, function(a, b) return a:GetPos():DistToSqr(opos) < b:GetPos():DistToSqr(opos) end)
			
			if ply:KeyDown(IN_ATTACK) then
				local newHeld = newColorPiki[1]
				ply:SetNWEntity("piki", newHeld)
				local grabSound = newColor == 7 and "pikmin/pikmin_pink_grab.wav" or newColor == 8 and "pikmin/pikmin_rock_grab.wav" or "pikmin/grab.wav"
				newHeld:EmitSound(grabSound, 100, math.random(98, 105))
				
				for _, v in ipairs(newColorPiki) do
					if not v.Called then
						v.Called = true
						v.PikMdl.CurAnim = 7
						timer.Simple(0.325, function() if IsValid(v) then v.Called = false end end)
					end
				end
			end
		end
	elseif key == IN_ATTACK then
		if ply:GetActiveWeapon().Whistling then return end
		local piki = {}
		local opos = ply:GetPos()
		local ctime = CurTime()
		for _,v in ipairs(ents.FindByClass("pikmin")) do
			if v.Olimar == ply and v.ThrowNext <= ctime and v:GetPos():Distance(opos) <= 200 and not v.Thrown and not v.Carrying and not v.Drinking and not v:IsOnFire() and not v.Attacking and not v.Poison then
				table.insert(piki,v)
			end
		end
		if #piki ~= 0 then
			ply:GetActiveWeapon().ThrowTick = CurTime()
			ply:GetActiveWeapon().PunchTick = CurTime()
			local selectedColor = ply:GetNWInt("SelectedPikiColor", 0)
			if selectedColor > 0 then
				table.sort(piki, function(a, b)
					local aMatch = a.Color == selectedColor
					local bMatch = b.Color == selectedColor
					if aMatch ~= bMatch then return aMatch end
					return a:GetPos():Distance(opos) < b:GetPos():Distance(opos)
				end)
			else
				table.sort(piki,function(a,b) return a:GetPos():Distance(opos) < b:GetPos():Distance(opos) end)
			end
			local throwpikmin = piki[1]
			local grabSound = throwpikmin.Color == 7 and "pikmin/pikmin_pink_grab.wav" or throwpikmin.Color == 8 and "pikmin/pikmin_rock_grab.wav" or "pikmin/grab.wav"
			timer.Simple(0.03,function() throwpikmin:EmitSound(grabSound, 100, math.random(98, 105)) end)
			--throwpikmin:SetPos(ply:GetPos()+Vector(0,0,30))
			--throwpikmin:SetParent(ply)
			ply:SetNWEntity("piki",throwpikmin)
		else
			if ply:GetActiveWeapon().PunchTick and CurTime()-ply:GetActiveWeapon().PunchTick < 0.5 then return end
			ply:GetActiveWeapon().PunchTick = CurTime()
			local tr = util.QuickTrace(ply:GetShootPos(), ply:GetAimVector() * 100, ply)
			if tr.Hit and tr.Entity:Health() > 0 and (tr.Entity:IsNPC() or tr.Entity:IsPlayer() or tr.Entity:GetClass() == "pikmin_fire") then
				tr.Entity:TakeDamage(10, ply, ply:GetActiveWeapon())
				ply:EmitSound("pikmin/punch.wav")
			else
				ply:EmitSound("pikmin/punchair.wav",75,math.random(90,120))
			end
			ply:GetActiveWeapon():SendWeaponAnim(ACT_VM_PRIMARYATTACK)
			net.Start("PikiVMThrow")
			net.WriteEntity(ply)
			net.Broadcast()
			if timer.Exists("OlimarGunIdle"..ply:GetActiveWeapon():EntIndex()) then
				timer.Remove("OlimarGunIdle"..ply:GetActiveWeapon():EntIndex())
			end
			timer.Create("OlimarGunIdle"..ply:GetActiveWeapon():EntIndex(), 0.8, 1, function() ply:GetActiveWeapon():SendWeaponAnim(ACT_VM_IDLE) end)
		end
	elseif key == IN_RELOAD then
		local throwpikmin = ply:GetNWEntity("piki")
		ply:SetNWEntity("piki",ply)
		if IsValid(throwpikmin) then throwpikmin:StopSound(throwpikmin.Color == 7 and "pikmin/pikmin_pink_grab.wav" or throwpikmin.Color == 8 and "pikmin/pikmin_rock_grab.wav" or "pikmin/grab.wav") end
		if ply:KeyDown(IN_USE) then
			local disbanded = false
			
			if PikiDisband == 1 then
				local pikiArray = {}
				local typeDict = {}
				local typeArray = {}
				local typeCount = 0
				local sepDist = 100
				local forDist = 200
				local pos = ply:GetPos()
				local eyeangles = ply:EyeAngles()
				eyeangles = Angle(0,eyeangles.Y,0)
				local forward = eyeangles:Forward()
				
				--split by color
				for _,v in ipairs(ents.FindByClass("pikmin")) do
					if v.Olimar == ply and not v.AttackTarget and not v.Drowning and not v:IsOnFire() and not v.Carrying and not v.Called then
						disbanded = true
						if v:GetPos():Distance(pos) >= 400 or v.Thrown or math.abs((v:GetPos()-pos)[3]) >= 120 then
							v:Disband()
						else
							if not table.KeyFromValue(typeArray,v.Color) then
							table.insert(typeArray,v.Color)
							end
							if not typeDict[v.Color] then
								typeDict[v.Color] = {}
								typeCount = typeCount + 1
							end
							table.insert(typeDict[v.Color],v)
							table.insert(pikiArray,v)
						end
					end
				end
				
				--Split by level if possible
				if typeCount == 1 then
					sepDist = 70
					forDist = 120
					typeDict = {}
					typeArray = {}
					typeCount = 0
					for _,v in ipairs(pikiArray) do
						if not table.KeyFromValue(typeArray,v.Level) then
							table.insert(typeArray,v.Level)
						end
						if not typeDict[v.Level] then
							typeDict[v.Level] = {}
							typeCount = typeCount + 1
						end
						table.insert(typeDict[v.Level],v)
					end
				end
				if typeCount == 2 then
					sepDist = 140
					forDist = 180
				elseif typeCount == 3 then
					sepDist = 160
					forDist = 200
				elseif typeCount >= 4 then
					sepDist = 180 + (typeCount - 4) * 25
					forDist = 220 + (typeCount - 4) * 20
				end
				
				sepDist = sepDist-math.Clamp(ply:EyeAngles().X-40,0,45)/2
				
				-- calculate disband direction from the relative position of the squad being grouped
				-- it be working
				local avgPos = Vector(0,0,0)
				local count = 0
				for _,v in ipairs(pikiArray) do
					avgPos = avgPos + v:GetPos()
					count = count + 1
				end
				
				local disbandDir = forward
				local disbandRight = eyeangles:Right()
				if count > 0 then
					avgPos = avgPos / count
					local dir = avgPos - pos
					dir.z = 0
					if dir:LengthSqr() > 1 then
						disbandDir = dir:GetNormalized()
						disbandRight = Vector(disbandDir.y, -disbandDir.x, 0)
					end
				end
				
				if typeCount == 1 then
					for _,v in ipairs(pikiArray) do
						v:Disband()
					end
				else
					local posArray = {}
					local basePos = pos + disbandDir*forDist
					local slice = 2 * math.pi / typeCount
					for i=0,typeCount-1 do
						local angle = slice * i
						table.insert(posArray,basePos+disbandRight*sepDist*math.cos(angle)+disbandDir*sepDist*math.sin(angle))
					end
					for k,typ in ipairs(typeArray) do
						for _,v in ipairs(typeDict[typ]) do
							if v.Color == 7 then 
								v:Disband() -- Winged Pikmin are not going to move if you disband them
							else
								v:Disband(posArray[k])
							end
						end
					end
				end
			else
				for _,v in ipairs(ents.FindByClass("pikmin")) do
					if v.Olimar == ply and not v.AttackTarget and not v.Drowning and not v:IsOnFire() and not v.Carrying and not v.Called then
						disbanded = true
						v:Disband()
					end
				end
			end
			
			if disbanded then
				ply:GetActiveWeapon().WhistleSound:Stop()
				ply:EmitSound("pikmin/disband.wav")
				ply:GetActiveWeapon():SendWeaponAnim(ACT_VM_DRYFIRE)
				if timer.Exists("OlimarGunIdle"..ply:GetActiveWeapon():EntIndex()) then
					timer.Remove("OlimarGunIdle"..ply:GetActiveWeapon():EntIndex())
				end
				if timer.Exists("OlimarGunIdleCharge"..ply:GetActiveWeapon():EntIndex()) then
					timer.Remove("OlimarGunIdleCharge"..ply:GetActiveWeapon():EntIndex())
				end
				timer.Create("OlimarGunIdle"..ply:GetActiveWeapon():EntIndex(), 0.8, 1, function() ply:GetActiveWeapon():SendWeaponAnim(ACT_VM_IDLE) end)
				if ply:GetActiveWeapon().Swarm then
					ply:GetActiveWeapon().Swarm = false
					ply:SetSlowWalkSpeed(ply.SlowSpeed)
					ply:GetActiveWeapon().SwarmSound:FadeOut(0.2)
					ply.SwarmVec = nil
				end
			end
		else
			if timer.Exists("OlimarGunIdle"..ply:GetActiveWeapon():EntIndex()) then
				timer.Remove("OlimarGunIdle"..ply:GetActiveWeapon():EntIndex())
			end
			if timer.Exists("OlimarGunIdleCharge"..ply:GetActiveWeapon():EntIndex()) then
				timer.Remove("OlimarGunIdleCharge"..ply:GetActiveWeapon():EntIndex())
			end
			ply:GetActiveWeapon():SendWeaponAnim(ACT_VM_RELOAD)
			ply:GetActiveWeapon().WhistleTime = CurTime()
			ply:GetActiveWeapon().Whistling = true
			ply:GetActiveWeapon().WhistleSound:Stop()
			ply:GetActiveWeapon().WhistleSound:Play()
		end
	elseif key == IN_WALK then
		ply.SlowSpeed = ply:GetSlowWalkSpeed()
		local valid = false
		for _,v in ipairs(ents.FindByClass("pikmin")) do if v.Olimar == ply then valid = true break end end
		if not valid then return end
		ply:SetSlowWalkSpeed(1)
		ply:GetActiveWeapon().Swarm = true
		ply:GetActiveWeapon().SwarmSound:Play()
	end
end

local function PikSWepKeyRelease(ply, key)
	if not SERVER then return end
	if not IsCaptain(ply) then return end
	if key == IN_ATTACK then
		local throwpikmin = ply:GetNWEntity("piki")
		if IsValid(throwpikmin) and throwpikmin ~= ply then
			ply:SetNWEntity("piki",ply)
			if throwpikmin:GetPos():Distance(ply:GetPos()) <= 200 then
				local aimVector = ply:GetAimVector()
				ply:GetActiveWeapon():SendWeaponAnim(ACT_VM_PRIMARYATTACK)
				net.Start("PikiVMThrow")
				net.WriteEntity(ply)
				net.Broadcast()
				if timer.Exists("OlimarGunIdle"..ply:GetActiveWeapon():EntIndex()) then
					timer.Remove("OlimarGunIdle"..ply:GetActiveWeapon():EntIndex())
				end
				timer.Create("OlimarGunIdle"..ply:GetActiveWeapon():EntIndex(), 0.8, 1, function() ply:GetActiveWeapon():SendWeaponAnim(ACT_VM_IDLE) end)
				local force = throwpikmin.Color == 2 and 56 or throwpikmin.Color == 7 and 50 or 40
				local forceMult = 0.8+math.min(0.3,CurTime()-ply:GetActiveWeapon().ThrowTick)
				local phys = throwpikmin:GetPhysicsObject()
				throwpikmin.ThrowNext = CurTime() + 1
				local right = ply:EyeAngles():Right()
				local up = ply:EyeAngles():Up()
				local offset = right * 10 - up * 8 + aimVector * 20
				if aimVector.Z < -0.4 then
					throwpikmin:SetPos((ply:GetShootPos() - Vector(0,0,16) + offset))
				else
					throwpikmin:SetPos((ply:GetShootPos() + offset))
				end
				timer.Simple(0,function() throwpikmin:StopSound(throwpikmin.Color == 7 and "pikmin/pikmin_pink_grab.wav" or throwpikmin.Color == 8 and "pikmin/pikmin_rock_grab.wav" or "pikmin/grab.wav") end)
				local throwSound = throwpikmin.Color == 2 and "pikmin/pikmin_yellow_throw.wav" or throwpikmin.Color == 7 and "pikmin/pikmin_pink_throw.wav" or throwpikmin.Color == 8 and ("pikmin/pikmin_rock_throw" .. math.random(1, 2) .. ".wav") or "pikmin/pikmin_throw.wav"
				local throwPitch = (throwpikmin.Color <= 3) and math.random(98, 102) or 100
				throwpikmin:EmitSound(throwSound, 100, throwPitch)
				throwpikmin.Thrown = true
				throwpikmin.params.angle = (throwpikmin:GetPos()-ply:GetShootPos()):Angle()
				if IsValid(phys) then
					phys:EnableMotion(true)
					phys:ApplyForceCenter(((aimVector*(force*forceMult) + Vector(0,0,5)) * 125))
				end
			end
		end
	elseif key == IN_RELOAD then
		if ply:GetActiveWeapon().Whistling then
			ply:GetActiveWeapon().Whistling = false
			ply:GetActiveWeapon().WhistleSound:FadeOut(0.2)
			ply:GetActiveWeapon():SendWeaponAnim(ACT_VM_IDLE)
		end
	elseif key == IN_WALK then
		ply:SetSlowWalkSpeed(ply.SlowSpeed)
		ply:GetActiveWeapon().Swarm = false
		ply:GetActiveWeapon().SwarmSound:FadeOut(0.2)
		ply.SwarmVec = nil
	end
end

hook.Add("KeyPress", "OlimarGunKeyPress", PikSWepKeyPress)
hook.Add("KeyRelease", "OlimarGunKeyRelease", PikSWepKeyRelease)

local BoxColor = Color(0,0,0,100)
local IconMat = Material("icons/piki.png","noclamp")
local IconColor = Color(255,255,255,255)
local TextColor = Color(255,255,255,255)
local MinPikiDistance = 40000

function SWEP:DrawHUD()
	if HideOlimarHUD then return end
	local pikEnts = ents.FindByClass("pikmin_model")
	local CurPik = 0
	local MinDist = MinPikiDistance
	local opos = LocalPlayer():GetPos()
	local heldpiki = LocalPlayer():GetNWEntity("piki")
	local selectedColor = LocalPlayer():GetNWInt("SelectedPikiColor", 0)
	local ourEnts = 0
	local selectedDist = MinPikiDistance
	for k,v in ipairs(pikEnts) do
		local parent = v:GetParent()
		if not IsValid(parent) or parent:GetNWEntity("Olimar") ~= self.Owner then continue end
		local seq = v:GetSequence()
		if seq > 2 and v:GetSequenceName(seq) ~= "swimming" then continue end
		ourEnts = ourEnts+1
		local dist = v:GetPos():DistToSqr(opos)
		if parent == heldpiki then
			MinDist = 0
			CurPik = dist <= MinPikiDistance and table.KeyFromValue(ColorModelTable,v:GetModel()) or 0
			continue
		end
		-- Prioritize showing the selected Pikmin color on the HUD
		local vColor = v:GetNWInt("Color", 1)
		if selectedColor > 0 and vColor == selectedColor then
			if dist <= selectedDist then
				selectedDist = dist
				MinDist = -1
				CurPik = table.KeyFromValue(ColorModelTable,v:GetModel())
			end
		elseif MinDist ~= -1 and dist <= MinDist then
			MinDist = dist
			CurPik = table.KeyFromValue(ColorModelTable,v:GetModel())
		end
	end
	local w,h = ScrW(),ScrH()
	draw.RoundedBox(8, w - 138 - 64, h - 58, 128, 48, BoxColor)
	draw.DrawText(ourEnts.." / "..#pikEnts,"DermaLarge",w-76 - 64,h-49,TextColor,TEXT_ALIGN_CENTER)
	surface.SetMaterial(IconMat)
	surface.SetDrawColor(IconColor)
	local suv = CurPik * 0.0302734375
	surface.DrawTexturedRectUV(w-68,h-72,64,64,suv,0,suv + 0.0302734375,1)
end

------------General Swep Info---------------
SWEP.Author = "Aska & jasherton"
SWEP.Purpose = "#olimar_gun.purpose"
SWEP.Instructions = ""
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.Category = "#pikmin"
if CLIENT then
	SWEP.Instructions = language.GetPhrase("olimar_gun.info1").."\n"..
	language.GetPhrase("olimar_gun.info2").."\n"..
	language.GetPhrase("olimar_gun.info3").."\n"..
	language.GetPhrase("olimar_gun.info4").."\n"..
	language.GetPhrase("olimar_gun.info5").."\n"..
	language.GetPhrase("olimar_gun.info6")
end
-----------------------------------------------

------------Models---------------------------
SWEP.ViewModel = ("models/weapons/v_olimar.mdl")
SWEP.WorldModel = ("models/weapons/w_olimar.mdl")
-----------------------------------------------

-- suggestion from basketcat54 to implement the trajectory arc
-- This just uses a beam and a little bit of math.

if CLIENT then
	hook.Add("PostDrawTranslucentRenderables", "PikiTrajectoryArc", function()
		local ply = LocalPlayer() if not IsValid(ply) then return end
		local wep = ply:GetActiveWeapon() if not IsValid(wep) or wep:GetClass() ~= "olimar_gun" then return end

		local heldpiki = ply:GetNWEntity("piki")
		if not IsValid(heldpiki) or heldpiki == ply then wep.ClientThrowTick = nil return end

		if not wep.ClientThrowTick then wep.ClientThrowTick = CurTime() end

		local aimVector = ply:GetAimVector()
		local pikiColor = 1
		for _, child in ipairs(heldpiki:GetChildren()) do
			if child:GetClass() == "pikmin_model" then
				pikiColor = child:GetNWInt("Color", 1)
				break
			end
		end
		local force = pikiColor == 2 and 56 or pikiColor == 7 and 50 or 40
		local forceMult = 0.8 + math.min(0.3, CurTime() - wep.ClientThrowTick)

		local mass = 10
		local vel = (aimVector * (force * forceMult) + Vector(0,0,5)) * (125 / mass)

		local right = ply:EyeAngles():Right()
		local up = ply:EyeAngles():Up()
		local offset = right * 10 - up * 8 + aimVector * 20

		local startPos
		if aimVector.Z < -0.4 then
			startPos = ply:GetShootPos() - Vector(0,0,16) + offset
		else
			startPos = ply:GetShootPos() + offset
		end
		
		local points = {}
		table.insert(points, startPos)

		local currentPos = startPos
		local currentVel = vel
		local gravity = Vector(0, 0, -GetConVar("sv_gravity"):GetFloat())
		local dt = 0.03
		local maxSteps = 45
		local hitPos, hitNormal

		for i = 1, maxSteps do
			local nextPos = currentPos + currentVel * dt
			local tr = util.TraceLine({
				start = currentPos,
				endpos = nextPos,
				filter = {ply, heldpiki}
			})
			if tr.Hit then
				table.insert(points, tr.HitPos)
				hitPos = tr.HitPos
				hitNormal = tr.HitNormal
				break
			else
				table.insert(points, nextPos)
			end
			currentVel = currentVel + gravity * dt
			currentPos = nextPos
		end

		local col = DisbandColors[pikiColor] or Color(255, 255, 255, 255)
		render.SetColorMaterial()
		render.StartBeam(#points)
		for i, pt in ipairs(points) do
			render.AddBeam(pt, 2.0, i / #points, col)
		end
		render.EndBeam()

		if hitPos and hitNormal then
			render.SetMaterial(Material("particle/particle_ring_wave_additive"))
			local size = 20 + math.sin(CurTime() * 8) * 4 -- This helps us find where the Pikmin wind up better
			render.DrawQuadEasy(hitPos + hitNormal * 0.5, hitNormal, size, size, col, 0) -- just like in the games, the end circle casts to surfaces on the wall too
		end
	end)
end