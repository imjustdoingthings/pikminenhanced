include("shared.lua")

function ENT:Initialize() end

function ENT:Draw()
	self:DrawModel()
	local lvl = self:GetNWInt("Level",0)
	local bone = self:LookupBone(lvl == 0 and "piki_leaf" or lvl == 1 and "piki_bud" or lvl == 2 and "piki_flower")
	if bone then
		local pos = self:GetBonePosition(bone)
		if pos == self:GetPos() then 
			local mat = self:GetBoneMatrix(bone)
			if mat then pos = mat:GetTranslation() end
		end
		render.SetMaterial(DisbandLight)
		render.DrawSprite(pos, 28, 28, DisbandColors[self:GetNWInt("Color",1)])
	end
end