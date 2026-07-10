include("autorun/sh_pikmin.lua")

HideOlimarHUD = false
CreateConVar("pikmin_nohud","0",{FCVAR_ARCHIVE},"hide the weapon HUD")
cvars.AddChangeCallback("pikmin_nohud",function(name,ov,nv) HideOlimarHUD = nv == "1" and true or false end)

local PikiMenu = nil

local function SpawnPikminMenu(ply, cmd, args)
	if args[1] == "0" then if PikiMenu then PikiMenu:Close() end return end
	if PikiMenu then return end
	if args[1] == "2" and LocalPlayer():GetNWBool("ispikmin") then return end
	if not LocalPlayer():Alive() then return end
	local w, h = surface.ScreenWidth(), surface.ScreenHeight()
	local frame = vgui.Create("DFrame")
	
	local MenuType = tonumber(args[1]) or 0
	
	if MenuType == 3 then
		frame:SetSize((w * .4), (h * .275))
	else
		frame:SetSize((w * .98), (h * .35))
	end
	
	PikiMenu = frame
	
	local W = frame:GetWide();
	local H = frame:GetTall();
	
	function frame:OnClose()
		PikiMenu = nil
		gui.EnableScreenClicker(false)
	end
	frame:SetPos(((w * .5) - (W * .5)), (h * .125));
	frame:SetVisible(true);
	
	frame:SetTitle("#pikispawn")
	if MenuType ~= 0 then frame:SetTitle("#pikispawn"..MenuType) end
	
	if MenuType <= 2 then
		local piktbl = {
			"red",
			"yellow",
			"blue",
			"purple",
			"white",
			"bulbmin",
			"pink",
			"rock",
			"mushroom"
		}
		
		local qtySlider = nil
		if MenuType ~= 2 then
			qtySlider = vgui.Create("DNumSlider", frame)
			qtySlider:SetPos((W * .1), (H * .75))
			qtySlider:SetWide((W * .35))
			qtySlider:SetTall((H * .1))
			qtySlider:SetText("Quantity:")
			qtySlider:SetMin(1)
			qtySlider:SetMax(100)
			qtySlider:SetDecimals(0)
			qtySlider:SetValue(1)
		end
		
		local matCombo = vgui.Create("DComboBox", frame)
		matCombo:SetPos(MenuType == 2 and (W * .3) or (W * .55), (H * .77))
		matCombo:SetWide(MenuType == 2 and (W * .4) or (W * .35))
		matCombo:SetTall((H * .06))
		matCombo:SetValue("Leaf")
		matCombo:AddChoice("Leaf", "leaf")
		matCombo:AddChoice("Bud", "bud")
		matCombo:AddChoice("Flower", "flower")

		local inc = 0;
		local itemSpace = (W * 0.9) / #piktbl;
		
		local modelLookup = {bulbmin = "green", mushroom = "puffmin"}
		for i = 1, #piktbl do //lets do this neatly...
			local btn = vgui.Create("DModelPanel", frame);
			btn:SetPos(((W * .05) + inc), (H * .15));
			btn:SetWide(itemSpace * 0.95);
			btn:SetTall((H * .55));
			btn:SetModel("models/pikmin/pikmin_" .. (modelLookup[piktbl[i]] or piktbl[i]) .. "1.mdl");
			btn:SetLookAt(Vector(0, 0, 25));
			btn:SetFOV(56);
			btn:SetAmbientLight(Color(80, 80, 80));
			btn:SetCamPos(Vector(60, 15, 40));
			btn:SetAnimSpeed(math.Rand(.9, 1.2));
			btn:SetAnimated(true);
			if piktbl[i] == "pink" then
				btn.Entity:ResetSequence(btn.Entity:LookupSequence("idle"));
			else
				btn.Entity:ResetSequence(btn.Entity:LookupSequence("dismissed"));
			end
			function btn:LayoutEntity(ent)
				self:RunAnimation();
			end
			function btn:DoClick()
				local _, mat = matCombo:GetSelected()
				mat = mat or "leaf"
				local qty = qtySlider and math.floor(qtySlider:GetValue()) or 1
				RunConsoleCommand("pikmin_create" .. (MenuType == 1 and "s" or MenuType == 2 and "p" or ""), piktbl[i], mat, qty)
				if MenuType == 2 then frame:Close() end
			end
			inc = inc + itemSpace;
		end
		
		local rand = vgui.Create("DButton", frame);
		rand:SetPos((W * .1), (H * .87));
		rand:SetWide((W * .8));
		rand:SetTall((H * .1));
		rand:SetText("#pikirand");
		rand.DoClick = function()
			local _, mat = matCombo:GetSelected()
			mat = mat or "leaf"
			local qty = qtySlider and math.floor(qtySlider:GetValue()) or 1
			RunConsoleCommand("pikmin_create" .. (MenuType == 1 and "s" or MenuType == 2 and "p" or ""), "random", mat, qty)
			if MenuType == 2 then frame:Close() end
		end
	elseif MenuType == 3 then
		local onionExist = {}
		for _,v in ipairs(ents.FindByClass("pikmin_onion")) do
			onionExist[v:GetSkin()] = true
		end
		local inc = 0
		-- old onions
		for i = 1,3 do
			if not onionExist[3-i] then
				local btn = vgui.Create("DModelPanel", frame);
				btn:SetPos(((W * .05) + inc), (H * .2))
				btn:SetWide((W * .35))
				btn:SetTall((H * .7))
				btn:SetModel("models/pikmin/onion.mdl")
				btn.Entity:SetSkin(3-i)
				btn:SetLookAt(Vector(0, 0, 25))
				btn:SetFOV(56)
				btn:SetAmbientLight(Color(80, 80, 80))
				btn:SetCamPos(Vector(500, 15, 500))
				btn:SetAnimSpeed(math.Rand(.9, 1.2))
				btn:SetAnimated(true)
				btn.Entity:ResetSequence(btn.Entity:LookupSequence("idle") or 1)
				function btn:LayoutEntity(ent) self:RunAnimation() end
				function btn:DoClick()
					RunConsoleCommand("pikmin_createo", 0, 3-i)
					frame:Close()
				end
				inc = (inc + (24 + (w * .1)))
			end
		end
	elseif MenuType == 5 then
		-- Pikmin 3 Onions
		local onionExist = {}
		for _,v in ipairs(ents.FindByClass("pikmin_onion_p3")) do
			onionExist[v:GetSkin()] = true
		end
		
		frame:SetSize((w * .6), (h * .4))
		W, H = frame:GetWide(), frame:GetTall()
		frame:SetPos(((w * .5) - (W * .5)), (h * .25))
		
		local inc = 0
		local itemSpace = (W * 0.9) / 6
		for i = 0, 4 do
			if not onionExist[i] then
				local btn = vgui.Create("DModelPanel", frame);
				btn:SetPos(((W * .05) + inc), (H * .25));
				btn:SetWide(itemSpace);
				btn:SetTall((H * .6));
				btn:SetModel("models/pikmin/onion_new.mdl");
				btn.Entity:SetSkin(i);
				btn:SetLookAt(Vector(0, 0, 40));
				btn:SetFOV(56);
				btn:SetAmbientLight(Color(80, 80, 80));
				btn:SetCamPos(Vector(250, 15, 250));
				btn:SetAnimated(true);
				function btn:LayoutEntity(ent) self:RunAnimation() end
				function btn:DoClick()
					RunConsoleCommand("pikmin_createo", 1, i)
					frame:Close()
				end
				inc = inc + itemSpace
			end
		end
		
		-- Master Onion (always show if not exists)
		local masterExists = #ents.FindByClass("pikmin_onion_master") > 0
		if not masterExists then
			local btn = vgui.Create("DModelPanel", frame);
			btn:SetPos(((W * .05) + inc), (H * .25));
			btn:SetWide(itemSpace);
			btn:SetTall((H * .6));
			btn:SetModel("models/pikmin/onion_large.mdl");
			btn:SetLookAt(Vector(0, 0, 80));
			btn:SetFOV(56);
			btn:SetAmbientLight(Color(80, 80, 80));
			btn:SetCamPos(Vector(600, 15, 600));
			btn:SetAnimated(true);
			function btn:LayoutEntity(ent) self:RunAnimation() end
			function btn:DoClick()
				RunConsoleCommand("pikmin_createo", 2, 0)
				frame:Close()
			end
		end



	elseif MenuType == 4 then
		local inc = 0
		for i = 1,5 do
			local btn = vgui.Create("DModelPanel", frame);
			btn:SetPos(inc, (H * .2))
			btn:SetWide((W * .2))
			btn:SetTall((H * .7))
			btn:SetModel("models/pikmin/pom.mdl")
			btn.Entity:SetSkin(i-1)
			btn:SetLookAt(Vector(0, 0, 25))
			btn:SetFOV(56)
			btn:SetAmbientLight(Color(80, 80, 80))
			btn:SetCamPos(Vector(140, 15, 140))
			btn:SetAnimSpeed(math.Rand(.9, 1.2))
			btn:SetAnimated(true)
			btn.Entity:ResetSequence(1)
			function btn:LayoutEntity(ent) self:RunAnimation() end
			function btn:DoClick() RunConsoleCommand("pikmin_createb",i) end
			inc = inc + W*.2
		end
	end
	frame:SizeToContents()
	gui.EnableScreenClicker(true)
