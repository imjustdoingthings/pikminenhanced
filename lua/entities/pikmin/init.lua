AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

--[[
--//Animations//--
Running (1)
Idle (2)
Thrown (3)
Attacking (4)
Swimming (5)
Drowning (6)
Called (7)
Dismissed (8)
Drinking (9)
Burning (10)
Sway (11)
CarryIdle (12)
CarryRun (13)
--]]

-- 1=Red, 2=Yellow, 3=Blue, 4=Purple, 5=White, 6=Bulbmin, 7=Winged, 8=Rock, 9=Mushroom
local IDLE_ANIMS_STANDARD = { "stemfidget", "stretcharms", "chatting", "lookback", "stretch" }
local IDLE_ANIMS_HEAVY    = { "stemfidget", "stretcharms", "chatting", "sitnstand" }  -- Purple, Rock (there is no lookback animation, their sit replaced)
local IDLE_ANIMS_WHITE    = { "stemfidget", "stretchcharms", "chatting", "sitnstand" }  -- White (uses stretchcharms, they do not have a lookback animation)

-- Which colors use which table
local function GetIdleAnimTable(color)
	if color == 4 or color == 8 then return IDLE_ANIMS_HEAVY
	elseif color == 5 then return IDLE_ANIMS_WHITE
	elseif color == 1 or color == 2 or color == 3 then return IDLE_ANIMS_STANDARD
	else return nil  -- other colors use no idle anims for now
	end
end

-- Returns true if this is a "sit" animation that has sitting hold and branch behavior
local function IsSitAnim(anim)
	return anim == "sitnstand"
end

-- Returns true if this is a lookback animation that needs to play forward then backward; so, a ping-pong animation 
local function IsLookbackAnim(anim) return anim == "lookback" or anim == "lookbehind" end

function ENT:SpawnFunction(ply,tr)
	ply:ConCommand("pikmin_menu")
end

--lua_run local ply = ents.FindByClass("player")[1] for i=1,20 do PikminCreate(ply,"",{"red"}) end

--lua_run local count = 0 for _,v in ipairs(ents.FindByClass("pikmin")) do v:Remove() count = count+1 if count >= 20 then break end end

hook.Add("ShouldCollide","PikiCollide",function(ent1,ent2)
	if ent1.PikMdl and ent2.PikMdl then return false end
	if ent1.PikMdl and ent2:IsPlayer() and ent1.Olimar == ent2 then local wep = ent2:GetActiveWeapon() if not IsValid(wep) or wep:GetClass() == "olimar_gun" then return false end end
	return GAMEMODE:ShouldCollide(ent1,ent2)
end)

function ENT:KeyValue(key,value)
	if key == "model" then
		local idx = tonumber(value) or 0
		self.Color = math.floor(idx/3)+1
		self.Level = idx%3
	end
end

function ENT:Initialize()
	if #ents.FindByClass("pikmin")+math.max(0,#ents.FindByClass("pikmin_sprout")-1) > PikiMaxField then self:Remove() return end
	self.Color = self.Color or 1
	self:SetModel(ColorCollideTable[self.Color])
	self:SetMoveCollide(MOVECOLLIDE_FLY_SLIDE)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:DrawShadow(false)
	self:StartMotionController()
	self:SetCustomCollisionCheck(true)
	local phys = self:GetPhysicsObject()
	self.Phys = phys
	if IsValid(phys) then
		phys:SetBuoyancyRatio(.375)
		phys:Wake()
	end
	self.Level = self.Level or 0
	local mdl = ents.Create("pikmin_model")
	mdl:SetNWInt("Level",math.min(2,self.Level))
	mdl:SetNWInt("Color",self.Color)
	mdl:SetModel(ColorModelTable[(self.Color-1)*3+1+self.Level])
	mdl:SetPos(self:GetPos())
	mdl:SetAngles(self:GetAngles())
	mdl:SetParent(self)
	mdl:Spawn()
	mdl:Activate()
	self.PikMdl = mdl
	self.WingedIdle = self.Color == 7 and "swimming" or "idle"
	self.PikHP = PikHealth[self.Color]
	self.Damage = PikDamage[self.Color]/PikDamageDivider
	self.Thrown = false
	self.AttackTarget = nil
	self.NextHop = CurTime()
	self.NextObHop = CurTime()
	self.NextAttack = CurTime()
	self.NextAI = CurTime()
	self.ThrowNext = CurTime()
	self.IdleSoundNext = CurTime() + math.random(5, 10)
	self.BaseMoveForce = GetConVar("pik_speed" .. self.Color):GetFloat()
	self.MoveForce = self.BaseMoveForce + self.Level*(self.Color == 5 and 320 or (self.Color == 4 or self.Color == 8) and 150 or 250)
	self.ZForceVector = (self.Color == 4 or self.Color == 8) and Vector(0,0,425) or self.Color == 7 and Vector(0,0,0) or Vector(0,0,325)
	self.JumpVector = Vector(0,0,(self.Color == 4 or self.Color == 8) and 2000 or 1750)
	self.HighJumpVector = self.JumpVector*2
	self.CarryForce = (self.Color == 4 or self.Color == 8) and 4000 or 50
	self.CarryWeight = self.Color == 4 and 10 or 1
	self.Called = false
	if not self.Olimar or self.Dismissed then self:Disband() end
	if self.Olimar and IsValid(self.Olimar) and self.Olimar:GetNWBool("ispikmin") then self:Disband() end
	self:SetNWEntity("Olimar",self.Olimar)
	--self.DrownCall = nil (used to help with drowning)
	--self.DismissPos = nil (use this to make them disband into groups)
end

function ENT:DisbandCarry()
	local obj = self.CarryObject
	obj.PikIgnore = true
	timer.Simple(0.5,function() if IsValid(obj) then obj.PikIgnore = false end end)
	self:Disband()
end

function ENT:Disband(pos, leader, offset)
	if self.Carrying then self:Drop() end
	self.Dismissed = true
	self.Olimar = nil
	self:SetNWEntity("Olimar",self)
	self.AttackTarget = nil
	self.PikMdl:SetNWBool("Dismissed",true)
	self.MeshIndex = nil
	self.MeshSquadSize = nil

	-- new disband logic 
	-- Should look significantly better. 
	-- Thank goodness for https://wiki.facepunch.com/gmod/Enums/MASK . lifesaver

	if pos and IsValid(leader) then
		self.DismissTimer = CurTime() + 10
		self.DisbandLeader = leader
		self.DisbandOffset = offset or Vector(0,0,0)
		self.DisbandGathered = false
		self.DisbandSpreadTimer = nil
		
		if leader == self then
			self.IsDisbandLeader = true
			local tr = util.TraceLine({
				start = pos + Vector(0, 0, 150),
				endpos = pos - Vector(0, 0, 150),
				mask = MASK_SOLID_BRUSHONLY
			})
			if tr.Hit then
				pos.z = tr.HitPos.z
			end
			self.DismissPos = pos
		else
			self.IsDisbandLeader = false
			self.DismissPos = nil
		end
	else
		self.DismissTimer = nil
		self.DismissPos = nil
		self.DisbandLeader = nil
		self.IsDisbandLeader = false
		self.DisbandGathered = true
		self.DisbandSpreadTimer = nil
	end
end

function ENT:Join(parent)
	if self.Dismissed then
		self.Dismissed = false
		self.Olimar = parent
		self:SetNWEntity("Olimar",parent)
		self.DisbandLeader = nil
		self.IsDisbandLeader = false
		self.DisbandGathered = true
		self.DisbandSpreadTimer = nil
		if IsValid(self.PikMdl) then
			self.PikMdl.CurAnim = "join"
			self.PikMdl:SetNWBool("Dismissed",false)
		end
		if not self.Drowning and not self.BurnTick and not self.Poison then
			self.Called = true
			self:EmitSound("pikmin/coming.wav")
			timer.Simple(.325,function() self.Called = false end)
		end
	end
end

function ENT:SetLevel(lvl)
	if lvl > self.Level then self.PikHP = PikHealth[self.Color] end
	self.Level = lvl
	self.PikMdl:SetModel(ColorModelTable[(self.Color-1)*3+math.min(lvl+1,3)])
	self.PikMdl.LastAnim = nil
	self.PikMdl:SetNWInt("Level",lvl)
	self.MoveForce = self.BaseMoveForce + self.Level*(self.Color == 5 and 320 or (self.Color == 4 or self.Color == 8) and 150 or 250)
end

function ENT:Charge(obj)
	if self.Carrying or self.Drinking or self.BurnTick or self.Drowning or self.Attacking or self.AttackTarget then return end
	if obj.PikIgnore then return end
	self.AttackTarget = obj
	local valid = IsCarryObject(obj)
	self.IsCarry = valid
	if valid then
		local radius = obj:OBBMins():Length()/2
		local angle = math.Rand(-math.pi,math.pi)
		self.CarryPos = PRVEC*radius*math.cos(angle)+PFVEC*radius*math.sin(angle)
	end
