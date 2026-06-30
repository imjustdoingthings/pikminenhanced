AddCSLuaFile()

ENT.Type 		= "anim"
ENT.Base 		= "base_anim"
ENT.PrintName	= "#pikmin6"
ENT.Category	= "#pikmin"
ENT.Spawnable	= false
ENT.AdminOnly	= false

function ENT:SpawnFunction(ply,tr)
	ply:ConCommand("pikmin_create bulbmin")
end