--[[local function recurseDerma(obj,id)
	local str = ""
	for i=1,id do str = str .. "	" end
	print(id..str,obj)
	for k,v in ipairs(obj:GetChildren()) do
		recurseDerma(v,id+1)
	end
end--]]

hook.Add("AddToolMenuCategories","PikiToolMenuCat",function()
	spawnmenu.AddToolCategory("Utilities","Pikmin","Pikmin (Enhanced!)")
end)
-- how could I forget to change that lmao

hook.Add("PopulateToolMenu","PikiToolMenu",function()
	spawnmenu.AddToolMenuOption("Utilities","Pikmin","PikiSettings","#pikimenu.settings","","",function(panel)
		panel:Help("#pikimenu.general"):SetFont("DermaLarge")
		
		local n = panel:NumSlider("#pikimenu.max","pik_field",0,9999,0)
		n:SetDefaultValue(PikiMaxField)
		panel:ControlHelp("#pikimenu.max2")
		
		local autobox = panel:CheckBox("#pikimenu.separate","pik_auto")
		panel:ControlHelp("#pikimenu.separate2")
		local dropbox = panel:CheckBox("#pikimenu.drops","pik_drops")
		local idlebox = panel:CheckBox("#pikimenu.idle","pik_idle")
		local adminbox = panel:CheckBox("Admin-only spawning","pik_admin")
		panel:ControlHelp("Restricts Pikmin and Onions to admins only.")
		local classicbox = panel:CheckBox("#pikimenu.classicpluck","pik_classicpluck")
		local disbandbox = panel:CheckBox("#pikimenu.disband","pik_disband")
		panel:ControlHelp("#pikimenu.disband2")
		local poisongasbox = panel:CheckBox("#pikimenu.whitegas","pik_white_poisongas")
		panel:ControlHelp("#pikimenu.whitegas2")
		local groundpoundbox = panel:CheckBox("#pikimenu.purplegroundpound", "pik_purple_groundpound")
		panel:ControlHelp("#pikimenu.purplegroundpound2")
		local superthrowbox = panel:CheckBox("#pikimenu.superthrow", "pik_superthrow")
		panel:ControlHelp("#pikimenu.superthrow2")
		local shakeoffbox = panel:CheckBox("#pikimenu.shakeoff", "pik_shakeoff")
		panel:ControlHelp("#pikimenu.shakeoff2")
		local npctargetbox = panel:CheckBox("#pikimenu.npctargetpikmin", "pik_npc_target_pikmin")
		panel:ControlHelp("#pikimenu.npctargetpikmin2")
		
		local meshbox = panel:CheckBox("Enable Pikmin Meshing", "piki_mesh")
		panel:ControlHelp("Makes Pikmin group behind you in a fixed array at a fixed distance. This copies how Pikmin move in the squad in Pikmin 1-4.")
		
		local meshSpacing = panel:NumSlider("Mesh Spacing", "piki_mesh_spacing", 0.1, 5.0, 2)
		panel:ControlHelp("Adjusts spacing between Pikmin in the squad mesh.")
		
		local meshShape = panel:ComboBox("Mesh Shape", "piki_mesh_shape")
		meshShape:AddChoice("Wedge (Default)", "wedge")
		meshShape:AddChoice("Circle", "circle")
		meshShape:AddChoice("Square", "square")
		meshShape:AddChoice("Diamond", "diamond")
		meshShape:AddChoice("Triangle", "triangle")
		meshShape:AddChoice("Hexagon", "hexagon")
		panel:ControlHelp("Adjusts the squad layout shape. The one most accurate to Pikmin itself is the Wedge.")
		
		local cambox = panel:CheckBox("Enable Thirdperson Camera", "pikmin_camera")
		panel:ControlHelp("Enables the thirdperson Pikmin camera view. This mimics how we see Olimar in the Pikmin games.")
		
		local pikiSettingsBtn = panel:Button("Pikmin Settings", "")
		function pikiSettingsBtn:DoClick()
			local frame = vgui.Create("DFrame")
			frame:SetTitle("Pikmin Settings")
			frame:SetSize(400, 600)
			frame:Center()
			frame:MakePopup()
			-- new Pikmin settings menu hooray

			local scroll = vgui.Create("DScrollPanel", frame)
			scroll:Dock(FILL)
			
			local bottom = vgui.Create("DPanel", frame)
			bottom:Dock(BOTTOM)
			bottom:SetHeight(40)
			bottom:SetPaintBackground(false)
			
			local hsliders, dsliders, ssliders = {}, {}, {}
			
			for i = 1, PikTypes do
				local typePanel = scroll:Add("DPanel")
				typePanel:Dock(TOP)
				typePanel:SetHeight(130)
				typePanel:DockMargin(5, 5, 5, 5)
				function typePanel:Paint(w, h)
					draw.RoundedBox(4, 0, 0, w, h, Color(240, 240, 240, 255))
				end
				
				local label = vgui.Create("DLabel", typePanel)
				label:SetText(language.GetPhrase("pikmin" .. i))
				label:SetFont("DermaDefaultBold")
				label:Dock(TOP)
				label:DockMargin(10, 5, 10, 2)
				label:SetTextColor(Color(50, 50, 50))
				
				-- Health
				local hSlider = vgui.Create("DNumSlider", typePanel)
				hSlider:SetText("Health")
				hSlider:SetConVar("pik_health" .. i)
				hSlider:SetMinMax(1, 100)
				hSlider:SetDecimals(0)
				hSlider:Dock(TOP)
				hSlider:DockMargin(15, 0, 15, 0)
				hSlider:SetDefaultValue(PikHealth[i])
				hSlider:SetDark(true)
				hsliders[i] = hSlider
				
				-- Damage
				local dSlider = vgui.Create("DNumSlider", typePanel)
				dSlider:SetText("Damage")
				dSlider:SetConVar("pik_damage" .. i)
				dSlider:SetMinMax(0, 40)
				dSlider:SetDecimals(0)
				dSlider:Dock(TOP)
				dSlider:DockMargin(15, 0, 15, 0)
				dSlider:SetDefaultValue(PikDamage[i])
				dSlider:SetDark(true)
				dsliders[i] = dSlider

				-- Speed
				local sSlider = vgui.Create("DNumSlider", typePanel)
				sSlider:SetText("Base Speed")
				sSlider:SetConVar("pik_speed" .. i)
				sSlider:SetMinMax(50, 3000)
				sSlider:SetDecimals(0)
				sSlider:Dock(TOP)
				sSlider:DockMargin(15, 0, 15, 0)
				sSlider:SetDefaultValue(PikSpeed[i])
				sSlider:SetDark(true)
				ssliders[i] = sSlider
			end
			
			local rbtn = vgui.Create("DButton", bottom)
			rbtn:SetText("Reset All")
			rbtn:Dock(FILL)
			rbtn:DockMargin(5, 5, 5, 5)
			function rbtn:DoClick()
				for i = 1, PikTypes do
					hsliders[i]:SetValue(PikHealth[i])
					dsliders[i]:SetValue(PikDamage[i])
					ssliders[i]:SetValue(PikSpeed[i])
				end
			end
		end
		
		local btn = panel:Button("#pikimenu.reset","")
		function btn:DoClick()
			n:SetValue(PikiMaxField)
		end
		
		local btn2 = panel:Button("#pikimenu.reset2","pikmin_oreset")
	end)
end)

