include("shared.lua")

function ENT:Initialize() end

function ENT:Think()
	local parent = self:GetParent()
	local isThrown = IsValid(parent) and parent:GetNWBool("Thrown")
	
	if isThrown then
		-- sparkles 
		self.NextSparkle = self.NextSparkle or 0
		if CurTime() >= self.NextSparkle then
			self.NextSparkle = CurTime() + 0.04
			
			local col = DisbandColors[self:GetNWInt("Color", 1)] or Color(255, 255, 255)
			local pos = self:GetPos() + VectorRand() * 5
			
			if not self.Emitter or not self.Emitter:IsValid() then
				self.Emitter = ParticleEmitter(self:GetPos())
			end
			
			if self.Emitter then
				local part = self.Emitter:Add("sprites/light_glow02_add", pos)
				if part then
					part:SetDieTime(math.Rand(0.4, 0.7))
					part:SetStartAlpha(255)
					part:SetEndAlpha(0)
					part:SetStartSize(math.Rand(12, 22))
					part:SetEndSize(0)
					part:SetRoll(math.Rand(0, 360))
					part:SetRollDelta(math.Rand(-6, 6))
					part:SetColor(col.r, col.g, col.b)
					part:SetGravity(Vector(0, 0, -30))
					part:SetAirResistance(10)
					-- i looooooove particles
				end
			end
		end
	else
		if self.Emitter and self.Emitter:IsValid() then
			self.Emitter:Finish()
			self.Emitter = nil
		end
	end
end

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

function ENT:OnRemove()
	if self.Emitter and self.Emitter:IsValid() then
		self.Emitter:Finish()
	end
end