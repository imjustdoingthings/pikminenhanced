include("shared.lua")

function ENT:Initialize() end

function ENT:Draw()
	self:DrawModel()
	if self:GetNWBool("Dismissed") then
		local lvl = self:GetNWInt("Level",0)
		local bone = self:LookupBone(lvl == 0 and "piki_leaf" or lvl == 1 and "piki_bud" or lvl == 2 and "piki_flower")
		if not bone then bone = self:LookupBone("piki_leaf") end
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
	if self:GetNWBool("Poison") then
		local lvl = self:GetNWInt("Level",0)
		local bone = self:LookupBone(lvl == 0 and "piki_leaf" or lvl == 1 and "piki_bud" or lvl == 2 and "piki_flower")
		if not bone then bone = self:LookupBone("piki_leaf") end
		if bone then
			local pos = self:GetBonePosition(bone)
			if pos == self:GetPos() then 
				local mat = self:GetBoneMatrix(bone)
				if mat then pos = mat:GetTranslation() end
			end
			render.SetMaterial(PoisonMat)
			local sizevar = math.sin(CurTime()*12)*4
			render.DrawQuadEasy(pos,(EyePos()-pos):GetNormal(),24+sizevar,24+sizevar,Color(175,25,175),math.sin(CurTime()*10)*8)
		end
	end
end