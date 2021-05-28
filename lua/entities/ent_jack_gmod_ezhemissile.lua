-- Jackarunda 2019
AddCSLuaFile()
ENT.Type="anim"
ENT.Author="Jackarunda"
ENT.Category="JMod - EZ Explosives"
ENT.Information="glhfggwpezpznore"
ENT.PrintName="EZ HE Missile"
ENT.Spawnable=true
ENT.AdminSpawnable=true
---
ENT.JModPreferredCarryAngles=Angle(0,90,0)
---
local STATE_BROKEN,STATE_OFF,STATE_ARMED,STATE_LAUNCHED=-1,0,1,2
function ENT:SetupDataTables()
	self:NetworkVar("Int",0,"State")
end
---
if(SERVER)then
	function ENT:SpawnFunction(ply,tr)
		local SpawnPos=tr.HitPos+tr.HitNormal*40
		local ent=ents.Create(self.ClassName)
		ent:SetAngles(Angle(180,0,0))
		ent:SetPos(SpawnPos)
		JMod_Owner(ent,ply)
		ent:Spawn()
		ent:Activate()
		--local effectdata=EffectData()
		--effectdata:SetEntity(ent)
		--util.Effect("propspawn",effectdata)
		return ent
	end
	function ENT:Initialize()
		self:SetModel("models/weapons/w_missile_closed.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:DrawShadow(true)
		self:SetUseType(SIMPLE_USE)
		---
		timer.Simple(.01,function()
			self:GetPhysicsObject():SetMass(40)
			self:GetPhysicsObject():EnableDrag(false)
			self:GetPhysicsObject():Wake()
		end)
		---
		self:SetState(STATE_OFF)
		self.NextDet=0
	end
	function ENT:PhysicsCollide(data,physobj)
		if not(IsValid(self))then return end
		if(data.DeltaTime>0.2)then
			if(data.Speed>50)then
				self:EmitSound("Canister.ImpactHard")
			end
			local DetSpd=300
			if((data.Speed>DetSpd)and(self:GetState()==STATE_LAUNCHED))then
				self:Detonate()
				return
			end
		end
	end
	function ENT:Break()
		if(self:GetState()==STATE_BROKEN)then return end
		self:SetState(STATE_BROKEN)
		self:EmitSound("snd_jack_turretbreak.wav",70,math.random(80,120))
		for i=1,20 do
			self:DamageSpark()
		end
		SafeRemoveEntityDelayed(self,10)
	end
	function ENT:DamageSpark()
		local effectdata=EffectData()
		effectdata:SetOrigin(self:GetPos()+self:GetUp()*10+VectorRand()*math.random(0,10))
		effectdata:SetNormal(VectorRand())
		effectdata:SetMagnitude(math.Rand(2,4)) --amount and shoot hardness
		effectdata:SetScale(math.Rand(.5,1.5)) --length of strands
		effectdata:SetRadius(math.Rand(2,4)) --thickness of strands
		util.Effect("Sparks",effectdata,true,true)
		self:EmitSound("snd_jack_turretfizzle.wav",70,100)
	end
	function ENT:OnTakeDamage(dmginfo)
		self:TakePhysicsDamage(dmginfo)
		if(dmginfo:GetDamage()>=100)then
			if(math.random(1,20)==1)then
				self:Break()
			elseif(dmginfo:IsDamageType(DMG_BLAST))then
				JMod_Owner(self,dmginfo:GetAttacker())
				self:Detonate()
			end
		end
	end
	--[[function ENT:Use(activator)
		local State=self:GetState()
		if(State<0)then return end
		
		local Alt=activator:KeyDown(JMOD_CONFIG.AltFunctionKey)
		if(State==STATE_OFF)then
			if(Alt)then
				JMod_Owner(self,activator)
				self:EmitSound("snds_jack_gmod/bomb_arm.wav",60,120)
				self:SetState(STATE_ARMED)
				self.EZlaunchableWeaponArmedTime=CurTime()
				JMod_Hint(activator, "launch", self)
			else
				activator:PickupObject(self)
				JMod_Hint(activator, "arm", self)
			end
		elseif(State==STATE_ARMED)then
			self:EmitSound("snds_jack_gmod/bomb_disarm.wav",60,120)
			self:SetState(STATE_OFF)
			JMod_Owner(self,activator)
			self.EZlaunchableWeaponArmedTime=nil
		end
	end--]]
	function ENT:Detonate()
		if(self.NextDet>CurTime())then return end
		if(self.Exploded)then return end
		self.Exploded=true
		local SelfPos,Att,Dir=self:GetPos()+Vector(0,0,30),self.Owner or game.GetWorld(),-self:GetRight()
		JMod_Sploom(Att,SelfPos,150)
		---
		util.ScreenShake(SelfPos,1000,3,2,1500)
		self:EmitSound("snd_jack_fragsplodeclose.wav",90,100)
		---
		util.BlastDamage(game.GetWorld(),Att,SelfPos+Vector(0,0,50),300,1000)
		for k,ent in pairs(ents.FindInSphere(SelfPos,200))do
			if(ent:GetClass()=="npc_helicopter")then ent:Fire("selfdestruct","",math.Rand(0,2)) end
		end
		---
		JMod_WreckBuildings(self,SelfPos,3)
		JMod_BlastDoors(self,SelfPos,3)
		---
		timer.Simple(.2,function()
			local Tr=util.QuickTrace(SelfPos-Dir*100,Dir*300)
			if(Tr.Hit)then util.Decal("Scorch",Tr.HitPos+Tr.HitNormal,Tr.HitPos-Tr.HitNormal) end
		end)
		---
		self:Remove()
		local Ang=self:GetAngles()
		Ang:RotateAroundAxis(Ang:Forward(),-90)
		timer.Simple(.1,function()
			ParticleEffect("50lb_air",SelfPos-Dir*20,Ang)
			ParticleEffect("50lb_air",SelfPos-Dir*50,Ang)
			ParticleEffect("50lb_air",SelfPos-Dir*80,Ang)
		end)
	end
	function ENT:OnRemove()
		--
	end
	function ENT:Launch()
		if(self:GetState()~=STATE_ARMED)then return end
		self:SetState(STATE_LAUNCHED)
		local Phys=self:GetPhysicsObject()
		--Phys:EnableGravity(false)
		constraint.RemoveAll(self)
		Phys:EnableMotion(true)
		Phys:Wake()
		Phys:ApplyForceCenter(self:GetForward()*20000)
		---
		self:EmitSound("snds_jack_gmod/rocket_launch.wav",80,math.random(95,105))
		---
		for i, v in pairs(ents.GetAll()) do
			-- check if target is in 15 degree cone in front of missile
			local MinimumDot = math.cos(math.rad(15))
			local Direction = (v:LocalToWorld(v:OBBCenter()) - self:GetPos()):GetNormalized()
			if self:GetForward():Dot(Direction) < MinimumDot then continue end

			if string.find(v:GetClass(), "wac_") then
				local TempTarg = nil
				if string.find(v:GetClass(), "wac_pod") || v:GetClass() == "wac_seat_connector" then
					TempTarg = v:GetParent()
				else
					TempTarg = v
				end
				if TempTarg.engineRpm && TempTarg.engineRpm > 0 then self.Target = v end
			end

			if string.find(v:GetClass(), "lunasflightschool_") then
				self.Target = v
			end
		end
		---
		self.NextDet=CurTime()+.25
		---
		timer.Simple(30,function()
			if(IsValid(self))then self:Detonate() end
		end)
		JMod_Hint(self.Owner, "backblast", self:GetPos())
	end
	function ENT:EZdetonateOverride(detonator)
		self:Detonate()
	end
	function ENT:PhysicsUpdate(Phys)
		JMod_AeroDrag(self, self:GetForward(), .75)
		if self:GetState() == STATE_LAUNCHED then
			Phys:ApplyForceCenter(self:GetForward() * 20000)

			-- thanks acf missiles
			if !self.LastPhysCalc then self.LastPhysCalc = CurTime() end
			local DeltaTime = CurTime() - self.LastPhysCalc
			if DeltaTime <= 0 then return end

			if self.Target then
				local TargetPos = self.Target:LocalToWorld(self.Target:OBBCenter())
				local Pos = self:GetPos()
				local LOS = (TargetPos - Pos):GetNormalized()
				local Dir = self:GetForward()
				local NewDir = Dir
				local DirDiff = 0
				local Speed = self:GetVelocity():Length()

				if self.LastLOS then
					local SpeedMul = math.min((Speed / DeltaTime) ^ 3, 1)
					local LOSDiff = math.deg(math.acos( self.LastLOS:Dot(LOS) )) * 20
					local MaxTurn = SpeedMul / 4

					if LOSDiff > 0.01 and MaxTurn > 0.1 then
						local LOSNormal = self.LastLOS:Cross(LOS):GetNormalized()
						local Ang = NewDir:Angle()
						Ang:RotateAroundAxis(LOSNormal, math.min(LOSDiff, MaxTurn))
						NewDir = Ang:Forward()
					end

					DirDiff = math.deg(math.acos( NewDir:Dot(LOS) ))
					if DirDiff > 0.01 then
						local DirNormal = NewDir:Cross(LOS):GetNormalized()
						local TurnAng = math.min(DirDiff, MaxTurn) / 10
						local Ang = NewDir:Angle()
						Ang:RotateAroundAxis(DirNormal, TurnAng)
						NewDir = Ang:Forward()
						DirDiff = DirDiff - TurnAng
					end
				end
				self.LastLOS = LOS
				self.LastPhysCalc = CurTime()

				if DirDiff < 45 then
					-- thanks lfs
					local AF = self:WorldToLocalAngles(NewDir:Angle())
					AF.p = math.Clamp(AF.p * 400,-20,20)
					AF.y = math.Clamp(AF.y * 400,-20,20)
					AF.r = math.Clamp(AF.r * 400,-20,20)

					Phys:AddAngleVelocity(Vector(AF.r,AF.p,AF.y) - Phys:GetAngleVelocity())
				else
					self.Target = nil
					self:Detonate()
				end
			end
			---
			--[[local Eff = EffectData()
			Eff:SetOrigin(self:GetPos())
			Eff:SetNormal(self:GetRight())
			Eff:SetScale(1)
			util.Effect("eff_jack_gmod_rockettrail", Eff, true, true)--]]
		end
	end
elseif(CLIENT)then
	function ENT:Initialize()
		--
	end
	function ENT:Think()
		--
	end
	local GlowSprite=Material("mat_jack_gmod_glowsprite")
	function ENT:Draw()
		local Pos,Ang,Dir=self:GetPos(),self:GetAngles(),-self:GetForward()
		Ang:RotateAroundAxis(Ang:Up(),90)
		self:DrawModel()
		if self:GetState() == STATE_LAUNCHED then
			render.SetMaterial(GlowSprite)
			for i=1,10 do
				local Inv=10-i
				render.DrawSprite(Pos+Dir*(i*10+math.random(30,40)),5*Inv,5*Inv,Color(255,255-i*10,255-i*20,255))
			end
			local dlight=DynamicLight(self:EntIndex())
			if dlight then
				dlight.pos = Pos + Dir * 45
				dlight.r = 255
				dlight.g = 175
				dlight.b = 100
				dlight.brightness = 2
				dlight.Decay = 200
				dlight.Size = 400
				dlight.DieTime = CurTime()+.5
			end
		end
	end
	language.Add("ent_jack_gmod_ezherocket","EZ HE Rocket")
end