end
concommand.Add("pikmin_menu", SpawnPikminMenu)

concommand.Add("pikmin_p3ospawnmenu", function(ply, cmd, args)
	SpawnPikminMenu(ply, cmd, {5, args[1], args[2], args[3], args[4]})
end)

local function PikminOnionMenu(ply,cmd,args)
	if not args[1] or not args[2] or not args[3] then return end
	--local tr = util.QuickTrace(ply:GetShootPos(), (ply:GetAimVector() * 200), ply)
	--if IsValid(tr.Entity) and tr.Entity:GetClass() == "pikmin_onion" then
	args[1] = tonumber(args[1])
	args[2] = tonumber(args[2])
	args[3] = tonumber(args[3])
	local onionColors = {
		[0] = Color(0, 0, 150, 250),    -- Legacy Blue
		[1] = Color(150, 150, 0, 250),  -- Legacy Yellow
		[2] = Color(150, 0, 0, 250),    -- Legacy Red
		[3] = Color(150, 0, 0, 250),    -- P3 Red
		[4] = Color(0, 0, 150, 250),    -- P3 Blue
		[5] = Color(150, 150, 0, 250),  -- P3 Yellow
		[6] = Color(255, 100, 150, 250),-- P3 Winged
		[7] = Color(80, 80, 80, 250),   -- P3 Rock
		[8] = Color(150, 150, 150, 250),-- Master Onion (Fallback)
	}
	local frameColor = onionColors[args[1]] or Color(100, 100, 100, 250)
	
	local w, h = surface.ScreenWidth(), surface.ScreenHeight()
	local frame = vgui.Create("DFrame")
	frame:SetSize((w * .3), (h * .5))
	
	local W = frame:GetWide()
	local H = frame:GetTall()
	frame.Paint = function()
		draw.RoundedBox(8,0,0,frame:GetWide(),frame:GetTall(),frameColor)
	end
	
	frame:SetPos(((w * .5) - (W * .5)), (h * .5) - (H * .5))
	frame:SetVisible(true)
	frame:MakePopup()
	frame:SetTitle("#pikionionmenu")
	
	local label = vgui.Create("DLabel",frame)
	label:SetPos(0,H*0.1)
	label:SetSize(W,H*0.1)
	label:SetText(args[2]..language.GetPhrase("pikmin_count"))
	label:SetFont("DermaLarge")
	label:SetTextColor(Color(255,255,255,255))
	label:SetContentAlignment(5)
	
	local call_slider = nil
	local send_slider = nil
	local act_button = nil
	
	if (args[2] ~= 0 and not args[4]) or args[3] ~= 0 then
		act_button = vgui.Create("DButton", frame)
		act_button:SetPos((W * .1), (H * .8))
		act_button:SetWide((W * .8))
		act_button:SetTall((H * .1))
		act_button:SetText("#pikicall")
		act_button.DoClick = function()
			if call_slider and send_slider then
				ply:ConCommand("pikmin_call "..math.floor(call_slider:GetValue()).." "..math.floor(send_slider:GetValue()))
			elseif call_slider then
				ply:ConCommand("pikmin_call "..math.floor(call_slider:GetValue()))
			elseif send_slider then
				ply:ConCommand("pikmin_call 0 "..math.floor(send_slider:GetValue()))
			end
			frame:Close()
		end
	end
	
	local CallTotal = math.min(100-#ents.FindByClass("pikmin")-#ents.FindByClass("pikmin_sprout"),args[2])
	
	if CallTotal ~= 0 then
		call_slider = vgui.Create("DNumSlider",frame)
		call_slider:SetMinMax(0,CallTotal)
		call_slider:SetPos(W*-0.18, H*0.6)
		call_slider:SetSize(W, H*0.1)
		call_slider:SetValue(0)
		call_slider:SetDecimals(0)
		function call_slider:OnValueChanged(val)
			if send_slider then
				label:SetText(args[2]-math.floor(val)+math.floor(send_slider:GetValue())..language.GetPhrase("pikmin_count"))
			else
				label:SetText(args[2]-math.floor(val)..""..language.GetPhrase("pikmin_count"))
			end
		end
	end
	
	if args[3] ~= 0 then
		act_button:SetText("#pikisend")
		send_slider = vgui.Create("DNumSlider",frame)
		send_slider:SetPos(W*-0.18, H*0.6)
		if call_slider then
			send_slider:SetPos(W*-0.18, H*0.4)
			act_button:SetText("#pikicallsend")
		end
		send_slider:SetMinMax(0,args[3])
		send_slider:SetSize(W, H*0.1)
		send_slider:SetValue(0)
		send_slider:SetDecimals(0)
		function send_slider:OnValueChanged(val)
			if call_slider then
				label:SetText(args[2]-math.floor(call_slider:GetValue())+math.floor(val)..language.GetPhrase("pikmin_count"))
			else
				label:SetText(args[2]+math.floor(val)..language.GetPhrase("pikmin_count"))
			end
		end
	end
	
	frame:SizeToContents()
	--end
end
concommand.Add("pikmin_omenu", PikminOnionMenu)

local function PikminMasterOnionMenu(onion, counts, oncounts, TooMany)
	local w, h = surface.ScreenWidth(), surface.ScreenHeight()
	local frame = vgui.Create("DFrame")
	frame:SetSize((w * .7), (h * .6))
	
	local W = frame:GetWide()
	local H = frame:GetTall()
	frame.Paint = function()
		draw.RoundedBox(8,0,0,W,H,Color(100,100,100,250))
	end
	
	frame:SetPos(((w * .5) - (W * .5)), (h * .5) - (H * .5))
	frame:SetVisible(true)
	frame:MakePopup()
	frame:SetTitle("Master Onion")
	
	local theme = CreateSound(LocalPlayer(), "pikmin/theme.wav")
	theme:Play()
	
	function frame:OnClose()
		theme:Stop()
	end
	
	local inc = 0
	local itemSpace = (W * 0.9) / #PikiOnionP3Colors
	local sliders = {}
	
	for k,c in ipairs(PikiOnionP3Colors) do
		local panel = vgui.Create("DPanel", frame)
		panel:SetPos((W * .05) + inc, H * 0.1)
		panel:SetSize(itemSpace * 0.95, H * 0.7)
		panel.Paint = function() end
		
		local label = vgui.Create("DLabel", panel)
		label:SetPos(0, 0)
		label:SetSize(panel:GetWide(), H * 0.05)
		label:SetText(oncounts[c] .. " / " .. counts[c])
		label:SetContentAlignment(5)
		
		local btn = vgui.Create("DModelPanel", panel)
		btn:SetPos(0, H * 0.05)
		btn:SetSize(panel:GetWide(), H * 0.35)
		btn:SetModel("models/pikmin/pikmin_" .. (c == 8 and "rock" or c == 7 and "pink" or c == 1 and "red" or c == 2 and "yellow" or c == 3 and "blue" or "red") .. "1.mdl")
		btn:SetLookAt(Vector(0, 0, 25))
		btn:SetFOV(56)
		btn:SetCamPos(Vector(60, 15, 40))
		btn:SetAnimated(true)
		local seq = (c == 7) and btn.Entity:LookupSequence("swimming") or btn.Entity:LookupSequence("idle")
		btn.Entity:ResetSequence(seq or 2)
		function btn:LayoutEntity(ent) self:RunAnimation() end
		
		local call_slider = vgui.Create("DNumSlider", panel)
		call_slider:SetPos(0, H * 0.45)
		call_slider:SetSize(panel:GetWide(), H * 0.05)
		call_slider:SetMinMax(0, oncounts[c])
		call_slider:SetDecimals(0)
		call_slider:SetText("Call")
		
		local send_slider = vgui.Create("DNumSlider", panel)
		send_slider:SetPos(0, H * 0.5)
		send_slider:SetSize(panel:GetWide(), H * 0.05)
		send_slider:SetMinMax(0, counts[c])
		send_slider:SetDecimals(0)
		send_slider:SetText("Send")
		
		sliders[c] = {call = call_slider, send = send_slider}
		
		inc = inc + itemSpace
	end
	
	local go_btn = vgui.Create("DButton", frame)
	go_btn:SetPos(W * .1, H * .85)
	go_btn:SetSize(W * .8, H * .1)
	go_btn:SetText("Go!")
	go_btn:SetFont("DermaLarge")
	go_btn.DoClick = function()
		local activeTransfers = {}
		for _,c in ipairs(PikiOnionP3Colors) do
			local slidersForColor = sliders[c]
			local callVal = math.floor(slidersForColor.call:GetValue())
			local sendVal = math.floor(slidersForColor.send:GetValue())
			if callVal > 0 or sendVal > 0 then
				table.insert(activeTransfers, {color = c, call = callVal, send = sendVal})
			end
		end
		
		if #activeTransfers > 0 then
			net.Start("PikiMasterOnionGo")
			net.WriteEntity(onion)
			net.WriteInt(#activeTransfers, 8)
			for _, t in ipairs(activeTransfers) do
				net.WriteInt(t.color, 8)
				net.WriteInt(t.call, 32)
				net.WriteInt(t.send, 32)
			end
			net.SendToServer()
		end
		frame:Close()
	end
end

net.Receive("PikiMasterOnionMenu", function()
	local onion = net.ReadEntity()
	local counts = {}
	local oncounts = {}
	for _,c in ipairs(PikiOnionP3Colors) do
		counts[c] = net.ReadInt(32)
		oncounts[c] = net.ReadInt(32)
	end
	local TooMany = net.ReadString()
	PikminMasterOnionMenu(onion, counts, oncounts, TooMany)
end)


--temp fix until next gmod update to display Olimar Gun info properly (https://github.com/Facepunch/garrysmod-issues/issues/5186)
language.Add("olimar_gun",language.GetPhrase("olimar_gun"))
language.Add("olimar_gun.purpose",language.GetPhrase("olimar_gun.purpose"))
language.Add("olimar_gun.info1",language.GetPhrase("olimar_gun.info1"))
language.Add("olimar_gun.info2",language.GetPhrase("olimar_gun.info2"))
language.Add("olimar_gun.info3",language.GetPhrase("olimar_gun.info3"))
language.Add("olimar_gun.info4",language.GetPhrase("olimar_gun.info4"))
language.Add("olimar_gun.info5",language.GetPhrase("olimar_gun.info5"))

--gamemode-specific features
hook.Add("PreGamemodeLoaded","PikiGMPreLoad",function()
	if GAMEMODE.FolderName == "sandbox" then include("pikmin_sandbox_cl.lua") end
end)

--//Hooks
local function GetPlayerColor(ply)
	if not IsValid(ply) then return end
	if ply:IsBot() then return Color(0,0,0,30) end
	local val = Vector(ply:GetInfo("cl_playercolor")):ToColor()
	local r,g,b,a = val:Unpack()
	val:SetUnpacked(r,g,b,30)
	return val
end

hook.Add("PostPlayerDraw", "PikiGlow", function(ply)
	local idx = table.KeyFromValue(OrimaModel,ply:GetModel())
	if not idx then return end
	if ply:GetBodygroup(1) ~= 0 then return end
	local bone = ply:LookupBone("ValveBiped.Bip01_Head1")
	if not bone then return end
	local pos,ang = ply:GetBonePosition(bone)
	pos = pos + ang:Forward()*OrimaLightMultX[idx] - ang:Right()*21
	local color = ply.PikiColor
	if not color then color = GetPlayerColor(ply) ply.PikiColor = color end
	render.SetMaterial(GlowLight)
	render.DrawSprite(pos, 18, 18, color)
	local EyeNormal = (EyePos() - pos):GetNormal()
	EyeNormal.z = 0
	render.SetMaterial(RayLight)
	local rad = 22 + math.sin(CurTime()*2.5)
	render.DrawQuadEasy(pos, EyeNormal, rad, rad, color_white, CurTime() * 22)
	local dlight = DynamicLight(ply:EntIndex())
	if not dlight then return end
	dlight.pos = pos
	dlight.r,dlight.g,dlight.b = color.r,color.g,color.b
	dlight.brightness = 1
	dlight.Decay = 1000
	dlight.Size = 100
	dlight.DieTime = CurTime() + 0.1
end)

hook.Add("ShouldCollide","PikiCollide",function(ent1,ent2)
	if ent1:GetClass() == "pikmin" and ent2:GetClass() == "pikmin" then return false end
	if ent1:GetClass() == "pikmin" and ent2:IsPlayer() and ent1:GetNWEntity("Olimar") == ent2 then local wep = ent2:GetActiveWeapon() if not IsValid(wep) or wep:GetClass() == "olimar_gun" then return false end end
	return GAMEMODE:ShouldCollide(ent1,ent2)
end)

gameevent.Listen("player_spawn")
hook.Add("player_spawn","PikiGlowPre",function(data)
	local ply = Player(data.userid)
	ply.PikiColor = GetPlayerColor(ply)
end)

--// Pikmin camera
CreateConVar("pikmin_camera", "0", {FCVAR_ARCHIVE, FCVAR_USERINFO}, "Enable third-person Pikmin camera")
CreateConVar("pikmin_camera_zoom", "2", {FCVAR_ARCHIVE, FCVAR_USERINFO}, "Pikmin camera zoom level (1=closest, 2=closer, 3=furthest)")
CreateConVar("pikmin_camera_birds", "1", {FCVAR_ARCHIVE, FCVAR_USERINFO}, "Pikmin camera birds-eye level (1=standard, 2=mid, 3=full)")

local cameraZoomDistances = {
	[1] = 380, -- closest
	[2] = 450, -- closer
	[3] = 650  -- furthest
}

local cameraPitchAngles = {
	[1] = 25, -- standard
	[2] = 55, -- sort of birds-eye
	[3] = 82  -- full birds-eye
}

-- Play the sound on convar changes
local function PlayCameraAdjustSound()
	surface.PlaySound("pikmin/camera.wav") -- ugh it's peak
end
cvars.AddChangeCallback("pikmin_camera", PlayCameraAdjustSound, "PikCamToggleSound")
cvars.AddChangeCallback("pikmin_camera_zoom", PlayCameraAdjustSound, "PikCamZoomSound")
cvars.AddChangeCallback("pikmin_camera_birds", PlayCameraAdjustSound, "PikCamBirdsSound")

-- Cycle commands
concommand.Add("pikmin_camera_toggle", function()
	local cv = GetConVar("pikmin_camera")
	local nextVal = cv:GetBool() and "0" or "1"
	cv:SetString(nextVal)
end)

concommand.Add("pikmin_camera_zoom_cycle", function()
	local cv = GetConVar("pikmin_camera_zoom")
	local curVal = cv:GetInt()
	local nextVal = curVal >= 3 and 1 or (curVal + 1)
	cv:SetInt(nextVal)
end)

concommand.Add("pikmin_camera_birds_cycle", function()
	local cv = GetConVar("pikmin_camera_birds")
	local curVal = cv:GetInt()
	local nextVal = curVal >= 3 and 1 or (curVal + 1)
	cv:SetInt(nextVal)
end)

hook.Add("InitPostEntity", "PikminCameraWelcome", function()
	timer.Simple(5, function()
		if IsValid(LocalPlayer()) then
			LocalPlayer():ChatPrint("[Pikmin Camera] Binds available: bind KEY pikmin_camera_toggle, pikmin_camera_zoom_cycle, pikmin_camera_birds_cycle")
		end
	end)
end)

hook.Add("CalcView", "PikminThirdPersonCamera", function(ply, pos, angles, fov)
	if not GetConVar("pikmin_camera"):GetBool() then
		-- reset the smoothing if camera is disabled
		ply.PikCamSmoothDistance = nil
		ply.PikCamSmoothPitch = nil
		return
	end
	if not ply:Alive() or ply:GetNWBool("ispikmin") then return end
	
	local zoomLvl = math.Clamp(GetConVar("pikmin_camera_zoom"):GetInt(), 1, 3)
	local birdsLvl = math.Clamp(GetConVar("pikmin_camera_birds"):GetInt(), 1, 3)
	
	local targetDistance = cameraZoomDistances[zoomLvl]
	local targetPitch = cameraPitchAngles[birdsLvl]
	
	-- Initialize smoothed variables if they don't exist
	if not ply.PikCamSmoothDistance then
		ply.PikCamSmoothDistance = targetDistance
	end
	if not ply.PikCamSmoothPitch then
		ply.PikCamSmoothPitch = targetPitch
	end
	
	-- interpolate towards the targets over time
	local dT = FrameTime()
	ply.PikCamSmoothDistance = Lerp(math.min(1.0, 8 * dT), ply.PikCamSmoothDistance, targetDistance)
	ply.PikCamSmoothPitch = Lerp(math.min(1.0, 8 * dT), ply.PikCamSmoothPitch, targetPitch)
	
	-- Angles for the camera: lock pitch based on smoothed pitch, yaw matches player look yaw
	local camAngles = Angle(ply.PikCamSmoothPitch, angles.y, 0)
	-- I'll come back to this later, since Olimar technically can't look up or down in the Pikmin games.

	-- calculate camera head position offset (centered slightly above the player)
	local targetHeadPos = ply:GetPos() + Vector(0, 0, 48)
	local pushBack = camAngles:Forward() * -ply.PikCamSmoothDistance
	
	-- anti clip
	local tr = util.TraceHull({
		start = targetHeadPos,
		endpos = targetHeadPos + pushBack,
		filter = ply,
		mins = Vector(-8, -8, -8),
		maxs = Vector(8, 8, 8),
		mask = MASK_SOLID_BRUSHONLY
	})
	
	local view = {
		origin = tr.HitPos + tr.HitNormal * 4,
		angles = camAngles,
		fov = fov,
		drawviewer = true
	}
	return view
end)

hook.Add("UpdateAnimation", "PikminAlwaysLookStraight", function(ply, velocity, maxseqgroundspeed)
	if not IsValid(ply) or ply:GetNWBool("ispikmin") then return end
	
	local wep = ply:GetActiveWeapon()
	if IsValid(wep) and wep:GetClass() == "olimar_gun" and GetConVar("pikmin_camera"):GetBool() then
		ply:SetPoseParameter("aim_pitch", 0)
		ply:SetPoseParameter("head_pitch", 0)
	end
end)