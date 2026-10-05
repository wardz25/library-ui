-- Auto Nightmare Module (Loaded Externally, Speed UI)
local S = _G.HH_Shared
if not S then return warn("AutoNightmare: HH_Shared not found!") end
if not S.outerScroll then return warn("AutoNightmare: outerScroll not provided!") end
if not S.modalRoot then return warn("AutoNightmare: modalRoot not provided!") end

-- Velium: readability pass (see leveling.lua) -- clamp fonts up + brighten dim gray.
local _V = S.V
local _labelFn, _buttonFn, _inputFn = _V.label, _V.button, _V.input
local V = setmetatable({}, { __index = function(_, k)
 if k == "label" then return function(_, parent, text, size, pos, col, fs, xa)
  return _labelFn(_V, parent, text, size, pos, col, math.max(fs or 12, 11), xa) end end
 if k == "button" then return function(_, parent, text, size, pos, bg, tc, fs)
  return _buttonFn(_V, parent, text, size, pos, bg, tc, math.max(fs or 12, 11)) end end
 if k == "input" then return function(_, parent, default, ph, size, pos)
  return _inputFn(_V, parent, default, ph, size, pos) end end
 return _V[k]
end })
local T             = setmetatable({ DIM = Color3.fromRGB(196, 194, 190) }, { __index = S.T })
local D             = S.D
local CFG             = S.CFG
local saveD           = S.saveD
local getInv        = S.getInv
local getKG         = S.getKG
local getAge        = S.getAge
local getBase       = S.getBase
local getPType      = S.getPType
local isFav         = S.isFav
local findPetTool   = S.findPetTool
local getMutName    = S.getMutName
local unequipAll    = S.unequipAll
local equipList     = S.equipList
local buildEquip    = S.buildEquip
local waitUntilEquipped = S.waitUntilEquipped
local getActivePets = S.getActivePets
local getFarmCF     = S.getFarmCF
local PetsRemote    = S.PetsRemote
local FavRemote     = S.FavRemote
local SellAllRemote = S.SellAllRemote
local DataService   = S.DataService
local htTrack       = S.htTrack
local UI            = S.UI
local outerScroll   = S.outerScroll
local modalRoot     = S.modalRoot
local PageLeveling  = S.PageLeveling
local _buildTeamDD  = S._buildTeamDD
local getTeamUUIDs  = S.getTeamUUIDs
local MUTATION_MAP  = S.MUTATION_MAP
local Player        = S.Player
local Backpack      = S.Backpack
local Char          = S.Char or S.Character

local RS  = game:GetService("ReplicatedStorage")
local GARDEN_CF = CFrame.new(-22.884647369384766, 0.13552331924438477, 55.001434326171875)
local PET_UUID  = "PET_UUID"

local NM_Running = false
local NM_POLL    = 1

local PetShardNM = RS:WaitForChild("GameEvents"):WaitForChild("PetShardService_RE")
local CS_NM      = game:GetService("CollectionService")

local function nmNormUUID(uuid)
 if not uuid then return nil end
 return uuid:gsub("[{}]", ""):lower()
end

local function nmGetMut(uuid)
 local ok, d = pcall(function() return DataService:GetData() end)
 if not ok or not d or not d.PetsData then return nil end
 local pd = d.PetsData.PetInventory.Data[uuid]
 if not pd or not pd.PetData then return nil end
 local mut = pd.PetData.MutationType
 if not mut or mut == "" or mut == "m" then return nil end
 return mut
end

local function nmGetLevel(uuid)
 local ok, d = pcall(function() return DataService:GetData() end)
 if not ok or not d or not d.PetsData then return 0 end
 local pd = d.PetsData.PetInventory.Data[uuid]
 if not pd or not pd.PetData then return 0 end
 return pd.PetData.Level or 0
end

local function nmFindMover(normUUID)
 local pp = workspace:FindFirstChild("PetsPhysical")
 if not pp then return nil end
 for _, mover in ipairs(pp:GetChildren()) do
  if nmNormUUID(mover:GetAttribute("UUID")) == normUUID then return mover end
 end
 return nil
end

local function nmWaitMover(normUUID, timeout)
 local elapsed = 0
 while elapsed < timeout do
  local m = nmFindMover(normUUID)
  if m then return m end
  task.wait(0.3); elapsed = elapsed + 0.3
 end
 return nil
end

local function nmFindShardTool()
 for _, cont in ipairs({Backpack, Char}) do
  for _, t in ipairs(cont:GetChildren()) do
   if t:IsA("Tool") and string.find(t.Name, "Cleansing") then return t end
  end
 end
 return nil
