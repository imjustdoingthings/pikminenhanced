AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:KeyValue(key,value)
	if key == "hammerid" then self.WorldEnt = true end
	if key == "target" then self.LockLink = value end
	if key == "repeat" and value == "1" then self.Repeat = true end
	if string.Left(key,2) == "On" then
		self:StoreOutput(key,value)
	end
end

function ENT:AcceptInput(name,activator,caller,data) 
	if name == "Destroy" then self:TakeDamage(self:Health()) return true end
	if name == "Trigger" then
		self.NextShock = CurTime()
		return true
	end
	if name == "TriggerWith" then
		local ent = ents.FindByName(data)
		if ent[1] then self.NextLink = ent[1] end
		print(ent[1])
		self.NextShock = CurTime()
		return true
	end
	return false
end

function ENT:Initialize()
	self:SetHealth(30)
	self:SetModel("models/pikmin/wirehiba.mdl")
	local tr = util.QuickTrace(self:GetPos(),-vector_up*10000,ents.GetAll())
	if tr.Hit then self:SetPos(tr.HitPos) end
	self:SetPos(self:GetPos()+self:GetUp()*2)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:DrawShadow(false)
	self.NextShock = CurTime()+2.5
	self.CanHurt = false
	self:StopZapSounds()
	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:EnableMotion(false)
	end
	self.ChargeHumSound = CreateSound(self, "pikmin/electricalwire/charge/chargehum.wav")
	self.ChargeSparksSound = CreateSound(self, "pikmin/electricalwire/charge/chargesparksloop.wav")
	self.ZapLoopSound = CreateSound(self, ")pikmin/electricalwire/zaploop.wav")

	self.SparkSounds = {
		"pikmin/electricalwire/charge/spark1.wav",
		"pikmin/electricalwire/charge/spark2.wav",
		"pikmin/electricalwire/charge/spark3.wav",
		"pikmin/electricalwire/charge/spark4.wav",
		"pikmin/electricalwire/charge/spark5.wav",
	}
	self.FireSounds = {
		"pikmin/electricalwire/fire/electricity7.wav",
		"pikmin/electricalwire/fire/electricity8.wav",
		"pikmin/electricalwire/fire/electricity11.wav",
		"pikmin/electricalwire/fire/electricity12.wav",
		"pikmin/electricalwire/fire/electricity13.wav",
		"pikmin/electricalwire/fire/electricity14.wav",
		"pikmin/electricalwire/fire/electricity15.wav",
		"pikmin/electricalwire/fire/electricity16.wav",
		"pikmin/electricalwire/fire/electricity17.wav",
		"pikmin/electricalwire/fire/electricity18.wav",
	}
end

local WireCenterOffset = Vector(0,0,10)

