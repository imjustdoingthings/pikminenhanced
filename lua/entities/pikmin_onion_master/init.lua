AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
	if #ents.FindByClass("pikmin_onion") + #ents.FindByClass("pikmin_onion_p3") + #ents.FindByClass("pikmin_onion_master") >= 8 then self:Remove() return end
	
	self:SetModel("models/pikmin/onion_large.mdl")
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	
	-- freeze ragdoll bones
	for i=0, self:GetPhysicsObjectCount()-1 do
		local phys = self:GetPhysicsObjectNum(i)
		if IsValid(phys) then
			phys:EnableMotion(false)
			phys:Sleep()
		end
	end
	
	self:SetColor(Color(255,255,255,0))
	self:SetRenderMode(RENDERMODE_TRANSCOLOR)
	timer.Create("vis"..self:EntIndex(), 0.5, 1, function() if IsValid(self) then self:SetColor(Color(255,255,255,255)) end end)
	
	self.IsMasterOnion = true
	self.PikiListMaster = {}
	for _,c in ipairs(PikiOnionP3Colors) do
		self.PikiListMaster[c] = {}
	end
	
	self.Color = 0
	self.Skin = 8
	self.PullTable = {}
	self.EXID = 0
	self.NextUse = CurTime()
	self:LoadData()
end

function ENT:SaveData()
	local data = util.TableToJSON(self.PikiListMaster)
	file.Write("master_onion.json", data)
end

function ENT:LoadData()
	if file.Exists("master_onion.json", "DATA") then
		local data = file.Read("master_onion.json", "DATA")
		local table = util.JSONToTable(data)
		if table then
			for _, c in ipairs(PikiOnionP3Colors) do
				self.PikiListMaster[c] = table[c] or {}
			end
		end
	end
end

