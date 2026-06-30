AddCSLuaFile()
ENT.Type = "point"
ENT.Base = "base_entity"
ENT.Spawnable = false

function ENT:Initialize()
end

function ENT:Think()
	local pik = ents.FindByClass("pikmin")
	if #pik ~= 0 then
		local pikDict = {}
		for _,v in ipairs(pik) do
			if IsValid(v.Olimar) and not v.Drowning and not v.Attacking and not v.Drinking and not v.Carrying then
				local t = pikDict[v.Olimar]
				if not t then t = {} pikDict[v.Olimar] = t end
				table.insert(t,v)
			end
		end
		for ply,pikt in pairs(pikDict) do
			if #pikt == 1 then continue end
			for i,pik1 in ipairs(pikt) do
				local pos = pik1:GetPos()
				local pik2
				for _,v in ipairs(ents.FindInSphere(pos,1)) do
					if v.Olimar ~= ply then continue end
					pik2 = v
					break
				end
				if not pik2 then continue end
				local p = (pos-pik2:GetPos())*100
				pik1.Phys:ApplyForceCenter(p-p*vector_up)
			end
		end
	end
	self:NextThink(CurTime()+0.1)
	return true
end