end

local function nmCleanse(targetUUID, logFn)
 logFn("Cleansing " .. getPType(targetUUID) .. "...", T.DIM)
 for _, item in ipairs(Char:GetChildren()) do
  if item:IsA("Tool") then item.Parent = Backpack end
 end
 task.wait(0.3)
 local shard = nmFindShardTool()
 if not shard then
  logFn("Cleansing Shard not found!", T.ERROR)
  return false
 end
 shard.Parent = Char
 task.wait(0.3)
 local normUUID = nmNormUUID(targetUUID)
 PetsRemote:FireServer("EquipPet", targetUUID, getFarmCF())
 local mover = nmWaitMover(normUUID, 6)
 if not mover then
  logFn("Mover missing, skip cleanse!", T.ERROR)
  return false
 end
 local model = nil
 for _, child in ipairs(mover:GetChildren()) do
  if child:IsA("Model") then model = child; break end
 end
 if not model then
  for _, m in ipairs(CS_NM:GetTagged("PetModel")) do
   if m.Parent == mover then model = m; break end
  end
 end
 if not model then
  logFn("Model not found!", T.ERROR)
  return false
 end
 PetShardNM:FireServer("ApplyShard", model)
 task.wait(0.5)
 logFn("Cleanse fired!", T.SUCCESS)
 return true
end

if not D.autoNM then
 D.autoNM = {lvTeam=nil, hsTeam=nil, lvThresh=30, targets={}, running=false}
end

local nmInner = outerScroll

local nmLvLbl = V:label(nmInner, "Leveling Team (1 → threshold)", UDim2.new(1,0,0,14), nil, T.DIM, 9)
nmLvLbl.LayoutOrder = 1; nmLvLbl.Font = Enum.Font.Gotham
local nmLvWrap = V:frame(nmInner, UDim2.new(1,0,0,26), nil, T.BG, 1); nmLvWrap.LayoutOrder = 2
local nmLvBtn  = V:button(nmLvWrap, (D.autoNM.lvTeam or "None selected"), UDim2.new(1,0,1,0), nil, T.BTN, T.TEXT, 9)
nmLvBtn.TextXAlignment = Enum.TextXAlignment.Left
V:pad(nmLvBtn, 0, 8, 8, 0); V:stroke(nmLvBtn, T.STROKE, 1)
V:label(nmLvWrap, "v", UDim2.new(0,20,1,0), UDim2.new(1,-22,0,0), T.DIM, 9, Enum.TextXAlignment.Center)
local nmLvList = V:frame(nmInner, UDim2.new(1,0,0,0), nil, Color3.fromRGB(10,10,10))
nmLvList.LayoutOrder = 3; nmLvList.Visible = false
V:corner(nmLvList, 5); V:stroke(nmLvList, T.STROKE, 1)
local nmLvSF = V:scroll(nmLvList); V:list(nmLvSF, 2); V:pad(nmLvSF, 2,2,2,2)

local nmHsLbl = V:label(nmInner, "Headless Horseman Team", UDim2.new(1,0,0,14), nil, T.DIM, 9)
nmHsLbl.LayoutOrder = 4; nmHsLbl.Font = Enum.Font.Gotham
local nmHsWrap = V:frame(nmInner, UDim2.new(1,0,0,26), nil, T.BG, 1); nmHsWrap.LayoutOrder = 5
local nmHsBtn  = V:button(nmHsWrap, (D.autoNM.hsTeam or "None selected"), UDim2.new(1,0,1,0), nil, T.BTN, T.TEXT, 9)
nmHsBtn.TextXAlignment = Enum.TextXAlignment.Left
V:pad(nmHsBtn, 0, 8, 8, 0); V:stroke(nmHsBtn, T.STROKE, 1)
V:label(nmHsWrap, "v", UDim2.new(0,20,1,0), UDim2.new(1,-22,0,0), T.DIM, 9, Enum.TextXAlignment.Center)
local nmHsList = V:frame(nmInner, UDim2.new(1,0,0,0), nil, Color3.fromRGB(10,10,10))
nmHsList.LayoutOrder = 6; nmHsList.Visible = false
V:corner(nmHsList, 5); V:stroke(nmHsList, T.STROKE, 1)
local nmHsSF = V:scroll(nmHsList); V:list(nmHsSF, 2); V:pad(nmHsSF, 2,2,2,2)

