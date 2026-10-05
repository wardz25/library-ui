-- Auto Leveling Module (Loaded Externally, Speed UI)
local S = _G.HH_Shared
if not S then return warn("AutoLeveling: HH_Shared not found!") end
if not S.outerScroll then return warn("AutoLeveling: outerScroll not provided!") end
if not S.modalRoot then return warn("AutoLeveling: modalRoot not provided!") end

-- Velium: readability pass. External modules used to render at TextSize 8-9 with
-- a muted gray, which read as "invisible" on the dark Speed window. Clamp every
-- label/button font up to a legible minimum and brighten the dim gray locally
-- (proxies only -- the shared theme table itself is left untouched).
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
local T = setmetatable({ DIM = Color3.fromRGB(196, 194, 190) }, { __index = S.T })
local D               = S.D
local CFG             = S.CFG
local saveD           = S.saveD
local getInv          = S.getInv
local getKG           = S.getKG
local getAge          = S.getAge
local isFav           = S.isFav
local getMutName      = S.getMutName
local unequipAll      = S.unequipAll
local equipList       = S.equipList
local buildEquip      = S.buildEquip
local MUTATION_MAP    = S.MUTATION_MAP
local outerScroll     = S.outerScroll
local modalRoot       = S.modalRoot
local _buildTeamDD    = S._buildTeamDD
local getTeamUUIDs    = S.getTeamUUIDs
local UI              = S.UI

local LV_Running = false
local LV_Thread  = nil

local lvScroll = outerScroll

local function makeLvDD(label, dataKey, lo_lbl, lo_wrap, lo_list)
 local lbl = V:label(lvScroll, label, UDim2.new(1,0,0,14), nil, T.DIM, 9)
 lbl.Font = Enum.Font.Gotham; lbl.LayoutOrder = lo_lbl
 local wrap = V:frame(lvScroll, UDim2.new(1,0,0,26), nil, T.BG, 1)
 wrap.LayoutOrder = lo_wrap
 local btn = V:button(wrap, (D.leveling[dataKey] or "None selected"), UDim2.new(1,0,1,0), nil, T.BTN, T.TEXT, 9)
 btn.TextXAlignment = Enum.TextXAlignment.Left
 V:pad(btn, 0, 8, 8, 0); V:stroke(btn, T.STROKE, 1)
 V:label(wrap, "v", UDim2.new(0,20,1,0), UDim2.new(1,-22,0,0), T.DIM, 9, Enum.TextXAlignment.Center)
 local list = V:frame(lvScroll, UDim2.new(1,0,0,0), nil, Color3.fromRGB(10,10,10))
 list.LayoutOrder = lo_list; list.Visible = false
 V:corner(list, 5); V:stroke(list, T.STROKE, 1)
 local sf = V:scroll(list); V:list(sf, 2); V:pad(sf, 2, 2, 2, 2)
 return btn, list, sf
end

local lvDD1Btn, lvDD1List, lvDD1Scroll = makeLvDD("Main Team (1 - 100)", "mainTeam", 1, 2, 3)
local optHdrRow = V:frame(lvScroll, UDim2.new(1,0,0,26), nil, T.BG, 1); optHdrRow.LayoutOrder = 4
V:label(optHdrRow, "[ Optional ] Team (threshold - 100)", UDim2.new(1,-52,1,0), UDim2.new(0,4,0,0), T.DIM, 9).Font = Enum.Font.Gotham
V:toggle(optHdrRow, UDim2.new(1,-48,0.5,-11), D.leveling.optEnabled, function(s)
 D.leveling.optEnabled = s; saveD()
end)

local lvDD2Btn, lvDD2List, lvDD2Scroll = makeLvDD("Optional Team", "optTeam", 5, 6, 7)

local optThreshRow = V:frame(lvScroll, UDim2.new(1,0,0,26), nil, T.BG, 1); optThreshRow.LayoutOrder = 8
V:label(optThreshRow, "Optional team from level", UDim2.new(1,-72,1,0), UDim2.new(0,4,0,0), T.DIM, 9).Font = Enum.Font.Gotham
local optThreshInp = V:input(optThreshRow, D.leveling.optThreshold, "", UDim2.new(0,64,0,20), UDim2.new(1,-68,0.5,-10))
optThreshInp.FocusLost:Connect(function()
 local v = tonumber(optThreshInp.Text)
 if v and v >= 1 and v <= 99 then D.leveling.optThreshold = v; saveD()
 else optThreshInp.Text = tostring(D.leveling.optThreshold) end
end)

V:divider(lvScroll, 8)