function ENT:StartChargeSequence()
	local idx = self:EntIndex()

	if self.ChargeHumSound then
		self.ChargeHumSound:Play()
	end

	timer.Create("wire_phase2_" .. idx, 4, 1, function()
		if not IsValid(self) or not self.Shocking then return end
		if self.ChargeHumSound then self.ChargeHumSound:Stop() end
		if self.ChargeSparksSound then self.ChargeSparksSound:Play() end

		local spark1 = self.SparkSounds[math.random(#self.SparkSounds)]
		local spark2 = self.SparkSounds[math.random(#self.SparkSounds)]
		self:EmitSound(spark1)
		timer.Create("wire_spark2_" .. idx, 1, 1, function()
			if not IsValid(self) or not self.Shocking then return end
			self:EmitSound(spark2)
		end)

		if IsValid(self.WireLink) then
			local pos = self:GetPos() + WireCenterOffset
			local pos2 = self.WireLink:GetPos() + WireCenterOffset
			timer.Create("spark" .. idx, 0.1, 20, function()
				if not IsValid(self) or not IsValid(self.WireLink) then return end
				local data = EffectData()
				data:SetOrigin(pos)
				data:SetScale(20)
				util.Effect("StunstickImpact", data)
				data:SetOrigin(pos2)
				util.Effect("StunstickImpact", data)
			end)
		end
	end)

	timer.Create("wire_phase3_" .. idx, 6, 1, function()
		if not IsValid(self) or not self.Shocking then return end
		if self.ChargeSparksSound then self.ChargeSparksSound:Stop() end

		self.CanHurt = true
		if self.ZapLoopSound then self.ZapLoopSound:Play() end

		local data = EffectData()
		data:SetEntity(self)
		util.Effect("pikmin_zap", data)

		if IsValid(self.WireLink) then
			self.WireLink.CanHurt = true
			if self.WireLink.ZapLoopSound then self.WireLink.ZapLoopSound:Play() end
		end

		self:StartFireSounds()
		if IsValid(self.WireLink) then
			self.WireLink:StartFireSounds()
		end
	end)
end

function ENT:StartFireSounds()
	local idx = self:EntIndex()
	timer.Create("wire_fire_" .. idx, 1, 0, function()
		if not IsValid(self) or not self.Shocking then return end
		local snd = self.FireSounds[math.random(#self.FireSounds)]
		self:EmitSound(snd)
	end)
end

function ENT:StopZapSounds()
	self.CanHurt = false
	if self.ChargeHumSound then self.ChargeHumSound:Stop() end
	if self.ChargeSparksSound then self.ChargeSparksSound:Stop() end
	if self.ZapLoopSound then self.ZapLoopSound:Stop() end
	local idx = self:EntIndex()
	timer.Remove("wire_phase2_" .. idx)
	timer.Remove("wire_phase3_" .. idx)
	timer.Remove("wire_spark2_" .. idx)
	timer.Remove("wire_fire_" .. idx)
	timer.Remove("spark" .. idx)
end

function ENT:SpawnFunction(ply,tr)
	local tr = util.QuickTrace(ply:GetShootPos(), ply:GetAimVector() * 10000, ents.GetAll())
	if not (tr.Hit and tr.HitPos) then return end
	local ent = ents.Create("pikmin_wire")
	ent:SetPos(tr.HitPos)
	local ang = (ply:GetPos()-tr.HitPos):Angle()
	ent:SetAngles(Angle(0,ang.Y,0))
	ent:Spawn()
	ent:Activate()
	undo.Create("#pikmin_wire")
		undo.AddEntity(ent)
		undo.SetPlayer(ply)
	undo.Finish()
end

function ENT:Think()
	if self.NoThink then return false end
	
	if self.CanHurt then
		if IsValid(self.WireLink) and self.WireLink:Health() > 0 then
			local dmg = DamageInfo()
			dmg:SetDamage(1)
			dmg:SetAttacker(self)
			dmg:SetInflictor(self)
			dmg:SetDamageType(DMG_SHOCK)
			local victims = ents.FindAlongRay(self:GetPos(),self.WireLink:GetPos(),Vector(-15,-15,-15),Vector(15,15,15))
			for _,v in ipairs(victims) do
				if v == self then continue end
				local class = v:GetClass()
				if class == "pikmin_fire" or class == "pikmin_gas" or class == "pikmin_wire" then continue end
				dmg:SetDamagePosition(v:WorldSpaceCenter())
				v:TakeDamageInfo(dmg)
			end
			for _,v in ipairs(ents.FindInSphere(self:GetPos(),30)) do
				if v == self then continue end
				local class = v:GetClass()
				if class == "pikmin_fire" or class == "pikmin_gas" or class == "pikmin_wire" then continue end
				dmg:SetDamagePosition(v:WorldSpaceCenter())
				v:TakeDamageInfo(dmg)
			end
		else
			self:StopZapSounds()
			self.WireLink = nil
			self.Shocking = false
			self.NextShock = CurTime()+2.5
			self:SetLinkWire(self)
		end
	end
	
	if CurTime() >= self.NextShock and not self.Linked then
		if not self.Shocking then
			self.Shocking = true
			self.NextShock = CurTime()+11
			local pos = self:GetPos()
			
			if self.LockLink and not self.LockFound then
				self.LockFound = true
				self.LockLink = ents.FindByName(self.LockLink)[1]
				self.LockLink.NoThink = true 
			end
			
			local wire = self.NextLink or self.LockLink
			if not wire or not IsValid(wire) then
				local wires = ents.FindByClass("pikmin_wire")
				table.sort(wires,function(a,b) return a:GetPos():DistToSqr(pos) < b:GetPos():DistToSqr(pos) end)
				wire = wires[2]
				if wire and wire.LockFound then wire = nil end
			end
			
			if self.NextLink then self.NextLink = nil end
			
			if wire and wire:Health() > 0 and not wire.Shocking and wire:GetPos():DistToSqr(pos) <= 180000 and not util.QuickTrace(pos+WireCenterOffset,wire:GetPos()-pos,ents.GetAll()).HitWorld then	
				self:TriggerOutput("OnActivated",self)
				self.Repeat = self.Repeat or wire.Repeat
				if (wire.LockFound and wire.LockLink == self) or (not wire.LockFound and wire.LockLink == self:GetName()) then
					wire.NoThink = true
					self.LockFound = true
					self.LockLink = wire
				end
				self.WireLink = wire
				self.WireLink.Shocking = true
				self.WireLink.NextShock = self.NextShock
				self.WireLink.WireLink = self
				self.WireLink.Linked = true
				self:SetLinkWire(self.WireLink)
				
				self:StartChargeSequence()
			else
				self.NextShock = CurTime()+2.5
			end
		else
			if not self.Repeat then
				self:StopZapSounds()
				self.Shocking = false
				self.NextShock = CurTime()+2.5
				if self.WireLink then
					if IsValid(self.WireLink) then
						self.WireLink.Shocking = false
						self.WireLink.NextShock = self.NextShock
						self.WireLink.Linked = false
						self.WireLink:StopZapSounds()
					end
					self.WireLink = nil
					self:SetLinkWire(self)
				end
				self:StopZapSounds()
				self:TriggerOutput("OnIdle",self)
			end
		end
	end
	self:NextThink(CurTime()+0.1)
	return true
end

function ENT:OnRemove()
	self:StopZapSounds()
	if self.WireLink and IsValid(self.WireLink) then 
		self.WireLink.Shocking = false 
		self.WireLink.Linked = false 
		self.WireLink:StopZapSounds()
	end
end

function ENT:OnTakeDamage(DamageInfo)
	if self.NoThink then self:SetHealth(0) return end
	if DamageInfo:IsDamageType(DMG_SHOCK) then return end
	local nhealth = self:Health()-DamageInfo:GetDamage()
	self:SetHealth(nhealth)
	if nhealth <= 0 then
		self.NoThink = true
		self:StopZapSounds()
		if self.WireLink then
			if IsValid(self.WireLink) then
				self.WireLink.Shocking = false
				self.WireLink.NextShock = self.NextShock
				DamageInfo:SetDamage(100)
				self.WireLink:TakeDamageInfo(DamageInfo)
				self.WireLink:StopZapSounds()
			end
			self.WireLink = nil
			self:SetLinkWire(self)
		end
		self:StopZapSounds()
		self:TriggerOutput("OnDeath",self)
	end
end

function ENT:PreEntityCopy()
	duplicator.StoreEntityModifier(self,"PikInfo",{Health=self:Health()})
end

function ENT:PostEntityPaste(ply,ent,created)
	local pikinfo = ent.EntityMods.PikInfo
	if pikinfo then
		self:SetHealth(pikinfo.Health)
	end
	self.Shocking = false
	self.WireLink = nil
	self.NextShock = CurTime() + 2.5
	self.Linked = false
	self:StopZapSounds()
	ent.EntityMods = nil
end