hook.Add("PopulateMenuBar","PikiContext",function(bar)
	local menu = bar:AddOrGetMenu("#pikmin")
	
	local skinMenu,skinOption = menu:AddSubMenu("#pikicontext.skin")
	skinMenu:SetDeleteSelf(false)
	
	for i=0,5 do
		local skinOption = skinMenu:AddOption("#pikicontext.skin"..i+1,function() RunConsoleCommand("pikmin_skinw",tostring(i)) end)
		local optionPaint = skinOption.Paint
		function skinOption:Paint(w,h)
			skinOption:SetChecked(LocalPlayer():GetNWInt("pikiskin",0) == i)
			optionPaint(skinOption,w,h)
		end
	end
	
	menu:AddSpacer()
	
	local option = nil
	option = menu:AddOption("#pikicontext.dismiss", function()
		RunConsoleCommand("pikmin_config","1",LocalPlayer():GetNWBool("pikidis",false) and "0" or "1")
	end)
	local optionPaint = option.Paint
	function option:Paint(w,h)
		option:SetChecked(LocalPlayer():GetNWBool("pikidis",false))
		optionPaint(option,w,h)
	end
	
	local option2 = nil
	option2 = menu:AddOption("#pikicontext.hide", function()
		RunConsoleCommand("pikmin_config","2",LocalPlayer():GetNWBool("piknd",false) and "0" or "1")
	end)
	local optionPaint = option2.Paint
	function option2:Paint(w,h)
		option2:SetChecked(LocalPlayer():GetNWBool("piknd",false))
		optionPaint(option2,w,h)
	end
	
	local option3 = nil
	option3 = menu:AddOption("#pikicontext.hud", function()
		RunConsoleCommand("pikmin_nohud",HideOlimarHUD and "0" or "1")
	end)
	local optionPaint = option3.Paint
	function option3:Paint(w,h)
		option3:SetChecked(cvars.Bool("pikmin_nohud"))
		optionPaint(option3,w,h)
	end
	
	menu:AddSpacer()
	
	local upgradeMenu,upgradeOption = menu:AddSubMenu("#pikicontext.upgrades")
	upgradeMenu:SetDeleteSelf(false)
	
	local option3 = nil
	option3 = upgradeMenu:AddOption("#pikiupgrade.pluck", function()
		RunConsoleCommand("pikmin_config","3",LocalPlayer():GetNWBool("pikipluck",false) and "0" or "1")
	end)
	local optionPaint = option3.Paint
	function option3:Paint(w,h)
		option3:SetChecked(LocalPlayer():GetNWBool("pikipluck",false))
		optionPaint(option3,w,h)
	end
	
	local option4 = nil
	option4 = upgradeMenu:AddOption("#pikiupgrade.fire", function()
		RunConsoleCommand("pikmin_config","4",LocalPlayer():GetNWBool("pikfire",false) and "0" or "1")
	end)
	local optionPaint = option4.Paint
	function option4:Paint(w,h)
		option4:SetChecked(LocalPlayer():GetNWBool("pikfire",false))
		optionPaint(option4,w,h)
	end
	
	local option5 = nil
	option5 = upgradeMenu:AddOption("#pikiupgrade.zap", function()
		RunConsoleCommand("pikmin_config","5",LocalPlayer():GetNWBool("pikzap",false) and "0" or "1")
	end)
	local optionPaint = option5.Paint
	function option5:Paint(w,h)
		option5:SetChecked(LocalPlayer():GetNWBool("pikzap",false))
		optionPaint(option5,w,h)
	end
end)