local lvTgtLvlRow = V:frame(lvScroll, UDim2.new(1,0,0,26), nil, T.BG, 1); lvTgtLvlRow.LayoutOrder = 9
V:label(lvTgtLvlRow, "Target Level", UDim2.new(1,-72,1,0), UDim2.new(0,4,0,0), T.DIM, 9).Font = Enum.Font.Gotham
local lvTgtLvlInp = V:input(lvTgtLvlRow, tostring(D.leveling.targetLevel or 100), "", UDim2.new(0,64,0,20), UDim2.new(1,-68,0.5,-10))
lvTgtLvlInp.FocusLost:Connect(function()
 local v = tonumber(lvTgtLvlInp.Text)
 if v and v >= 1 then D.leveling.targetLevel = v; saveD()
 else lvTgtLvlInp.Text = tostring(D.leveling.targetLevel or 100) end
end)

local lvSelectRow = S.selectRow

local lvTgtSession
local function lvUpdateTgtLbl() lvTgtSession.setValue("Target pets: "..#D.leveling.targets, #D.leveling.targets > 0) end
lvTgtSession = lvSelectRow(lvScroll, 10, "Select Target Pets", {
 placeholder = "Search pet name...",
 getRows = function()
  local inv = getInv(); local list = {}
  for uuid in pairs(inv) do table.insert(list, uuid) end
  table.sort(list, function(a,b) return getAge(a) < getAge(b) end)
  local rows = {}
  for _, uuid in ipairs(list) do
   local d = inv[uuid]
   if d then
    local age = (d.PetData and d.PetData.Level) or 0
    local base = (d.PetData and d.PetData.BaseWeight) or 0
    local mutCode2 = (d.PetData and d.PetData.MutationType) or ""
    local mutName2 = (mutCode2 ~= "" and mutCode2 ~= "m") and (" [".. (MUTATION_MAP[mutCode2] or mutCode2) .."]") or ""
    local fav = isFav(uuid) and " ❤" or ""
    table.insert(rows, {id = uuid, text = (d.PetType or "?") .. fav,
     sub = string.format("Age %d | %.2f KG", age, getKG(uuid)),
     search = (d.PetType or "") .. mutName2, selected = table.find(D.leveling.targets, uuid) ~= nil})
   end
  end
  return rows
 end,
 onToggle = function(r)
  local idx = table.find(D.leveling.targets, r.id)
  if idx then table.remove(D.leveling.targets, idx) else table.insert(D.leveling.targets, r.id) end
  saveD(); lvUpdateTgtLbl()
 end,
 selectAll = function(shown)
  local allSel = #shown > 0
  for _, r in ipairs(shown) do if not table.find(D.leveling.targets, r.id) then allSel = false; break end end
  for _, r in ipairs(shown) do
   local idx = table.find(D.leveling.targets, r.id)
   if allSel then if idx then table.remove(D.leveling.targets, idx) end
   elseif not idx then table.insert(D.leveling.targets, r.id) end
  end
  saveD(); lvUpdateTgtLbl()
 end,
 refresh = lvUpdateTgtLbl,
})
lvUpdateTgtLbl()

local lvLogPanel = V:frame(lvScroll, UDim2.new(1,0,0,74), nil, T.PANEL); lvLogPanel.LayoutOrder = 11
V:stroke(lvLogPanel, T.STROKE, 1)
local lvLogHdr = V:frame(lvLogPanel, UDim2.new(1,0,0,18), nil, T.BG, 1)
V:label(lvLogHdr, "LOGS", UDim2.new(1,-70,1,0), UDim2.new(0,6,0,0), T.ACCENT, 11).Font = Enum.Font.GothamBold
local lvDoneLbl = V:label(lvLogHdr, "Done: 0", UDim2.new(0,66,1,0), UDim2.new(1,-70,0,0), T.DIM, 11, Enum.TextXAlignment.Right)
lvDoneLbl.Font = Enum.Font.Gotham
local lvLogScroll = V:scroll(lvLogPanel, UDim2.new(1,-4,1,-20), UDim2.new(0,2,0,19))
V:list(lvLogScroll, 1); V:pad(lvLogScroll, 1, 4, 4, 1)
local lvLogCount = 0
local function lvAddLog(msg, col)
 lvLogCount = lvLogCount + 1
 local row = Instance.new("TextLabel"); row.Size = UDim2.new(1,0,0,15)
 row.BackgroundTransparency = 1; row.Text = os.date("%H:%M:%S").."  "..msg
 row.TextColor3 = col or T.DIM; row.Font = Enum.Font.Gotham; row.TextSize = 11
 row.TextXAlignment = Enum.TextXAlignment.Left; row.TextTruncate = Enum.TextTruncate.AtEnd
 row.LayoutOrder = lvLogCount; row.Parent = lvLogScroll
 local kids = {}; for _,c in ipairs(lvLogScroll:GetChildren()) do if c:IsA("TextLabel") then table.insert(kids,c) end end
 while #kids > 12 do kids[1]:Destroy(); table.remove(kids,1) end
 task.defer(function() lvLogScroll.CanvasPosition = Vector2.new(0,math.huge) end)
end

local lvBotBar = V:frame(lvScroll, UDim2.new(1,0,0,38), nil, T.PANEL); lvBotBar.LayoutOrder = 12
V:stroke(lvBotBar, T.STROKE, 1)
V:label(lvBotBar, "AUTO LEVELING", UDim2.new(0,100,0,20), UDim2.new(0,8,0.5,-10), T.TEXT, 10).Font = Enum.Font.GothamBold
local lvStatusLbl = V:label(lvBotBar, "● IDLE", UDim2.new(1,-160,1,0), UDim2.new(0,102,0,0), T.DIM, 9)
lvStatusLbl.Font = Enum.Font.Gotham; lvStatusLbl.TextTruncate = Enum.TextTruncate.AtEnd
local function lvSetStatus(msg, col) lvStatusLbl.Text = msg; lvStatusLbl.TextColor3 = col or T.DIM end

local lvDD1Open, lvDD2Open = false, false
local function buildLvDD(sf, onPick, cur)
 return _buildTeamDD(sf, onPick, cur, V, D, T)
end

lvDD1Btn.MouseButton1Click:Connect(function()
 lvDD1Open = not lvDD1Open; lvDD2List.Visible = false; lvDD2Open = false
 lvDD1List.Visible = lvDD1Open
 if lvDD1Open then
  local cnt = buildLvDD(lvDD1Scroll, function(name)
   D.leveling.mainTeam = name; saveD(); lvDD1Btn.Text = name; lvDD1List.Visible = false; lvDD1Open = false
  end, D.leveling.mainTeam)
  lvDD1List.Size = UDim2.new(1,0,0,math.min(cnt*24+6,130))
 end
end)
lvDD2Btn.MouseButton1Click:Connect(function()
 lvDD2Open = not lvDD2Open; lvDD1List.Visible = false; lvDD1Open = false
 lvDD2List.Visible = lvDD2Open
 if lvDD2Open then
  local cnt = buildLvDD(lvDD2Scroll, function(name)
   D.leveling.optTeam = name; saveD(); lvDD2Btn.Text = name; lvDD2List.Visible = false; lvDD2Open = false
  end, D.leveling.optTeam)
  lvDD2List.Size = UDim2.new(1,0,0,math.min(cnt*24+6,130))
 end
end)

local function lvCleanTargets()
 local inv = getInv(); local cleaned = {}
 for _, uuid in ipairs(D.leveling.targets) do if inv[uuid] then table.insert(cleaned, uuid) end end
 local removed = #D.leveling.targets - #cleaned
 D.leveling.targets = cleaned
 if removed > 0 then saveD() end
 return removed
end

local function startLeveling(tog)
 lvCleanTargets()
 if #D.leveling.targets == 0 then lvSetStatus("No targets!", T.ERROR); if tog then tog.Set(false) end; return end
 LV_Running = true
 lvSetStatus("Running…", T.SUCCESS)
 lvAddLog("════ AUTO LEVELING START ════", T.ACCENT)
 local lvDoneCount = 0

 LV_Thread = task.spawn(function()
  local mainUUIDs = getTeamUUIDs(D.leveling.mainTeam)
  local optUUIDs  = getTeamUUIDs(D.leveling.optTeam)
  local optThresh = D.leveling.optThreshold
  local snapshot  = {}
  for _, u in ipairs(D.leveling.targets) do table.insert(snapshot, u) end
  local total = #snapshot

  for idx, targetUUID in ipairs(snapshot) do
   if not LV_Running then break end
   if not getInv()[targetUUID] then
    lvAddLog(string.format("[%d/%d] Skip — not in inventory", idx, total), T.DIM)
    local i = table.find(D.leveling.targets, targetUUID); if i then table.remove(D.leveling.targets, i); saveD() end
    continue
   end

   local petName  = S.getPType(targetUUID)
   local petStart = os.clock()
   local ageNow   = getAge(targetUUID)
   local targetLvl = D.leveling.targetLevel or 100
   lvAddLog(string.format("[%d/%d] %s — Lv%d → %d", idx, total, petName, ageNow, targetLvl), T.ACCENT)
   lvSetStatus(string.format("[%d/%d] %s", idx, total, petName), T.TEXT)

   if ageNow >= targetLvl then
    lvAddLog(string.format("Already Lv%d, skip", targetLvl), T.DIM)
    local i = table.find(D.leveling.targets, targetUUID); if i then table.remove(D.leveling.targets, i); saveD() end
    lvUpdateTgtLbl()
    continue
   end

   local usingOpt = D.leveling.optEnabled and #optUUIDs > 0 and ageNow >= optThresh
   local curTeam  = usingOpt and optUUIDs or mainUUIDs
   unequipAll(); task.wait(0.5)
   equipList(buildEquip(targetUUID, curTeam))
   local lastLog = ageNow - (ageNow % 10)

   while LV_Running do
    task.wait(CFG.POLL_RATE)
    if not getInv()[targetUUID] then
     lvAddLog(string.format("%s removed from inventory", petName), T.ERROR)
     local i = table.find(D.leveling.targets, targetUUID); if i then table.remove(D.leveling.targets, i); saveD() end
     lvUpdateTgtLbl()
     unequipAll(); break
    end
    local age2 = getAge(targetUUID)
    lvSetStatus(string.format("Lv%d/%d | %s", age2, targetLvl, petName), T.DIM)

    if not usingOpt and D.leveling.optEnabled and #optUUIDs > 0 and age2 >= optThresh then
     usingOpt = true
     lvAddLog(string.format("  Switch opt team at Lv%d", age2), T.ACCENT)
     unequipAll(); task.wait(0.5)
     equipList(buildEquip(targetUUID, optUUIDs))
    end

    if age2 >= lastLog + 10 then
     lvAddLog(string.format("  Lv%d/%d  %s", age2, petName), T.DIM)
     lastLog = age2 - (age2 % 10)
    end

    if age2 >= targetLvl then
     unequipAll()
     lvDoneCount = lvDoneCount + 1
     lvDoneLbl.Text = "Done: "..lvDoneCount
     local elapsed = os.clock() - petStart
     lvAddLog(string.format("DONE  %s  Lv%d  (%s)", petName, targetLvl, UI.fmtTime(elapsed)), T.SUCCESS)
     lvSetStatus(string.format("%s done! %s", petName, UI.fmtTime(elapsed)), T.SUCCESS)
     local i = table.find(D.leveling.targets, targetUUID); if i then table.remove(D.leveling.targets, i); saveD() end
     lvUpdateTgtLbl()
     local fkg = 0; pcall(function() fkg = getKG(targetUUID) end)
     pcall(function()
      if S.sendPetFinishedWebhook then
       S.sendPetFinishedWebhook(petName, fkg, elapsed, 0, lvDoneCount, total)
      end
     end)
     break
    end
   end
  end

  LV_Running = false; if tog then tog.Set(false) end
  D.leveling.running = false; saveD()
  lvAddLog("════════════════════", T.ACCENT)
  lvAddLog(string.format("ALL DONE  %d/%d", lvDoneCount, total), T.SUCCESS)
  lvSetStatus(string.format("Done! %d pets", lvDoneCount), T.SUCCESS)
  pcall(function()
   if S.sendWebhook then
    S.sendWebhook({{title = "Leveling ALL DONE", color = 5763719,
     description = string.format("%d/%d pets reached Level %d", lvDoneCount, total, D.leveling.targetLevel or 100),
     fields = {
      {name = "Queue", value = string.format("%d / %d done", lvDoneCount, total), inline = true},
     },
     footer = {text = "Velium Hub " .. os.date("%d/%m/%Y %H:%M:%S")},
     thumbnail = {url = "https://raw.githubusercontent.com/wardz25/library-ui/main/VeliumHub.png"},
    }})
   end
  end)
 end)
end

if D.leveling.running == nil then D.leveling.running = false end
local lvTog
lvTog = V:toggle(lvBotBar, UDim2.new(1,-52,0.5,-11), D.leveling.running, function(state)
 D.leveling.running = state; saveD()
 if state then
  startLeveling(lvTog)
 else
  LV_Running = false
  lvAddLog("Stopped by user", T.ERROR)
  lvSetStatus("Stopped", T.DIM)
 end
end)
if D.leveling.running then
 task.defer(function() startLeveling(lvTog) end)
end

lvAddLog("Auto Leveling ready!", T.SUCCESS)
