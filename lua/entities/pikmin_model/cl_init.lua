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

	-- procedural squash for Purple Pikmin Ground Pound on client that I'm gonna get back to later
	local impactTime = self:GetNWFloat("GroundPoundImpactTime", 0)
	local bone = self:LookupBone("Pik_Body")
	if bone then
		local isCrushed = IsValid(parent) and parent:GetNWBool("Crushed")
		local isBuried = IsValid(parent) and parent:GetNWBool("Buried")
		
		-- pikmin surface projection based on Pikmin 2
		if isCrushed then
			if not self.MatrixApplied then
				local mat = Matrix()
				mat:Scale(Vector(2.2, 2.2, 0.001))
				self:EnableMatrix("RenderMultiply", mat)
				self.MatrixApplied = true
			end
			for i = 0, self:GetBoneCount() - 1 do
				self:ManipulateBoneScale(i, Vector(1, 1, 1))
				self:ManipulateBonePosition(i, Vector(0, 0, 0))
			end
		else
			if self.MatrixApplied then
				self:DisableMatrix("RenderMultiply")
				self.MatrixApplied = nil
			end
			
			if isBuried then
				for i = 0, self:GetBoneCount() - 1 do
					self:ManipulateBoneScale(i, Vector(1, 1, 1))
				end
				local progress = parent:GetNWFloat("BuryProgress", 0)
				local zOffset = Lerp(progress, -34, 0)
				self:ManipulateBonePosition(bone, Vector(zOffset, 0, 0))
			else
				self:ManipulateBonePosition(bone, Vector(0, 0, 0))
				for i = 0, self:GetBoneCount() - 1 do
					self:ManipulateBoneScale(i, Vector(1, 1, 1))
				end
				
				if impactTime > 0 then
					local dt = CurTime() - impactTime
					if dt >= 0 and dt < 0.35 then
						if dt < 0.1 then
							local frac = dt / 0.1
							local z = Lerp(frac, 0.488, 0.514)
							local xy = Lerp(frac, 1.858, 1.794)
							local spineScale = Vector(z, xy, xy)
							local legScale = Vector(0.001, 0.001, 0.001)
							
							self:ManipulateBoneScale(bone, spineScale)
							local lLeg = self:LookupBone("Pik_LL")
							local rLeg = self:LookupBone("Pik_RL")
							if lLeg then self:ManipulateBoneScale(lLeg, legScale) end
							if rLeg then self:ManipulateBoneScale(rLeg, legScale) end
						elseif dt < 0.2 then
							local frac = (dt - 0.1) / 0.1
							local z = Lerp(frac, 0.514, 0.582)
							local xy = Lerp(frac, 1.794, 1.636)
							local spineScale = Vector(z, xy, xy)
							local legScale = Vector(0.001, 0.001, 0.001)
							
							self:ManipulateBoneScale(bone, spineScale)
							local lLeg = self:LookupBone("Pik_LL")
							local rLeg = self:LookupBone("Pik_RL")
							if lLeg then self:ManipulateBoneScale(lLeg, legScale) end
							if rLeg then self:ManipulateBoneScale(rLeg, legScale) end
						elseif dt < 0.3 then
							local frac = (dt - 0.2) / 0.1
							local z = Lerp(frac, 0.582, 1.0)
							local xy = Lerp(frac, 1.636, 1.0)
							local spineScale = Vector(z, xy, xy)
							local legFrac = Lerp(frac, 0.001, 1.0)
							local legScale = Vector(legFrac, legFrac, legFrac)
							
							self:ManipulateBoneScale(bone, spineScale)
							local lLeg = self:LookupBone("Pik_LL")
							local rLeg = self:LookupBone("Pik_RL")
							if lLeg then self:ManipulateBoneScale(lLeg, legScale) end
							if rLeg then self:ManipulateBoneScale(rLeg, legScale) end
						end
					end
				end
			end
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