local nmThreshRow = V:frame(nmInner, UDim2.new(1,0,0,26), nil, T.BTN)
nmThreshRow.LayoutOrder = 7; V:corner(nmThreshRow, 5); V:stroke(nmThreshRow, T.STROKE, 1)
V:label(nmThreshRow, "Level threshold (Horseman active at)", UDim2.new(1,-80,1,0), UDim2.new(0,6,0,0), T.DIM, 9).Font = Enum.Font.Gotham
local nmThreshInp = V:input(nmThreshRow, D.autoNM.lvThresh, "", UDim2.new(0,64,0,20), UDim2.new(1,-68,0.5,-10))
nmThreshInp.FocusLost:Connect(function()
 local v = tonumber(nmThreshInp.Text)
 if v and v >= 1 then D.autoNM.lvThresh = v; saveD()
 else nmThreshInp.Text = tostring(D.autoNM.lvThresh) end
end)

local nmTgtRow = V:frame(nmInner, UDim2.new(1,0,0,22), nil, T.BG, 1); nmTgtRow.LayoutOrder = 8
local nmTgtLbl = V:label(nmTgtRow, "Target pets: " .. #D.autoNM.targets, UDim2.new(1,-90,1,0), UDim2.new(0,4,0,0), T.DIM, 9)
nmTgtLbl.Font = Enum.Font.Gotham
local nmOpenTgtBtn = V:button(nmTgtRow, "Select pets >", UDim2.new(0,84,0,20), UDim2.new(1,-86,0.5,-10), T.BTN, T.ACCENT, 9)
V:stroke(nmOpenTgtBtn, T.STROKE, 1)

local nmLogPanel = V:frame(nmInner, UDim2.new(1,0,0,74), nil, T.PANEL); nmLogPanel.LayoutOrder = 9
V:stroke(nmLogPanel, T.STROKE, 1)
local nmLogHdr = V:frame(nmLogPanel, UDim2.new(1,0,0,18), nil, T.BG, 1)
V:label(nmLogHdr, "LOGS", UDim2.new(1,-60,1,0), UDim2.new(0,6,0,0), T.ACCENT, 11).Font = Enum.Font.GothamBold
local nmLogScroll = V:scroll(nmLogPanel, UDim2.new(1,-4,1,-20), UDim2.new(0,2,0,19))
V:list(nmLogScroll, 1); V:pad(nmLogScroll, 1, 4, 4, 1)
local nmLogCount = 0
local function nmLog(msg, col)
 nmLogCount = nmLogCount + 1
 local row = Instance.new("TextLabel"); row.Size = UDim2.new(1,0,0,15)
 row.BackgroundTransparency = 1; row.Text = os.date("%H:%M:%S").."  "..msg
 row.TextColor3 = col or T.DIM; row.Font = Enum.Font.Gotham; row.TextSize = 11
 row.TextXAlignment = Enum.TextXAlignment.Left; row.TextTruncate = Enum.TextTruncate.AtEnd
 row.LayoutOrder = nmLogCount; row.Parent = nmLogScroll
 local kids = {}; for _,c in ipairs(nmLogScroll:GetChildren()) do if c:IsA("TextLabel") then table.insert(kids,c) end end
 while #kids > 12 do kids[1]:Destroy(); table.remove(kids,1) end
 task.defer(function() nmLogScroll.CanvasPosition = Vector2.new(0,math.huge) end)
end

local nmBotBar = V:frame(nmInner, UDim2.new(1,0,0,36), nil, T.PANEL); nmBotBar.LayoutOrder = 10
V:stroke(nmBotBar, T.STROKE, 1)
V:label(nmBotBar, "AUTO NIGHTMARE", UDim2.new(0,110,0,20), UDim2.new(0,8,0.5,-10), T.TEXT, 10).Font = Enum.Font.GothamBold
local nmStatusLbl = V:label(nmBotBar, "● IDLE", UDim2.new(1,-170,1,0), UDim2.new(0,114,0,0), T.DIM, 9)
nmStatusLbl.Font = Enum.Font.Gotham; nmStatusLbl.TextTruncate = Enum.TextTruncate.AtEnd
local function nmSetStatus(msg, col) nmStatusLbl.Text = msg; nmStatusLbl.TextColor3 = col or T.DIM end

local function nmBuildDD(sf, onPick, cur)
 return _buildTeamDD(sf, onPick, cur, V, D, T)
end

local nmLvOpen, nmHsOpen = false, false
nmLvBtn.MouseButton1Click:Connect(function()
 nmLvOpen = not nmLvOpen; nmHsList.Visible = false; nmHsOpen = false
 nmLvList.Visible = nmLvOpen
 if nmLvOpen then
  local cnt = nmBuildDD(nmLvSF, function(name)
   D.autoNM.lvTeam = name; saveD(); nmLvBtn.Text = name
   nmLvList.Visible = false; nmLvOpen = false
  end, D.autoNM.lvTeam)
  nmLvList.Size = UDim2.new(1,0,0,math.min(cnt*24+6,130))
 end
end)
nmHsBtn.MouseButton1Click:Connect(function()
 nmHsOpen = not nmHsOpen; nmLvList.Visible = false; nmLvOpen = false
 nmHsList.Visible = nmHsOpen
 if nmHsOpen then
  local cnt = nmBuildDD(nmHsSF, function(name)
   D.autoNM.hsTeam = name; saveD(); nmHsBtn.Text = name
   nmHsList.Visible = false; nmHsOpen = false
  end, D.autoNM.hsTeam)
  nmHsList.Size = UDim2.new(1,0,0,math.min(cnt*24+6,130))
 end
end)

local nmTgtOverlay = V:frame(modalRoot, UDim2.new(1,0,1,0), nil, T.BG)
nmTgtOverlay.Visible = false; nmTgtOverlay.ZIndex = 20
local nmTgtHdr = V:frame(nmTgtOverlay, UDim2.new(1,0,0,26), nil, T.PANEL); V:stroke(nmTgtHdr, T.STROKE, 1)
V:label(nmTgtHdr, "Select Target Pets (Nightmare)", UDim2.new(1,-36,1,0), UDim2.new(0,8,0,0), T.ACCENT, 10)
local nmTgtClose = V:button(nmTgtHdr, "X", UDim2.new(0,24,0,20), UDim2.new(1,-28,0.5,-11), T.ERROR, T.TEXT, 10)
V:stroke(nmTgtClose, T.ERROR, 1)
nmTgtClose.MouseButton1Click:Connect(function()
 nmTgtOverlay.Visible = false
 nmTgtLbl.Text = "Target pets: " .. #D.autoNM.targets
end)
local nmTgtSearch = V:input(nmTgtOverlay, "", "Search pet...", UDim2.new(1,-8,0,22), UDim2.new(0,4,0,28))
nmTgtSearch.TextColor3 = T.TEXT; nmTgtSearch.Font = Enum.Font.Gotham
local nmTgtScroll = V:scroll(nmTgtOverlay, UDim2.new(1,0,1,-56), UDim2.new(0,0,0,54))
V:list(nmTgtScroll, 3); V:pad(nmTgtScroll, 3,4,4,3)

local function nmBuildTgtList()
 for _, c in ipairs(nmTgtScroll:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
 local inv = getInv(); local q = string.lower(nmTgtSearch.Text)
 local list = {}
 for uuid in pairs(inv) do table.insert(list, uuid) end
 table.sort(list, function(a,b) return getKG(a) > getKG(b) end)
 for i, uuid in ipairs(list) do
  local d = inv[uuid]; if not d then continue end
  if q ~= "" and not string.lower(d.PetType or ""):find(q,1,true) then continue end
  local isSel = table.find(D.autoNM.targets, uuid) ~= nil
  local age = d.PetData and (d.PetData.Level or 0) or 0
  local kg  = getKG(uuid)
  local mut = nmGetMut(uuid)
  local mutTxt = mut and (" [" .. (MUTATION_MAP[mut] or mut) .. "]") or ""
  local mutDisplay = mutTxt ~= "" and string.format('<font color="rgb(180,160,255)">%s</font>', mutTxt) or ""
  local txt = string.format("[%s%s] | Age %d | %.2f KG", d.PetType or "?", mutDisplay, age, kg)
  local row = V:button(nmTgtScroll, txt, UDim2.new(1,0,0,22), nil,
   isSel and T.SEL_BG or Color3.fromRGB(13,13,13), isSel and T.SEL_TXT or T.TEXT, 9)
  row.LayoutOrder = i; row:SetAttribute("uuid", uuid)
  row.TextXAlignment = Enum.TextXAlignment.Left
  V:pad(row, 0,8,4,0); V:stroke(row, isSel and T.ACCENT or T.STROKE, 1)
  row.MouseButton1Click:Connect(function()
   local idx = table.find(D.autoNM.targets, uuid)
   if idx then table.remove(D.autoNM.targets, idx)
   else table.insert(D.autoNM.targets, uuid) end
   saveD(); nmTgtLbl.Text = "Target pets: " .. #D.autoNM.targets
   V:updateRowVisual(row, table.find(D.autoNM.targets,uuid)~=nil,
    T.SEL_BG,T.SEL_TXT,Color3.fromRGB(13,13,13),T.TEXT,T.ACCENT,T.STROKE)
  end)
 end
end
nmTgtSearch:GetPropertyChangedSignal("Text"):Connect(nmBuildTgtList)
nmOpenTgtBtn.MouseButton1Click:Connect(function() nmTgtOverlay.Visible = true; nmBuildTgtList() end)

local function nmRunLoop(logFn, setStatusFn)
 local lvUUIDs = getTeamUUIDs(D.autoNM.lvTeam)
 local hsUUIDs = getTeamUUIDs(D.autoNM.hsTeam)
 local thresh  = D.autoNM.lvThresh or 30
 local snapshot = {}
 for _, u in ipairs(D.autoNM.targets) do table.insert(snapshot, u) end

 for idx, targetUUID in ipairs(snapshot) do
  if not NM_Running then break end
  if not getInv()[targetUUID] then
   logFn(string.format("[%d/%d] Skip — not in inventory", idx, #snapshot), T.DIM)
   continue
  end

  local petName = getPType(targetUUID)
  logFn(string.format("[%d/%d] START %s", idx, #snapshot, petName), T.ACCENT)

  local gotNightmare = false
  local attempt = 0

  while NM_Running and not gotNightmare do
   attempt = attempt + 1
   logFn(string.format("Attempt %d — leveling %s to %d", attempt, petName, thresh), T.DIM)
   setStatusFn(string.format("A%d Leveling %s", attempt, petName), T.DIM)

   local preCheckMut = nmGetMut(targetUUID)
   if preCheckMut ~= nil and preCheckMut ~= "A" then
    local mutName = MUTATION_MAP[preCheckMut] or preCheckMut
    logFn(string.format("Pre-level check: mutation [%s], cleansing...", mutName), T.ERROR)
    setStatusFn("Pre-cleansing " .. petName, T.DIM)
    nmCleanse(targetUUID, logFn)
    task.wait(1)
    unequipAll(); task.wait(0.3)
   end

   unequipAll(); task.wait(0.5)
   equipList(buildEquip(targetUUID, lvUUIDs))

   local lastLv = nmGetLevel(targetUUID)
   while NM_Running do
    task.wait(NM_POLL)
    local lv = nmGetLevel(targetUUID)
    setStatusFn(string.format("Lv%d/%d | %s", lv, thresh, petName), T.DIM)
    if lv >= thresh then
     logFn(string.format("Level %d reached, switch to horseman!", lv), T.ACCENT)
     break
    end
   end
   if not NM_Running then break end

   logFn("Switch to Horseman team...", T.ACCENT)
   setStatusFn("Horseman | " .. petName, Color3.fromRGB(255,150,50))
   unequipAll(); task.wait(0.5)

   local hsEquip = {targetUUID}
   for _, u in ipairs(hsUUIDs) do
    if #hsEquip >= 8 then break end
    if u ~= targetUUID then table.insert(hsEquip, u) end
   end
   equipList(hsEquip)

   local prevMut   = nmGetMut(targetUUID)
   local prevLevel = nmGetLevel(targetUUID)
   logFn(string.format("Watching... prevMut=%s prevLv=%d", tostring(prevMut), prevLevel), T.DIM)

   while NM_Running do
    task.wait(NM_POLL)
    local curMut = nmGetMut(targetUUID)
    local curLv  = nmGetLevel(targetUUID)
    local mutChanged = curMut ~= prevMut
    local levelReset = curLv < (prevLevel - 5)

    if mutChanged or levelReset then
     logFn(string.format("Skill landed! mut=%s lv=%d", tostring(curMut), curLv), T.SUCCESS)
     if curMut == "A" then
      logFn("NIGHTMARE GET! " .. petName, T.SUCCESS)
      setStatusFn("Nightmare! " .. petName, T.SUCCESS)
      gotNightmare = true
      unequipAll()
      local _wh = D.webhook and D.webhook.url or ""
      if _wh ~= "" then
       local _kg = getKG(targetUUID)
       local _base = getBase(targetUUID)
       local _age = getAge(targetUUID)
       pcall(function()
        local _body = game:GetService("HttpService"):JSONEncode({
         username = "Velium Hub",
         embeds = {{
          title = "NIGHTMARE GET!",
          color = 0x7B77DD,
          fields = {
           { name = "Pet",     value = petName,                              inline = true },
           { name = "KG",      value = string.format("%.2f kg", _kg),        inline = true },
           { name = "Base",    value = string.format("%.2f kg", _base),       inline = true },
           { name = "Age",     value = tostring(_age),                       inline = true },
           { name = "Attempt", value = tostring(attempt),                    inline = true },
          },
          footer = { text = "Velium Hub • " .. os.date("%d/%m/%Y %H:%M:%S") },
         }},
        })
        local _req = syn and syn.request or (http and http.request) or request
        if _req then
         _req({ Url=_wh, Method="POST", Headers={["Content-Type"]="application/json"}, Body=_body })
        else
         game:GetService("HttpService"):PostAsync(_wh, _body, Enum.HttpContentType.ApplicationJson, false)
        end
       end)
      end
     else
      local mutName = curMut and (MUTATION_MAP[curMut] or curMut) or "none"
      logFn(string.format("Got %s, not Nightmare — cleanse & retry", mutName), T.ERROR)
      setStatusFn("Cleansing " .. petName, T.DIM)
      local _wh = D.webhook and D.webhook.url or ""
      if _wh ~= "" then
       pcall(function()
        local _body = game:GetService("HttpService"):JSONEncode({
         username = "Velium Hub",
         embeds = {{
          title = "Wrong Mutation — Cleansing",
          color = 0xD74646,
          fields = {
           { name = "Pet",        value = petName,  inline = true },
           { name = "Got",        value = mutName,  inline = true },
           { name = "Attempt",   value = tostring(attempt),  inline = true },
          },
          footer = { text = "Velium Hub • " .. os.date("%d/%m/%Y %H:%M:%S") },
         }},
        })
        local _req = syn and syn.request or (http and http.request) or request
        if _req then
         _req({ Url=_wh, Method="POST", Headers={["Content-Type"]="application/json"}, Body=_body })
        else
         game:GetService("HttpService"):PostAsync(_wh, _body, Enum.HttpContentType.ApplicationJson, false)
        end
       end)
      end
      nmCleanse(targetUUID, logFn)
      task.wait(1)
      unequipAll()
     end
     break
    end
    prevLevel = curLv
   end
  end

  if gotNightmare then
   local idx2 = table.find(D.autoNM.targets, targetUUID)
   if idx2 then table.remove(D.autoNM.targets, idx2); saveD() end
   nmTgtLbl.Text = "Target pets: " .. #D.autoNM.targets
   logFn("Next pet...", T.DIM)
   task.wait(1)
  end
 end

 NM_Running = false
 D.autoNM.running = false; saveD()
 logFn("════ ALL DONE ════", T.ACCENT)
 setStatusFn("● IDLE", T.DIM)
end

local nmTog
nmTog = V:toggle(nmBotBar, UDim2.new(1,-52,0.5,-11), D.autoNM.running or false, function(state)
 if state then
  if not D.autoNM.lvTeam then nmLog("Set Leveling Team first!", T.ERROR); if nmTog then nmTog.Set(false) end; return end
  if not D.autoNM.hsTeam then nmLog("Set Horseman Team first!", T.ERROR); if nmTog then nmTog.Set(false) end; return end
  if #D.autoNM.targets == 0 then nmLog("Pick target pets first!", T.ERROR); if nmTog then nmTog.Set(false) end; return end
  D.autoNM.running = true; saveD()
  NM_Running = true
  nmLog("════ AUTO NIGHTMARE START ════", T.ACCENT)
  nmSetStatus("Starting...", T.SUCCESS)
  task.spawn(function() nmRunLoop(nmLog, nmSetStatus) end)
 else
  NM_Running = false
  D.autoNM.running = false; saveD()
  nmLog("Stopped", T.ERROR)
  nmSetStatus("● IDLE", T.DIM)
 end
end)
if D.autoNM.running then
 task.defer(function()
  if not D.autoNM.lvTeam or not D.autoNM.hsTeam or #D.autoNM.targets == 0 then
   D.autoNM.running = false; saveD(); if nmTog then nmTog.Set(false) end; return
  end
  NM_Running = true
  nmLog("════ AUTO NIGHTMARE RESUMED ════", T.ACCENT)
  task.spawn(function() nmRunLoop(nmLog, nmSetStatus) end)
 end)
end

nmLog("Auto Nightmare ready!", T.SUCCESS)
