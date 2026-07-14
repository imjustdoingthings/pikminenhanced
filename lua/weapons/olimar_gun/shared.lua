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

local function HoldPikmin(ply, piki)
	if not SERVER then return end
	if not IsValid(piki) then return end
	piki.IsHeldForThrow = true
	piki:SetSolid(SOLID_NONE)
	piki:SetMoveType(MOVETYPE_NONE)
	piki:SetParent(ply)
	piki:Fire("SetParentAttachment", "anim_attachment_RH")
	piki:SetLocalPos(Vector(0, 0, -2))
	piki:SetLocalAngles(Angle(0, 90, 0))
	piki.PikMdl.CurAnim = "drowning"

	local phys = piki:GetPhysicsObject()
	if IsValid(phys) then
		phys:EnableCollisions(false)
		phys:EnableGravity(false)
		phys:Sleep()
	end
end

local function ReleasePikmin(ply, piki, isCanceled)
	if not SERVER then return end
	if not IsValid(piki) then return end
	piki.IsHeldForThrow = nil
	
	local handPos = ply:GetPos() + Vector(0, 0, 40)
	if IsValid(ply) then
		local attach_id = ply:LookupAttachment("anim_attachment_RH")
		if attach_id and attach_id > 0 then
			local attach = ply:GetAttachment(attach_id)
			if attach then
				handPos = attach.Pos
			end
		end
	end
	
	piki:SetParent(nil)
	piki:SetPos(handPos)
	piki:SetSolid(SOLID_VPHYSICS)
	piki:SetMoveType(MOVETYPE_VPHYSICS)
	
	local phys = piki:GetPhysicsObject()
	if IsValid(phys) then
		phys:EnableCollisions(true)
		phys:EnableGravity(piki.Color ~= 7)
		phys:SetPos(handPos)
		phys:Wake()
	end
end

local function CalcThrowVelocity(startPos, aimHitPos)
	local diff = aimHitPos - startPos
	local diff2d = Vector(diff.x, diff.y, 0)
	local dist2d = diff2d:Length()
	
	local t = math.max(0.2, dist2d / 400)
	local gravityVal = GetConVar("sv_gravity"):GetFloat()
	
	local vel_h = diff2d:GetNormalized() * (dist2d / t)
	local vel_z = (diff.z / t) + 0.5 * gravityVal * t
	
	-- clamp upward velocity to prevent sky-high throws (
	-- unless superthrow is enabled)
	if not cvars.Bool("pik_superthrow") then
		vel_z = math.min(vel_z, 350)
	end
	
	return vel_h + Vector(0, 0, vel_z)
end

