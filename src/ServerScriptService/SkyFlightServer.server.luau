local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local ReplicatedStorage=game:GetService('ReplicatedStorage')
local ServerStorage=game:GetService('ServerStorage')
local ServerScriptService=game:GetService('ServerScriptService')
local ConfigService=game:GetService('ConfigService')
local SupabaseService=require(ServerScriptService:WaitForChild('SupabaseService'))
local cruiseSpeed=65
local starReward=100
-- Defaults also work in an unpublished place without Experience Configs.
task.spawn(function()
 local ok,snapshot=pcall(function() return ConfigService:GetConfigAsync() end)
 if not ok or not snapshot then return end
 local function read()
  local success,value=pcall(function() return snapshot:GetValue('HeliCruiseSpeed') end)
  if success and type(value)=='number' then cruiseSpeed=math.clamp(value,25,100) end
 end
 read()
 snapshot.UpdateAvailable:Connect(function() if pcall(function() snapshot:Refresh() end) then read() end end)
end)
local remote=Instance.new('RemoteEvent'); remote.Name='SkyFlightEvent'; remote.Parent=ReplicatedStorage
local helicopters=Instance.new('Folder'); helicopters.Name='PlayerHelicopters'; helicopters.Parent=workspace
local map=workspace:WaitForChild('SkyIslands')
local template=ServerStorage:WaitForChild('HeliAsset'):FindFirstChild('Heli',true)
local reference=template:FindFirstChildWhichIsA('VehicleSeat',true)
local states={}
local sequence={2,3,4,1}
local cachedLeaderboard={}

local function broadcastLeaderboard(targetPlayer)
 if targetPlayer then
  remote:FireClient(targetPlayer,'leaderboard',cachedLeaderboard)
 else
  remote:FireAllClients('leaderboard',cachedLeaderboard)
 end
end

local function refreshSupabaseData()
 local configs=SupabaseService.fetchLiveConfigs()
 if configs then
  if configs.heli_cruise_speed and type(configs.heli_cruise_speed.num)=='number' then
   cruiseSpeed=math.clamp(configs.heli_cruise_speed.num,25,120)
  end
  if configs.star_reward and type(configs.star_reward.num)=='number' then
   starReward=math.max(1,math.floor(configs.star_reward.num))
  end
  if configs.server_notice and type(configs.server_notice.text)=='string' then
   workspace:SetAttribute('ServerNotice',configs.server_notice.text)
  end
 end
 local board=SupabaseService.fetchTopLeaderboard(5)
 if board then
  cachedLeaderboard=board
  broadcastLeaderboard()
 end
end

task.spawn(function()
 while true do
  refreshSupabaseData()
  task.wait(30)
 end
end)

local function buildHelicopter(player,index)
 local model=Instance.new('Model'); model.Name=player.Name..'_Helicopter'
 local seat=Instance.new('VehicleSeat'); seat.Name='PilotSeat'; seat.Size=Vector3.new(2,1,2); seat.Transparency=1; seat.CanCollide=false; seat.MaxSpeed=0; seat.Torque=0; seat.TurnSpeed=0
 seat.CFrame=CFrame.new((index%3-1)*24,10.1,math.floor(index/3)%3*25); seat.Parent=model; model.PrimaryPart=seat
 -- Give the aircraft a simple solid underside while the imported shell is visual only.
 local hull=Instance.new('Part'); hull.Name='CollisionHull'; hull.Size=Vector3.new(6,1,11); hull.Transparency=1; hull.CFrame=seat.CFrame*CFrame.new(0,-4.5,5); hull.Massless=true; hull.Parent=model
 local weld=Instance.new('WeldConstraint'); weld.Part0=seat; weld.Part1=hull; weld.Parent=hull
 local mainRotor
 for _,original in template:GetDescendants() do
  if original:IsA('BasePart') and not original:IsA('Seat') and not original:IsA('VehicleSeat') and original.Transparency<1 and original.Name~='Gun1' then
   local piece=original:Clone()
   for _,d in piece:GetDescendants() do if d:IsA('BaseScript') or d:IsA('JointInstance') or d:IsA('Constraint') or d:IsA('Sound') or d:IsA('ClickDetector') or d:IsA('RemoteEvent') then d:Destroy() end end
   piece.Anchored=false; piece.CanCollide=false; piece.CanTouch=false; piece.Massless=true
   piece.CFrame=seat.CFrame*reference.CFrame:ToObjectSpace(original.CFrame); piece.Parent=model
   if original.Name=='Rotor1' then
    local motor=Instance.new('Motor6D'); motor.Name='MainRotorMotor'; motor.Part0=seat; motor.Part1=piece; motor.C0=seat.CFrame:ToObjectSpace(piece.CFrame); motor.Parent=seat; mainRotor=motor
   else
    local joint=Instance.new('WeldConstraint'); joint.Part0=seat; joint.Part1=piece; joint.Parent=piece
   end
  end
 end
 local attachment=Instance.new('Attachment'); attachment.Name='FlightAttachment'; attachment.Parent=seat
 local force=Instance.new('VectorForce'); force.Name='FlightForce'; force.Attachment0=attachment; force.RelativeTo=Enum.ActuatorRelativeTo.World; force.ApplyAtCenterOfMass=true; force.Parent=seat
 local align=Instance.new('AlignOrientation'); align.Name='FlightLevel'; align.Mode=Enum.OrientationAlignmentMode.OneAttachment; align.Attachment0=attachment; align.RigidityEnabled=false; align.MaxTorque=10000000; align.MaxAngularVelocity=5; align.Responsiveness=12; align.Parent=seat
 model.Parent=helicopters
 pcall(function() seat:SetNetworkOwner(nil) end)
 return model,seat,force,align,mainRotor