--hacky fix for entity list
if not PikiLayoutFixed then
	PikiLayout = nil
	PikiLayoutFixed = false
	PikiBaseEntSwitchPanelFun = nil
	local function CreateContentIconWrapper(data,name,panel)
		data = data[name]
		if not data then return end
		spawnmenu.CreateContentIcon( data.ScriptedEntityType or "entity", panel, {
			nicename	= data.PrintName or data.ClassName,
			spawnname	= name,
			material	= data.IconOverride or "entities/" .. name .. ".png",
			admin		= data.AdminOnly
		})
	end
	local function FixPikiEntList(pnlContent)
		if IsValid(pnlContent.SelectedPanel) then
			local scroll = pnlContent.SelectedPanel:GetChild(0)
			if not IsValid(scroll) then return end
			local layout = scroll:GetChild(0)
			if not IsValid(layout) then return end

			if not PikiLayout then
				local child = layout:GetChildren()
				for k,v in ipairs(child) do
					if v.GetSpawnName and v:GetSpawnName() == "pikmin" then PikiLayout = layout break end
				end
				if layout == PikiLayout then for k,v in ipairs(child) do v:Remove() end end
			end
			if PikiLayout and layout == PikiLayout then
				PikiLayoutFixed = true
				hook.Remove("SpawnMenuOpen","PikiSpawnMenuOpen")
				local ents = list.Get("SpawnableEntities")
				CreateContentIconWrapper(ents,"pikmin",pnlContent.SelectedPanel)
				CreateContentIconWrapper(ents,"pikmin_sprout",pnlContent.SelectedPanel)
				CreateContentIconWrapper(ents,"pikmin_player",pnlContent.SelectedPanel)
				CreateContentIconWrapper(ents,"pikmin_onion",pnlContent.SelectedPanel)
				CreateContentIconWrapper(ents,"pikmin_onion_p3",pnlContent.SelectedPanel)
				CreateContentIconWrapper(ents,"pikmin_onion_master",pnlContent.SelectedPanel)
				CreateContentIconWrapper(ents,"pikmin_bud",pnlContent.SelectedPanel)
				CreateContentIconWrapper(ents,"pikmin_nectar",pnlContent.SelectedPanel)
				CreateContentIconWrapper(ents,"pikmin_fire",pnlContent.SelectedPanel)
				CreateContentIconWrapper(ents,"pikmin_gas",pnlContent.SelectedPanel)
				CreateContentIconWrapper(ents,"pikmin_wire",pnlContent.SelectedPanel)
			end
		end
	end
	hook.Add("SpawnMenuOpen","PikiSpawnMenuOpen",function()
		if not g_SpawnMenu then return end
		local entPanel = nil
		for k,v in ipairs(g_SpawnMenu.CreateMenu.Items) do
			if v.Name == "#spawnmenu.category.entities" then
				entPanel = v.Panel
				break
			end
		end
		if entPanel then
			local pnlContent = entPanel:Find("SpawnmenuContentPanel")
			if not PikiLayoutFixed then FixPikiEntList(pnlContent) end
			pnlContent.SwitchPanel = function(self,panel)
				if ( IsValid( self.SelectedPanel ) ) then
					self.SelectedPanel:SetVisible( false )
					self.SelectedPanel = nil
				end

				self.SelectedPanel = panel

				if ( !IsValid( panel ) ) then return end
				if not PikiLayoutFixed then FixPikiEntList(self) end

				self.HorizontalDivider:SetRight( self.SelectedPanel )
				self.HorizontalDivider:InvalidateLayout( true )

				self.SelectedPanel:SetVisible( true )
				self:InvalidateParent()
			end
		end
	end)
