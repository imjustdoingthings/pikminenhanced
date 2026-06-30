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
	self.WingedIdle = self.Color == 7 and self.PikMdl:LookupSequence("swimming") or 2
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
	self.BaseMoveForce = (self.Color == 4 or self.Color == 8) and 600 or self.Color == 5 and 1000 or 700
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

function ENT:Disband(pos)
	if self.Carrying then self:Drop() end
	if pos then self.DismissTimer = CurTime() + 2 end
	self.DismissPos = pos
	self.Dismissed = true
	self.Olimar = nil
	self:SetNWEntity("Olimar",self)
	self.AttackTarget = nil
	self.PikMdl:SetNWBool("Dismissed",true)
end

function ENT:Join(parent)
	if self.Dismissed then
		self.Dismissed = false
		self.Olimar = parent
		self:SetNWEntity("Olimar",parent)
		if IsValid(self.PikMdl) then
			self.PikMdl.CurAnim = 7
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
	if not self.Dismissed and not self.Attacking and (not IsValid(self.Olimar) or not self.Olimar:Alive()) then self:Disband() end
	if not IsValid(self.AttackTarget) or self.AttackTarget.PikIgnore then self.AttackTarget = nil end
	
	local pos = self:GetPos()
	local speed = self:GetVelocity():Length()
	local targetPos = pos
	local minDist = 200
	local CTime = CurTime()
	if IsValid(self.Olimar) then
		targetPos = self.Olimar:GetPos()
		if self.Olimar.SwarmVec then
			targetPos = targetPos + self.Olimar.SwarmVec
			minDist = 50
		else
			local tpik = self.Olimar:GetNWEntity("piki")
			if IsValid(tpik) and tpik ~= self.Olimar then
				if tpik.Color ~= self.Color or tpik.Level ~= self.Level then
					minDist = 50
					targetPos = targetPos - self.Olimar:GetAngles():Forward()*120
				else
					minDist = 80
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
		if not isSwarming and not self.AttackTarget and not self.PikPly then
			targetPos = targetPos + Vector(0,0,75)
		end
		local shouldFloat = not self.Thrown and not self.Dead
		if IsValid(self.Phys) then
			if self.Phys:IsGravityEnabled() == shouldFloat then
				self.Phys:EnableGravity(not shouldFloat)
			end
			if shouldFloat then
				local vel = self.Phys:GetVelocity()
				local friction = (not self.Dismissed and not self.Carrying and not self.Attacking) and 0.5 or 0.15
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
		if not (self.Color == 3 or self.Color == 6 or self.Color == 9) then
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
	
	self.PikMdl.CurAnim = self.Called and 7 or self.Attacking and 4 or self.Drinking and 9 or self.Thrown and 3 or (OnFire or self.Poison) and 10 or self.Drowning and 6 or InWater and 5 or speed >= 6 and (self.Color == 7 and self.WingedIdle or 1) or (self.Dismissed and (self.Color == 7 and self.WingedIdle or 8) or self.WingedIdle)
	
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
	if not self.Called and not self.Drinking and not self.Attacking then
		local targetDist = pos:Distance(targetPos)
		
		if targetDist >= 1400 and not self.Attacking and not self.AttackTarget and not self.Dismissed and not self.Drowning and not (OnFire or self.Poison) and (not self.Carrying or minDist ~= 0) then if self.Carrying then self:DisbandCarry() else self:Disband() end end
		
		--if self.IsCarry and self.AttackTarget then
		--	if not InWater and math.abs((targetPos-pos).Z) >= 200 then self:Drop() end
		--end
		
		if self.DismissPos and self.Dismissed and (targetDist <= minDist or CTime >= self.DismissTimer) then self.DismissPos = nil end
		
		if not self.Thrown and (not self.Dismissed or self.DismissPos or OnFire or self.Carrying or self.Poison) and targetDist >= minDist and CTime >= self.NextHop then
			self.NextHop = CTime + 0.1
			
			if self.Carrying and self.CarryObject:GetVelocity():Length() >= 5 and not self.CarryObject.CarrySound:IsPlaying() then
				self.CarryObject.CarrySound:Play()
			end
			
			if speed <= self.MoveForce/4 then
				local dirVec = targetPos - pos
				if InWater then
					self.Phys:ApplyForceCenter(dirVec * (self.Color == 3 and 10 or self.Color == 6 and 30 or self.Color == 9 and 10 or (self.DrownCall and CTime < self.DrownCall and 5 or 0)))
				else
					local finalVec = Vector(dirVec.X,dirVec.Y,self.Color == 7 and dirVec.Z or 0):GetNormalized()
					local finalSpeed = self.MoveForce
					if self.Dismissed and not OnFire and not self.Carrying then finalSpeed = 400 end
					if self.Carrying then finalSpeed = self.CarryMass*self.CarryWeight*4 + self.MoveForce end
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
		if self.Color == 5 and not self.Shock then --Poison the bastards that killed us
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

function ENT:LatchOn(ent)
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
		self.BaseMoveForce = (self.Color == 4 or self.Color == 8) and 600 or self.Color == 5 and 1000 or 700
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