end
local function spawnHeli(player)
 local state=states[player]; if not state or not player.Character then return end
 local character=player.Character; local humanoid=character:FindFirstChildOfClass('Humanoid')
 if humanoid then humanoid.Sit=false end
 if state.model then state.model:Destroy() end
 local model,seat,force,align,rotor=buildHelicopter(player,state.index)
 state.model=model; state.seat=seat; state.force=force; state.align=align; state.rotor=rotor; state.forward=0; state.turn=0; state.lift=0; state.yaw=0; state.lastInput=0; state.rotorAngle=0
 task.delay(.35,function() if states[player]==state and state.model==model and player.Character==character and humanoid and humanoid.Health>0 then seat:Sit(humanoid) end end)
end
local function savePlayerState(player,s)
 if not s then return end
 SupabaseService.saveProfile(player,{
  missions=s.missions.Value,
  stars=s.stars.Value,
  bestLapMs=s.bestLapMs,
  totalResets=s.totalResets,
 })
end
local function setup(player)
 local stats=Instance.new('Folder'); stats.Name='leaderstats'; stats.Parent=player
 local missions=Instance.new('IntValue'); missions.Name='완료'; missions.Parent=stats
 local stars=Instance.new('IntValue'); stars.Name='별'; stars.Parent=stats
 local bestRecord=Instance.new('StringValue'); bestRecord.Name='최고기록'; bestRecord.Value='--'; bestRecord.Parent=stats
 local state={
  index=#Players:GetPlayers()-1,
  targetIndex=1,
  missions=missions,
  stars=stars,
  bestRecord=bestRecord,
  bestLapMs=nil,
  totalResets=0,
  lapResets=0,
  lapStart=os.clock(),
  topSpeed=0,
  maxAltitude=0,
 }
 states[player]=state
 player:SetAttribute('SkyTarget',sequence[1]); player:SetAttribute('SkyMissionStep',1); player:SetAttribute('LapStartClock',workspace:GetServerTimeNow())
 task.spawn(function()
  local profile=SupabaseService.loadOrCreateProfile(player)
  if states[player]~=state or not profile then return end
  missions.Value=tonumber(profile.missions_completed) or 0
  stars.Value=tonumber(profile.stars) or 0
  state.totalResets=tonumber(profile.total_resets) or 0
  if type(profile.best_lap_ms)=='number' then
   state.bestLapMs=profile.best_lap_ms
   bestRecord.Value=string.format('%.2fs',profile.best_lap_ms/1000)
   player:SetAttribute('BestLapMs',profile.best_lap_ms)
  end
  broadcastLeaderboard(player)
 end)
 player.CharacterAdded:Connect(function() task.wait(.6); if states[player]==state then spawnHeli(player) end end)
 if player.Character then task.delay(.6,function() if states[player]==state then spawnHeli(player) end end) end
end
Players.PlayerAdded:Connect(setup)
for _,player in Players:GetPlayers() do setup(player) end
Players.PlayerRemoving:Connect(function(player)
 local s=states[player]
 if s then
  if s.model then s.model:Destroy() end
  task.spawn(savePlayerState,player,s)
 end
 states[player]=nil
end)
game:BindToClose(function()
 for player,s in states do
  savePlayerState(player,s)
 end
end)
local function axis(value)
 if type(value)~='number' or value~=value or math.abs(value)>10 then return 0 end
 return math.clamp(value,-1,1)
