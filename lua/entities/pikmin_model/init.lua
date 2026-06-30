AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include('shared.lua')

ENT.CurAnim = 2

function ENT:Initialize()
	self:DrawShadow(false)
	self.Cycle = self.Cycle or math.Rand(0,1)
end

function ENT:Think()
	if self.LastAnim ~= self.CurAnim then
		self.LastAnim = self.CurAnim
		self:ResetSequence(self.CurAnim)
		if self.Cycle then self:SetCycle(self.Cycle) self.Cycle = nil end
	end
	self:NextThink(CurTime())
	return true
end