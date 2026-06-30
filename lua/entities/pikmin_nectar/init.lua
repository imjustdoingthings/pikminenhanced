AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

ENT.Debounce = false
ENT.PikInteract = true

function ENT:Initialize()
	self:SetModel("models/pikmin/nectar.mdl") --self:SetModel("models/props_vehicles/carparts_wheel01a.mdl")
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetColor(Color(255, 191, 0, 255))
	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetMass(500)
		phys:Wake()
	end
end

function ENT:SpawnFunction(ply, tr)
	if !tr.Hit then return end
	local ent = ents.Create("pikmin_nectar")
	ent:SetPos(tr.HitPos + tr.HitNormal * 16)
	ent:Spawn()
	ent:Activate()
	undo.Create("#pikmin_nectar")
		undo.AddEntity(ent)
		undo.SetPlayer(ply)
	undo.Finish()
end

function ENT:StartTouch(obj)
	if obj:GetClass() == "pikmin" then
		if obj.Level == 2 then if obj.AttackTarget == self then obj.AttackTarget = nil end return end
		if (not obj.AttackTarget or obj.AttackTarget == self) and not obj.Drowning and not obj.Burning then
			if obj.Thrown then obj.Thrown = false end
			obj.Drinking = true
			obj:SetParent(self)
			obj:EmitSound("pikmin/suck.wav")
			if not self.Debounce then
				self.Debounce = true
				timer.Create("nectar"..self:EntIndex(),2.5,1,function()
					local pos = self:GetPos()
					for _,v in ipairs(ents.FindByClass("pikmin")) do
						if v:GetParent() == self then
							v.AttackTarget = nil
							v:SetParent()
							v:SetPos(pos + Vector(math.Rand(-20, 20), math.Rand(-20, 20), 10))
							v:SetLevel(2)
							v:EmitSound("pikmin/level.wav")
							v.Drinking = false
						end
					end
					self:Remove()
				end)
			end
		end
	end
end

function ENT:OnRemove()
	timer.Remove("nectar"..self:EntIndex())
	local pos = self:GetPos()
	for _,v in ipairs(ents.FindByClass("pikmin")) do
		if v:GetParent() == self then
			v.AttackTarget = nil
			v:SetParent()
			v:SetPos(pos + Vector(math.Rand(-20, 20), math.Rand(-20, 20), 10))
			v.Drinking = false
		end
	end
end