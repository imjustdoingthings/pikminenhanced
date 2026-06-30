AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
	if not self.Olimar:Alive() or self.Olimar:GetNWBool("ispikmin") then self:Remove() return end
	self:DrawShadow(false)
	self.Olimar:SetNWBool("ispikmin",true)
	local pik = ents.Create("pikmin")
	pik.PikPly = true
	pik.Color = self.Color
	pik.Level = self.Level
	pik.Olimar = self
	pik.Dismissed = false
	self:SetPos(self.Olimar:GetPos())
	pik:SetPos(self.Olimar:GetPos())
	pik:SetAngles(self.Olimar:GetAngles())
	pik:Spawn()
	pik:Activate()
	self.Pik = pik
	self.Olimar:StripWeapons()
	self.Olimar:SetMoveType(MOVETYPE_OBSERVER)
	self.Olimar:Spectate(OBS_MODE_CHASE)
	self.Olimar:SpectateEntity(pik)
	if self.Olimar:FlashlightIsOn() then self.Olimar:Flashlight(false) end
	self.Olimar:AllowFlashlight(false)
	self:SetNWEntity("Olimar",self.Olimar)
	self:SetNWEntity("Piki",self.Pik)
	self.IgnoreList = {self,self.Olimar,self.Pik}
	for _,v in ipairs(ents.FindByClass("pikmin")) do if v.Olimar == self.Olimar then v.Olimar = nil end end
end

local function GetChargeTarget(pos,aim,ignore)
	local tr = util.QuickTrace(pos,aim,ignore)
	if IsValid(tr.Entity) then
		if tr.Entity.PikIgnore then return end
		local class = tr.Entity:GetClass()
		if class == "pikmin" or class == "pikmin_onion" or class == "pikmin_model" or class == "prop_ragdoll" or class == "pikmin_sprout" then return end
		if class == "prop_physics" and not (table.KeyFromValue(PikiCarryOnionList,tr.Entity:GetModel()) or tr.Entity.IsCarry) then return end
		if (class == "pikmin_fire" or class == "pikmin_gas" or class == "pikmin_wire") and tr.Entity:Health() <= 0 then return end
		if string.sub(class,1,4) == "func" then return end
	end
	return tr.Entity
end

local SingLow = {
{"pikmin/sing1.wav",0.5},
{"pikmin/sing2.wav",0.5},
{"pikmin/sing3.wav",0.25},
{"pikmin/sing4.wav",0.25},
{"pikmin/sing2.wav",0.5},
{"pikmin/sing5.wav",1}
}
local SingMed = {
{"pikmin/sing6.wav",0.5},
{"pikmin/sing7.wav",0.5},
{"pikmin/sing8.wav",0.25},
{"pikmin/sing9.wav",0.25},
{"pikmin/sing7.wav",0.5},
{"pikmin/sing10.wav",1}
}
local SingHigh = {
{"pikmin/sing11.wav",0.5},
{"pikmin/sing12.wav",0.5},
{"pikmin/sing13.wav",0.25},
{"pikmin/sing14.wav",0.25},
{"pikmin/sing12.wav",0.5},
{"pikmin/sing15.wav",1}
}
local SingAll = {SingLow,SingMed,SingHigh}

function ENT:Think()
	if not IsValid(self.Pik) or not IsValid(self.Olimar) then self:Remove() return false end
	if not self.Olimar:Alive() then self.Pik:Die() self:Remove() return false end
	
	if not self.Pik.Dead then
		local LookAngles = self.Olimar:EyeAngles()
		LookAngles = Angle(0,LookAngles.y,0)
		local MoveX,MoveZ = self.Olimar:KeyDown(IN_MOVERIGHT) and 1 or self.Olimar:KeyDown(IN_MOVELEFT) and -1 or 0,self.Olimar:KeyDown(IN_FORWARD) and 1 or self.Olimar:KeyDown(IN_BACK) and -1 or 0
		local MoveUp = self.Color == 7 and (self.Olimar:KeyDown(IN_JUMP) and 1 or self.Olimar:KeyDown(IN_DUCK) and -1 or 0) or 0
		self:SetPos(self.Pik:GetPos()+LookAngles:Forward()*50+LookAngles:Forward()*MoveZ*500+LookAngles:Right()*MoveX*500+Vector(0,0,MoveUp*500))
		
		if self.Olimar:KeyDown(IN_ATTACK) and (self.Pik.PikMdl.CurAnim == 1 or self.Pik.PikMdl.CurAnim == 2 or self.Pik.PikMdl.CurAnim == self.Pik.WingedIdle) then
			if self.SingTick and CurTime() >= self.SingTick or not self.SingTick then
				if not self.SingID then
					self.SingType = math.random(1,3)
					self.SingID = 1
				end
				local info = SingAll[self.SingType][self.SingID]
				self.SingTick = CurTime()+info[2]
				self.Pik:EmitSound(info[1])
				self.SingID = self.SingID + 1
				if self.SingID > 6 then self.SingID = nil end
			end
		end
		
		if self.Olimar:KeyDown(IN_ATTACK2) then
			if not self.Pik.Dismissed and not self.Pik.AttackTarget then
				local target = GetChargeTarget(self.Pik:GetPos()+Vector(0,0,30),self.Olimar:EyeAngles():Forward()*6000,self.IgnoreList)
				if target and IsValid(target) then self.Pik:Charge(target) end
			end
		end
		
		if self.Olimar:KeyDown(IN_RELOAD) and (self.ActDebounce and CurTime() >= self.ActDebounce or not self.ActDebounce) then
			self.ActDebounce = CurTime()+0.5
			if self.Olimar:KeyDown(IN_USE) then
				if not self.Pik.Dismissed then
					if self.Pik.AttackTarget or self.Pik.Carrying then self.Pik:Drop() end
					self.Pik:Disband()
				end
			else
				if self.Pik.Dismissed then
					self.Pik:Join(self)
				elseif self.Pik.Olimar ~= self then
					self.Pik.Olimar = self
				end
				if self.Pik.AttackTarget or self.Pik.Carrying then
					self.Pik:Drop()
				end
			end
		end
		
		if self.Color ~= 7 and self.Olimar:KeyDown(IN_JUMP) then
			local ground = util.QuickTrace(self.Pik:GetPos(),vector_up*-5,self.IgnoreList)
			if ground.Hit and (self.JumpDebounce and CurTime() >= self.JumpDebounce or not self.JumpDebounce) then
				self.JumpDebounce = CurTime()+1
				if not self.Pik.Dismissed and not self.Pik.Carrying and not self.Pik.Drinking and not self.Pik:IsOnFire() and not self.Pik.Poison and not self.Pik.Drowning and not self.Pik.Attacking and not self.Pik.Thrown and CurTime() >= self.Pik.ThrowNext then
					self.Pik.Thrown = true
					self.Pik.Phys:ApplyForceCenter(self.Pik.JumpVector*2)
				end
			end
		end
	end
	
	self:NextThink(CurTime())
	return true
end

--haha read this fake value
function ENT:Alive()
	return true
end

function ENT:OnRemove()
	if self.Pik and IsValid(self.Pik) then if not self.Pik.Dead then self.Pik:Remove() end end
	if self.Olimar and IsValid(self.Olimar) then self.Olimar:SetNWBool("ispikmin",false) self.Olimar:KillSilent() end
end

function ENT:SpawnFunction(ply)
	ply:ConCommand("pikmin_menu 2")
end