end

spawnmenu.AddPropCategory("pikmin","#pikmin",{
{
type = "model",
model = "models/pikmin/pikmin_red1.mdl",
},
{
type = "model",
model = "models/pikmin/pikmin_red2.mdl",
},
{
type = "model",
model = "models/pikmin/pikmin_red3.mdl",
},
{
type = "model",
model = "models/pikmin/pikmin_yellow1.mdl",
},
{
type = "model",
model = "models/pikmin/pikmin_yellow2.mdl",
},
{
type = "model",
model = "models/pikmin/pikmin_yellow3.mdl",
},
{
type = "model",
model = "models/pikmin/pikmin_blue1.mdl",
},
{
type = "model",
model = "models/pikmin/pikmin_blue2.mdl",
},
{
type = "model",
model = "models/pikmin/pikmin_blue3.mdl",
},
{
type = "model",
model = "models/pikmin/pikmin_purple1.mdl",
},
{
type = "model",
model = "models/pikmin/pikmin_purple2.mdl",
},
{
type = "model",
model = "models/pikmin/pikmin_purple3.mdl",
},
{
type = "model",
model = "models/pikmin/pikmin_white1.mdl",
},
{
type = "model",
model = "models/pikmin/pikmin_white2.mdl",
},
{
type = "model",
model = "models/pikmin/pikmin_white3.mdl",
},
{
type = "model",
model = "models/pikmin/pikmin_green1.mdl",
},
{
type = "model",
model = "models/pikmin/pikmin_green2.mdl",
},
{
type = "model",
model = "models/pikmin/pikmin_green3.mdl",
},
{
type = "model",
model = "models/pikmin/pikmin_pink1.mdl",
},
{
type = "model",
model = "models/pikmin/pikmin_pink2.mdl",
},
{
type = "model",
model = "models/pikmin/pikmin_pink3.mdl",
},
{
type = "model",
model = "models/pikmin/pikmin_rock1.mdl",
},
{
type = "model",
model = "models/pikmin/pikmin_rock2.mdl",
},
{
type = "model",
model = "models/pikmin/pikmin_rock3.mdl",
},
{
type = "model",
model = "models/pikmin/pikmin_puffmin1.mdl",
},
{
type = "model",
model = "models/weapons/w_olimar.mdl",
},
{
type = "model",
model = "models/pikmin/onion.mdl",
skin = 2
},
{
type = "model",
model = "models/pikmin/onion_large.mdl",
},
{
type = "model",
model = "models/pikmin/onion_new.mdl",
},
{
type = "model",
model = "models/pikmin/pellet_1.mdl",
skin = 2
},
{
type = "model",
model = "models/pikmin/pellet_5.mdl",
skin = 2
},
{
type = "model",
model = "models/pikmin/pellet_10.mdl",
skin = 2
},
{
type = "model",
model = "models/pikmin/pellet_20.mdl",
skin = 2
},
{
type = "model",
model = "models/pikmin/pom.mdl",
skin = 0
},
{
type = "model",
model = "models/player/orima_r.mdl",
skin = 0
},
{
type = "model",
model = "models/player/louie_r.mdl",
skin = 0
},
{
type = "model",
model = "models/player/chacho_r.mdl",
skin = 0
},
}, "icons/flower.png")

--[[hook.Add("PostDraw2DSkyBox","SkyOverride",function()
    render.OverrideDepthEnable(true,false)
    cam.Start2D()
	render.DrawScreenQuad()
    cam.End2D()
    render.OverrideDepthEnable(false,false)
end)--]]