local function GetAimTarget(ply)
	local isThirdperson = false
	if CLIENT then
		isThirdperson = GetConVar("pikmin_camera"):GetBool()
	else
		isThirdperson = ply:GetInfoNum("pikmin_camera", 0) == 1
	end

	if isThirdperson then
		local pikiColor = 1
		local heldpiki = ply:GetNWEntity("piki")
		if IsValid(heldpiki) and heldpiki ~= ply then
			pikiColor = heldpiki.Color or 1
		else
			pikiColor = ply:GetNWInt("SelectedPikiColor", 1)
		end

		local maxDist = 450
		if pikiColor == 2 then -- Yellow
			maxDist = 550
		elseif pikiColor == 4 then -- Purple
			maxDist = 280
		end

		local pitch = ply:EyeAngles().p
		local targetDist = math.Clamp(220 - pitch * 3.5, 50, maxDist)

		local aimDir = ply:GetAimVector()
		aimDir.z = 0
		aimDir:Normalize()

		local targetPos = ply:GetPos() + aimDir * targetDist

		local tr = util.TraceLine({
			start = targetPos + Vector(0, 0, 150),
			endpos = targetPos - Vector(0, 0, 500),
			filter = function(ent)
				if IsValid(ent) and (ent:GetClass() == "pikmin" or ent:GetClass() == "pikmin_sprout" or ent:GetClass() == "pikmin_model") then
					return false
				end
				return ent ~= ply
			end
		})

		if not tr.Hit then
			tr.Hit = true
			tr.HitPos = targetPos
			tr.HitNormal = Vector(0, 0, 1)
		end
		if not tr.HitNormal or tr.HitNormal:LengthSqr() < 0.01 then
			tr.HitNormal = Vector(0, 0, 1)
		end
		return tr
	else
		local endpos = ply:GetShootPos() + ply:GetAimVector() * 750
		local tr = util.TraceLine({
			start = ply:GetShootPos(),
			endpos = endpos,
			filter = function(ent)
				if IsValid(ent) and (ent:GetClass() == "pikmin" or ent:GetClass() == "pikmin_sprout" or ent:GetClass() == "pikmin_model") then
					return false
				end
				return ent ~= ply
			end
		})
		if not tr.Hit then
			tr.Hit = true
			tr.HitPos = endpos
			tr.HitNormal = Vector(0, 0, 1)
		end
		if not tr.HitNormal or tr.HitNormal:LengthSqr() < 0.01 then
			tr.HitNormal = Vector(0, 0, 1)
		end
		return tr
	end
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
		self:SetNWBool("Whistling", false)
		self.WhistleSound:Stop()
		self.SwarmSound:Stop()
		self:SendWeaponAnim(ACT_VM_HOLSTER)
		
		local held = self.Owner:GetNWEntity("piki")
		if IsValid(held) and held ~= self.Owner then
			self.Owner:SetNWEntity("piki", self.Owner)
			ReleasePikmin(self.Owner, held, true)
		end
	end
	return true
end