function ENT:Call(ply, call, send, color)
	if not color then return end
	if not self.PikiListMaster[color] then color = 1 end
	if call > 0 or send > 0 then self.NextUse = CurTime() + 0.5 end
	if send > 0 then
		local pikiCount = 0
		for _, v in ipairs(ents.FindByClass("pikmin")) do
			if not v.PikPly and v.Color == color and v.Olimar == ply and (v.PikMdl.CurAnim == "running" or v.PikMdl.CurAnim == "idle" or v.PikMdl.CurAnim == v.WingedIdle) then
				pikiCount = pikiCount + 1
				table.insert(self.PikiListMaster[color], v.Level)
				v:Remove()
				if pikiCount == send then break end
			end
		end
		self:SaveData()
	end
	
	local list = self.PikiListMaster[color]
	if call > 0 and #list >= call then
		timer.Create("call" .. self:EntIndex() .. color, 0.1, 1, function()
			for i = 1, call do
				if PikminCreateServer(ply, {level = list[#list], color = color}) then
					table.remove(list, #list)
				end
			end
			self:SaveData()
		end)
	end
end

function ENT:Use(activator, caller)
	if CurTime() < (self.NextUse or 0) then return end
	self.NextUse = CurTime() + 1
	if activator:IsPlayer() then
		local counts = {}
		local oncounts = {}
		for _, c in ipairs(PikiOnionP3Colors) do
			local pikiCount = 0
			for _, v in ipairs(ents.FindByClass("pikmin")) do
				if not v.PikPly and v.Color == c and v.Olimar == activator and (v.PikMdl.CurAnim == "running" or v.PikMdl.CurAnim == "idle" or v.PikMdl.CurAnim == v.WingedIdle) then
					pikiCount = pikiCount + 1
				end
			end
			counts[c] = pikiCount
			oncounts[c] = #self.PikiListMaster[c]
		end

		local TooMany = #ents.FindByClass("pikmin") + #ents.FindByClass("pikmin_sprout") >= PikiMaxField and " 1" or " 0"
		net.Start("PikiMasterOnionMenu")
		net.WriteEntity(self)
		for _, c in ipairs(PikiOnionP3Colors) do
			net.WriteInt(counts[c], 32)
			net.WriteInt(oncounts[c], 32)
		end
		net.WriteString(TooMany)
		net.Send(activator)
	end
end

local function IsValidFood(obj)
	if not IsValid(obj) then return false end
	local class = obj:GetClass()
	return (class == "prop_physics" or class == "prop_ragdoll") and (table.KeyFromValue(PikiCarryOnionList, obj:GetModel()) or obj:GetNWBool("iscarry", false))
end

function ENT:Pull(obj)
	if not IsValidFood(obj) then return end
	if obj.PikAbducting then return end
	obj.PikAbducting = true
	
	-- determine majority color from current carriers before they drop it
	local counts = {}
	local maxW, bestColor = 0, 1
	for _, p in ipairs(ents.FindByClass("pikmin")) do
		if p.CarryObject == obj then
			local weight = p.CarryWeight or 1
			counts[p.Color] = (counts[p.Color] or 0) + weight
			if counts[p.Color] > maxW then
				maxW = counts[p.Color]
				bestColor = p.Color
			end
		end
	end
	obj:SetNWInt("pikiColor", bestColor)
	
	timer.Simple(1.25, function()
		if IsValid(self) and IsValid(obj) then
			obj.PikIgnore = true
			table.insert(self.PullTable, obj)
			self:EmitSound("pikmin/abduction.wav")
		end
	end)
end

function ENT:Think()
	if self.LastAnim ~= self.CurAnim then
		self.LastAnim = self.CurAnim
		self:ResetSequence(self.CurAnim or 2)
	end
	
	local PullCenter = self:GetPos() + Vector(0, 0, 160)
	
	if (self.NextItemSearch or 0) < CurTime() then
		self.NextItemSearch = CurTime() + 0.5
		for _, v in ipairs(ents.FindInSphere(self:GetPos(), 250)) do
			if IsValidFood(v) and not v.PikIgnore then
				self:Pull(v)
			end
		end
	end

	for _, v in ipairs(self.PullTable) do
		if not IsValid(v) then table.remove(self.PullTable, table.KeyFromValue(self.PullTable, v)) continue end
		local phys = v.PikPhys
		if not phys then
			phys = v:GetPhysicsObject()
			if IsValid(phys) then
				phys:EnableGravity(false)
				v:SetCollisionGroup(COLLISION_GROUP_WORLD)
				v.PikPR = v:BoundingRadius()
				v.PikPhys = phys
				v:SetModelScale(0, v:GetPos():Distance(PullCenter) / math.min(200, 5 * v.PikPR))
			end
		end
		if not IsValid(phys) then continue end
		local pos = v:GetPos()
		local speed = math.max((40000 - pos:DistToSqr(PullCenter)) / 64, 64)
		phys:SetVelocity((PullCenter - pos):GetNormalized() * speed)
		if pos:DistToSqr(PullCenter) <= v.PikPR * 2 + 30000 then -- Significantly increased snap distance to account for height
			self.CurAnim = 5
			timer.Remove("suck" .. self:EntIndex())
			timer.Create("suck" .. self:EntIndex(), 0.8, 1, function() if IsValid(self) then self.CurAnim = 2 end end)
			self.EXID = self.EXID + 1

			local pikCount = v.PikiSproutsCount or PikiFueDict[v:GetModel()] or math.random(1, 3)
			local fColor = v:GetNWInt("pikiColor", 1)
			if fColor == 0 then fColor = 1 end
			if not self.PikiListMaster[fColor] then fColor = 1 end
			
			local finalColor = fColor -- Localize for the timer closure
			timer.Create("expel" .. self:EntIndex() .. self.EXID, 1.8, 1, function()
				if not IsValid(self) then return end
				if self.CurAnim == 4 then self.CurAnim = 2 end
				for i = 1, pikCount do
					local rand = math.Rand(-10, 10)
					local spawnPos = self:GetPos() + Vector(math.sin(rand) * 150, math.cos(rand) * 150, 100)
					if not PikminCreateSproutServer(self, spawnPos, finalColor) then
						table.insert(self.PikiListMaster[finalColor], 0)
					end
				end
				self:TriggerOutput("OnCreate", self, pikCount)
				self:SaveData()
				if self.EXID > 0 then self.EXID = self.EXID - 1 end
			end)
			v:Remove()
		end
	end
	self:NextThink(CurTime())
	return true
end


function ENT:SpawnFunction(ply, tr)
	if not tr.Hit then return end
	local ent = ents.Create("pikmin_onion_master")
	ent:SetPos(tr.HitPos + Vector(0,0,120)) -- height offset for Master Onion, it's a weird ragdoll
	ent:Spawn()
	ent:Activate()
	return ent
end
