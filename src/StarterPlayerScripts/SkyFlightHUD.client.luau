local Players=game:GetService('Players')
local ReplicatedStorage=game:GetService('ReplicatedStorage')
local RunService=game:GetService('RunService')
local ContextActionService=game:GetService('ContextActionService')
local player=Players.LocalPlayer
local remote=ReplicatedStorage:WaitForChild('SkyFlightEvent')
local gui=Instance.new('ScreenGui'); gui.Name='SkyFlightHUD'; gui.ResetOnSpawn=false; gui.Parent=player:WaitForChild('PlayerGui')
local panel=Instance.new('Frame'); panel.Size=UDim2.fromOffset(315,196); panel.Position=UDim2.fromOffset(16,65); panel.BackgroundColor3=Color3.fromRGB(17,34,53); panel.BackgroundTransparency=.12; panel.Parent=gui
local corner=Instance.new('UICorner'); corner.CornerRadius=UDim.new(0,14); corner.Parent=panel
local stroke=Instance.new('UIStroke'); stroke.Color=Color3.fromRGB(73,214,240); stroke.Thickness=2; stroke.Parent=panel
local function label(y,h,text,size,color,parent)
 local t=Instance.new('TextLabel'); t.Position=UDim2.fromOffset(12,y); t.Size=UDim2.new(1,-24,0,h); t.BackgroundTransparency=1; t.TextXAlignment=Enum.TextXAlignment.Left; t.TextColor3=color or Color3.new(1,1,1); t.Font=Enum.Font.GothamBold; t.TextSize=size; t.Text=text; t.Parent=parent or panel; return t
end
label(7,25,'🚁 SKY ISLANDS',19)
local target=label(34,22,'목표를 불러오는 중...',15,Color3.fromRGB(118,237,255))
local stats=label(57,21,'고도 --  |  속도 --',14)
local lapInfo=label(80,21,'⏱️ 랩 타임 0.0s  |  최고 --',14,Color3.fromRGB(255,221,107))
local noticeLabel=label(103,20,'⚡ Supabase 실시간 랭킹 연동 중...',12,Color3.fromRGB(160,248,255))
noticeLabel.TextTruncate=Enum.TextTruncate.AtEnd
local help=label(126,60,[[W/S 전후진  ·  A/D 회전
Q 상승  ·  E 하강  ·  손을 떼면 호버링]],13,Color3.fromRGB(205,222,230)); help.TextWrapped=true

-- 우측 상단 Supabase 글로벌 랭킹 패널
local lbPanel=Instance.new('Frame'); lbPanel.Size=UDim2.fromOffset(270,185); lbPanel.Position=UDim2.new(1,-286,0,120); lbPanel.BackgroundColor3=Color3.fromRGB(17,34,53); lbPanel.BackgroundTransparency=.15; lbPanel.Parent=gui
local lbCorner=Instance.new('UICorner'); lbCorner.CornerRadius=UDim.new(0,14); lbCorner.Parent=lbPanel
local lbStroke=Instance.new('UIStroke'); lbStroke.Color=Color3.fromRGB(255,204,77); lbStroke.Thickness=2; lbStroke.Parent=lbPanel
label(8,24,'🏆 SUPABASE 글로벌 랭킹',15,Color3.fromRGB(255,216,99),lbPanel)
local lbRows={}
for i=1,5 do
 lbRows[i]=label(12+i*28,24,string.format('%d. 데이터 불러오는 중...',i),13,Color3.fromRGB(225,238,245),lbPanel)
end

local function updateNotice()
 local msg=workspace:GetAttribute('ServerNotice')
 if type(msg)=='string' and #msg>0 then noticeLabel.Text=msg end
