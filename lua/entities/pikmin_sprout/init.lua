AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

ENT.Planted = false

function ENT:KeyValue(key,value)
	if key == "model" then
		local idx = tonumber(value) or 0
		self.Color = math.floor(idx/3)+1
		self.Level = idx%3
	end
	if string.Left(key,2) == "On" then
		self:StoreOutput(key,value)
	end
end

function ENT:Initialize()
	if #ents.FindByClass("pikmin") == 100 then self:Remove() return end
	if not self.Planted then
		local tr = util.QuickTrace(self:GetPos(), vector_up * -10000, ents.GetAll())
		if tr.HitWorld then
			self:SetPos(tr.HitPos + tr.HitNormal*-12)
		else
			self:Remove()
			return
		end
	end
	self.Color = self.Color or 1
	self.Level = 0
	self.NextBloom = CurTime()+math.random(6,10)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetModel(ColorCollideTable[self.Color])
	self:DrawShadow(false)
	local mdl = ents.Create("pikmin_model")
	mdl:DrawShadow(false)
	mdl.CurAnim = self.Color == 7 and 2 or 11
	mdl:SetNWInt("Level",self.Level)
	mdl:SetNWInt("Color",self.Color)
	mdl:SetNWBool("Dismissed",true)
	mdl:SetModel(ColorModelTable[(self.Color-1)*3+1+self.Level])
	mdl:SetPos(self:GetPos()-self:GetUp()*13)
	mdl:SetAngles(self:GetAngles())
	mdl:SetParent(self)
	if self.Color == 5 then self:SetPos(self:GetPos()+self:GetUp()*3.25) end
	mdl:Spawn()
	mdl:Activate()
	self.PikMdl = mdl
	if not self.SaveOnly then self:EmitSound("pikmin/burrow.wav", 100, math.random(98, 105)) end
end

function ENT:SpawnFunction(ply,tr)
	ply:ConCommand("pikmin_menu 1")
end

function ENT:Think()
	if self.Level < 2 then
		if CurTime() >= self.NextBloom then
			self.NextBloom = CurTime()+math.random(8,14)
			self.Level = self.Level + 1
			self.PikMdl:SetModel(ColorModelTable[(self.Color-1)*3+1+self.Level])
			self.PikMdl:SetNWInt("Level",self.Level)
			self.PikMdl.LastAnim = nil
			self:EmitSound(self.Level == 2 and "pikmin/upgrade2.wav" or "pikmin/upgrade.wav", 100, math.random(98, 105))
			local effectdata = EffectData()
			effectdata:SetFlags(self.Level)
			effectdata:SetEntity(self.PikMdl)
			effectdata:SetStart(FlowerColorVectors[self.Color])
			util.Effect("pikmin_leveldown", effectdata)
		end
	end
	self:NextThink(CurTime())
	return true
end

function ENT:Pluck(owner,auto)
	if owner:IsPlayer() then
		self:TriggerOutput("OnPlucked",self)
		local args = {color=self.Color,level=self.Level}
		if auto then args.pos = self:GetPos()+Vector(0,0,28) end
		self:Remove()
		local ent = PikminCreateServer(owner,args)
		if ent then
			local snd = self.Color == 9 and "pikmin/infected.wav" or (cvars.Bool("pik_classicpluck") and "pikmin/pikmin_pluck.wav" or PikiSoundPluck[math.random(1, #PikiSoundPluck)])
			ent:EmitSound(snd)
		end
	end
end

function ENT:StartTouch(thing)
	if thing:IsPlayer() then
		self:Pluck(thing)
	end
end

function ENT:OnTakeDamage(DamageInfo)
	local dmg = DamageInfo:GetDamage()
	if dmg >= 80 then self:Remove() return end
	if self.Level > 0 then
		self.NextBloom = CurTime()+math.random(6,10)
		local effectdata = EffectData()
		local pos = self.PikMdl:GetBonePosition(self.PikMdl:LookupBone(self.Level == 1 and "piki_bud" or self.Level == 2 and "piki_flower"))
		effectdata:SetOrigin(pos)
		effectdata:SetStart(FlowerColorVectors[self.Color])
		util.Effect("pikmin_leveldown", effectdata)
		self.Level = dmg <= 10 and self.Level-1 or 0
		self.PikMdl:SetModel(ColorModelTable[(self.Color-1)*3+1+self.Level])
		self.PikMdl:SetNWInt("Level",self.Level)
		self.PikMdl.LastAnim = nil
	else
		local effectdata = EffectData()
		effectdata:SetOrigin(self:GetPos()+self:GetUp()*24)
		effectdata:SetStart(DeathColorVectors[self.Color])
		util.Effect("pikmin_leveldown", effectdata)
		self:Remove()
	end
end


--Duplicator/Save
function ENT:PreEntityCopy()
	local data = {
		Color=self.Color,
		Level=self.Level,
		Cycle=self.PikMdl:GetCycle(),
		BloomOffset=self.NextBloom-CurTime(),
		Pos=self:GetPos()
	}
	duplicator.StoreEntityModifier(self,"PikInfo",data)
end

function ENT:PostEntityPaste(ply,ent,created)
	local pikinfo = ent.EntityMods.PikInfo
	if pikinfo then
		self.Color = pikinfo.Color
		self.Level = pikinfo.Level
		self.NextBloom = CurTime()+pikinfo.BloomOffset
		self:SetModel(ColorCollideTable[self.Color])
		self.PikMdl:SetNWInt("Color",self.Color)
		self.PikMdl:SetNWInt("Level",math.min(2,self.Level))
		self.PikMdl:SetModel(ColorModelTable[(self.Color-1)*3+1+self.Level])
		self.PikMdl.Cycle = pikinfo.Cycle
		self:SetPos(pikinfo.Pos)
	end
	ent.EntityMods = nil
end