end

function ENT:Drop()
	self.IsCarry = nil
	if IsValid(self.AttackTarget) then
		self.Attacking = false
		if self:GetParent() == self.AttackTarget then
			local quickpos = self:GetPos()+Vector(0,0,8)
			self:SetParent()
			self:SetPos(quickpos)
		end
		self.AttackTarget = nil
	end
	if self.Carrying then
		self.Carrying = false
		if IsValid(self.CarryWeld) then self.CarryWeld:Remove() end
		local npik = self.CarryObject:GetNWInt("piki",1)-1
		if npik <= 0 then
			self.CarryObject.CarryD = nil
			self.CarryObject.CarryPath = nil
			self.CarryObject.CarrySound:Stop()
			npik = 0
		end
		local nweight = math.max(self.CarryObject:GetNWInt("weight")-self.CarryWeight,0)
		self.CarryObject:SetNWInt("weight",nweight)
		self.CarryObject.PikMove = nweight >= self.CarryObject:GetNWInt("pikiweight")
		self.CarryObject:SetNWInt("piki",npik)
		self.CarryObject.CarryTarget = nil
		self.CarryObject = nil
	end
end

function ENT:Carry(obj)
	self.IsCarry = nil
	if self.Carrying then return end
	if obj.PikIgnore then return end
	local maxCount = obj:GetNWInt("pikimax")
	local minWeight = obj:GetNWInt("pikiweight")
	local dictInfo = PikiCarryDict[obj:GetModel()]
	if maxCount == 0 then
		if dictInfo then maxCount = dictInfo[2] else maxCount = math.floor(obj:GetPhysicsObject():GetMass()/10)*2 end
		obj:SetNWInt("pikimax",maxCount)
	end
	if minWeight == 0 then
		if dictInfo then minWeight = dictInfo[1] else minWeight = math.floor(obj:GetPhysicsObject():GetMass()/10) end
		obj:SetNWInt("pikiweight",minWeight)
	end
	if obj:GetNWInt("piki") >= maxCount or not obj:GetPhysicsObject():IsMotionEnabled() then self.AttackTarget = nil return end
	obj:SetNWInt("piki",obj:GetNWInt("piki")+1)
	obj:SetNWInt("weight",obj:GetNWInt("weight")+self.CarryWeight)
	obj.PikMove = obj:GetNWInt("weight") >= minWeight
	self.Carrying = true
	self.AttackTarget = nil
	self:SetAngles(Angle(0,(obj:GetPos()-self:GetPos()):Angle().Y,0))
	self.CarryWeld = constraint.Weld(self,obj,0,0,0,true,false)
	self.CarryObject = obj
	self.CarryMass = math.Clamp(obj:GetPhysicsObject():GetMass(),400,2000)/math.max(1,self.CarryWeight/3)
	self.CarryDist = 10000
	if not obj.CarrySound then obj.CarrySound = CreateSound(obj,"pikmin/carry.wav") end
	if not obj.CarryD or (self.Color ~= 3 and obj.CarryWater) then
		obj.CarryD = true
		obj.CarryWater = self.Color == 3
		if obj.CarryTarget and self.Color ~= 3 and obj.CarryTarget:WaterLevel() >= 1 then return end
		if not obj.CarryOnion then return end
		local pathent = ents.Create("pikmin_path")
		if obj:BoundingRadius() <= 60 then pathent:SetModel(obj:GetModel()) end
		pathent:Spawn()
		pathent:SetPos(obj:GetPos())
		pathent:Activate()
		timer.Simple(0.1,function()
			if IsValid(pathent) and IsValid(obj) then
				local TargetEntity = nil
				local dropTab = ents.FindByClass("pikmin_onion")
				table.Add(dropTab, ents.FindByClass("pikmin_onion_p3"))
				table.Add(dropTab, ents.FindByClass("pikmin_onion_master"))
				
				-- Prioritize Master Onion
				local masterOnions = ents.FindByClass("pikmin_onion_master")
				if #masterOnions > 0 then
					TargetEntity = masterOnions[1]
				else
					for _, v in ipairs(dropTab) do
						local color = 0
						if v:GetClass() == "pikmin_onion_p3" then
							local p3Colors = {1, 3, 2, 7, 8}
							color = p3Colors[v:GetSkin() + 1] or 0
						elseif v:GetClass() == "pikmin_onion" then
							color = v:GetSkin() == 2 and 1 or v:GetSkin() == 1 and 2 or v:GetSkin() == 0 and 3
						end
						
						if color == self.Color then
							TargetEntity = v
							break
						end
					end
				end
				
				local targetPosForPath = IsValid(TargetEntity) and TargetEntity:GetPos() or nil
				if IsValid(TargetEntity) and (TargetEntity:GetClass() == "pikmin_onion_master" or TargetEntity:GetClass() == "pikmin_onion" or TargetEntity:GetClass() == "pikmin_onion_p3") then
					local trGround = util.QuickTrace(TargetEntity:GetPos(), Vector(0,0,-2000), {TargetEntity})
					if trGround.Hit then targetPosForPath = trGround.HitPos end
				end
				
				if not IsValid(TargetEntity) and #dropTab ~= 0 then
					TargetEntity = dropTab[1]
					for _, v in ipairs(dropTab) do
						if v:WaterLevel() < 1 then
							TargetEntity = v
							break
						end
					end
					targetPosForPath = TargetEntity:GetPos()
				end
				if IsValid(TargetEntity) and (not obj.CarryWater and TargetEntity:WaterLevel() < 1 or obj.CarryWater) then
					obj.CarryTarget = TargetEntity
					if TargetEntity:GetPos():Distance(obj:GetPos()) >= 300 then
						local path = Path("Chase")
						path:SetMinLookAheadDistance(300)
						path:SetGoalTolerance(10)
						local valid = obj.CarryWater and path:Compute(pathent,targetPosForPath,function(...) return pathent:WaterPathFunc(...) end) or not obj.CarryWater and path:Compute(pathent,targetPosForPath,function(...) return pathent:PathFunc(...) end)
						if valid and path:GetAllSegments() then
							local ntab = {}
							for _,v in ipairs(path:GetAllSegments()) do
								table.insert(ntab,v.pos)
							end
							if math.abs((ntab[1]-obj:GetPos()).Z) >= 1000 then
								obj.CarryPath = nil
							else
								obj.CarryPID = 1
								obj.CarryPath = ntab
							end
						else
							obj.CarryPID = 1
							obj.CarryPath = {TargetEntity:GetPos()}
						end
					else
						obj.CarryPID = 1
						obj.CarryPath = {TargetEntity:GetPos()}
					end
				else
					obj.CarryPath = nil
				end
			end
			if IsValid(pathent) then pathent:Remove() end
		end)
	end
end