end
updateNotice()
workspace:GetAttributeChangedSignal('ServerNotice'):Connect(updateNotice)
local reset=Instance.new('TextButton'); reset.Size=UDim2.fromOffset(145,43); reset.Position=UDim2.new(1,-160,0,70); reset.BackgroundColor3=Color3.fromRGB(227,92,72); reset.Text='헬기 리셋'; reset.Font=Enum.Font.GothamBold; reset.TextSize=16; reset.TextColor3=Color3.new(1,1,1); reset.Parent=gui
local rc=Instance.new('UICorner'); rc.CornerRadius=UDim.new(0,10); rc.Parent=reset
reset.Activated:Connect(function() remote:FireServer('reset') end)
local toast=Instance.new('TextLabel'); toast.Size=UDim2.fromOffset(360,36); toast.Position=UDim2.new(.5,-180,0,18); toast.BackgroundTransparency=.2; toast.BackgroundColor3=Color3.fromRGB(15,42,60); toast.TextColor3=Color3.fromRGB(160,248,255); toast.Font=Enum.Font.GothamBold; toast.TextSize=16; toast.Visible=false; toast.Parent=gui
local tc=Instance.new('UICorner'); tc.CornerRadius=UDim.new(0,9); tc.Parent=toast
local toastVersion=0
remote.OnClientEvent:Connect(function(action,payload)
 if action=='complete' then
  toastVersion+=1; local n=toastVersion; toast.Text=payload; toast.Visible=true
  task.delay(3,function() if toastVersion==n then toast.Visible=false end end)
 elseif action=='leaderboard' and type(payload)=='table' then
  for i=1,5 do
   local row=payload[i]
   if row then
    local name=row.display_name or row.username or 'Pilot'
    local lapText=type(row.best_lap_ms)=='number' and string.format('%.2fs',row.best_lap_ms/1000) or '기록없음'
    local starText=tonumber(row.stars) or 0
    lbRows[i].Text=string.format('%d. %s · %s (⭐%d)',i,name,lapText,starText)
   else
    lbRows[i].Text=string.format('%d. -',i)
   end
  end
 end
end)
task.defer(function() remote:FireServer('requestLeaderboard') end)
local held={forward=false,back=false,left=false,right=false,up=false,down=false}
local function pilotSeat()
 local char=player.Character; local humanoid=char and char:FindFirstChildOfClass('Humanoid'); local seat=humanoid and humanoid.SeatPart
 if seat and seat.Name=='PilotSeat' and seat.Parent and seat.Parent.Name==player.Name..'_Helicopter' then return seat end
end
local function bind(name,key,title,pos,...)
 ContextActionService:BindAction(name,function(_,state)
  if state==Enum.UserInputState.End or state==Enum.UserInputState.Cancel then held[key]=false; return Enum.ContextActionResult.Pass end
  if not pilotSeat() then return Enum.ContextActionResult.Pass end
  if state==Enum.UserInputState.Begin then held[key]=true end
  return Enum.ContextActionResult.Sink
 end,true,...)
 ContextActionService:SetTitle(name,title); ContextActionService:SetPosition(name,pos)
end
bind('SkyForward','forward','전진',UDim2.new(0,80,1,-245),Enum.KeyCode.W,Enum.KeyCode.Up)
bind('SkyBack','back','후진',UDim2.new(0,80,1,-125),Enum.KeyCode.S,Enum.KeyCode.Down)
bind('SkyLeft','left','좌회전',UDim2.new(0,20,1,-185),Enum.KeyCode.A,Enum.KeyCode.Left)
bind('SkyRight','right','우회전',UDim2.new(0,140,1,-185),Enum.KeyCode.D,Enum.KeyCode.Right)
bind('SkyUp','up','상승',UDim2.new(1,-130,1,-245),Enum.KeyCode.Q)
bind('SkyDown','down','하강',UDim2.new(1,-130,1,-125),Enum.KeyCode.E)
local timer=0
RunService.Heartbeat:Connect(function(dt)
 timer+=dt; if timer<.1 then return end; timer=0
 local seat=pilotSeat()
 if seat then
  local forward=(held.forward and 1 or 0)-(held.back and 1 or 0)
  local turn=(held.right and 1 or 0)-(held.left and 1 or 0)
  local lift=(held.up and 1 or 0)-(held.down and 1 or 0)
  remote:FireServer('input',forward,turn,lift)
  local n=player:GetAttribute('SkyTarget') or 2
  local marker=workspace:WaitForChild('SkyIslands'):FindFirstChild('Marker'..n)
  if marker then target.Text=string.format('목표 %d/4: %s  ·  %d',player:GetAttribute('SkyMissionStep') or 1,marker:GetAttribute('PadName') or '섬',math.floor((marker.Position-seat.Position).Magnitude)) end
  stats.Text=string.format('고도 %d  |  속도 %d',math.max(0,math.floor(seat.Position.Y-4)),math.floor(seat.AssemblyLinearVelocity.Magnitude))
  local lapStart=player:GetAttribute('LapStartClock')
  local elapsed=lapStart and math.max(0,workspace:GetServerTimeNow()-lapStart) or 0
  local bestMs=player:GetAttribute('BestLapMs')
  local bestStr=type(bestMs)=='number' and string.format('%.2fs',bestMs/1000) or '--'
  lapInfo.Text=string.format('⏱️ 랩 타임 %.1fs  |  최고 %s',elapsed,bestStr)
 else
  for k in held do held[k]=false end
  stats.Text='헬기에 탑승하세요 · 리셋 가능'
 end
end)