end
remote.OnServerEvent:Connect(function(player,action,a,b,c)
 local s=states[player]; if not s then return end
 if action=='reset' then
  if s.lastReset and os.clock()-s.lastReset<3 then return end
  s.lastReset=os.clock(); s.totalResets+=1; s.lapResets+=1; spawnHeli(player)
 elseif action=='requestLeaderboard' then
  broadcastLeaderboard(player)
 elseif action=='input' then
  if s.lastPacket and os.clock()-s.lastPacket<.04 then return end
  if not s.seat or not s.seat.Occupant or s.seat.Occupant.Parent~=player.Character then return end
  s.forward=axis(a); s.turn=axis(b); s.lift=axis(c); s.lastInput=os.clock(); s.lastPacket=os.clock()
 end
end)
local missionTick=0
RunService.Heartbeat:Connect(function(dt)
 missionTick+=dt; local check=missionTick>=.2; if check then missionTick=0 end
 for player,s in states do
  local seat=s.seat
  if seat and seat.Parent then
   local flying=seat.Occupant and player.Character and seat.Occupant.Parent==player.Character
   if flying then
    if os.clock()-s.lastInput>.65 then s.forward=0; s.turn=0; s.lift=0 end
    s.yaw-=s.turn*1.05*math.min(dt,.1)
    local yawCF=CFrame.Angles(0,s.yaw,0)
    local direction=yawCF.LookVector
    local desired=direction*(s.forward*cruiseSpeed)+Vector3.new(0,s.lift*28,0)
    local delta=desired-seat.AssemblyLinearVelocity
    local acc=Vector3.new(math.clamp(delta.X*2,-45,45),math.clamp(delta.Y*3,-75,75),math.clamp(delta.Z*2,-45,45))
    s.force.Force=(acc+Vector3.new(0,workspace.Gravity,0))*seat.AssemblyMass
    s.align.CFrame=yawCF*CFrame.Angles(-s.forward*.12,0,-s.turn*.10)
    if s.rotor then s.rotorAngle=(s.rotorAngle+dt*18)%(2*math.pi); s.rotor.Transform=CFrame.Angles(0,s.rotorAngle,0) end
    local curSpeed=math.floor(seat.AssemblyLinearVelocity.Magnitude)
    local curAlt=math.max(0,math.floor(seat.Position.Y-4))
    if curSpeed>s.topSpeed then s.topSpeed=curSpeed end
    if curAlt>s.maxAltitude then s.maxAltitude=curAlt end
    if check then
     local target=map:FindFirstChild('Marker'..sequence[s.targetIndex])
     if target and (seat.Position-target.Position).Magnitude<32 then
      s.targetIndex+=1
      if s.targetIndex>#sequence then
       local lapTimeMs=math.max(1000,math.floor((os.clock()-s.lapStart)*1000))
       local isNewBest=not s.bestLapMs or lapTimeMs<s.bestLapMs
       if isNewBest then
        s.bestLapMs=lapTimeMs
        s.bestRecord.Value=string.format('%.2fs',lapTimeMs/1000)
        player:SetAttribute('BestLapMs',lapTimeMs)
       end
       local runTopSpeed=s.topSpeed
       local runMaxAlt=s.maxAltitude
       local runResets=s.lapResets
       s.targetIndex=1
       s.missions.Value+=1
       s.stars.Value+=starReward
       s.lapStart=os.clock()
       s.topSpeed=0
       s.maxAltitude=0
       s.lapResets=0
       player:SetAttribute('LapStartClock',workspace:GetServerTimeNow())
       local msg=string.format('비행 코스 완료! (%.2f초%s) 별 +%d',lapTimeMs/1000,isNewBest and ' · NEW 신기록!' or '',starReward)
       remote:FireClient(player,'complete',msg)
       task.spawn(function()
        savePlayerState(player,s)
        SupabaseService.recordFlightLap(player,lapTimeMs,runTopSpeed,runMaxAlt,runResets)
        local board=SupabaseService.fetchTopLeaderboard(5)
        if board then cachedLeaderboard=board; broadcastLeaderboard() end
       end)
      else
       remote:FireClient(player,'complete','목표 통과! 다음 섬으로 이동하세요.')
      end
      player:SetAttribute('SkyTarget',sequence[s.targetIndex]); player:SetAttribute('SkyMissionStep',s.targetIndex)
     end
    end
   else
    s.force.Force=Vector3.zero
    s.align.CFrame=CFrame.Angles(0,s.yaw,0)
   end
  end
 end
end)