function ENT:Think()
	if self.Dead then return end
	if self.IsHeldForThrow then
		if IsValid(self.PikMdl) then
			self.PikMdl.CurAnim = "drowning"
		end
		return
	end
	if self.LastNWThrown ~= self.Thrown then
		self.LastNWThrown = self.Thrown
		self:SetNWBool("Thrown", self.Thrown)
	end
	
	-- height detection for Purple Pikmin's groundpound
	if self.Color == 4 and self.Thrown and cvars.Bool("pik_purple_groundpound") then
		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			local vel = phys:GetVelocity()
			if self.IsGroundPounding then
				-- gradual downward acceleration (just adds negative vertical velocity each tick)
				local newZ = math.max(vel.z - 80, -900)
				phys:SetVelocity(Vector(vel.x, vel.y, newZ))
			else
				if vel.z < -10 then
					self.IsGroundPounding = true
					if IsValid(self.PikMdl) then
						self.PikMdl.CurAnim = "dosin"
					end
				end
			end
		end
	else
		self.IsGroundPounding = false
	end

	if not self.Dismissed and not self.Attacking and (not IsValid(self.Olimar) or not self.Olimar:Alive()) then self:Disband() end
	if not IsValid(self.AttackTarget) or self.AttackTarget.PikIgnore then self.AttackTarget = nil end
	
	local pos = self:GetPos()
	local speed = self:GetVelocity():Length()
	local targetPos = pos
	local minDist = 200
	local CTime = CurTime()
	local olimar = self.Olimar
	if IsValid(olimar) then
		local isOlimarPlayer = olimar:IsPlayer() -- Lots of fixes had to be made related to this throughout the addon
		local activeWep = isOlimarPlayer and olimar:GetActiveWeapon()
		local isSwarming = IsValid(activeWep) and activeWep:GetClass() == "olimar_gun" and activeWep.Swarm
		local isPlayAsPikmin = isOlimarPlayer and olimar:GetNWBool("ispikmin", false)
		local useMesh = GetConVar("piki_mesh"):GetBool() and not self.Dismissed and not self.Attacking and not self.Carrying and not self.Poison and not olimar.SwarmVec and not isSwarming and not isPlayAsPikmin
		if useMesh then
			-- update squad mesh positions once per frame
			if not olimar.LastSquadUpdate or olimar.LastSquadUpdate ~= CTime then
				olimar.LastSquadUpdate = CTime
				
				local squad = {}
				for _, p in ipairs(ents.FindByClass("pikmin")) do
					if IsValid(p) and p.Olimar == olimar and not p.Dismissed and not p.Attacking and not p.Carrying and not p.Poison and not p.Dead then
						table.insert(squad, p)
					end
				end
				
				local held = olimar:GetNWEntity("piki")
				local selectedColor = (IsValid(held) and held.Color) or olimar:GetNWInt("SelectedPikiColor", 0)
				
				local defaultOrder = {
					[1] = 1, -- Red
					[2] = 2, -- Yellow
					[3] = 3, -- Blue
					[4] = 4, -- Purple
					[5] = 5, -- White
					[7] = 6, -- Winged
					[8] = 7, -- Rock
					[6] = 8, -- Bulbmin
					[9] = 9  -- Mushroom
				}
				-- note: come back to this later for Glow and Ice Pikmin
				-- note 2: let's hope that time actually comes if the stupid animations ever port correctly

				table.sort(squad, function(a, b)
					local pA = (a.Color == selectedColor) and 0 or (defaultOrder[a.Color] or 99)
					local pB = (b.Color == selectedColor) and 0 or (defaultOrder[b.Color] or 99)
					
					if pA ~= pB then
						return pA < pB
					end
					
					if a.Level ~= b.Level then
						return a.Level < b.Level
					end
					return a:EntIndex() < b:EntIndex()
				end)
				
				for k, p in ipairs(squad) do
					p.MeshIndex = k
					p.MeshSquadSize = #squad
				end
			end
			-- ok crazy math time 

			if self.MeshIndex then
				local k = self.MeshIndex
				local squadSize = self.MeshSquadSize or 1
				local squadScale = 0.9 + math.min(100, squadSize) / 200
				local spacingScale = GetConVar("piki_mesh_spacing"):GetFloat()
				local shape = GetConVar("piki_mesh_shape"):GetString()
				
				local localX, localY = 0, 0
				
				if shape == "circle" then
					local ring = 0
					local ringIndex = 1
					local ringCount = 1
					local remaining = k
					while remaining > 0 do
						local ringCapacity = (ring == 0) and 1 or (ring * 6)
						if remaining <= ringCapacity then
							ringIndex = remaining
							ringCount = ringCapacity
							remaining = 0
						else
							remaining = remaining - ringCapacity
							ring = ring + 1
						end
					end
					local rVal = (ring == 0) and 0 or (28 + ring * 22) * squadScale * spacingScale
					local theta = (ringCount == 1) and 0 or (ringIndex / ringCount) * 2 * math.pi
					localX = -70 * squadScale * spacingScale + rVal * math.cos(theta)
					localY = rVal * math.sin(theta)
				elseif shape == "square" then
					local width = math.ceil(math.sqrt(squadSize))
					local r = math.floor((k - 1) / width) + 1
					local c = ((k - 1) % width) + 1
					local col_centered = c - (width + 1) / 2
					localX = -45 * squadScale * spacingScale - (r - 1) * 18 * squadScale * spacingScale
					localY = col_centered * 18 * squadScale * spacingScale
				elseif shape == "diamond" then
					local width = math.ceil(math.sqrt(squadSize))
					local r = math.floor((k - 1) / width) + 1
					local c = ((k - 1) % width) + 1
					local row_centered = r - (width + 1) / 2
					local col_centered = c - (width + 1) / 2
					local gridX = row_centered * 18 * squadScale * spacingScale
					local gridY = col_centered * 18 * squadScale * spacingScale
					local rotX = (gridX - gridY) * 0.7071
					local rotY = (gridX + gridY) * 0.7071
					localX = -70 * squadScale * spacingScale + rotX
					localY = rotY
				elseif shape == "triangle" then
					local r = 1
					local col = 1
					local remaining = k
					while remaining > 0 do
						local rowCapacity = 1 + r * 2
						if remaining <= rowCapacity then
							col = remaining
							remaining = 0
						else
							remaining = remaining - rowCapacity
							r = r + 1
						end
					end
					local rowCapacityReal = 1 + r * 2
					local col_centered = col - (rowCapacityReal + 1) / 2
					localX = -35 * squadScale * spacingScale - (r - 1) * 18 * squadScale * spacingScale
					localY = col_centered * 18 * squadScale * spacingScale
				elseif shape == "hexagon" then
					local width = math.ceil(math.sqrt(squadSize))
					local r = math.floor((k - 1) / width) + 1
					local c = ((k - 1) % width) + 1
					local col_centered = c - (width + 1) / 2
					local colSpacing = 18 * squadScale * spacingScale
					local rowSpacing = 15.588 * squadScale * spacingScale
					local shift = (r % 2 == 0) and 0.5 or 0
					localX = -45 * squadScale * spacingScale - (r - 1) * rowSpacing
					localY = (col_centered + shift) * colSpacing
				else -- default: wedge
					local r = 1
					local col = 1
					local remaining = k
					while remaining > 0 do
						local rowCapacity = 1 + r * 2
						if remaining <= rowCapacity then
							col = remaining
							remaining = 0
						else
							remaining = remaining - rowCapacity
							r = r + 1
						end
					end
					local rowCapacityReal = 1 + r * 2
					local col_centered = col - (rowCapacityReal + 1) / 2
					local rVal = (35 + r * 18) * squadScale * spacingScale
					local thetaDiv = 0.7 + 0.14 * r
					local theta = math.pi + (col_centered * (0.32 * squadScale * spacingScale) / thetaDiv)
					localX = rVal * math.cos(theta)
					localY = rVal * math.sin(theta)
				end
				-- I hope this is performant enough theoretically but it will do for now, will focus on optimization another time
				
				if not olimar.PikiMeshAngle then
					olimar.PikiMeshAngle = olimar:GetAngles().y
				end
				
				local targetYaw = olimar:GetAngles().y
				olimar.PikiMeshAngle = math.ApproachAngle(olimar.PikiMeshAngle, targetYaw, FrameTime() * 120)
				
				local smoothedAng = Angle(0, olimar.PikiMeshAngle, 0)
				local smoothedForward = smoothedAng:Forward()
				local smoothedRight = smoothedAng:Right()
				
				local yMul = self.Color == 4 and 1.25 or 1.0 -- Purples spread a bit more
				targetPos = olimar:GetPos() + smoothedForward * localX + smoothedRight * (localY * yMul)
				minDist = 8
			else
				targetPos = olimar:GetPos()
				minDist = 80
			end
		else
			self.MeshIndex = nil
			self.MeshSquadSize = nil
			
			targetPos = olimar:GetPos()
			if olimar.SwarmVec then
				targetPos = targetPos + olimar.SwarmVec
				minDist = 50
			else
				local tpik = olimar:GetNWEntity("piki")
				if IsValid(tpik) and tpik ~= olimar then
					if tpik.Color ~= self.Color or tpik.Level ~= self.Level then
						minDist = 50
						targetPos = targetPos - olimar:GetAngles():Forward()*120
					else
						minDist = 80
					end
				end
			end
		end
	end
	
	if self.Carrying then
		self.AttackTarget = nil
		minDist = 300
		if not IsValid(self.CarryObject) then
			self.Carrying = false
		else
			if not self.CarryObject.PikMove then targetPos = pos end
			if not IsValid(self.CarryWeld) or self.CarryObject.PikIgnore or not self.CarryObject.IsCarry or not self.CarryObject.CarryD or math.abs(self:GetAngles()[3]) >= 75 then self:Drop() end
			if self.CarryObject and self.CarryObject.CarryPath and self.CarryObject.PikMove then
				local pid = self.CarryObject.CarryPID
				targetPos = self.CarryObject.CarryPath[pid]
				minDist = 0

				-- Winged Pikmin lifting logic
				if self.Color == 7 then
					local isLastSegment = pid >= #self.CarryObject.CarryPath
					if not isLastSegment then
						targetPos = targetPos + Vector(0, 0, 150) -- Lift height
					end
					if IsValid(self.Phys) then
						self.Phys:ApplyForceCenter(Vector(0, 0, self.CarryMass * 100))
					end
				end

				if math.abs((targetPos-pos).Z) >= 1000 then
					targetPos = pos
					self:Drop()
				end
				if self.CarryObject and self.CarryObject:GetPos():DistToSqr(targetPos) <= (self.Color == 7 and 50000 or self.CarryDist) then
					local nid = pid + 1
					local c = #self.CarryObject.CarryPath
					if nid > c then
						self.CarryObject.CarryPath = nil
						if IsValid(self.CarryObject.CarryTarget) then
							if self.CarryObject.CarryTarget.Pull then
								self.CarryObject.CarryTarget:Pull(self.CarryObject)
							end
						end
					elseif nid == c then
						self.CarryDist = 8000
					end
					self.CarryObject.CarryPID = nid
				end
			end
		end
	end
	
	if self.AttackTarget then
		targetPos = self.AttackTarget:GetPos()
		if self.IsCarry then
			targetPos = targetPos + self.CarryPos
		end
		minDist = 0
	end
	
	if self.DismissPos and self.Dismissed then targetPos = self.DismissPos minDist = 50 end
	
	if self.Color == 7 then
		local isSwarming = IsValid(self.Olimar) and self.Olimar.SwarmVec
		-- Only add the hover offset when NOT in a structured disband (the disband
		-- target already has the +75 baked in via terrain projection).
		local inStructuredDisband = self.Dismissed and IsValid(self.DisbandLeader)
		if not isSwarming and not self.AttackTarget and not self.PikPly and not inStructuredDisband then
			targetPos = targetPos + Vector(0,0,75)
		end
		local shouldFloat = not self.Thrown and not self.Dead
		if IsValid(self.Phys) then
			if self.Phys:IsGravityEnabled() == shouldFloat then
				self.Phys:EnableGravity(not shouldFloat)
			end
			if shouldFloat then
				local vel = self.Phys:GetVelocity()
				-- Use the same friction during disband so Winged Pikmin decelerate properly
				local friction = (not self.Carrying and not self.Attacking) and 0.5 or 0.15
				self.Phys:ApplyForceCenter(-vel * friction)
			end
		end
	end
	
	local OnFire = self:IsOnFire()
	local InWater = self:WaterLevel() >= 1
	
	if self.Poison then
		if OnFire then self:Extinguish() end
		if self.Carrying then self:Drop() end
		if not self.GasTick then
			self.GasTick = CTime + 5
			self.GasCryNext = CTime
			self.PikMdl:SetNWBool("Poison",true)
		end
		if CTime >= self.GasTick then
			self:Die()
		end
		if CTime >= self.GasCryNext then
			self.GasCryNext = CTime + math.Rand(0.3,0.8)
			self:EmitSound(PikiSoundGas[math.random(1,#PikiSoundGas)])
		end
		targetPos = pos + Vector(math.Rand(-500,500), math.Rand(-500,500), 0)
	else
		if self.GasTick then self.GasTick = nil self.PikMdl:SetNWBool("Poison",false) end
	end
	
	if OnFire then
		if self.Color == 1 or self.Color == 6 or self.Color == 9 then
			self:Extinguish()
		else
			if self.Poison then self.Poison = false end
			if self.Thrown then self.Thrown = false end
			if self.Carrying then self:Drop() end
			if not self.BurnTick then
				self.BurnTick = CTime + 5
				self.BurnCryNext = CTime
			end
			if CTime >= self.BurnTick then
				self:Die()
			end
			if CTime >= self.BurnCryNext then
				self.BurnCryNext = CTime + math.Rand(0.5,1)
				self:EmitSound(PikiSoundBurn[math.random(1,#PikiSoundBurn)])
			end
			targetPos = pos + Vector(math.Rand(-500,500), math.Rand(-500,500), 0)
		end
	else
		if self.BurnTick then self.BurnTick = nil end
	end
	
	if InWater then
		if OnFire then self:Extinguish() end
		if self.Poison then self.Poison = false end
		if self.Thrown then self.Thrown = false end
		if not (self.Color == 3 or self.Color == 6 or self.Color == 9 or self.Color == 7) then
			minDist = 30
			if self.Carrying then self:Drop() end
			self.Drowning = true
			self.Phys:ApplyForceCenter(Vector(0, 0, (self.Color == 4 or self.Color == 8) and 70 or self.Color == 5 and 40 or 50))
			if not self.DrownTick then
				self.DrownCall = CTime
				self:EmitSound("pikmin/drowning.wav")
				self.DrownTick = CTime + 5
			end
			if CTime >= self.DrownTick then
				self:Die()
			end
		end
	else
		if self.DrownTick then
			self.DrownTick = nil
			self.Drowning = false
			self.DrownCall = nil
			self:StopSound("pikmin/drowning.wav")
		end
	end
	
	if self.Attacking then
		if self.AttackTarget:IsOnFire() and not OnFire and not (self.Color == 1 or self.Color == 6 or self.Color == 9) then self:Ignite(1000,0) end
		if self.Poison or OnFire or self.DrownTick then
			self.Attacking = false
			self.AttackTarget = nil
			local quickpos = self:GetPos() + Vector(0, 0, 8)
			self:SetParent()
			self:SetPos(quickpos)
		else
			if CTime >= self.NextAttack then
				self.NextAttack = CTime + 0.75
				local dmg = self.Damage ~= 0 and self.Damage+self.Level*2 or 0
				if self.AttackTarget:Health() - dmg <= 0 then
					for k,v in ipairs(ents.FindByClass("pikmin")) do
						if v.AttackTarget == self.AttackTarget and v ~= self then
							v.Attacking = false
							v.AttackTarget = nil
							local quickpos = v:GetPos() + Vector(0, 0, 8)
							v:SetParent()
							v:SetPos(quickpos)
						end
					end
					self.Attacking = false
					local quickpos = self:GetPos() + Vector(0, 0, 8)
					self:SetParent()
					self:SetPos(quickpos)
					self.AttackTarget:TakeDamage(dmg, self.PikPly and self or self.Olimar, self)
					self.AttackTarget = nil
				else
					self.AttackTarget:TakeDamage(dmg, self.PikPly and self or self.Olimar, self)
				end
				self:EmitSound("pikmin/hit.wav", 100, math.random(98, 105))
			end
		end
	end
	
	-- base animation selection
	local baseAnim = self.Called and "join" or self.Attacking and "attack" or self.Drinking and "nectar" or (self.IsGroundPounding and "dosin") or self.Thrown and "thrown" or (OnFire or self.Poison) and "onfire" or self.Drowning and "drowning" or InWater and "swimming" or speed >= 6 and (self.Color == 7 and self.WingedIdle or "running") or (self.Dismissed and (self.Color == 7 and self.WingedIdle or "dismissed") or self.WingedIdle)

	-- Idle animation state
	local isDoingIdleStuff = self.Dismissed and (baseAnim == "dismissed" or baseAnim == "idle" or baseAnim == self.WingedIdle) and speed < 30
	if not isDoingIdleStuff then
		-- Interrupt any plaaying idle animation when the Pikmin has something to do or is moving/squaded.
		if self.IdleAnimState then
			self.IdleAnimState = nil
			self.IdleAnimEnd = nil
			self.IdleAnimSitMidDone = nil
			self.IdleAnimCurrent = nil
			self.IdleAnimIsBackward = nil
			if IsValid(self.PikMdl) then
				self.PikMdl.PlaybackRate = 1.0
				self.PikMdl:SetPlaybackRate(1.0)
			end
		end
	end

	if self.IdleAnimState then
		local mdl = self.PikMdl
		if IsValid(mdl) then
			if self.IdleAnimState == "playing" then
				if CTime >= (self.IdleAnimEnd or 0) then
					-- lookback animations need to play both forward and then backwards
					if IsLookbackAnim(self.IdleAnimCurrent or "") and not self.IdleAnimIsBackward then
						self.IdleAnimIsBackward = true
						
						local fullDur = mdl:SequenceDuration(self.IdleAnimCurrent) or 2.0
						if fullDur <= 0 then fullDur = 2.0 end
						self.IdleAnimEnd = CTime + (fullDur / 0.85)
						
						mdl:SetCycle(1.0) -- Start backward playback from the end frame
					-- Check for the sit animation'
					elseif IsSitAnim(self.IdleAnimCurrent or "") and not self.IdleAnimSitMidDone then
						-- intro finished, choose next state
						local sitHoldDur = self.IdleAnimSitHoldDur or math.Rand(1.0, 2.0)
						if self.Color == 4 or self.Color == 8 or self.Color == 5 then
							-- Purple, Rock, White have branching choices
							-- the rest will likely not as their animations are totally screwed
							local branchChance = math.random()
							if branchChance < 0.5 then
								-- choose sitlean or sitlookup
								local branchAnim = "sitlean"
								if self.Color == 5 and math.random() < 0.5 then
									branchAnim = "sitlookup"
								end
								
								self.IdleAnimCurrent = branchAnim
								self.IdleAnimState = "sitting_branch"
								
								local branchDur = mdl:SequenceDuration(branchAnim) or 1.5
								if branchDur <= 0 then branchDur = 1.5 end
								self.IdleAnimEnd = CTime + (branchDur / 0.85)
								self.IdleAnimSitMidDone = true
							else
								-- Stay sitting
								self.IdleAnimState = "sitting_hold" -- Good boy
								self.IdleAnimEnd = CTime + sitHoldDur
								self.IdleAnimSitMidDone = true
							end
						else
							-- Red, Blue, Yellow stay sitting
							self.IdleAnimState = "sitting_hold" -- Good boy
							self.IdleAnimEnd = CTime + sitHoldDur
							self.IdleAnimSitMidDone = true
						end
					else
						-- end idle animation
						self.IdleAnimState = nil
						self.IdleAnimEnd = nil
						self.IdleAnimSitMidDone = nil
						self.IdleAnimCurrent = nil
						self.IdleAnimIsBackward = nil
					end
				end
			elseif self.IdleAnimState == "sitting_hold" then
				if CTime >= (self.IdleAnimEnd or 0) then
					-- the sitting hold finished, so play stand-up outro
					self.IdleAnimState = "playing"
					local sitAnim = (self.Color == 4 or self.Color == 8 or self.Color == 5) and "sitnstand" or "stretch"
					self.IdleAnimCurrent = sitAnim
					
					local startCycle = (self.Color == 4 or self.Color == 8 or self.Color == 5) and 0.5 or 0.4
					mdl.Cycle = startCycle -- Sync start cycle to the Pikmin's model
					
					local fullDur = mdl:SequenceDuration(sitAnim) or 2.0
					if fullDur <= 0 then fullDur = 2.0 end
					
					local outroDur = (1.0 - startCycle) * fullDur
					self.IdleAnimEnd = CTime + (outroDur / 0.85)
					self.IdleAnimSitMidDone = true
				end
			elseif self.IdleAnimState == "sitting_branch" then
				if CTime >= (self.IdleAnimEnd or 0) then
					-- stand-up outro 2
					self.IdleAnimState = "playing"
					local sitAnim = "sitnstand"
					self.IdleAnimCurrent = sitAnim
					
					mdl.Cycle = 0.5
					
					local fullDur = mdl:SequenceDuration(sitAnim) or 2.0
					if fullDur <= 0 then fullDur = 2.0 end
					
					local outroDur = 0.5 * fullDur
					self.IdleAnimEnd = CTime + (outroDur / 0.85)
					self.IdleAnimSitMidDone = true
				end
			end
		end
	end

	if self.IdleAnimCurrent and self.IdleAnimState then
		self.PikMdl.CurAnim = self.IdleAnimCurrent

		if self.IdleAnimState == "sitting_hold" then
			self.PikMdl.PlaybackRate = 0
			self.PikMdl:SetPlaybackRate(0)
			local freezeCycle = (self.Color == 4 or self.Color == 8 or self.Color == 5) and 0.5 or 0.4
			self.PikMdl:SetCycle(freezeCycle)
		else
			-- Set playback rate to negative for backward phase
			local rate = self.IdleAnimIsBackward and -0.85 or 0.85
			self.PikMdl.PlaybackRate = rate
			self.PikMdl:SetPlaybackRate(rate)
		end
	else
		self.PikMdl.CurAnim = baseAnim
		if IsValid(self.PikMdl) then
			if baseAnim == "dosin" then
				local cycle = self.PikMdl:GetCycle()
				if cycle >= 0.95 then
					self.PikMdl.PlaybackRate = 0
					self.PikMdl:SetPlaybackRate(0)
					self.PikMdl:SetCycle(0.99)
				else
					self.PikMdl.PlaybackRate = 1.0
					self.PikMdl:SetPlaybackRate(1.0)
				end
			else
				self.PikMdl.PlaybackRate = 1.0
				self.PikMdl:SetPlaybackRate(1.0) -- Reset to default rate
			end
		end
	end

	-- idle sounds
	if cvars.Bool("pik_idle") and CTime >= (self.IdleSoundNext or 0) then
		local nextIdle = IsValid(self.Olimar) and self.Olimar.NextPikiIdle or PIKI_GLOBAL_NEXT_IDLE or 0
		if CTime >= nextIdle then
			local idleChance = self.Color == 9 and 0.07 or 0.05
			local canIdle = self.Color == 9 or self.Dismissed or speed < 5
			if canIdle and not self.Thrown and not OnFire and not self.Poison and not self.Drowning and not self.Attacking and not self.Drinking and math.random() < idleChance then
				local snd = self.Color == 9 and "pikmin/puffmin_idle.wav" or PikiSoundIdle[math.random(1, #PikiSoundIdle)]
				self:EmitSound(snd, 60, math.random(95, 110))
				self.IdleSoundNext = CTime + 15
				local nextVal = CTime + math.random(5, 15)
				if IsValid(self.Olimar) then
					self.Olimar.NextPikiIdle = nextVal
				else
					PIKI_GLOBAL_NEXT_IDLE = nextVal
				end
			end
		end
	end

	-- idle animation trigger block
	if isDoingIdleStuff and not self.IdleAnimState then
		self.NextIdleAnimCheck = self.NextIdleAnimCheck or (CTime + math.random(3, 8))
		if CTime >= self.NextIdleAnimCheck then
			-- reset check timer 
			self.NextIdleAnimCheck = CTime + math.random(4, 8)
			
			--  every Pikmin has a 40% chance of starting an idle animation when check timer fires
			if math.random() < 0.4 then
				local animTable = GetIdleAnimTable(self.Color)
				if animTable then
					local anim = animTable[math.random(#animTable)]
					self.IdleAnimCurrent = anim
					self.IdleAnimSitMidDone = false
					self.IdleAnimIsBackward = false
					
					local mdl = self.PikMdl
					local seqDur = IsValid(mdl) and mdl:SequenceDuration(anim) or 2.0
					if seqDur <= 0 then seqDur = 2.0 end
					
					if IsSitAnim(anim) then
						self.IdleAnimState = "playing"
						local sitIntroRatio = (self.Color == 4 or self.Color == 8 or self.Color == 5) and 0.5 or 0.4
						self.IdleAnimEnd = CTime + (sitIntroRatio * seqDur / 0.85)
						self.IdleAnimSitHoldDur = math.Rand(1.0, 2.0) -- Sitting duration is multiplied by 1-2x
					else
						self.IdleAnimState = "playing"
						self.IdleAnimEnd = CTime + (seqDur / 0.85)
					end
					
					-- Set NextIdleAnimCheck to  after the animation finishes plus a cooldown
					self.NextIdleAnimCheck = self.IdleAnimEnd + math.random(6, 15)
				end
			end
		end
	elseif not isDoingIdleStuff then
		self.NextIdleAnimCheck = nil
	end
	if not self.Called and not self.Drinking and not self.Attacking then
		if self.Dismissed then
			minDist = 30
			if IsValid(self.DisbandLeader) then
				if self.IsDisbandLeader then
					if self.DismissPos then
						targetPos = self.DismissPos
						minDist = 32
						if pos:Distance(self.DismissPos) <= 32 or (self.DismissTimer and CTime >= self.DismissTimer) then
							self.DismissPos = nil
							self.DismissTimer = nil
						end
					else
						targetPos = pos
					end
				else
					if not self.DisbandGathered then
						local leaderPos = self.DisbandLeader:GetPos()
						if self.DisbandLeader.Color == 7 then
							leaderPos = leaderPos - Vector(0, 0, 75)
						end
						targetPos = leaderPos
						if self.Color == 7 then
							targetPos = targetPos + Vector(0, 0, 75)
						end
						
						local leaderArrived = not self.DisbandLeader.DismissPos or self.DisbandLeader:GetPos():Distance(self.DisbandLeader.DismissPos) <= 50
						if (leaderArrived and pos:Distance(leaderPos) <= 80) or (self.DismissTimer and CTime >= self.DismissTimer) then
							self.DisbandGathered = true
							self.DisbandSpreadTimer = CTime + 1.5
						end
					else
						if CTime < (self.DisbandSpreadTimer or 0) then
							local leaderPos = self.DisbandLeader:GetPos()
							if self.DisbandLeader.Color == 7 then
								leaderPos = leaderPos - Vector(0, 0, 75)
							end
							local targetGround = leaderPos + self.DisbandOffset
							
							-- project oonto terrain slopes
							local tr = util.TraceLine({
								start = targetGround + Vector(0, 0, 150),
								endpos = targetGround - Vector(0, 0, 150),
								mask = MASK_SOLID_BRUSHONLY
							})
							if tr.Hit then
								targetGround.z = tr.HitPos.z
							end
							
							targetPos = targetGround
							if self.Color == 7 then
								targetPos = targetPos + Vector(0, 0, 75)
							end
						else
							targetPos = pos
							self.DisbandLeader = nil
						end
					end
				end
			else
				if self.DismissPos then
					targetPos = self.DismissPos
					minDist = 32
					if pos:Distance(self.DismissPos) <= 32 or (self.DismissTimer and CTime >= self.DismissTimer) then
						self.DismissPos = nil
						self.DismissTimer = nil
					end
				else
					targetPos = pos
				end
			end
		end

		local targetDist = pos:Distance(targetPos)
		
		if targetDist >= 1400 and not self.Attacking and not self.AttackTarget and not self.Dismissed and not self.Drowning and not (OnFire or self.Poison) and (not self.Carrying or minDist ~= 0) then if self.Carrying then self:DisbandCarry() else self:Disband() end end
		
		-- I removed whatever comment was here it didn't seem important
		
		local isMovingDisband = self.DismissPos or (IsValid(self.DisbandLeader) and (not self.DisbandGathered or CTime < (self.DisbandSpreadTimer or 0)))
		if not self.Thrown and (not self.Dismissed or isMovingDisband or OnFire or self.Carrying or self.Poison) and targetDist >= minDist and CTime >= self.NextHop then
			self.NextHop = CTime + 0.1
			
			if self.Carrying and self.CarryObject:GetVelocity():Length() >= 5 and not self.CarryObject.CarrySound:IsPlaying() then
				self.CarryObject.CarrySound:Play()
			end
			
			local dirVec = targetPos - pos
			local dist = dirVec:Length()
			
			local finalSpeed = self.MoveForce
			if self.Dismissed then
				if not self.IsDisbandLeader and (not self.DisbandGathered or (self.DisbandSpreadTimer and CTime < self.DisbandSpreadTimer)) then
					finalSpeed = self.BaseMoveForce * 0.6
				elseif not self.DismissPos and not OnFire and not self.Carrying then
					finalSpeed = 400
				end
			end
			if self.Carrying then finalSpeed = self.CarryMass*self.CarryWeight*4 + self.MoveForce end
			
			-- Cap White Pikmin speed when far from their mesh position to prevent aimless running
			local isSwarming = false
			local isPlayAsPikmin = false
			local olimar = self.Olimar
			if IsValid(olimar) then
				local isOlimarPlayer = olimar:IsPlayer()
				local activeWep = isOlimarPlayer and olimar:GetActiveWeapon()
				isSwarming = IsValid(activeWep) and activeWep:GetClass() == "olimar_gun" and activeWep.Swarm
				isPlayAsPikmin = isOlimarPlayer and olimar:GetNWBool("ispikmin", false) -- small fixes 
			end
			local useMesh = GetConVar("piki_mesh"):GetBool() and IsValid(olimar) and not self.Dismissed and not self.Attacking and not self.Carrying and not self.Poison and not (olimar and olimar.SwarmVec) and not isSwarming and not isPlayAsPikmin
			if useMesh and self.Color == 5 and dist > 50 then
				finalSpeed = math.min(finalSpeed, 700)
			end
			
			if self.Color == 7 then
				local pointContents = util.PointContents(targetPos - Vector(0, 0, 20))
				if bit.band(pointContents, CONTENTS_WATER) != 0 then
					local waterTr = util.TraceLine({
						start = targetPos + Vector(0, 0, 500),
						endpos = targetPos - Vector(0, 0, 200),
						mask = MASK_WATER
					})
					if waterTr.Hit then
						targetPos.z = waterTr.HitPos.z + 50
						dirVec = targetPos - pos
						dist = dirVec:Length()
					end
				end
			end

			-- Distance-based deceleration/damping to prevent overshooting/jiggling
			local easeDist = self.Color == 7 and 60 or 32
			if dist < easeDist then
				finalSpeed = finalSpeed * (dist / easeDist)
			end
			
			if speed <= math.max(50, finalSpeed / 4) then
				if InWater and self.Color ~= 7 then
					self.Phys:ApplyForceCenter(dirVec * (self.Color == 3 and 10 or self.Color == 6 and 30 or self.Color == 9 and 10 or (self.DrownCall and CTime < self.DrownCall and 5 or 0)))
				else
					local finalVec = Vector(dirVec.X,dirVec.Y,self.Color == 7 and dirVec.Z or 0):GetNormalized()
					self.Phys:ApplyForceCenter(finalVec * finalSpeed + self.ZForceVector)
				end
			end
			if CTime >= self.NextObHop then
				self.NextObHop = CTime + 1.5
				if not InWater then
					local qpos = pos + Vector(0,0,4)
					local ptab = ents.FindByClass("pikmin")
					local tr = util.QuickTrace(qpos, self:GetForward() * 20, ptab)
					if self.Carrying and not tr.HitWorld then tr = util.QuickTrace(qpos, self:GetForward() * -30, ptab) end
					if tr.HitWorld then
						self.Phys:ApplyForceCenter(self.Carrying and self.HighJumpVector or self.JumpVector)
					end
				end
			end
		else
			if self.Carrying and self.CarryObject:GetVelocity():Length() < 5 and self.CarryObject.CarrySound:IsPlaying() then self.CarryObject.CarrySound:FadeOut(0.1) end
		end
	end
	
	if CTime >= self.NextAI then
		self.NextAI = CTime + 0.5
		if self.AttackTarget and self.AttackTarget.IsCarry then
			local max = self.AttackTarget:GetNWInt("pikimax")
			if max ~= 0 and self.AttackTarget:GetNWInt("piki") >= self.AttackTarget:GetNWInt("pikimax") then self.AttackTarget = nil end
		end
	end
	
	self:NextThink(CurTime() + 0.03)
	return true
end

function ENT:CreatePikRagdoll(dis)
	local mdl = self.PikMdl
	--w00t at TetaBonita for the ragdoll code!
	local rag = ents.Create("prop_ragdoll")
	rag:SetModel(mdl:GetModel())
	rag:SetPos(mdl:GetPos())
	rag:SetAngles(mdl:GetAngles())
	rag:Spawn()
	if not IsValid(rag) then
		return
	end
	rag:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
	local entvel = self:GetVelocity()
	local entphys = self.Phys
	if IsValid(entphys) then entvel = entphys:GetVelocity() end
	for i = 1, rag:GetPhysicsObjectCount() do
		local bone = rag:GetPhysicsObjectNum(i)
		if IsValid(bone) then
			local bonepos,boneang = mdl:GetBonePosition(rag:TranslatePhysBoneToBone(i))
			bone:SetPos(bonepos)
			bone:SetAngles(boneang)
			if (dis) then --is this for the dissolve effect?
				bone:ApplyForceOffset(self:GetVelocity() * 0.04, self:GetPos())
				bone:AddVelocity(entvel * 0.05)
				bone:AddVelocity(Vector(0,0,10))
				bone:EnableGravity(false)
			else
				bone:ApplyForceOffset(self:GetVelocity(), self:GetPos())
				bone:AddVelocity(entvel)
			end
		end
	end
	rag:SetSkin(mdl:GetSkin())
	rag:SetColor(mdl:GetColor())
	rag:SetMaterial(mdl:GetMaterial())
	rag:Activate()
	return rag
end

local function CreateDeathSoul(pos,color)
	if color:Length() ~= 0 then
		local effectdata = EffectData()
		effectdata:SetOrigin(pos + Vector(0,0,15))
		effectdata:SetStart(color/2)
		util.Effect("pikmin_deathsoul",effectdata)
	end
end

local function DeathRagdoll(ent, pikColor)
	if IsValid(ent) then
		local pos = ent:GetPos()
		CreateDeathSoul(pos,DeathColorVectors[pikColor])
		if pikColor == 7 then
			sound.Play("pikmin/pikmin_pink_die.wav", pos, 100, math.random(95, 110), 1)
		elseif pikColor == 8 then
			sound.Play("pikmin/pikmin_rock_die.wav", pos, 100, math.random(95, 110), 1)
		else
			sound.Play("pikmin/pikmin_pop.wav", pos, 100, math.random(95, 110), 1)
		end
	end
end

function ENT:Die()
	if self.Dead then return end
	self.Dead = true
	if IsValid(self.CarryObject) then
		local npik = self.CarryObject:GetNWInt("piki",1)-1
		if npik <= 0 then
			self.CarryObject.CarryD = nil
			self.CarryObject.CarryPath = nil
			self.CarryObject.CarrySound:Stop()
			npik = 0
		end
		local nweight = math.max(self.CarryObject:GetNWInt("weight")-self.CarryWeight,0)
		self.CarryObject:SetNWInt("weight",nweight)
		self.CarryObject.PikMove = nweight >= self.CarryObject:GetNWInt("pikiweight")
		self.CarryObject:SetNWInt("piki",npik)
		self.CarryObject = nil
	end
	
	local pikColor = self.Color
	self.Olimar = nil
	self:StopSound("pikmin/drowning.wav")
	self:SetCollisionGroup(COLLISION_GROUP_WORLD)
	
	self:EmitSound(self.Shock and "pikmin/pikmin_shock.wav" or
	(self.BurnTick or self.Poison) and "pikmin/pikmin_die3.wav" or
	self.Drowning and "pikmin/pikmin_die2.wav" or "pikmin/pikmin_die.wav")
	
	if self.Shock then
		self.PikMdl:Remove()
		local effectdata = EffectData()
		effectdata:SetOrigin(self:GetPos())
		util.Effect("pikmin_shock",effectdata)
		timer.Simple(0.25,function() if not IsValid(self) then return end DeathRagdoll(self, pikColor) self:Remove() end)
		return
	end
	
	local rag = self:CreatePikRagdoll(false)
	if self.BurnTick then rag:Ignite(math.Rand(8,10),0) end
	timer.Simple(math.Rand(1.6, 2.5),function() if not IsValid(rag) then return end DeathRagdoll(rag, pikColor) rag:Remove() end)
	if pikColor == 5 then self.PikMdl:Remove() return end
	self:Remove()
end

function ENT:OnRemove()
	if IsValid(self.CarryObject) then
		local npik = self.CarryObject:GetNWInt("piki",1)-1
		if npik <= 0 then
			self.CarryObject.CarryD = nil
			self.CarryObject.CarryPath = nil
			self.CarryObject.CarrySound:Stop()
			npik = 0
		end
		local nweight = math.max(self.CarryObject:GetNWInt("weight")-self.CarryWeight,0)
		self.CarryObject:SetNWInt("weight",nweight)
		self.CarryObject.PikMove = nweight >= self.CarryObject:GetNWInt("pikiweight")
		self.CarryObject:SetNWInt("piki",npik)
	end
end

function ENT:OnTakeDamage(DMGInfo)
	if self.Dead then return end
	local dmg,dmgType = DMGInfo:GetDamage(),DMGInfo:GetDamageType()
	
	if DMGInfo:IsDamageType(DMG_BURN) then if not (self.Color == 1 or self.Color == 6 or self.Color == 9) then self:Ignite(1000,0) end return end
	
	if DMGInfo:IsDamageType(DMG_SHOCK) or DMGInfo:IsDamageType(DMG_ENERGYBEAM) then
		if self.Color == 2 or self.Color == 6 or self.Color == 9 then return end
		self.Shock = true
		self:Die()
		return
	end
	
	local inflict = DMGInfo:GetInflictor()
	if DMGInfo:IsDamageType(DMG_POISON) and (inflict:GetClass() == "pikmin_gas" or inflict:GetClass() == "pikmin") then
		if not (self.Color == 5 or self.Color == 6) then self.Poison = true end
		return
	end
	
	self.PikHP = self.PikHP - dmg
	if self.PikHP <= 0 then
		if self.Color == 5 and not self.Shock and cvars.Bool("pik_white_poisongas") then --Poison the bastards that killed us
			local ef = EffectData()
			ef:SetOrigin(self:GetPos())
			util.Effect("pikmin_poison", ef)
			local poisonpos = self:GetPos()
			local pikolimar = self.Olimar
			local poisonrep = math.random(10,12)
			timer.Create("PikPoison"..self:EntIndex(), 0.9, poisonrep, function()
				if not IsValid(self) then return end
				local dmg = DamageInfo()
				dmg:SetDamage(math.random(1,2))
				dmg:SetAttacker(pikolimar or self)
				dmg:SetInflictor(self)
				dmg:SetDamageType(DMG_POISON)
				for k,v in ipairs(ents.FindInSphere(poisonpos, 125)) do
					if v:IsPlayer() or v:IsNPC() or v:GetClass() == "pikmin" then
						v:TakeDamageInfo(dmg)
					end
				end
				poisonrep = poisonrep - 1
				if poisonrep <= 0 then self:Remove() end
			end)
			undo.ReplaceEntity(self,nil)
		end
		self:Die()
	else
		if self.Level > 0 then
			local effectdata = EffectData()
			effectdata:SetFlags(self.Level-1)
			effectdata:SetEntity(self.PikMdl)
			effectdata:SetStart(FlowerColorVectors[self.Color])
			util.Effect("pikmin_leveldown", effectdata)
			self:SetLevel(self.Level-1)
		end
	end
end

function ENT:IsValidVictim(ent)
	if ent:Health() <= 0 then return false end
	if ent.Breakable then return true end
	local class = ent:GetClass()
	if string.sub(class,1,4) == "func" then return false end
	if (IsValid(self.Olimar) and ent == self.Olimar) or ent.PikIgnore or class == "pikmin_nectar" or class == "pikmin" or class == "pikmin_onion" or class == "prop_physics" or class == "pikmin_model" or class == "prop_ragdoll" or class == "npc_rollermine" then return false end
	return true
end

function IsCarryObject(ent)
	if ent.IsCarry then return true end
	if ent:GetClass() == "prop_physics" and table.KeyFromValue(PikiCarryOnionList,ent:GetModel()) then
		ent.IsCarry = true
		ent.CarryOnion = true
		return true
	end
	return false
end

function ENT:DoGroundPoundSlam(impactPos)
	self.IsGroundPounding = false
	self.Thrown = false
	-- Only disband AI-controlled Pikmin; player-controlled Pikmin can't be dismissed
	-- Can't believe I had to add this but hooray
	if not self.PikPly then self:Disband() end
	
	-- Sound
	self:EmitSound("pikmin/groundslam.wav", 100, 100)
	
	-- Particles (HL2 Thumper Dust ring)
	local effect = EffectData()
	effect:SetOrigin(impactPos)
	effect:SetScale(2.5)
	util.Effect("ThumperDust", effect) 
	
	-- Screen shake
	util.ScreenShake(impactPos, 8, 5, 0.5, 300)
	
	-- damage + stun in radius (120 units)
	local radius = 120
	local damage = 100
	
	-- calculate damage and apply stun
	for _, v in ipairs(ents.FindInSphere(impactPos, radius)) do
		-- Never affect: self, Olimar, other Pikmin entities, or any player (allies, Olimar, Pikmin-players)
		if not IsValid(v) then continue end
		if v == self then continue end
		if v:IsPlayer() then continue end
		if v:GetClass() == "pikmin" or v:GetClass() == "pikmin_model" then continue end
		
		local targetPos = v:NearestPoint(impactPos)
		local dist = targetPos:Distance(impactPos)
		local fraction = math.Clamp(1.0 - (dist / radius), 0, 1)
		local finalDamage = math.Round(damage * fraction)
		
		if finalDamage > 0 then
			local dmgInfo = DamageInfo()
			dmgInfo:SetDamage(finalDamage)
			dmgInfo:SetAttacker(IsValid(self.Olimar) and self.Olimar or self)
			dmgInfo:SetInflictor(self)
			dmgInfo:SetDamageType(DMG_BLAST)
			v:TakeDamageInfo(dmgInfo)
		end
		
		-- Stun NPCs only
		if v:IsNPC() then
			if COND_NPC_FREEZE then
				v:SetCondition(COND_NPC_FREEZE)
				local npc = v
				timer.Simple(2.5, function()
					if IsValid(npc) then
						npc:ClearCondition(COND_NPC_FREEZE)
					end
				end)
			else
				-- fallback stun
				v:SetNPCState(NPC_STATE_LOST)
			end
		end
	end
	
	-- trigger procedural squash-and-stretch 
	local mdl = self.PikMdl
	if IsValid(mdl) then
		mdl:SetNWFloat("GroundPoundImpactTime", CurTime())
	end
end

function ENT:LatchOn(ent)
	if self.IsGroundPounding or (self.Color == 4 and self.Thrown and cvars.Bool("pik_purple_groundpound")) then
		self:DoGroundPoundSlam(self:GetPos())
		return
	end
	if not self:IsValidVictim(ent) then return end
	if ent:GetClass() == "pikmin_gas" and not (self.Color == 5 or self.Color == 6) then self.Poison = true return end
	if self.Color == 8 then
		if (self.NextRockHit or 0) > CurTime() then return end
		self.NextRockHit = CurTime() + 0.5
		
		local dmg = self.Damage ~= 0 and self.Damage+self.Level*2 or 0
		if self.Thrown then
			dmg = dmg * 3
		end
		ent:TakeDamage(dmg, self.PikPly and self or self.Olimar, self)
		self:EmitSound("physics/body/body_medium_impact_hard" .. math.random(4, 6) .. ".wav")
		
		self.Thrown = false
		self.AttackTarget = ent
		
		local dir = (self:GetPos() - ent:GetPos()):GetNormalized()
		dir.Z = math.max(dir.Z, 0.5)
		if IsValid(self.Phys) then
			self.Phys:SetVelocity(Vector(0,0,0))
			self.Phys:ApplyForceCenter(dir * self.MoveForce * 3 + Vector(0,0,3000))
		end
		return
	end
	
	if self.Color == 4 and self.Thrown then
		ent:TakeDamage(10,self,self)
		self:EmitSound("physics/body/body_medium_impact_hard" .. math.random(4, 6) .. ".wav")
	end
	self.Thrown = false
	self.AttackTarget = ent
	local pos = self:GetPos()
	local epos = ent:GetPos()
	local dir = (epos - pos):Angle()
	if ent.Breakable then dir = Angle(0,dir.Y,0) end
	self.Attacking = true
	self.Victim = ent
	self:SetAngles(dir)
	self:SetParent(ent)
end

--//Used to make the pikmin keep their current angle and face the player or attack target
function ENT:PhysicsSimulate(phys, delta)
	local pos = IsValid(self.AttackTarget) and self.AttackTarget:GetPos() or self.Olimar and self.Olimar:GetPos() or self:GetPos()
	phys:Wake()
	if self.params == nil then self.params = table.Copy(BaseShadowParams) self.params.angle = self:GetAngles() end
	local params = self.params
	params.pos = Vector(0, 0, 0)
	params.angle = (self.Dismissed or self.Thrown or self.Attacking or self.Carrying) and self.params.angle or (pos - self:GetPos()):Angle()
	params.angle.p = self.Color == 7 and 25 or 0
	params.deltatime = delta
	phys:ComputeShadowControl(params)
end

local ValidEnemyList = {
"pikmin_fire",
"pikmin_gas",
"pikmin_wire",
}

--//Used to detect a collision when thrown; stopping the spin animation
function ENT:PhysicsCollide(data,phys)
	if self.IsGroundPounding or (self.Color == 4 and self.Thrown and cvars.Bool("pik_purple_groundpound")) then
		self:DoGroundPoundSlam(data.HitPos)
		return
	end
	if data.HitEntity.Breakable and (self.AttackTarget == data.HitEntity or self.Thrown) then timer.Simple(0,function() self:LatchOn(data.HitEntity) end) return end
	if self.Thrown then
		local validcarry = IsCarryObject(data.HitEntity)
		if data.HitEntity:IsWorld() or (not data.HitEntity:IsNPC() and not data.HitEntity:IsPlayer()) or validcarry then
			if validcarry then self:Charge(data.HitEntity) self.NextHop = CurTime()+1 end
			if table.KeyFromValue(ValidEnemyList,data.HitEntity:GetClass()) and data.HitEntity:Health() > 0 then return end
			if not self.PikPly and not data.HitEntity.PikInteract and not self.AttackTarget then self:Disband() end
			self.Thrown = false
		end
	end
end

function ENT:StartTouch(obj)
	if self.AttackTarget and not self.Thrown then
		if self.AttackTarget.Breakable then self:LatchOn(data.HitEntity) return end
	end
	if not (self.AttackTarget or self.Thrown) then
		if obj:IsPlayer() then
			if self.Dismissed then
				self:Join(obj)
			end
		end
		if not self.AttackTarget and IsValid(self.Olimar) and self.Olimar.SwarmVec then
			if self:IsValidVictim(obj) then
				self.AttackTarget = obj
				self:LatchOn(obj)
			elseif IsCarryObject(obj) then
				if not self.Drowning and not self.BurnTick and ((self:GetPos()-obj:WorldSpaceAABB()).Z < 8 or self:WaterLevel() >= 1)  then
					self:Carry(obj)
				end
			end
		end
	else
		if (obj == self.AttackTarget or self.Thrown or SwarmTouch) and not self.Attacking and self:IsValidVictim(obj) then
			self.AttackTarget = obj
			self:LatchOn(obj)
		end
		if not self.Thrown and obj == self.AttackTarget and IsCarryObject(obj) and not self.Carrying then
			if not self.Drowning and not self.BurnTick and ((self:GetPos()-obj:WorldSpaceAABB()).Z < 8 or self:WaterLevel() >= 1)  then
				self:Carry(obj)
			end
		end
	end
	if (obj:GetClass() == "prop_combine_ball") then
		if IsValid(self) and not self.Dissolving and not (self.Color == 2 or self.Color == 6 or self.Color == 9) then
			self.Dissolving = true
			self:EmitSound("pikmin/pikmin_die.wav", 100, math.random(95, 110))
			local mdl = self:CreatePikRagdoll(true)
			local dissolve = ents.Create("env_entity_dissolver")
			dissolve:SetPos(mdl:GetPos())
			mdl:SetName(tostring(mdl))
			dissolve:SetKeyValue("target", mdl:GetName())
			dissolve:SetKeyValue("dissolvetype", "0")
			dissolve:Spawn()
			dissolve:Fire("Dissolve", "", 0)
			dissolve:Fire("kill", "", 1)
			dissolve:EmitSound(Sound("NPC_CombineBall.KillImpact"))
			mdl:Fire("sethealth", "0", 0)
			self:Remove()
		end
	end
end

--Duplicator/Save support
function ENT:PreEntityCopy()
	local data = {
		Drinking=self.Drinking,
		Dead=self.Dead,
		Color=self.Color,
		Level=self.Level,
		params=self.params
	}
	if not self.PikPly then
		data.Olimar=IsValid(self.Olimar) and self.Olimar:UserID()
	end
	if not self.Dead then
		data.Cycle=self.PikMdl:GetCycle()
		local parent = self:GetParent()
		if IsValid(parent) then data.Parent = parent:EntIndex() data.ppos = self:GetPos()-parent:GetPos() end
		if self.CarryObject and IsValid(self.CarryObject) then data.CarryObject = self.CarryObject:EntIndex() end
		if self.AttackTarget and IsValid(self.AttackTarget) then data.AttackTarget = self.AttackTarget:EntIndex() end
	end
	duplicator.StoreEntityModifier(self,"PikInfo",data)
end

function ENT:PostEntityPaste(ply,ent,created)
	local pikinfo = ent.EntityMods.PikInfo
	if pikinfo then
		if self.PikPly then self:Remove() return end
		if pikinfo.Dead then self:Remove() return end
		self.Color = pikinfo.Color
		self.Level = pikinfo.Level
		self:SetModel(ColorCollideTable[self.Color])
		self.PikMdl:SetNWInt("Color",self.Color)
		self.PikMdl:SetNWInt("Level",math.min(2,self.Level))
		self.PikMdl:SetModel(ColorModelTable[(self.Color-1)*3+1+self.Level])
		self.PikMdl.Cycle = pikinfo.Cycle
		self.BaseMoveForce = GetConVar("pik_speed" .. self.Color):GetFloat()
		self.MoveForce = self.BaseMoveForce + self.Level*(self.Color == 5 and 320 or (self.Color == 4 or self.Color == 8) and 150 or 250)
		self.ZForceVector = (self.Color == 4 or self.Color == 8) and Vector(0,0,425) or self.Color == 7 and Vector(0,0,0) or Vector(0,0,325)
		self.JumpVector = Vector(0,0,(self.Color == 4 or self.Color == 8) and 2000 or 1750)
		self.HighJumpVector = self.JumpVector*2
		self.CarryForce = (self.Color == 4 or self.Color == 8) and 4000 or 50
		self.CarryWeight = (self.Color == 4 or self.Color == 8) and 10 or 1
		self.Called = false
		
		local time = CurTime()
		self.NextHop = time
		self.NextObHop = time
		self.NextAttack = time
		self.ThrowNext = time
		self.DismissTimer = time
		
		if pikinfo.Olimar then
			local ply = Player(pikinfo.Olimar)
			if IsValid(ply) then
				self.Dismissed = false
				self.Olimar = ply
				self.PikMdl:SetNWBool("Dismissed",false)
			end
		end
		
		self.params = pikinfo.params
		
		if pikinfo.CarryObject then
			self.Carrying = false
			timer.Simple(0.1,function()
				local find = constraint.Find(self,created[pikinfo.CarryObject],"Weld",0,0)
				if find then find:Remove() end
				self:Charge(created[pikinfo.CarryObject])
			end)
		end
		
		if pikinfo.AttackTarget then
			self.AttackTarget = created[pikinfo.AttackTarget]
			if self.Attacking then
				self:SetPos(self.AttackTarget:GetPos()+pikinfo.ppos)
				self:SetParent(self.AttackTarget)
			end
		end
		
		if pikinfo.Drinking and pikinfo.Parent then
			local parent = created[pikinfo.Parent]
			parent:StartTouch(self)
		end
		
		if self.BurnTick then
			self.BurnTick = nil
			self:Ignite(1000,0)
		end
		if self.GasTick then
			self.GasTick = nil
		end
		if self.DrownTick then
			self.DrownTick = nil
			self.Drowning = false
		end
	end
	ent.EntityMods = nil
end

-- this code is so chonky, I wonder if we can cut down.