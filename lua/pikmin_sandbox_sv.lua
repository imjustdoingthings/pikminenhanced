local EntDrops = {
	{"models/pikmin/pellet_1.mdl"},
	{"models/pikmin/pellet_5.mdl"},
	{"models/pikmin/pellet_10.mdl"},
}

local function PikiDropSandbox(ent,dmg,took)
	if not took then return end
	if not ent.PikDrops and ent:IsNPC() and ent:Health() <= 0 and IsValid(dmg:GetInflictor()) and dmg:GetInflictor().PikMdl then
		ent.PikDrops = true
		if ent:GetClass() == "npc_antlion" then if math.random(1,8) <= 4 then return end ent.PikDropName = "models/pikmin/pellet_1.mdl" end
		if ent:GetClass() == "npc_dog" then if math.random(1,8) <= 4 then return end ent.PikDropName = "models/pikmin/pellet_5.mdl" end
		local drop = ent.PikDropName
		if not drop then
			if ent:GetMaxHealth() <= 35 or math.random(1,8) <= 4 then return end
			local rng = ent:GetMaxHealth()+math.random(0,20)
			rng = math.ceil(rng/8)/60
			local dropTable = EntDrops[math.Clamp(math.floor(rng*3),1,3)]
			drop = dropTable[math.random(#dropTable)]
		end
		local dropEnt = ents.Create("prop_physics")
		dropEnt:SetModel(drop)
		dropEnt:SetPos(ent:WorldSpaceCenter()+Vector(0,0,10))
		dropEnt:SetAngles(Angle(math.random(-15,15),math.random(-90,90),math.random(-15,15)))
		dropEnt:SetSkin(math.random(dropEnt:SkinCount())-1)
		dropEnt:Spawn()
		dropEnt:Activate()
		dropEnt:EmitSound("pikmin/discover.wav")
	end
end

cvars.AddChangeCallback("pik_drops", function(name,ov,nv)
	hook.Remove("PostEntityTakeDamage","PikiDropSandbox")
	if nv == "1" then
		hook.Add("PostEntityTakeDamage","PikiDropSandbox",PikiDropSandbox)
	end
end)

--0.4 fadebias for morning sky
--Sunset Vector (0,-1,0)
--X axis is forward in GMod

--make pik_mapinfo class to manage variables for gamemode related things
--such as: level name, sky properties, etc

--also make class for end of day camera position (small custom background area to be seen when lifting off; wouldn't be required)

--[[hook.Add("InitPostEntity","SkyInit",function()
	local sky = ents.FindByClass("env_skypaint")[1]
	if not sky then
		sky = ents.Create("env_skypaint")
		sky:Spawn()
		timer.Simple(1,function() RunConsoleCommand("sv_skyname","painted") end)
	end
	local sun = ents.FindByClass("env_sun")[1]
	if sun then sun:Remove() end
	sky:SetKeyValue("topcolor","0 0 0.01 0")
	sky:SetKeyValue("bottomcolor","0 0 0 0")
	sky:SetKeyValue("fadebias","0")
	sky:SetKeyValue("duskintensity","0")
	sky:SetKeyValue("sunsize","0")
	sky:SetKeyValue("starfade","1")
	sky:SetKeyValue("starlayers","1")
	sky:SetKeyValue("starscale","2")
	sky:SetKeyValue("starspeed","0.01")
	sky:SetKeyValue("hdrscale","0.1")
	sky:SetKeyValue("drawstars","Yes")
	sky:SetKeyValue("startexture","skybox/starfield")
	engine.LightStyle(0,"a")
	timer.Simple(0.1,function() BroadcastLua("render.RedownloadAllLightmaps()") end)
end)--]]