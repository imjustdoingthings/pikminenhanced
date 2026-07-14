AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
	if #ents.FindByClass("pikmin_onion") + #ents.FindByClass("pikmin_onion_p3") + #ents.FindByClass("pikmin_onion_master") >= 8 then self:Remove() return end
	
	self:SetModel("models/pikmin/onion_new.mdl")
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	
	-- Freeze ragdoll bones
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
	
	self.IsP3Onion = true
	self.PikiColor = PikiOnionP3Colors[self:GetSkin()+1] or 1
	self.Color = self.PikiColor
	
	-- Data slot mapping (use 3-7 for P3 Onions to avoid clashing with 0-2)
	self.Skin = 3 + self:GetSkin()
	if not self.PikiList then
		self.PikiList = PIKIONIONDATA[self.Skin] and table.Copy(PIKIONIONDATA[self.Skin]) or {}
	end
	
	self.PullTable = {}
	self.EXID = 0
	self.NextUse = CurTime()
end

function ENT:Call(ply, call, send, color)
	local targetColor = color or self.Color
	if call > 0 or send > 0 then self.NextUse = CurTime() + 0.5 end
	if send > 0 then
		local pikiCount = 0
		for _, v in ipairs(ents.FindByClass("pikmin")) do
			if not v.PikPly and v.Color == targetColor and v.Olimar == ply and (v.PikMdl.CurAnim == "running" or v.PikMdl.CurAnim == "idle" or v.PikMdl.CurAnim == v.WingedIdle) then
				pikiCount = pikiCount + 1
				table.insert(self.PikiList, v.Level)
				v:Remove()
				if pikiCount == send then break end
			end
		end
		SetPikiOnionData(self.Skin, self.PikiList)
	end
	
	if call > 0 and #self.PikiList >= call then
		timer.Create("call" .. self:EntIndex(), 0.1, 1, function()
			for i = 1, call do
				if PikminCreateServer(ply, {level = self.PikiList[#self.PikiList], color = targetColor}) then
					table.remove(self.PikiList, #self.PikiList)
				end
			end
			SetPikiOnionData(self.Skin, self.PikiList)
		end)
	end
end

function ENT:Use(activator, caller)
	if CurTime() < (self.NextUse or 0) then return end
	self.NextUse = CurTime() + 1
	if activator:IsPlayer() then
		local pikiCount = 0
		for _, v in ipairs(ents.FindByClass("pikmin")) do
			if not v.PikPly and v.Color == self.Color and v.Olimar == activator and (v.PikMdl.CurAnim == "running" or v.PikMdl.CurAnim == "idle" or v.PikMdl.CurAnim == v.WingedIdle) then
				pikiCount = pikiCount + 1
			end
		end
		local TooMany = #ents.FindByClass("pikmin") + #ents.FindByClass("pikmin_sprout") >= PikiMaxField and " 1" or ""
		activator:ConCommand("pikmin_omenu " .. self.Skin .. " " .. #self.PikiList .. " " .. pikiCount .. TooMany)
	end
end


function ENT:SpawnFunction(ply, tr)
	ply:ConCommand("pikmin_p3ospawnmenu")
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
		if pos:DistToSqr(PullCenter) <= v.PikPR * 2 + 30000 then
			self.CurAnim = 5
			timer.Remove("suck" .. self:EntIndex())
			timer.Create("suck" .. self:EntIndex(), 0.8, 1, function() if IsValid(self) then self.CurAnim = 2 end end)
			self.EXID = self.EXID + 1

			local pikCount = v.PikiSproutsCount or PikiFueDict[v:GetModel()] or math.random(1, 3)
			local fColor = self.Color
			
			timer.Create("expel" .. self:EntIndex() .. self.EXID, 1.8, 1, function()
				if IsValid(self) and self.CurAnim == 4 then self.CurAnim = 2 end
				for i = 1, pikCount do
					local rand = math.Rand(-10, 10)
					local spawnPos = self:GetPos() + Vector(math.sin(rand) * 150, math.cos(rand) * 150, 100)
					if not PikminCreateSproutServer(self, spawnPos, fColor) then
						table.insert(self.PikiList, 0)
					end
				end
				self:TriggerOutput("OnCreate", self, pikCount)
				SetPikiOnionData(self.Skin, self.PikiList)
				if IsValid(self) and self.EXID > 0 then self.EXID = self.EXID - 1 end
			end)
			v:Remove()
		end
	end
	self:NextThink(CurTime())
	return true
end