function SWEP:OnRemove()
	if self.Swarm and IsValid(self.Owner) then self.Owner:SetSlowWalkSpeed(self.Owner.SlowSpeed) end
	if IsValid(self.Owner) then
		self.Owner.SwarmVec = nil
		if SERVER then
			local held = self.Owner:GetNWEntity("piki")
			if IsValid(held) and held ~= self.Owner then
				self.Owner:SetNWEntity("piki", self.Owner)
				ReleasePikmin(self.Owner, held, true)
			end
		end
	end
	self.Swarm = false
	self.Whistling = false
	if self.WhistleSound then self.WhistleSound:Stop() end
	if self.SwarmSound then self.SwarmSound:Stop() end
	if CLIENT and self.WhistleEmitter and self.WhistleEmitter:IsValid() then
		self.WhistleEmitter:Finish()
		self.WhistleEmitter = nil
	end
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
		if IsValid(chargetype) and chargetype.PikMdl and (chargetype.PikMdl.CurAnim == "running" or chargetype.PikMdl.CurAnim == "idle" or chargetype.PikMdl.CurAnim == chargetype.WingedIdle) then
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
			self:SetNWBool("Whistling", false)
			self:SendWeaponAnim(ACT_VM_IDLE)
		end
		local tr = GetAimTarget(self.Owner)
		if tr.Hit then
			local whistleRange = (10 + diffTime*150) * 1.75
			local hasPluck = self.Owner:GetNWBool("pikipluck",false)
			if hasPluck then
				for _,v in ipairs(ents.FindByClass("pikmin_sprout")) do
					local dist = util.DistanceToLine(self.Owner:GetShootPos(), tr.HitPos, v:GetPos())
					if dist <= whistleRange then
						v:Pluck(self.Owner,true)
					end
				end
			end
			local drownTick = CurTime() + 0.1
			for _,v in ipairs(ents.FindByClass("pikmin")) do
				local dist = util.DistanceToLine(self.Owner:GetShootPos(), tr.HitPos, v:GetPos())
				if dist <= whistleRange and self.Owner:GetForward():Dot((self.Owner:GetPos()-v:GetPos()):GetNormalized()) < 0 then
					if v:GetNWBool("Buried") then continue end
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
			ReleasePikmin(ply, heldPikmin, true)
		end
		
		local newColorPiki = pikminByColor[newColor]
		if newColorPiki and #newColorPiki > 0 then
			table.sort(newColorPiki, function(a, b) return a:GetPos():DistToSqr(opos) < b:GetPos():DistToSqr(opos) end)
			
			if ply:KeyDown(IN_ATTACK) then
				local newHeld = newColorPiki[1]
				ply:SetNWEntity("piki", newHeld)
				HoldPikmin(ply, newHeld)
				local grabSound = newColor == 7 and "pikmin/pikmin_pink_grab.wav" or newColor == 8 and "pikmin/pikmin_rock_grab.wav" or "pikmin/grab.wav"
				newHeld:EmitSound(grabSound, 100, math.random(98, 105))
				
				for _, v in ipairs(newColorPiki) do
					if not v.Called then
						v.Called = true
						v.PikMdl.CurAnim = "join"
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
			ply:SetNWEntity("piki",throwpikmin)
			ply:SetNWInt("SelectedPikiColor", throwpikmin.Color)
			HoldPikmin(ply, throwpikmin)
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
				
				--Split by level if all Pikmin are the same color
				if typeCount == 1 then
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
					for _,v in ipairs(pikiArray) do v:Disband() end
				else
					local posArray = {}
					local arcSpan = math.rad(math.Clamp(typeCount * 22, 44, 180))

					-- find the largest group's outermost ring so the dismissal (now) arc 
					-- can be sized to prevent adjacent groups from overlapping

					-- Results in this, combined with our other code https://files.catbox.moe/0elr4t.png

					local ringSpacing = 36
					local maxGroupRad = 0
					for _, typ in ipairs(typeArray) do
						local groupSize = #typeDict[typ]
						local rem = groupSize - 1
						local outerRing = 0
						while rem > 0 do
							outerRing = outerRing + 1
							rem = rem - outerRing * 6
						end
						maxGroupRad = math.max(maxGroupRad, outerRing * ringSpacing)
					end

					-- find the center-center dist between adjacent groups
					-- so their footprints don't overlap 
					local minCenterDist = maxGroupRad * 2 + 48 -- add an offset/gap

					-- centers are at least minCenterDist apart.
					local arcRadius
					if typeCount <= 1 then
						arcRadius = 180
					elseif typeCount == 2 then
						arcRadius = (minCenterDist / 2) / math.sin(arcSpan / 2)
					else
						local adjacentAngle = arcSpan / (typeCount - 1)
						arcRadius = (minCenterDist / 2) / math.sin(adjacentAngle / 2)
					end
					-- Never let it be smaller than this given minimum
					arcRadius = math.max(arcRadius, 180 + typeCount * 12)

					for i = 0, typeCount - 1 do
						local t = typeCount > 1 and (i / (typeCount - 1)) or 0.5
						local angle = -arcSpan / 2 + t * arcSpan
						table.insert(posArray, pos + disbandRight * math.sin(angle) * arcRadius + disbandDir * math.cos(angle) * arcRadius)
					end
					for k,typ in ipairs(typeArray) do
						local groupPikmin = typeDict[typ]
						local leader = groupPikmin[1]
						local idx = 1
						for _,v in ipairs(groupPikmin) do
							local offset = Vector(0,0,0)
							if idx > 1 then
								local ring = 0
								local ringIndex = 1
								local ringCount = 1
								local remaining = idx - 1
								while remaining > 0 do
									ring = ring + 1
									local ringCapacity = ring * 6
									if remaining <= ringCapacity then
										ringIndex = remaining
										ringCount = ringCapacity
										remaining = 0
									else
										remaining = remaining - ringCapacity
									end
								end
								local rVal = ring * ringSpacing
								local theta = (ringIndex / ringCount) * 2 * math.pi
								offset = Vector(rVal * math.cos(theta), rVal * math.sin(theta), 0)
							end
							v:Disband(posArray[k], leader, offset)
							idx = idx + 1
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
			local activeWep = ply:GetActiveWeapon()
			activeWep:SendWeaponAnim(ACT_VM_RELOAD)
			activeWep.WhistleTime = CurTime()
			activeWep.Whistling = true
			activeWep:SetNWBool("Whistling", true)
			activeWep:SetNWFloat("WhistleStart", CurTime())
			activeWep.WhistleSound:Stop()
			activeWep.WhistleSound:Play()
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
			ReleasePikmin(ply, throwpikmin, false)
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
				local startPos
				if aimVector.Z < -0.4 then
					startPos = ply:GetShootPos() - Vector(0,0,16) + offset
				else
					startPos = ply:GetShootPos() + offset
				end
				throwpikmin:SetPos(startPos)
				
				local trAim = GetAimTarget(ply)
				local aimHitPos = trAim.HitPos
				
				local vel = CalcThrowVelocity(startPos, aimHitPos)
				
				timer.Simple(0,function() throwpikmin:StopSound(throwpikmin.Color == 7 and "pikmin/pikmin_pink_grab.wav" or throwpikmin.Color == 8 and "pikmin/pikmin_rock_grab.wav" or "pikmin/grab.wav") end)
				local throwSound = throwpikmin.Color == 2 and "pikmin/pikmin_yellow_throw.wav" or throwpikmin.Color == 7 and "pikmin/pikmin_pink_throw.wav" or throwpikmin.Color == 8 and ("pikmin/pikmin_rock_throw" .. math.random(1, 2) .. ".wav") or "pikmin/pikmin_throw.wav"
				local throwPitch = (throwpikmin.Color <= 3) and math.random(98, 102) or 100
				throwpikmin:EmitSound(throwSound, 100, throwPitch)
				throwpikmin.Thrown = true
				throwpikmin.params.angle = (throwpikmin:GetPos()-ply:GetShootPos()):Angle()
				if IsValid(phys) then
					phys:EnableMotion(true)
					phys:SetVelocity(vel)
				end
			end
		end
	elseif key == IN_RELOAD then
		local activeWep = ply:GetActiveWeapon()
		if IsValid(activeWep) and activeWep.Whistling then
			activeWep.Whistling = false
			activeWep:SetNWBool("Whistling", false)
			activeWep.WhistleSound:FadeOut(0.2)
			activeWep:SendWeaponAnim(ACT_VM_IDLE)
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

		local right = ply:EyeAngles():Right()
		local up = ply:EyeAngles():Up()
		local offset = right * 10 - up * 8 + aimVector * 20

		local startPos
		if aimVector.Z < -0.4 then
			startPos = ply:GetShootPos() - Vector(0,0,16) + offset
		else
			startPos = ply:GetShootPos() + offset
		end

		local trAim = GetAimTarget(ply)
		local aimHitPos = trAim.HitPos
		
		local vel = CalcThrowVelocity(startPos, aimHitPos)
		
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

	hook.Add("PostDrawTranslucentRenderables", "PikiWhistleEffect", function()
		local ply = LocalPlayer() if not IsValid(ply) then return end
		local wep = ply:GetActiveWeapon() if not IsValid(wep) or wep:GetClass() ~= "olimar_gun" then return end

		-- Draw the big pink cursor if thirdperson camera is active
		if GetConVar("pikmin_camera"):GetBool() then
			local tr = GetAimTarget(ply)
			if tr.Hit and not tr.HitSky then
				local dist = ply:GetShootPos():Distance(tr.HitPos)
				if dist <= 600 then
					local alpha = 220
					if dist > 450 then
						local ratio = (dist - 450) / 150
						alpha = math.max(0, 220 * (1 - ratio))
					end
					
					if alpha > 0 then
						local cursorSize = 24 + dist * 0.06
						
						render.SetMaterial(Material("effects/select_ring"))
						render.DrawQuadEasy(tr.HitPos + tr.HitNormal * 0.5, tr.HitNormal, cursorSize, cursorSize, Color(255, 100, 255, alpha), CurTime() * 45)
						
						render.SetMaterial(Material("sprites/light_glow02_add"))
						render.DrawSprite(tr.HitPos + tr.HitNormal * 2, cursorSize * 0.4, cursorSize * 0.4, Color(255, 150, 255, alpha * (255 / 220)))
					end
				end
			end
		end

		-- Whistle rendering & particle logic
		if wep:GetNWBool("Whistling") then
			local whistleStart = wep:GetNWFloat("WhistleStart", 0)
			local diffTime = CurTime() - whistleStart
			if diffTime >= 0 and diffTime <= 1.25 then
				local tr = GetAimTarget(ply)
				if tr.Hit then
					local whistleRange = (10 + diffTime * 150) * 1.75
					
					-- track whistle position velocity
					if not wep.LastWhistlePos then
						wep.LastWhistlePos = tr.HitPos
						wep.WhistleVelocity = Vector(0,0,0)
					end
					
					local dt = RealFrameTime()
					if dt > 0 then
						local rawVel = (tr.HitPos - wep.LastWhistlePos) / dt
						wep.WhistleVelocity = LerpVector(math.min(1.0, 10 * dt), wep.WhistleVelocity, rawVel)
					end
					wep.LastWhistlePos = tr.HitPos

					-- center circle
					render.SetMaterial(Material("effects/select_ring"))
					render.DrawQuadEasy(tr.HitPos + tr.HitNormal * 0.5, tr.HitNormal, 24, 24, Color(255, 100, 255), 0)

					-- Render particles
					render.SetMaterial(Material("sprites/light_glow02_add"))
					
					local numArms = 6
					local numDotsPerTail = 16 -- 16 particles per trail is enough lol
					local rotationSpeed = 6 
					local maxAge = 0.35
					
					-- Calculate basis vectors/directions/whatever
					local up = (math.abs(tr.HitNormal.z) < 0.99) and Vector(0,0,1) or Vector(1,0,0)
					local right = tr.HitNormal:Cross(up):GetNormalized()
					local forward = right:Cross(tr.HitNormal):GetNormalized()
					for arm = 1, numArms do local armAngleBase = (arm / numArms) * 2 * math.pi
						
						for i = 1, numDotsPerTail do
							local t_ratio = i / numDotsPerTail -- 0 (top of tail) to 1 (ground/edge of whistle)
							local minTau = math.max(0, diffTime - maxAge)
							local tau = minTau + t_ratio * (diffTime - minTau)
							local rVal = whistleRange
							
							-- Lag offset based on movement velocity and age
							local age = (diffTime - tau)
							
							-- this took forever to figure out
							local dragForce = 225
							local angleVal = armAngleBase - CurTime() * rotationSpeed + (math.pow(age, 1.5) * dragForce) / whistleRange
							local offset = right * rVal * math.cos(angleVal) + forward * rVal * math.sin(angleVal)
							
							-- Height
							local zVal = age * 160
							
							-- movement lag 
							local lag = (wep.WhistleVelocity or Vector(0,0,0)) * age
							if lag:LengthSqr() > 90000 then
								lag = lag:GetNormalized() * 300
							end
							
							local dotPos = tr.HitPos + offset + tr.HitNormal * 12 + Vector(0, 0, zVal) - lag
							local hue = (1 - t_ratio) * 300
							local col = HSVToColor(hue, 1, 1)
							local size = 60 * (1 + 0.15 * math.sin(CurTime() * 12 + zVal * 0.05))
							render.DrawSprite(dotPos, size, size, col)
						end
					end
				end
			end
		else
			wep.LastWhistlePos = nil
			wep.WhistleVelocity = nil
		end
	end)
end