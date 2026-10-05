-- Velium Hub (GAG)
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Http = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local CS = game:GetService("CollectionService")
local UIS = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")

-- ============================================================
-- PREFETCH (parallel) — start every remote fetch immediately, before
-- any WaitForChild / character wait, so total startup cost is the
-- slowest single request instead of the sum of all of them.
-- ============================================================
local PREFETCH = {}
local function prefetchRaw(key, url)
	task.spawn(function()
		local ok, data = pcall(function() return game:HttpGet(url) end)
		PREFETCH[key] = (ok and type(data) == "string" and data ~= "") and data or false
	end)
end
local function prefetchJson(key, url)
	task.spawn(function()
		local ok, data = pcall(function() return Http:JSONDecode(game:HttpGet(url)) end)
		PREFETCH[key] = (ok and type(data) == "table") and data or false
	end)
end
local function prefetchAwait(key, timeout)
	local waited = 0
	while PREFETCH[key] == nil and waited < (timeout or 20) do
		task.wait(0.05)
		waited = waited + 0.05
	end
	return PREFETCH[key] or nil
end
-- Bump this on every push: it cache-busts the inner fetches so a stale
-- raw-CDN copy of the UI library can never be served to a client.
local VELIUM_BUILD = "2026-09-16m"
local LIB_URL  = "https://raw.githubusercontent.com/wardz25/library-ui/refs/heads/main/VeliumMainLibrary.lua?v=" .. VELIUM_BUILD
local UI_URL   = "https://raw.githubusercontent.com/wardz25/library-ui/refs/heads/main/SpeedHubX_UI.lua?v=" .. VELIUM_BUILD
local PETS_URL = "https://raw.githubusercontent.com/Punpunzero02/updater/refs/heads/main/pets.json"
local MUT_URL  = "https://raw.githubusercontent.com/Punpunzero02/updater/refs/heads/main/mutation.json"
prefetchRaw("lib", LIB_URL)
prefetchRaw("speedui", UI_URL)
prefetchJson("pets", PETS_URL)
prefetchJson("mutation", MUT_URL)

local LocalPlayer = Players.LocalPlayer
local Backpack = LocalPlayer:WaitForChild("Backpack", 15)
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
LocalPlayer.CharacterAdded:Connect(function(char) Character = char end)
local DataService = require(RS.Modules.DataService)
local PetsRemote = RS:WaitForChild("GameEvents"):WaitForChild("PetsService")
local BoostRemote = RS:WaitForChild("GameEvents"):WaitForChild("PetBoostService")
local PetEggService = RS:WaitForChild("GameEvents"):WaitForChild("PetEggService")
local FavItemRemote = RS:WaitForChild("GameEvents"):WaitForChild("Favorite_Item")
local PetAgeLimitBreak = RS:WaitForChild("GameEvents"):FindFirstChild("PetAgeLimitBreak")
local PetMutationMachine = RS:WaitForChild("GameEvents"):FindFirstChild("PetMutationMachineService_RE")
local ActivePetService = RS:WaitForChild("GameEvents"):FindFirstChild("ActivePetService")
local SellPetRE = RS:WaitForChild("GameEvents"):FindFirstChild("SellPet_RE")
local SellAllPetsRE = RS:WaitForChild("GameEvents"):FindFirstChild("SellAllPets_RE")
local SellOnePetRE = RS:WaitForChild("GameEvents"):FindFirstChild("SellPetShopSelected")
local PetGiftingService = RS:WaitForChild("GameEvents"):FindFirstChild("PetGiftingService")
local PetShardService = RS:WaitForChild("GameEvents"):FindFirstChild("PetShardService_RE")

local tStart = os.clock()
print("[Velium Hub] Loading... (fetching assets in parallel)")
local Library
do
local libSrc = prefetchAwait("lib")
local ok, lib = pcall(function()
if type(libSrc) ~= "string" then error("empty VeliumMainLibrary source") end
return loadstring(libSrc)()
end)
if ok and lib then
Library = lib
else
warn("[Velium Hub] Failed to load VeliumMainLibrary, retrying...")
task.wait(2)
local ok2, lib2 = pcall(function()
return loadstring(game:HttpGet(LIB_URL))()
end)
if ok2 and lib2 then Library = lib2
else error("[Velium Hub] Could not load VeliumMainLibrary!") end
end
end
local UI = Library.new()
if not Library.buildPetList then
Library.buildPetList = function(self, parent, selected, favs, onClick, getKG2, getInventory2, isFav2, sortFn2)
local T2 = self.T
for _, c in ipairs(parent:GetChildren()) do
if c:IsA("GuiObject") then c:Destroy() end
end
local q = string.lower(sortFn2 or "")
local inv = getInventory2()
local uuids = {}
for u in pairs(inv) do table.insert(uuids, u) end
table.sort(uuids, function(a, b)
local sa = (selected[a] and 1) or 0
local sb = (selected[b] and 1) or 0
if sa ~= sb then return sa > sb end
return getKG2(a) > getKG2(b)
end)
for i, uuid in ipairs(uuids) do
local pet = inv[uuid]
if not pet then continue end
local name = pet.PetType or "?"
if q ~= "" and not name:lower():find(q, 1, true) then continue end
local isActive = selected[uuid]
local isFav2 = favs[uuid] == true
local level = (pet.PetData and (pet.PetData.Level or 0)) or 0
local kg = getKG2(uuid)
local base = (pet.PetData and (pet.PetData.BaseWeight or 0)) or 0
local favMark = (isFav2 and "*") or ""
local activeMark = (isActive and "(active)") or ""
local txt = string.format("%s%s%s | Age %d | %.2f KG | Base %.2f", name, activeMark, favMark, level, kg, base)
local b = self:button(parent, txt, UDim2.new(1,0,0,26), nil,
(isActive and T2.SEL_BG) or (isActive and T2.ACTIVE_BG) or Color3.fromRGB(13,13,13),
(isActive and T2.SEL_TXT) or (isActive and T2.ACTIVE_TXT) or T2.TEXT, 9)
b.LayoutOrder = i
b:SetAttribute("uuid", uuid)
b.TextXAlignment = Enum.TextXAlignment.Left
self:pad(b, 0, 8, 4, 0)
self:stroke(b, (isActive and T2.ACCENT) or T2.STROKE, 1)
b.MouseButton1Click:Connect(function()
onClick(uuid, b, selected)
end)
end
end
end
local T = {
BG = Color3.fromRGB(22, 22, 22),
PANEL = Color3.fromRGB(17, 17, 22),
BTN = Color3.fromRGB(24, 24, 31),
SIDEBAR = Color3.fromRGB(17, 17, 22),
STROKE = Color3.fromRGB(24, 66, 60),
ACCENT = Color3.fromRGB(128, 255, 234),
TEXT = Color3.fromRGB(245, 243, 236),
DIM = Color3.fromRGB(166, 164, 160),
SEL_BG  = Color3.fromRGB(14, 40, 36),      -- near-black teal
SEL_TXT = Color3.fromRGB(128, 255, 234),    -- mint — matches T.ACCENT exactly
SUCCESS = Color3.fromRGB(80, 210, 100),
ERROR = Color3.fromRGB(215, 70, 70),
TOGGLE_ON = Color3.fromRGB(128, 255, 234),
TOGGLE_OFF = Color3.fromRGB(24, 66, 60),
ACTIVE_BG = Color3.fromRGB(24, 66, 60),
ACTIVE_TXT = Color3.fromRGB(128, 255, 234),
DARK_CARD = Color3.fromRGB(17, 17, 22),
PHASE2 = Color3.fromRGB(52, 160, 150),
}
UI.T = T
local TIMING = {
EQUIP_DELAY = 0.08,
UNEQUIP_DELAY = 0.05,
UNEQUIP_BUFFER = 0.01,
AH_EQUIP_DELAY = 0.15,
AH_UNEQUIP_DELAY = 0.1,
AH_POST_UNEQUIP_BUFFER = 0.5,
AH_KOI_SAFE_DELAY = 1,
AH_KOI_POST_HATCH = 1.5,
AH_SEAL_SAFE_DELAY = 1,
AH_SEAL_POST_SELL = 2,
POLL_RATE = 3,
}
local CONFIG_FILE = "VeliumHub_Config.json"
local cfg = {
petTeams = {},
elephant = {
levelingTeam = nil,
elephantTeam = nil,
targetWeight = 3.5,
levelThreshold = 50,
phase2Team = nil,
phase2Enabled = false,
phase2Threshold = 50,
levelTo100 = true,
gardenSlots = 1,
gardenMode = "A",
useExtraPets = false,
extraPets = {},
useExtraElePets = false,
extraElePets = {},
},
targets = {},
placeEggs = {
enabled = false,
order = {},
method = "Random",
maxEggs = 20,
eggPlaceDelay = 0.2,
},
pickplace = {
petTimer = 0,
pickDelay = 0.2,
placeDelay = 0.1,
selPets = {},
},
petboost = {
mode1 = { boostOptions = {["Small Toy"] = true}, selPets = {} },
mode2 = { pairs = {}, boostOptions = {} },
},
autoMutation = {
enabled = false,
method = "Level",
targetUUID = nil,
targetAge = 100,
farmLoadout = 1,
timeLoadout = 2,
claimLoadout = 3,
targetMutant = "Normal",
delay = 10,
},
autoGift = {
enabled = false,
friendName = "",
petTypes = {},
weightThreshold = 0,
weightMode = "Below",
mutantFilter = "ALL",
},
autoFeed = {
enabled = false,
hungerThreshold = 50,
crops = {},
},
plotState = {
plotNum = 1,
order = 0,
currentX = nil,
},
toggles = {
autoKG = false,
pickplace = false,
mode1boost = false,
mode2boost = false,
autoCollect = false,
hidePlants = false,
hideNotif = false,
autoRefresh = false,
autoTradeWorld = false,
autoMutation = false,
autoGift = false,
autoFeed = false,
},
misc = { rsInterval = 19 },
webhook = { url = "", continueSession = false, sendCycle = true, sendFinished = true, sendSpecial = true, sendHatch = true },
leveling = {
mainTeam = nil,
optTeam = nil,
optEnabled = false,
optThreshold = 50,
targetLevel = 100,
targets = {},
},
autoCollect = {
interval = 0.1,
sellAfter = false,
selFruits = {},
selVariants = {},
stopWhenFull = false,
maxInv = 200,
},
autoBuy = {
seed = {on=false, items={}},
egg = {on=false, items={}},
gear = {on=false, items={}},
},
autoHatch = {
eggName = "Paradise Egg",
eggCount = 13,
eggSpacing = 7,
teamCD = nil,
teamKoi = nil,
teamSeal = nil,
teamBronto = nil,
brontoEnabled = true,
brontoThresh = 4,
sellPets = {},
sellAll = false,
sellEnabled = true,
sellThresh = 0,
favDelay = 0.1,
espEnabled = true,
running = false,
autoSellWhenFull = false,
petInvMax = 200,
dontPickPlace = false,
autoFeedDelay = 0,
specialBronto = {enabled=true, pets={}},
},
autoTrade = {
targetPlayer = nil,
selPets = {},
kgMode = "Above",
kgVal = 0,
ageMode = "Above",
ageVal = 0,
autoAccept = false,
autoGift = false,
},
}
-- saveConfig
local function saveConfig()
if not writefile then return end
pcall(function() writefile(CONFIG_FILE, Http:JSONEncode(cfg)) end)
end
-- loadConfig
local function loadConfig()
if not readfile or not isfile or not isfile(CONFIG_FILE) then return end
local ok, data = pcall(function() return Http:JSONDecode(readfile(CONFIG_FILE)) end)
if not ok or not data then return end
if data.petTeams then cfg.petTeams = data.petTeams end
if data.elephant then for k, v in pairs(data.elephant) do cfg.elephant[k] = v end end
if data.targets then cfg.targets = data.targets end
if data.placeEggs then for k, v in pairs(data.placeEggs) do cfg.placeEggs[k] = v end end
if data.pickplace then for k, v in pairs(data.pickplace) do cfg.pickplace[k] = v end end
if data.petboost then
if data.petboost.mode1 then
if type(data.petboost.mode1.boostOptions) == "table" then
cfg.petboost.mode1.boostOptions = data.petboost.mode1.boostOptions
elseif data.petboost.mode1.boostOption then
cfg.petboost.mode1.boostOptions = {[data.petboost.mode1.boostOption] = true}
end
if data.petboost.mode1.selPets then cfg.petboost.mode1.selPets = data.petboost.mode1.selPets end
end
if data.petboost.mode2 then for k, v in pairs(data.petboost.mode2) do cfg.petboost.mode2[k] = v end end
end
if data.toggles then for k, v in pairs(data.toggles) do cfg.toggles[k] = v end end
if data.uiW ~= nil then cfg.uiW = data.uiW end
if data.uiH ~= nil then cfg.uiH = data.uiH end
if data.uiManual ~= nil then cfg.uiManual = data.uiManual end
if data.uiScale ~= nil then cfg.uiScale = data.uiScale end
if data.misc then for k, v in pairs(data.misc) do cfg.misc[k] = v end end
if data.webhook then for k, v in pairs(data.webhook) do cfg.webhook[k] = v end end
if cfg.webhook.continueSession == nil then cfg.webhook.continueSession = false end
if cfg.webhook.sendCycle == nil then cfg.webhook.sendCycle = true end
if cfg.webhook.sendFinished == nil then cfg.webhook.sendFinished = true end
if cfg.webhook.sendSpecial == nil then cfg.webhook.sendSpecial = true end
if cfg.webhook.sendHatch == nil then cfg.webhook.sendHatch = true end
if not cfg.autoBuy then cfg.autoBuy = {seed={on=false,items={}},egg={on=false,items={}},gear={on=false,items={}}} end
if data.autoBuy then for k, v in pairs(data.autoBuy) do if type(v) == "table" then if not cfg.autoBuy[k] then cfg.autoBuy[k] = {} end for kk, vv in pairs(v) do cfg.autoBuy[k][kk] = vv end else cfg.autoBuy[k] = v end end end
if data.leveling then for k, v in pairs(data.leveling) do cfg.leveling[k] = v end end
if data.autoHatch then for k, v in pairs(data.autoHatch) do cfg.autoHatch[k] = v end end
if data.autoTrade then for k, v in pairs(data.autoTrade) do cfg.autoTrade[k] = v end end
if data.autoNM then
if not cfg.autoNM then cfg.autoNM = {lvTeam=nil, hsTeam=nil, lvThresh=30, targets={}} end
for k, v in pairs(data.autoNM) do cfg.autoNM[k] = v end
end
if data.autoEV then
if not cfg.autoEV then cfg.autoEV = {pvTeam=nil, lvTeam=nil, levelTo100=false, autoCleanseFirst=false, targets={}} end
for k, v in pairs(data.autoEV) do cfg.autoEV[k] = v end
end
if data.autoAgeBreaker then
if not cfg.autoAgeBreaker then cfg.autoAgeBreaker = {targets={}, tumbalKgMax=2, tumbalAgeMax=99, skipEnabled=false} end
for k, v in pairs(data.autoAgeBreaker) do cfg.autoAgeBreaker[k] = v end
end
if cfg.autoAgeBreaker and cfg.autoAgeBreaker.skipEnabled == nil then cfg.autoAgeBreaker.skipEnabled = false end
if cfg.autoAgeBreaker and cfg.autoAgeBreaker.maxLevel == nil then cfg.autoAgeBreaker.maxLevel = 125 end
if cfg.autoAgeBreaker and cfg.autoAgeBreaker.autoStart == nil then cfg.autoAgeBreaker.autoStart = false end
if data.autoMutMachine then
if not cfg.autoMutMachine then cfg.autoMutMachine = {targets={}, targetMut="Golden", cdTeam=nil, claimTeam=nil, lvTeam=nil, lvThresh=50} end
for k, v in pairs(data.autoMutMachine) do cfg.autoMutMachine[k] = v end
end
if data.autoCollect then
if type(data.autoCollect.selFruits) == "table" then cfg.autoCollect.selFruits = data.autoCollect.selFruits end
if type(data.autoCollect.selVariants) == "table" then cfg.autoCollect.selVariants = data.autoCollect.selVariants end
if data.autoCollect.interval ~= nil then cfg.autoCollect.interval = data.autoCollect.interval end
if data.autoCollect.sellAfter ~= nil then cfg.autoCollect.sellAfter = data.autoCollect.sellAfter end
if data.autoCollect.stopWhenFull ~= nil then cfg.autoCollect.stopWhenFull = data.autoCollect.stopWhenFull end
if data.autoCollect.maxInv ~= nil then cfg.autoCollect.maxInv = data.autoCollect.maxInv end
end
if data.autoMutation then
for k, v in pairs(data.autoMutation) do
if k ~= "petType" then cfg.autoMutation[k] = v end
end
end
if data.autoGift then for k, v in pairs(data.autoGift) do cfg.autoGift[k] = v end end
if data.autoFeed then for k, v in pairs(data.autoFeed) do cfg.autoFeed[k] = v end end
cfg.autoHatch.brontoEnabled = true
if cfg.elephant.levelTo100 == nil then cfg.elephant.levelTo100 = true end
if cfg.elephant.phase2Enabled == nil then cfg.elephant.phase2Enabled = false end
if cfg.elephant.phase2Threshold == nil then cfg.elephant.phase2Threshold = 50 end
if cfg.elephant.gardenSlots == nil then cfg.elephant.gardenSlots = 1 end
if cfg.elephant.gardenMode == nil then cfg.elephant.gardenMode = "A" end
if cfg.elephant.useExtraPets == nil then cfg.elephant.useExtraPets = false end
if cfg.elephant.extraPets == nil then cfg.elephant.extraPets = {} end
if cfg.elephant.useExtraElePets == nil then cfg.elephant.useExtraElePets = false end
if cfg.elephant.extraElePets == nil then cfg.elephant.extraElePets = {} end
if cfg.toggles.hideNotif == nil then cfg.toggles.hideNotif = false end
if cfg.autoHatch.dontPickPlace == nil then cfg.autoHatch.dontPickPlace = false end
if cfg.autoHatch.autoFeedDelay == nil then cfg.autoHatch.autoFeedDelay = 0 end
if not cfg.autoHatch.specialBronto then cfg.autoHatch.specialBronto = {enabled=true, pets={}} end
if not cfg.petboost.mode1.boostOptions or not next(cfg.petboost.mode1.boostOptions) then
cfg.petboost.mode1.boostOptions = {["Small Toy"] = true}
end
if cfg.leveling.optThreshold == nil then cfg.leveling.optThreshold = 50 end
if cfg.leveling.optEnabled == nil then cfg.leveling.optEnabled = false end
if type(cfg.leveling.targets) ~= "table" then cfg.leveling.targets = {} end
if data.autoHatch and data.autoHatch.specialBronto then
if not cfg.autoHatch.specialBronto then cfg.autoHatch.specialBronto = {enabled=true, pets={}} end
if data.autoHatch.specialBronto.enabled ~= nil then cfg.autoHatch.specialBronto.enabled = data.autoHatch.specialBronto.enabled end
if type(data.autoHatch.specialBronto.pets) == "table" then cfg.autoHatch.specialBronto.pets = data.autoHatch.specialBronto.pets end
end
local defaults = {
eggName="Paradise Egg", eggCount=13, eggSpacing=7, teamCD=nil, teamKoi=nil, teamSeal=nil,
teamBronto=nil, brontoEnabled=true, brontoThresh=4, sellPets={}, sellAll=false, sellEnabled=true, sellThresh=0, favDelay=0.1,
espEnabled=true, running=false, ahUnequipDelay=0.1, ahEquipDelay=0.15, autoSellWhenFull=false,
petInvMax=200, postUnequipBuffer=0.5, koiSafeDelay=1, koiPostHatch=1.5, sealSafeDelay=1, sealPostSell=2,
dontPickPlace=false, autoFeedDelay=0, specialBronto={enabled=true, pets={}},
}
for k, v in pairs(defaults) do
if cfg.autoHatch[k] == nil then cfg.autoHatch[k] = v end
end
end
loadConfig()
if type(cfg.uiW) ~= "number" or cfg.uiW < 560 or cfg.uiW > 1400 then cfg.uiW = 620 end
if type(cfg.uiH) ~= "number" or cfg.uiH < 340 or cfg.uiH > 1000 then cfg.uiH = 400 end
if cfg.uiManual == nil then cfg.uiManual = false end
if cfg.autoHatch.ahEquipDelay then TIMING.AH_EQUIP_DELAY = cfg.autoHatch.ahEquipDelay end
if cfg.autoHatch.ahUnequipDelay then TIMING.AH_UNEQUIP_DELAY = cfg.autoHatch.ahUnequipDelay end
if cfg.autoHatch.postUnequipBuffer then TIMING.AH_POST_UNEQUIP_BUFFER = cfg.autoHatch.postUnequipBuffer end
if cfg.autoHatch.koiSafeDelay then TIMING.AH_KOI_SAFE_DELAY = cfg.autoHatch.koiSafeDelay end
if cfg.autoHatch.koiPostHatch then TIMING.AH_KOI_POST_HATCH = cfg.autoHatch.koiPostHatch end
if cfg.autoHatch.sealSafeDelay then TIMING.AH_SEAL_SAFE_DELAY = cfg.autoHatch.sealSafeDelay end
if cfg.autoHatch.sealPostSell then TIMING.AH_SEAL_POST_SELL = cfg.autoHatch.sealPostSell end
local PET_UUID_KEY = "PET_UUID"
local FAV_KEY = "d"
local function getInventory()
local d = DataService:GetData()
return (d and d.PetsData and d.PetsData.PetInventory.Data) or {}
end
local function getKG(uuid)
for _, container in ipairs({Backpack, Character}) do
for _, tool in ipairs(container:GetChildren()) do
if tool:IsA("Tool") and tool:GetAttribute(PET_UUID_KEY) == uuid then
local kg = tool:GetAttribute("KG")
if kg then return kg end
local m = tool.Name:match("%[(%d+%.?%d*)%s*KG%]")
if m then return tonumber(m) end
end
end
end
local inv = getInventory()
return (inv[uuid] and (inv[uuid].PetData.BaseWeight or 0)) or 0
end
local function getAge(uuid)
local inv = getInventory()
return (inv[uuid] and (inv[uuid].PetData.Level or 0)) or 0
end
local function getBase(uuid)
local inv = getInventory()
return (inv[uuid] and (inv[uuid].PetData.BaseWeight or 0)) or 0
end
local function getPType(uuid)
local inv = getInventory()
return (inv[uuid] and (inv[uuid].PetType or "Unknown") or "Unknown")
end
local function isFav(uuid)
for _, container in ipairs({Backpack, Character}) do
for _, tool in ipairs(container:GetChildren()) do
if tool:IsA("Tool") and tool:GetAttribute(PET_UUID_KEY) == uuid then
return tool:GetAttribute(FAV_KEY) == true
end
end
end
return false
end
local function findPetTool(uuid)
for _, container in ipairs({Backpack, Character}) do
for _, tool in ipairs(container:GetChildren()) do
if tool:IsA("Tool") and tool:GetAttribute(PET_UUID_KEY) == uuid then
return tool
end
end
end
return nil
end
local function getHumanoid()
return Character and Character:FindFirstChildOfClass("Humanoid")
end
local PetJSON = prefetchAwait("pets") or {}
if type(PetJSON) ~= "table" or next(PetJSON) == nil then
pcall(function() PetJSON = Http:JSONDecode(game:HttpGet(PETS_URL)) end)
end
if type(PetJSON) ~= "table" then PetJSON = {} end
local AssetIDs = {}
task.spawn(function()
local ok, data = pcall(function()
return Http:JSONDecode(game:HttpGet("https://raw.githubusercontent.com/Punpunzero02/updater/refs/heads/main/PetAssetId.json"))
end)
if ok and data then AssetIDs = data end
end)
local MutJSON = prefetchAwait("mutation") or {}
if type(MutJSON) ~= "table" or next(MutJSON) == nil then
pcall(function() MutJSON = Http:JSONDecode(game:HttpGet(MUT_URL)) end)
end
if type(MutJSON) ~= "table" then MutJSON = {} end
local function getMutName(uuid)
local inv = getInventory()
local pet = inv[uuid]
if not pet or not pet.PetData then return "" end
local mut = pet.PetData.MutationType or ""
if mut == "" or mut == "m" then return "" end
return MutJSON[mut] or mut
end
local function getAssetThumbnail(assetId)
if not assetId then return nil end
local id = tostring(assetId):match("%d+")
if not id then return nil end
local ok, res = pcall(function()
return Http:JSONDecode(game:HttpGet("https://thumbnails.roblox.com/v1/assets?assetIds=" .. id .. "&size=150x150&format=Png&isCircular=false"))
end)
if ok and res and res.data and res.data[1] and res.data[1].imageUrl then
return res.data[1].imageUrl
end
return nil
end
local function sendWebhook(embeds)
local url = cfg.webhook.url
if not url or url == "" then return end
if not string.match(url, "^https://discord") and not string.match(url, "^https://ptb.discord") and not string.match(url, "^https://canary.discord") then return end
task.spawn(function()
local ok, err = pcall(function()
local hasSpecial = embeds and embeds[1] and embeds[1].title and embeds[1].title:find("Special Pet")
local body = Http:JSONEncode({
username = LocalPlayer.Name,
avatar_url = "https://raw.githubusercontent.com/wardz25/library-ui/main/VeliumHub.png",
content = (hasSpecial and "@everyone") or nil,
embeds = embeds,
})
local req = (syn and syn.request) or (http and http.request) or request
if req then
req({Url = url, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = body})
else
Http:PostAsync(url, body, Enum.HttpContentType.ApplicationJson, false)
end
end)
if not ok then warn("[Velium Hub Webhook] ", err) end
end)
end
-- HATCH TRACKING (ported from HACT: egg snapshot delta + lucky-back counters)
local HatchTrack = {
startTime = os.clock(),
cycleCount = 0,
totalHatched = 0,
totalSold = 0,
lastCycleTime = os.clock(),
eggBefore = nil,
lastEggDelta = 0,
lastEggBefore = 0,
lastEggAfter = 0,
luckyHatch = 0,
luckySell = 0,
specialTotal = 0,
godly = 0,
titan = 0,
huge = 0,
species = {},
}
local function totalEggNow()
local n = 0
for _, holder in ipairs({Backpack, Character}) do
if holder then
for _, tool in ipairs(holder:GetChildren()) do
if tool:IsA("Tool") and (CS:HasTag(tool, "PetEggTool") or tool.Name:lower():find("egg")) then
n = n + (tonumber(tool.Name:match("x(%d+)$")) or 1)
end
end
end
end
return n
end
local BuySys = {}
BuySys.remotes = {seed = "BuySeedStock", egg = "BuyPetEgg", gear = "BuyGearStock"}
BuySys.getBuyItemList = function(dataKey)
local out, seen = {}, {}
pcall(function()
local dataF = RS:FindFirstChild("Data")
local mod = dataF and dataF:FindFirstChild(dataKey)
if not mod then return end
local ok, tbl = pcall(require, mod)
if ok and type(tbl) == "table" then
for k, v in pairs(tbl) do
local nm = nil
if type(k) == "string" and #k >= 2 and not k:match("^_") then
nm = k
elseif type(v) == "table" then
nm = v.Name or v.SeedName or v.ItemName or v.DisplayName
end
if nm and type(nm) == "string" and not seen[nm] then
seen[nm] = true
table.insert(out, nm)
end
end
end
end)
table.sort(out)
return out
end
BuySys.fireBuyKind = function(kind)
local st = cfg.autoBuy and cfg.autoBuy[kind]
if not st or not st.on then return end
if not next(st.items or {}) then return end
local ge = RS:FindFirstChild("GameEvents")
local re = ge and BuySys.remotes[kind] and ge:FindFirstChild(BuySys.remotes[kind])
if not re then return end
for itemName in pairs(st.items) do
pcall(function() re:FireServer(itemName) end)
task.wait(0.1)
end
end
for _, kind in ipairs({"seed", "egg", "gear"}) do
task.spawn(function()
while true do
task.wait(1)
pcall(function() BuySys.fireBuyKind(kind) end)
end
end)
end
local progressHistory = {}
local function sendCycleWebhook(petName, fromKG, toKG, targetKG, cycleTime, phase, queuePos, queueTotal, petId)
if cfg.webhook.sendCycle == false then return end
local pct = math.min((toKG / targetKG) * 100, 100)
local bar = string.rep("#", math.floor(pct / 10)) .. string.rep("-", 10 - math.floor(pct / 10))
if petId then
if not progressHistory[petId] then progressHistory[petId] = {times={}, gains={}} end
local h = progressHistory[petId]
table.insert(h.times, cycleTime)
table.insert(h.gains, toKG - fromKG)
if #h.times > 5 then table.remove(h.times, 1) end
if #h.gains > 5 then table.remove(h.gains, 1) end
end
local avgTime, avgGain = cycleTime, toKG - fromKG
if petId and progressHistory[petId] then
local h = progressHistory[petId]
local st, sg = 0, 0
for _, t in ipairs(h.times) do st = st + t end
for _, g in ipairs(h.gains) do sg = sg + g end
avgTime = st / #h.times
avgGain = sg / #h.gains
end
local remaining = math.max(targetKG - toKG, 0)
local cyclesLeft = (avgGain > 0) and math.ceil(remaining / avgGain) or 0
local eta = cyclesLeft * avgTime
local estDone = (cyclesLeft > 0) and string.format("~%d cycles (~%s)", cyclesLeft, Library.fmtTime(eta)) or "Almost done!"
local function fmt3(n) local s = string.format("%.3f", n); return s:gsub("%.?0+$", "") end
sendWebhook({{title = "Cycle Complete", color = 5793266,
description = string.format("%s | Queue `%d/%d`\n\n`%s` %.1f%%", petName, queuePos or 0, queueTotal or 0, bar, pct),
fields = {
{name = "Weight", value = string.format("%s -> %s kg", fmt3(fromKG), fmt3(toKG)), inline = true},
{name = "Target", value = string.format("%s kg", fmt3(targetKG)), inline = true},
{name = "Phase", value = phase or "?", inline = true},
{name = "Cycle", value = Library.fmtTime(cycleTime), inline = true},
{name = "Gain", value = string.format("+%s kg", fmt3(toKG - fromKG)), inline = true},
{name = "Est. Done", value = estDone, inline = true},
},
footer = {text = "Velium Hub " .. os.date("%d/%m/%Y %H:%M:%S")},
thumbnail = {url = "https://raw.githubusercontent.com/wardz25/library-ui/main/VeliumHub.png"},
}})
end
local function sendPetFinishedWebhook(petName, finalKG, totalTime, p2Time, doneCount, totalPets)
if cfg.webhook.sendFinished == false then return end
local starCount = math.min(math.floor(finalKG / 1), 5)
local stars = string.rep("*", starCount) .. string.rep(".", 5 - starCount)
sendWebhook({{title = "Pet Finished!", color = 5763719,
description = string.format("%s has reached Level 100!\n%s", petName, stars),
fields = {
{name = "Final Base", value = string.format("%.3f kg", finalKG), inline = true},
{name = "Queue", value = string.format("%d / %d done", doneCount or 0, totalPets or 0), inline = true},
{name = "Total Time", value = Library.fmtTime(totalTime), inline = false},
{name = "Phase 2 Time", value = Library.fmtTime(p2Time), inline = true},
{name = "Phase 1 Time", value = Library.fmtTime(totalTime - p2Time), inline = true},
},
footer = {text = "Velium Hub " .. os.date("%d/%m/%Y %H:%M:%S")},
thumbnail = {url = "https://raw.githubusercontent.com/wardz25/library-ui/main/VeliumHub.png"},
}})
end
local function sendTestWebhook()
sendWebhook({{title = "Velium Hub Connection Test", color = 5793266,
description = "Webhook Connected!",
fields = {
{name = "Status", value = "Online", inline = true},
{name = "Time", value = os.date("%H:%M:%S"), inline = true},
{name = "Player", value = LocalPlayer.Name, inline = true},
},
footer = {text = "Velium Hub v1"},
}})
end
local function getSpecialTier(brontoKG)
if brontoKG >= 9 then return "godly" end
if brontoKG >= 7 then return "titan" end
if brontoKG >= 5 then return "huge" end
return nil
end
local function sendSpecialWebhook(petName, kg, brontoKG, age, eggName)

local url = cfg.webhook.url
if not url or url == "" then return end
if cfg.webhook.sendSpecial == false then return end
local tier = ""
if brontoKG >= 9 then tier = "Godly"
elseif brontoKG >= 7 then tier = "Titan"
elseif brontoKG >= 5 then tier = "Huge"
end
local assetId = AssetIDs[petName]
if not assetId then
local ok2, data2 = pcall(function()
return Http:JSONDecode(game:HttpGet("https://raw.githubusercontent.com/Punpunzero02/updater/refs/heads/main/PetAssetId.json"))
end)
if ok2 and data2 then assetId = data2[petName] end
end
local thumb = getAssetThumbnail(assetId) or "https://raw.githubusercontent.com/wardz25/library-ui/main/VeliumHub.png"
local color = 5793266
if tier == "Godly" then color = 16766720
elseif tier == "Titan" then color = 12632256
elseif tier == "Huge" then color = 5763719
end
sendWebhook({{title = "🐾 Special Pet Found — " .. petName, color = color,
fields = {
{name = "🐾 Pet Info", value = petName .. "\nWeight: " .. string.format("%.2f KG", kg) .. "\nBronto: " .. string.format("%.2f KG", brontoKG) .. "\nAge: Age " .. tostring(age or 0), inline = false},
{name = "🥚 Egg Info", value = "Egg: " .. (eggName or "?") .. "\nTier: " .. ((tier ~= "") and tier or "Normal"), inline = false},
{name = "🔀 Info", value = "Player: ||" .. LocalPlayer.Name .. "||" .. "\nTime: " .. os.date("%d/%m/%Y %H:%M:%S"), inline = false},
},
thumbnail = {url = thumb},
footer = {text = "Velium Hub  •  " .. os.date("%d/%m/%Y %H:%M:%S")},
}})
end
local function fmtDur(s)
s = math.max(0, math.floor(s or 0))
local h = math.floor(s / 3600)
local m = math.floor((s % 3600) / 60)
local sec = s % 60
if h > 0 then return string.format("%dh %dm %ds", h, m, sec)
elseif m > 0 then return string.format("%dm %ds", m, sec)
else return string.format("%ds", sec) end
end
local function sendHatchWebhook(eggName, hatchedList, teamLines)
if cfg.webhook.sendHatch == false then return end
local count = (hatchedList and #hatchedList) or 0
if count == 0 then return end
local now = os.clock()
local cycleDur = now - HatchTrack.lastCycleTime
local allDur = now - HatchTrack.startTime
teamLines = teamLines or {Core = "-", Hatch = "-", Special = "-", Sell = "-"}
local koiPct = HatchTrack.totalHatched > 0 and (HatchTrack.luckyHatch / HatchTrack.totalHatched * 100) or 0
local sealPct = HatchTrack.totalSold > 0 and (HatchTrack.luckySell / HatchTrack.totalSold * 100) or 0
local totalBack = HatchTrack.luckyHatch + HatchTrack.luckySell
local delta = HatchTrack.lastEggDelta
local dsign = delta >= 0 and "+" or ""
local spec = {}
for name, st in pairs(HatchTrack.species or {}) do
table.insert(spec, {name = name, n = st.n or 0, mn = st.minKg or 0, mx = st.maxKg or 0})
end
table.sort(spec, function(a, b) return a.n > b.n end)
local specLines = {}
for i, s in ipairs(spec) do
if i > 15 then break end
table.insert(specLines, string.format("• %s x%d (%.2f-%.2fkg)", s.name, s.n, s.mn, s.mx))
end
if #spec > 15 then table.insert(specLines, string.format("+%d more species...", #spec - 15)) end
if #specLines == 0 then table.insert(specLines, "-") end
local desc = table.concat({
"👤 Profile",
"**Username:** ||" .. LocalPlayer.Name .. "||",
"**🐾 Teams**",
"**Core:** " .. (teamLines.Core or "-"),
"**Hatch:** " .. (teamLines.Hatch or "-"),
"Special: " .. (teamLines.Special or "-"),
"**Sell:** " .. (teamLines.Sell or "-"),
"**⚜️ Special Statistics**",
"**⭐ Special: " .. tostring(HatchTrack.specialTotal or 0) .. "**",
"Godly x" .. tostring(HatchTrack.godly or 0),
"Titan x" .. tostring(HatchTrack.titan or 0),
"Huge x" .. tostring(HatchTrack.huge or 0),
"**💎 Overall Statistics**",
table.concat(specLines, "\n"),
"**🥚 Egg Statistics**",
"🥚 Egg Before: " .. tostring(HatchTrack.lastEggBefore),
"📦 Current Egg: " .. tostring(HatchTrack.lastEggAfter),
"📊 Net Result: " .. dsign .. tostring(delta),
"",
"🍀 Koi Cashback: " .. tostring(HatchTrack.luckyHatch) .. string.format(" (%.2f%%)", koiPct),
"🤝 Seal Cashback: " .. tostring(HatchTrack.luckySell) .. string.format(" (%.2f%%)", sealPct),
"✨ Total Cashback: " .. tostring(totalBack),
"**📈 Hatch Statistics**",
"**🔄 Hatch Cycles: " .. tostring(HatchTrack.cycleCount) .. "**",
"**🐾 Total Hatched: " .. tostring(HatchTrack.totalHatched) .. "**",
"**🪺 Overall Pet Sell: " .. tostring(HatchTrack.totalSold) .. "**",
"",
"⏱️ Cycle Duration: " .. fmtDur(cycleDur),
"🕐 All Time Duration: " .. fmtDur(allDur),
}, "\n")
sendWebhook({{title = "🥚 Hatch Cycle #" .. tostring(HatchTrack.cycleCount), color = 5793266,
description = desc,
footer = {text = "Velium Hub  •  " .. os.date("%d/%m/%Y %H:%M:%S")},
thumbnail = {url = "https://raw.githubusercontent.com/wardz25/library-ui/main/VeliumHub.png"},
}})
HatchTrack.lastCycleTime = now
end
local SESSION_FILE = "VeliumHub_Session.json"
local session = {
startTime = 0, cycleCount = 0, totalHatched = 0,
eggBefore = 0, eggCurrent = 0,
koiProc = 0, sealProc = 0, koiLastCycle = 0, sealLastCycle = 0,
petTypes = {},
specials = {huge={count=0, pets={}}, titan={count=0, pets={}}, godly={count=0, pets={}}},
}
local function saveSession()
if not writefile then return end
pcall(function() writefile(SESSION_FILE, Http:JSONEncode({
AH = {startTime=session.startTime, cycleCount=session.cycleCount, totalHatched=session.totalHatched,
eggBefore=session.eggBefore, eggCurrent=session.eggCurrent, koiProc=session.koiProc,
sealProc=session.sealProc, koiLastCycle=session.koiLastCycle, sealLastCycle=session.sealLastCycle,
petTypes=session.petTypes, specials=session.specials},
KG = {startTime=0, doneCount=0, totalPets=0},
})) end)
end
local function loadSession()
if not readfile or not isfile or not isfile(SESSION_FILE) then return nil end
local ok, data = pcall(function() return Http:JSONDecode(readfile(SESSION_FILE)) end)
if not ok or not data then return nil end
return data
end
local function deleteSession()
if not isfile or not isfile(SESSION_FILE) then return end
pcall(function() if delfile then delfile(SESSION_FILE) end end)
end
local equipState = {IsEquipping = false, PP_Processing = {}, GlobalBoostApplying = false}
local _activePetsRep = nil
-- Pre-warm the replicator at startup so it's ready on first use
task.spawn(function()
	local ok, r = pcall(function()
		local re = require(RS.Modules.ReplicationClass).new("ActivePetsService_Replicator")
		re:YieldUntilData()
		return re
	end)
	if ok and r then _activePetsRep = r end
end)
local function getActivePets()
local rep = _activePetsRep
if not rep then
local ok, r = pcall(function()
local re = require(RS.Modules.ReplicationClass).new("ActivePetsService_Replicator")
re:YieldUntilData()
return re
end)
if ok then rep = r; _activePetsRep = r end
end
if rep then
local ok, data = pcall(function() return rep:GetData().Table end)
if ok and data then
local states = data.ActivePetStates
local myPets = states[LocalPlayer.Name] or states[tonumber(LocalPlayer.Name)] or {}
local list = {}
for uuid in pairs(myPets) do table.insert(list, uuid) end
if #list > 0 then return list end
end
end
local fallback = {}
local pp = workspace:FindFirstChild("PetsPhysical")
if pp then
local char = LocalPlayer.Character
local charPart = char and char:FindFirstChild("HumanoidRootPart")
for _, pet in ipairs(pp:GetChildren()) do
local owner = pet:GetAttribute("OWNER")
if owner == LocalPlayer.Name then
local uuid = pet:GetAttribute("UUID")
if uuid then table.insert(fallback, uuid) end
end
end
end
return fallback
end
local function unequipAll()
equipState.IsEquipping = true
for _, uuid in ipairs(getActivePets()) do
pcall(function() PetsRemote:FireServer("UnequipPet", uuid) end)
task.wait(TIMING.UNEQUIP_DELAY)
end
task.wait(TIMING.UNEQUIP_BUFFER)
equipState.IsEquipping = false
end
local function getFarmCF()
local farm = workspace:FindFirstChild("Farm")
if farm then
local myPlot = farm:FindFirstChild(LocalPlayer.Name)
if myPlot then
local important = myPlot:FindFirstChild("Important")
if important then
local plantLoc = important:FindFirstChild("Plant_Locations")
if plantLoc then
local children = plantLoc:GetChildren()
if #children > 0 then return children[1]:GetPivot() end
end
end
end
end
end
local function equipList(list)
equipState.IsEquipping = true
local cf = getFarmCF()
for _, uuid in ipairs(list) do
pcall(function() PetsRemote:FireServer("EquipPet", uuid, cf) end)
task.wait(TIMING.EQUIP_DELAY)
end
equipState.IsEquipping = false
end
local function waitUntilEquipped(targetCount, timeout)
timeout = timeout or 8
local t = os.clock()
while os.clock() - t < timeout do
if #getActivePets() >= targetCount then return true end
task.wait(0.2)
end
return false
end
local function buildEquip(target, team)
local list = {target}
for _, uuid in ipairs(team or {}) do
if #list >= 8 then break end
local found = false
for _, e in ipairs(list) do if e == uuid then found = true; break end end
if not found then table.insert(list, uuid) end
end
return list
end
local currentTarget = nil
local currentTeam = {}
local isKGRunning = false
local teamWatcherRunning = false
local desiredPets = {}
local function startTeamWatcher()
teamWatcherRunning = true
task.spawn(function()
while teamWatcherRunning do
task.wait(TIMING.POLL_RATE)
if equipState.IsEquipping or not isKGRunning then continue end
if not next(desiredPets) then continue end
local active = getActivePets()
local toAdd, toRemove = {}, {}
for uuid in pairs(desiredPets) do
local found = false
for _, a in ipairs(active) do
if a == uuid then found = true; break end
end
if not found then table.insert(toAdd, uuid) end
end
for _, a in ipairs(active) do
if not desiredPets[a] then table.insert(toRemove, a) end
end
if #toRemove > 0 or #toAdd > 0 then
equipState.IsEquipping = true
for _, uuid in ipairs(toRemove) do
pcall(function() PetsRemote:FireServer("UnequipPet", uuid) end)
task.wait(TIMING.UNEQUIP_DELAY)
end
local cf = getFarmCF()
for _, uuid in ipairs(toAdd) do
pcall(function() PetsRemote:FireServer("EquipPet", uuid, cf) end)
task.wait(TIMING.EQUIP_DELAY)
end
equipState.IsEquipping = false
end
end
end)
end
local function stopTeamWatcher()
teamWatcherRunning = false
table.clear(desiredPets)
end
local function setDesiredPets(equipList2, teamList)
table.clear(desiredPets)
for _, uuid in ipairs(equipList2) do desiredPets[uuid] = true end
for _, uuid in ipairs(teamList) do desiredPets[uuid] = true end
end
local builtInTeams = {
 {name="7 Mimic + 1 Bald Eagle", desc="Max passive Mimic\n1 Eagle filler",
 slots={{petType="Mimic Octopus",count=7},{petType="Bald Eagle",count=1}}},
 {name="Koi Max Passive", desc="Max hatch rate bonus\nHighest KG + mutation",
 slots={{petType="Koi",count=8}}},
 {name="Seal Max Passive", desc="Max sell return chance\nAlways 8 Seals",
 slots={{petType="Seal",count=8}}},
 {name="Bronto Max Passive", desc="Max hatch size bonus (~30%)\nRest filled with Koi",
 slots={{petType="Brontosaurus",count=8},{petType="Koi",count=8}}},
 {name="Magpie Method", desc="1 Mimic, 3 Magpie\n1 Cockatrice\n3 filler priority",
 slots={{petType="Mimic Octopus",count=1},{petType="Magpie",count=3},{petType="Cockatrice",count=1}},
 priorityFiller={"Giant Ant", "Red Giant Ant", "Silver Monkey", "Cape Buffalo"}, fillerCount=3},
}
local function getTeamUUIDs(teamName)
if not teamName then return {} end
for _, team in ipairs(builtInTeams) do
if team.name == teamName then
local inv = (function() local d = DataService:GetData()
return (d and d.PetsData and d.PetsData.PetInventory.Data) or {} end)()
local byType = {}
for uuid, pet in pairs(inv) do
local pt = pet.PetType or ""
if not byType[pt] then byType[pt] = {} end
table.insert(byType[pt], uuid)
end
local mutBonus = {a=0,b=0.1,c=0.2,d=0.3,g=0.5,s=0.05,z=0.08,A=0.22,J=0.01,K=0.03,L=0.045,M=0.06,N=0.07,O=0.07,P=0.3,V=0.2,X=0.3,Y=0.3,Z=0.3,["@"]=0.23,EV=0.3,RJ=0.25}
local function effKG(uuid)
local p = inv[uuid]
if not p or not p.PetData then return 0 end
local bw = p.PetData.BaseWeight or 0
local mt = p.PetData.MutationType or "m"
return bw * (1 + (mutBonus[mt] or 0))
end
local function brontoEffKG(uuid)
local p = inv[uuid]
if not p or not p.PetData then return 0 end
local bw = p.PetData.BaseWeight or 0
local mt = p.PetData.MutationType or "m"
return (5.35 + (bw * 0.1)) * (1 + (mutBonus[mt] or 0))
end
for _, list in pairs(byType) do table.sort(list, function(a,b) return effKG(a) > effKG(b) end) end
if team.name == "Magpie Method" then
local result = {}
for _, slot in ipairs(team.slots) do
local pts = byType[slot.petType] or {}
local count = 0
for _, uuid in ipairs(pts) do
if #result >= 8 then break end
if count >= slot.count then break end
table.insert(result, uuid); count = count + 1
end
end
local fillerCount = 0
local maxFiller = team.fillerCount or 3
local fillerPool = {}
for _, ft in ipairs(team.priorityFiller or {}) do
for _, uuid in ipairs(byType[ft] or {}) do
local already = false
for _, r in ipairs(result) do if r == uuid then already = true; break end end
if not already then table.insert(fillerPool, uuid) end
end
end
table.sort(fillerPool, function(a,b) return effKG(a) > effKG(b) end)
for _, uuid in ipairs(fillerPool) do
if #result >= 8 then break end
if fillerCount >= maxFiller then break end
table.insert(result, uuid); fillerCount = fillerCount + 1
end
return result
end
if team.name == "Bronto Max Passive" then
local result = {}
local totalBronto = 0
local brontos = byType["Brontosaurus"] or {}
table.sort(brontos, function(a,b) return brontoEffKG(a) > brontoEffKG(b) end)
for _, uuid in ipairs(brontos) do
if #result >= 8 then break end
if totalBronto >= 30 then break end
table.insert(result, uuid); totalBronto = totalBronto + brontoEffKG(uuid)
end
local koi = byType["Koi"] or {}
for _, uuid in ipairs(koi) do
if #result >= 8 then break end
table.insert(result, uuid)
end
return result
end
local result = {}
for _, slot in ipairs(team.slots) do
local pts = byType[slot.petType] or {}
local count = 0
for _, uuid in ipairs(pts) do
if #result >= 8 then break end
if count >= slot.count then break end
table.insert(result, uuid); count = count + 1
end
end
if #result < 8 then
for _, slot in ipairs(team.slots) do
local pts = byType[slot.petType] or {}
for _, uuid in ipairs(pts) do
if #result >= 8 then break end
local already = false
for _, r in ipairs(result) do if r == uuid then already = true; break end end
if not already then table.insert(result, uuid) end
end
end
end
return result
end
end
return (cfg.petTeams[teamName] and cfg.petTeams[teamName].uuids) or {}
end
local function buildTeamDD(parent, onSelect, current, UI2, cfg2, T2)
for _, c in ipairs(parent:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
local teamNames = {}
if _G._NH_BUILTIN_TEAMS then
for _, t in ipairs(_G._NH_BUILTIN_TEAMS) do table.insert(teamNames, t.name) end
end
for name in pairs(cfg2.petTeams) do table.insert(teamNames, name) end
table.sort(teamNames)
if #teamNames == 0 then
local lbl = UI2:label(parent, "(save a team first)", UDim2.new(1,0,0,22), nil, T2.DIM, 9)
lbl.LayoutOrder = 1
return 1
end
for i, name in ipairs(teamNames) do
local isSelected = current == name
local isBuiltin = false
if _G._NH_BUILTIN_TEAMS then
for _, bt in ipairs(_G._NH_BUILTIN_TEAMS) do
if bt.name == name then isBuiltin = true; break end
end
end
local bg = (isBuiltin and Color3.fromRGB(24, 66, 60)) or Color3.fromRGB(22, 22, 22)
local txt = (isBuiltin and Color3.fromRGB(128, 255, 234)) or T2.TEXT
local stroke = (isBuiltin and Color3.fromRGB(24, 66, 60)) or T2.STROKE
if isSelected then
bg = (isBuiltin and Color3.fromRGB(128, 255, 234)) or T2.SEL_BG
txt = (isBuiltin and Color3.fromRGB(16, 42, 38)) or T2.SEL_TXT
stroke = (isBuiltin and Color3.fromRGB(52, 160, 150)) or T2.ACCENT
end
local btn = UI2:button(parent, name, UDim2.new(1,0,0,22), nil, bg, txt, 9)
btn.LayoutOrder = i; btn.TextXAlignment = Enum.TextXAlignment.Left
UI2:pad(btn, 0, 8, 0, 0); UI2:stroke(btn, stroke, 1)
if isBuiltin then
local icon = Instance.new("ImageLabel", btn)
icon.Size = UDim2.new(0,16,0,16); icon.Position = UDim2.new(1,-20,0.5,-8)
icon.BackgroundTransparency = 1
icon.Image = "rbxassetid://118973578063038"
icon.ScaleType = Enum.ScaleType.Fit; icon.ZIndex = btn.ZIndex + 1
end
btn.MouseButton1Click:Connect(function() onSelect(name) end)
end
return #teamNames
end
local function getExtraPets(excluded, maxCount)
local inv = getInventory()
local candidates = {}
for uuid in pairs(cfg.elephant.extraPets) do
if not excluded[uuid] and inv[uuid] then table.insert(candidates, uuid) end
end
table.sort(candidates, function(a,b) return getKG(a) > getKG(b) end)
local result = {}
for i = 1, math.min(maxCount, #candidates) do table.insert(result, candidates[i]) end
return result
end
local function getExtraElePets(excluded, maxCount)
local inv = getInventory()
local candidates = {}
for uuid in pairs(cfg.elephant.extraElePets) do
if not excluded[uuid] and inv[uuid] then table.insert(candidates, uuid) end
end
table.sort(candidates, function(a,b) return getKG(a) > getKG(b) end)
local result = {}
for i = 1, math.min(maxCount, #candidates) do table.insert(result, candidates[i]) end
return result
end
local function getMyFarm()
local farm = workspace:FindFirstChild("Farm")
if not farm then return nil end
local myPlot = farm:FindFirstChild(LocalPlayer.Name)
if not myPlot then return nil end
return myPlot
end
local function getEggPositions()
local plot = getMyFarm()
if not plot then return {} end
local important = plot:FindFirstChild("Important")
if not important then return {} end
local plantLoc = important:FindFirstChild("Plant_Locations")
if not plantLoc then return {} end
local children = plantLoc:GetChildren()
if #children == 0 then return {} end
local base = children[1].Position
local positions = {}
for i = -2, 2 do
table.insert(positions, Vector3.new(base.X + (i * 4), base.Y, base.Z - 15))
end
for i = -1, 1 do
table.insert(positions, Vector3.new(base.X + (i * 4), base.Y, base.Z - 19))
end
return positions
end
local function countPlacedEggs()
local plot = getMyFarm()
if not plot then return 0, {} end
local important = plot:FindFirstChild("Important")
if not important then return 0, {} end
local objects = important:FindFirstChild("Objects_Physical")
if not objects then return 0, {} end
local count = 0
local placedPositions = {}
for _, obj in ipairs(objects:GetChildren()) do
if obj.Name == "PetEgg" then
count = count + 1
local eggPart = obj:FindFirstChild("PetEgg")
if eggPart then
table.insert(placedPositions, eggPart.Position)
end
end
end
return count, placedPositions
end
local function getEggToolByName(eggName)
for _, tool in ipairs(Backpack:GetChildren()) do
if tool:IsA("Tool") and CS:HasTag(tool, "PetEggTool") then
if tool:GetAttribute("h") == eggName then
return tool
end
end
end
return nil
end
local PetBoostRegistry = nil
do
local ok, reg = pcall(function()
local folder = RS:FindFirstChild("Data") or RS:WaitForChild("Data", 2)
if not folder then return nil end
local reg2 = folder:FindFirstChild("PetBoostRegistry") or folder:WaitForChild("PetBoostRegistry", 2)
if not reg2 then return nil end
return require(reg2)
end)
if ok and reg then PetBoostRegistry = reg end
end
local function hasBoostApplied(uuid, statName, petModelName)
if not PetBoostRegistry then return false end
local ok, data = pcall(function() return DataService:GetData() end)
if not ok or not data then return false end
local petData = data.PetsData and data.PetsData.PetInventory and data.PetsData.PetInventory.Data
if not petData or not petData[uuid] then return false end
local boosts = petData[uuid].PetData and petData[uuid].PetData.Boosts
if not boosts or not next(boosts) then return false end
local applied = {}
for _, boost in pairs(boosts) do
local bType = boost.BoostType or boost.Type
local bAmount = boost.BoostAmount or boost.Amount
local statData = PetBoostRegistry.BoostTypeStatData and PetBoostRegistry.BoostTypeStatData[bType]
if statData and statData.Amount then
local modelName = PetBoostRegistry.BoostTypeToPetModelName[bType]
for stat, amount in pairs(statData.Amount) do
if amount == bAmount then applied[stat .. " " .. modelName] = true end
end
end
end
return applied[statName .. " " .. petModelName] == true
end
local function findBoostTool(statName, petModelName)
for _, tool in ipairs(Backpack:GetChildren()) do
if tool:IsA("Tool") and CS:HasTag(tool, "PetBoost") and string.find(tool.Name, statName) and string.find(tool.Name, petModelName) then
return tool
end
end
return nil
end
local function applyBoost(uuid, statName, petModelName)
if equipState.GlobalBoostApplying then return false end
if hasBoostApplied(uuid, statName, petModelName) then return false end
local tool = findBoostTool(statName, petModelName)
if not tool then return false end
equipState.GlobalBoostApplying = true
for _, t in ipairs(Character:GetChildren()) do
if t:IsA("Tool") then t.Parent = Backpack end
end
task.wait(0.05)
pcall(function() tool.Parent = Character end)
task.wait(0.1)
pcall(function() BoostRemote:FireServer("ApplyBoost", "{" .. tostring(uuid):gsub("[{}]", "") .. "}") end)
task.wait(0.1)
if not hasBoostApplied(uuid, statName, petModelName) then
pcall(function() BoostRemote:FireServer("ApplyBoost", uuid) end)
task.wait(0.1)
end
pcall(function()
local t = Character:FindFirstChildWhichIsA("Tool")
if t and CS:HasTag(t, "PetBoost") then t.Parent = Backpack end
end)
task.wait(0.5)
local result = hasBoostApplied(uuid, statName, petModelName)
equipState.GlobalBoostApplying = false
return result
end
-- ======================== FEED PETS LOGIC ========================
local function feedPets()
if not cfg.toggles.autoFeed then return end
local hungerThreshold = cfg.autoFeed.hungerThreshold or 50
local hum = getHumanoid()
if not hum then return end
local ok, data = pcall(function() return DataService:GetData() end)
if not ok or not data then return end
local inv = data.PetsData and data.PetsData.PetInventory
if not inv then return end
local hungerData = data.HungerDataTable or {}
for _, tool in ipairs(Backpack:GetChildren()) do
if tool:IsA("Tool") and (tool:FindFirstChild("PetToolLocal") or tool:FindFirstChild("PetToolServer")) then
local uuid = tool:GetAttribute("PET_UUID")
if uuid then
for _, tData in pairs(inv) do
if type(tData) == "table" then
for _, pet in pairs(tData) do
if type(pet) == "table" and pet.UUID == uuid then
local hunger = pet.PetData and pet.PetData.Hunger or 0
local petType = pet.PetType or "Unknown"
local maxHunger = hungerData[petType] or 10000
local hungerPercent = 100 * (hunger / maxHunger)
if hungerPercent <= hungerThreshold then
for _, cropTool in ipairs(Backpack:GetChildren()) do
if cropTool:IsA("Tool") then
local itemType = cropTool:GetAttribute("b")
if itemType == "j" or itemType == "u" then
pcall(function() hum:EquipTool(cropTool) end)
task.wait(0.5)
pcall(function() ActivePetService:FireServer("Feed", uuid) end)
task.wait(1)
break
end
end
end
end
end
end
end
end
end
end
end
end
task.spawn(function()
while true do
task.wait(30)
if cfg.toggles.autoFeed then
pcall(feedPets)
end
end
end)
pcall(function() CoreGui:FindFirstChild("VeliumHubUI"):Destroy() end)
local viewport = workspace.CurrentCamera.ViewportSize
local isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled
-- Velium: adapt the WINDOW SIZE to the user's screen (wide layout) instead of
-- scaling the whole UI with a UIScale (which looked zoomed / cramped).
local function computeAutoSize(vp)
if not vp or vp.X <= 0 or vp.Y <= 0 then return 620, 400 end
if isMobile then
return math.clamp(math.floor(vp.X * 0.92), 360, 900), math.clamp(math.floor(vp.Y * 0.74), 300, 760)
end
return math.clamp(math.floor(vp.X * 0.47), 600, 900), math.clamp(math.floor(vp.Y * 0.50), 380, 640)
end
local autoW, autoH = computeAutoSize(viewport)
local savedOK = type(cfg.uiW) == "number" and type(cfg.uiH) == "number" and cfg.uiW >= 560 and cfg.uiH >= 340
local guiW, guiH
if cfg.uiManual and savedOK then
guiW, guiH = cfg.uiW, cfg.uiH
else
guiW, guiH = autoW, autoH
end
local guiScale = 1
if isMobile then
guiScale = math.clamp((viewport.X / 420) * 0.72, 0.65, 1.4)
end
local speedSrc = prefetchAwait("speedui")
if type(speedSrc) ~= "string" then
speedSrc = game:HttpGet(UI_URL)
end
local SpeedLib = loadstring(speedSrc)()
local speedTabs = SpeedLib:CreateWindow({"Velium Hub", "| Grow A Garden", 200, UDim2.fromOffset(guiW, guiH)})
local ScreenGui = speedTabs._Gui
local mainFrame = speedTabs._Main
local confirmOv
local modalRoot = UI:frame(ScreenGui, UDim2.new(1,0,1,0), UDim2.new(0,0,0,0), T.BG, 1)
modalRoot.Name = "VeliumModal"
modalRoot.ZIndex = 200
local TAB_ICONS = {
	HATCH = "🥚",
	AUTOMATION = "🤖",
	TEAMS = "🐾",
	WEBHOOK = "📡",
	MISC = "⚙️",
}
local tabHatch = speedTabs:CreateTab({"HATCH", TAB_ICONS.HATCH})
local tabAuto = speedTabs:CreateTab({"AUTOMATION", TAB_ICONS.AUTOMATION})
local tabTeams = speedTabs:CreateTab({"TEAMS", TAB_ICONS.TEAMS})
local tabWebhook = speedTabs:CreateTab({"WEBHOOK", TAB_ICONS.WEBHOOK})
local tabMisc = speedTabs:CreateTab({"MISC", TAB_ICONS.MISC})

-- ============================================================
-- Speed-native item helpers (thin wrappers for terse call sites)
-- ============================================================
-- Velium: every helper is wrapped in pcall and returns a harmless stub on
-- failure. A single malformed item must never abort the rest of a tab's
-- build (that is what left every non-HATCH tab empty).
local function spStub()
	local s = {}
	function s.Set() end
	function s.Refresh() end
	function s.AddOption() end
	function s.Clear() end
	s.Value = {}
	s.Title = { Text = "" }
	s.Content = { Text = "", TextColor3 = Color3.fromRGB(166,164,160) }
	-- Real instances so call sites that do `.ButtonButton.Activated:Connect(...)`
	-- or read `.Frame` do not throw if an item failed to build.
	local dummy = Instance.new("Frame")
	dummy.Visible = false
	s.Frame = dummy
	s.ButtonButton = Instance.new("TextButton")
	return s
end
local function spGuard(label, fn)
	local ok, res = pcall(fn)
	if ok then return res end
	warn("[Velium Hub] item failed (" .. tostring(label) .. "): " .. tostring(res))
	return spStub()
end
local function spToggle(sec, order, title, content, default, cb)
	return spGuard("toggle:" .. tostring(title), function()
		return sec:AddToggle({LayoutOrder=order, Title=title, Content=content or "", Default=default, Callback=cb})
	end)
end
local function spInput(sec, order, title, content, default, cb)
	return spGuard("input:" .. tostring(title), function()
		return sec:AddInput({LayoutOrder=order, Title=title, Content=content or "", Default=default, Callback=cb})
	end)
end
local function spButton(sec, order, title, content, icon, cb)
	return spGuard("button:" .. tostring(title), function()
		return sec:AddButton({LayoutOrder=order, Title=title, Content=content or "", Icon=icon or "", Callback=cb})
	end)
end
local function spDropdown(sec, order, title, content, multi, opts, default, cb)
	return spGuard("dropdown:" .. tostring(title), function()
		return sec:AddDropdown({LayoutOrder=order, Title=title, Content=content or "", Multi=multi, Options=opts, Default=default or {}, Callback=cb})
	end)
end
local function spLabel(sec, order, text)
	return spGuard("label:" .. tostring(text), function()
		return sec:AddParagraph({LayoutOrder=order, Title=text, Content=""})
	end)
end
-- Velium: AddSection is the first call in every tab block; if it throws the
-- whole tab renders empty. Wrap it and hand back a stub container on failure.
local function spSection(tab, title, open)
	local ok, sec = pcall(function() return tab:AddSection(title, open) end)
	if not ok or not sec then
		warn("[Velium Hub] section failed (" .. tostring(title) .. "): " .. tostring(sec))
		local stub = {}
		function stub.GetContainer()
			local f = Instance.new("Frame")
			f.BackgroundTransparency = 1
			f.Size = UDim2.new(1, 0, 0, 0)
			f.Visible = false
			return f
		end
		function stub.Resize() end
		return stub
	end
	return sec
end

-- Team dropdown helper + registry for post-load refresh
local teamDropdowns = {}
local function getTeamNameList()
	local names, seen = {}, {}
	if type(_G._NH_BUILTIN_TEAMS) == "table" then
		for _, t in ipairs(_G._NH_BUILTIN_TEAMS) do
			if type(t) == "table" and type(t.name) == "string" and not seen[t.name] then
				seen[t.name] = true
				table.insert(names, t.name)
			end
		end
	end
	for name in pairs(cfg.petTeams or {}) do
		if not seen[name] then seen[name] = true; table.insert(names, name) end
	end
	table.sort(names)
	return names
end
local function spTeamDD(sec, order, title, tbl, key)
	local function build()
		local opts = getTeamNameList()
		local cur = tbl[key]
		local def = (cur and table.find(opts, cur)) and {cur} or {}
		return opts, def
	end
	local opts, def = build()
	local dd = sec:AddDropdown({LayoutOrder=order, Title=title, Content="Choose a team", Multi=false, Options=opts, Default=def, Callback=function(v)
		if v and v[1] ~= nil then tbl[key] = v[1]; saveConfig() end
	end})
	table.insert(teamDropdowns, {dd=dd, build=build})
	return dd
end
local function refreshTeamDropdowns()
	for _, ref in ipairs(teamDropdowns) do
		local opts, def = ref.build()
		ref.dd:Refresh(opts, def)
	end
end
do
local topF = mainFrame:FindFirstChild("Top")
if topF then
-- Velium: the title row ("Velium Hub" + "| Grow A Garden") is laid out by a
-- horizontal UIListLayout inside SpeedHubX_UI.CreateWindow, so spacing is
-- fixed and snug. Here we only need to place the logo to its left.
local logoImg = Instance.new("ImageLabel")
logoImg.Size = UDim2.new(0, 24, 0, 24)
logoImg.Position = UDim2.new(0, 7, 0.5, -12)
logoImg.BackgroundTransparency = 1
logoImg.Image = "rbxassetid://118973578063038"
logoImg.ScaleType = Enum.ScaleType.Fit
logoImg.ZIndex = 2
logoImg.Parent = topF
end
local layersTab = mainFrame:FindFirstChild("LayersTab")
local scrollTab = layersTab and layersTab:FindFirstChild("ScrollTab")
if layersTab and scrollTab then
scrollTab.Size = UDim2.new(1, 0, 1, -66)
local prof = UI:frame(layersTab, UDim2.new(1, -8, 0, 52), UDim2.new(0, 4, 1, -56), T.PANEL)
UI:corner(prof, 8); UI:stroke(prof, T.STROKE, 1)
local av = Instance.new("ImageLabel", prof)
av.Size = UDim2.new(0, 36, 0, 36)
av.Position = UDim2.new(0, 7, 0.5, -18)
av.BackgroundTransparency = 1
av.Image = "rbxassetid://118973578063038"
av.ScaleType = Enum.ScaleType.Fit
av.ClipsDescendants = true
UI:corner(av, 18)
pcall(function()
local thumb = Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
if thumb and thumb ~= "" then av.Image = thumb end
end)
local nm = UI:label(prof, LocalPlayer.Name, UDim2.new(1, -52, 1, 0), UDim2.new(0, 49, 0, 0), T.TEXT, 12)
nm.Font = Enum.Font.GothamBold
nm.TextTruncate = Enum.TextTruncate.AtEnd
end
end
local PageHatch = modalRoot
SpeedLib.OnCloseRequest = function() confirmOv.Visible = true end
-- TOAST NOTIFICATIONS (bottom-right corner, outside main UI)
local toastRoot = Instance.new("Frame", ScreenGui)
toastRoot.Name = "VeliumToasts"
toastRoot.AnchorPoint = Vector2.new(1, 1)
toastRoot.Position = UDim2.new(1, -16, 1, -16)
toastRoot.Size = UDim2.new(0, 250, 0, 0)
toastRoot.AutomaticSize = Enum.AutomaticSize.Y
toastRoot.BackgroundTransparency = 1
do
local toastLayout = Instance.new("UIListLayout", toastRoot)
toastLayout.FillDirection = Enum.FillDirection.Vertical
toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
toastLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
toastLayout.Padding = UDim.new(0, 8)
end
local VeliumTween = game:GetService("TweenService")
local toastOrder = 0
local notifyReady = false
local function VeliumNotify(featureName, enabled)
if not notifyReady then return end
if cfg and cfg.toggles and cfg.toggles.hideNotif then return end
toastOrder = toastOrder + 1
local existing = {}
for _, c in ipairs(toastRoot:GetChildren()) do if c:IsA("Frame") then table.insert(existing, c) end end
if #existing >= 5 then table.sort(existing, function(a, b) return a.LayoutOrder < b.LayoutOrder end) pcall(function() existing[1]:Destroy() end) end
local toast = UI:frame(toastRoot, UDim2.new(1, 0, 0, 0), nil, T.PANEL)
toast.LayoutOrder = toastOrder
toast.BackgroundTransparency = 1
toast.ClipsDescendants = true
UI:corner(toast, 8)
local tStroke = UI:stroke(toast, T.ACCENT, 1)
tStroke.Transparency = 1
local tLogo = Instance.new("ImageLabel", toast)
tLogo.Size = UDim2.new(0, 20, 0, 20); tLogo.Position = UDim2.new(0, 8, 0, 6)
tLogo.BackgroundTransparency = 1
tLogo.Image = "rbxassetid://118973578063038"
tLogo.ScaleType = Enum.ScaleType.Fit
tLogo.ImageTransparency = 1
local tVelium = UI:label(toast, "Velium", UDim2.new(0, 0, 0, 20), UDim2.new(0, 32, 0, 6), T.TEXT, 11)
tVelium.Font = Enum.Font.GothamBold
tVelium.AutomaticSize = Enum.AutomaticSize.X
tVelium.TextTransparency = 1
local tHub = UI:label(toast, "Hub", UDim2.new(0, 0, 0, 20), UDim2.new(0, 78, 0, 6), T.ACCENT, 11)
tHub.Font = Enum.Font.GothamBold
tHub.AutomaticSize = Enum.AutomaticSize.X
tHub.TextTransparency = 1
task.defer(function() pcall(function() tHub.Position = UDim2.new(0, 32 + tVelium.TextBounds.X + 4, 0, 6) end) end)
local tClose = UI:button(toast, "X", UDim2.new(0, 22, 0, 20), UDim2.new(1, -26, 0, 4), T.BTN, T.DIM, 9)
tClose.BackgroundTransparency = 1
tClose.TextTransparency = 1
local tCloseStroke = UI:stroke(tClose, T.STROKE, 1)
tCloseStroke.Transparency = 1
local tSub = UI:label(toast, tostring(featureName) .. (enabled and " enabled" or " disabled"), UDim2.new(1, -16, 0, 20), UDim2.new(0, 8, 0, 32), enabled and T.SUCCESS or T.DIM, 10)
tSub.Font = Enum.Font.GothamBold
tSub.TextTruncate = Enum.TextTruncate.AtEnd
tSub.TextTransparency = 1
local closed = false
local function closeToast() if closed then return end closed = true pcall(function() toast:Destroy() end) end
tClose.MouseButton1Click:Connect(closeToast)
task.delay(4, closeToast)
local appearInfo = TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
VeliumTween:Create(toast, appearInfo, {Size = UDim2.new(1, 0, 0, 60), BackgroundTransparency = 0}):Play()
VeliumTween:Create(tStroke, appearInfo, {Transparency = 0}):Play()
VeliumTween:Create(tLogo, appearInfo, {ImageTransparency = 0}):Play()
VeliumTween:Create(tVelium, appearInfo, {TextTransparency = 0}):Play()
VeliumTween:Create(tHub, appearInfo, {TextTransparency = 0}):Play()
VeliumTween:Create(tSub, appearInfo, {TextTransparency = 0}):Play()
VeliumTween:Create(tClose, appearInfo, {BackgroundTransparency = 0, TextTransparency = 0}):Play()
VeliumTween:Create(tCloseStroke, appearInfo, {Transparency = 0}):Play()
end
_G.VeliumNotify = VeliumNotify
local interfaceScales = {SMALL = 0.85, MEDIUM = 1, BIG = 1.15, MASSIVE = 1.3}
if type(cfg.uiScale) ~= "string" or not interfaceScales[cfg.uiScale] then cfg.uiScale = "MEDIUM" end
local uiScaleObj = Instance.new("UIScale", mainFrame)
uiScaleObj.Name = "VeliumUIScale"
local function applyInterfaceScale()
uiScaleObj.Scale = guiScale * (interfaceScales[cfg.uiScale] or 1)
end
applyInterfaceScale()
-- Velium: re-fit the window size whenever the game window / screen size changes
-- (only when the user has not manually resized + saved a size).
pcall(function()
local cam = workspace.CurrentCamera
if cam then
cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
local vp = cam.ViewportSize
local nw, nh = computeAutoSize(vp)
if not cfg.uiManual then
mainFrame.Size = UDim2.new(0, nw, 0, nh)
end
if isMobile then
guiScale = math.clamp((vp.X / 420) * 0.72, 0.65, 1.4)
applyInterfaceScale()
end
end)
end
end)
-- RESIZE GRIPS (BOTTOM EDGE: bottom-left drags left+bottom, bottom-right drags right+bottom)
local RESIZE_MIN_W, RESIZE_MIN_H = 560, 340
local function makeGrip(pos)
local b = UI:button(mainFrame, "", UDim2.new(0, 22, 0, 22), pos, T.BTN, T.TEXT, 10)
b.BackgroundTransparency = 0.75
b.AutoButtonColor = false
b.ZIndex = 60
local stripes = {}
for k = 0, 2 do
local s = UI:frame(b, UDim2.new(0, 8, 0, 2), UDim2.new(0, 7, 0, 6 + k * 4), T.DIM)
s.BorderSizePixel = 0; s.Rotation = 45; s.ZIndex = 61
stripes[k + 1] = s
end
b.MouseEnter:Connect(function() for _, s in ipairs(stripes) do s.BackgroundColor3 = T.ACCENT end end)
b.MouseLeave:Connect(function() for _, s in ipairs(stripes) do s.BackgroundColor3 = T.DIM end end)
return b
end
local brGripBtn = makeGrip(UDim2.new(1, -22, 1, -22))
local blGripBtn = makeGrip(UDim2.new(0, 0, 1, -22))
do
local activeHandle = nil
local dragInput = nil
local startMouse = nil
local startSize = nil
local startPos = nil
local function clampLeftW(startW, rightEdge, dx, vpX, effScale)
local maxW = math.clamp(math.floor(vpX / effScale) - 24, RESIZE_MIN_W, 1400)
local newW = math.clamp(startW - dx, RESIZE_MIN_W, maxW)
local posX = rightEdge - newW
local minPX = 8 - vpX * 0.5
local maxPX = vpX * 0.5 - 8 - newW * effScale
if maxPX < minPX then maxPX = minPX end
posX = math.clamp(posX, minPX, maxPX)
newW = math.clamp(rightEdge - posX, RESIZE_MIN_W, maxW)
return newW, posX
end
local function beginResize(handle, input)
if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
if activeHandle and dragInput == input then return end
activeHandle = handle
dragInput = input
startMouse = input.Position
startSize = mainFrame.Size
startPos = mainFrame.Position
print("[Velium Hub] Resize start (" .. tostring(handle) .. ")")
input.Changed:Connect(function()
if input.UserInputState == Enum.UserInputState.End and input == dragInput then
activeHandle = nil
dragInput = nil
if cfg then cfg.uiW = mainFrame.Size.X.Offset; cfg.uiH = mainFrame.Size.Y.Offset; cfg.uiManual = true; saveConfig() end
print("[Velium Hub] Resize end, size saved: " .. tostring(mainFrame.Size.X.Offset) .. "x" .. tostring(mainFrame.Size.Y.Offset))
end
end)
end
brGripBtn.InputBegan:Connect(function(input) beginResize("BR", input) end)
blGripBtn.InputBegan:Connect(function(input) beginResize("BL", input) end)
UIS.InputBegan:Connect(function(input)
if activeHandle then return end
if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
local so = mainFrame.Size.X.Offset
if so <= 0 then return end
local fp = mainFrame.AbsolutePosition
local fs = mainFrame.AbsoluteSize
local gs = fs.X / so
local mp = input.Position
local blTop = fp.Y + fs.Y - 22 * gs
local inBottomY = mp.Y >= blTop and mp.Y <= blTop + 22 * gs
local inLeftX = mp.X >= fp.X and mp.X <= fp.X + 22 * gs
local inRightX = mp.X >= fp.X + fs.X - 22 * gs and mp.X <= fp.X + fs.X
if inLeftX and inBottomY then
beginResize("BL", input)
elseif inRightX and inBottomY then
beginResize("BR", input)
end
end)
UIS.InputChanged:Connect(function(input)
if not activeHandle then return end
if input.UserInputType == Enum.UserInputType.Touch and input ~= dragInput then return end
if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
if not startMouse or not startSize or not startPos then return end
local cam = workspace.CurrentCamera
local vp = (cam and cam.ViewportSize) or Vector2.new(1280, 720)
local effScale = (uiScaleObj and uiScaleObj.Scale) or 1
local startW, startH = startSize.X.Offset, startSize.Y.Offset
local rightEdge = startPos.X.Offset + startW
local delta = input.Position - startMouse
local newW, posX = clampLeftW(startW, rightEdge, delta.X, vp.X, effScale)
if activeHandle == "BL" then
local maxH = math.clamp(math.floor(vp.Y / effScale) - 24, RESIZE_MIN_H, 1000)
local newH = math.clamp(startH + delta.Y, RESIZE_MIN_H, maxH)
mainFrame.Size = UDim2.new(0, math.floor(newW), 0, math.floor(newH))
mainFrame.Position = UDim2.new(startPos.X.Scale, math.floor(posX), startPos.Y.Scale, startPos.Y.Offset)
else
local maxW2 = math.clamp(math.floor(vp.X / effScale) - 24, RESIZE_MIN_W, 1400)
local newWR = math.clamp(startW + delta.X, RESIZE_MIN_W, maxW2)
local maxH = math.clamp(math.floor(vp.Y / effScale) - 24, RESIZE_MIN_H, 1000)
local newH = math.clamp(startH + delta.Y, RESIZE_MIN_H, maxH)
mainFrame.Size = UDim2.new(0, math.floor(newWR), 0, math.floor(newH))
mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset, startPos.Y.Scale, startPos.Y.Offset)
end
end)
end
isKGRunning = false
confirmOv = UI:frame(ScreenGui, UDim2.new(1,0,1,0), nil, Color3.fromRGB(0,0,0))
confirmOv.Visible = false; confirmOv.ZIndex = 100
local confirmBox = UI:frame(confirmOv, UDim2.new(0,280,0,120), UDim2.new(0.5,-140,0.5,-60), T.PANEL)
UI:corner(confirmBox, 8); UI:stroke(confirmBox, T.ERROR, 2); confirmBox.ZIndex = 101
UI:label(confirmBox, "Unload Velium Hub?", UDim2.new(1,0,0,24), UDim2.new(0,0,0,12), T.TEXT, 12, Enum.TextXAlignment.Center).Font = Enum.Font.GothamBold
UI:label(confirmBox, "All features will stop running.", UDim2.new(1,0,0,16), UDim2.new(0,0,0,38), T.DIM, 9, Enum.TextXAlignment.Center).Font = Enum.Font.Gotham
local yesBtn = UI:button(confirmBox, "Yes, Unload", UDim2.new(0,110,0,28), UDim2.new(0,20,0,70), T.ERROR, T.TEXT, 10)
UI:stroke(yesBtn, T.ERROR, 1)
local noBtn = UI:button(confirmBox, "Cancel", UDim2.new(0,110,0,28), UDim2.new(1,-130,0,70), T.BTN, T.ACCENT, 10)
UI:stroke(noBtn, T.STROKE, 1)
yesBtn.MouseButton1Click:Connect(function()
isKGRunning = false
SpeedLib.Unloaded = true
pcall(function() ScreenGui:Destroy() end)
end)
noBtn.MouseButton1Click:Connect(function()
confirmOv.Visible = false
end)
-- ============================================================
-- HATCH TAB
-- ============================================================
print("[Velium Hub] TAB build: HATCH")
do
local hatchSec = spSection(tabHatch, "AUTO HATCH", true)
local hatchInner = hatchSec:GetContainer()
-- ── Egg to place (Speed dropdown, search built in) ──
do
local eggList, seen = {}, {}
for _, pet in ipairs(PetJSON) do
if pet.egg and not seen[pet.egg] then
seen[pet.egg] = true
table.insert(eggList, pet.egg)
end
end
table.sort(eggList)
local eggDefault = {}
if cfg.autoHatch.eggName and table.find(eggList, cfg.autoHatch.eggName) then
eggDefault = {cfg.autoHatch.eggName}
end
spDropdown(hatchSec, 1, "Egg to place", "Search & pick the egg", false, eggList, eggDefault, function(v)
cfg.autoHatch.eggName = v[1] or "Common Egg"; saveConfig()
end)
end
-- ── Count / Spacing ──
do
local cntInp
cntInp = spInput(hatchSec, 2, "Count", "Eggs per hatch cycle", tostring(cfg.autoHatch.eggCount or 13), function(v)
local n = tonumber(v)
if n and n >= 1 then cfg.autoHatch.eggCount = n; saveConfig()
elseif cntInp then cntInp:Set(tostring(cfg.autoHatch.eggCount or 13)) end
end)
local spInp
spInp = spInput(hatchSec, 3, "Spacing", "Studs between eggs", tostring(cfg.autoHatch.eggSpacing or 7), function(v)
local n = tonumber(v)
if n and n >= 1 then cfg.autoHatch.eggSpacing = n; saveConfig()
elseif spInp then spInp:Set(tostring(cfg.autoHatch.eggSpacing or 7)) end
end)
end
-- ── Place method / max ──
spDropdown(hatchSec, 4, "Place Method", "How eggs are positioned", false, {"Random", "Set"}, {cfg.placeEggs.method or "Random"}, function(v)
cfg.placeEggs.method = v[1] or "Random"; saveConfig()
end)
do
local maxInp
maxInp = spInput(hatchSec, 5, "Max eggs", "Maximum eggs placed per cycle", tostring(cfg.placeEggs.maxEggs or 20), function(v)
local n = tonumber(v)
if n and n >= 0 then cfg.placeEggs.maxEggs = n; saveConfig()
elseif maxInp then maxInp:Set(tostring(cfg.placeEggs.maxEggs or 20)) end
end)
end
-- ── Team selectors (Speed dropdowns) ──
spTeamDD(hatchSec, 10, "CD Team (Reduce cooldown)", cfg.autoHatch, "teamCD")
spTeamDD(hatchSec, 11, "Koi Team", cfg.autoHatch, "teamKoi")
spTeamDD(hatchSec, 12, "Seal Team (Sell)", cfg.autoHatch, "teamSeal")
spTeamDD(hatchSec, 13, "Bronto Team (Heavy hatch)", cfg.autoHatch, "teamBronto")
-- ── Egg ESP / pick-place ──
spToggle(hatchSec, 20, "Egg ESP", "Highlight placed eggs", cfg.autoHatch.espEnabled, function(val)
cfg.autoHatch.espEnabled = val; saveConfig()
if HatchTrack.EggESP then HatchTrack.EggESP.on = val; if not val and HatchTrack.clearEggESP then HatchTrack.clearEggESP() end end
end)
spToggle(hatchSec, 21, "Don't Pick-Place saat Koi/Bronto/Seal active", "", cfg.autoHatch.dontPickPlace, function(val)
cfg.autoHatch.dontPickPlace = val; saveConfig()
end)
-- ── Timing editor (custom overlay, kept) ──
do
local timingBtnRow = UI:frame(hatchInner, UDim2.new(1,0,0,26), nil, T.BTN)
timingBtnRow.LayoutOrder = 22
UI:corner(timingBtnRow, 5); UI:stroke(timingBtnRow, T.STROKE, 1)
local timingTeBtn, timingOverlay = UI:timingEditor(timingBtnRow, PageHatch, TIMING, cfg, saveConfig)
if timingTeBtn then
timingBtnRow.Size = UDim2.new(1,0,0,44)
end
end
-- ── Auto feed ──
do
local feedInp
feedInp = spInput(hatchSec, 30, "Auto Feed (sec)", "Delay between feed actions", tostring(cfg.autoHatch.autoFeedDelay or 0), function(v)
local n = tonumber(v)
if n and n >= 0 then cfg.autoHatch.autoFeedDelay = n; saveConfig()
elseif feedInp then feedInp:Set(tostring(cfg.autoHatch.autoFeedDelay or 0)) end
end)
spToggle(hatchSec, 31, "Auto Feed enabled", "", cfg.autoHatch.autoFeedEnabled or false, function(val)
cfg.autoHatch.autoFeedEnabled = val; saveConfig()
end)
end
do
local logPanel = UI:frame(hatchInner, UDim2.new(1,0,0,80), nil, T.PANEL)
logPanel.LayoutOrder = 40
UI:stroke(logPanel, T.STROKE, 1)
local logHdr = UI:frame(logPanel, UDim2.new(1,0,0,14), nil, T.BG, 1)
UI:label(logHdr, "LOGS", UDim2.new(1,-60,1,0), UDim2.new(0,6,0,0), T.ACCENT, 8).Font = Enum.Font.GothamBold
local logSF = UI:scroll(logPanel, UDim2.new(1,-4,1,-16), UDim2.new(0,2,0,15))
UI:list(logSF, 2); UI:pad(logSF, 1,4,4,1)
local function addLog(text, color)
local ts = os.date("%H:%M:%S")
local l = UI:label(logSF, ts .. " " .. text, UDim2.new(1,0,0,12), nil, color or T.DIM, 8)
l.TextXAlignment = Enum.TextXAlignment.Left
l.TextTruncate = Enum.TextTruncate.AtEnd
end
addLog("Auto Hatch ready!", T.SUCCESS)
local hatchRunning = false
local hatchThread = nil
local statusRow = UI:frame(hatchInner, UDim2.new(1,0,0,30), nil, T.DARK_CARD)
statusRow.LayoutOrder = 50
UI:corner(statusRow, 5); UI:stroke(statusRow, T.STROKE, 1)
UI:label(statusRow, "AUTO HATCH", UDim2.new(0,120,1,0), UDim2.new(0,8,0,0), T.TEXT, 10).Font = Enum.Font.GothamBold
local dot = UI:label(statusRow, " ", UDim2.new(0,10,0,10), UDim2.new(0,120,0.5,-5), T.ERROR, 10)
dot.BackgroundColor3 = T.ERROR; UI:corner(dot, 5)
local statusLbl = UI:label(statusRow, "● IDLE", UDim2.new(1,-56,1,0), UDim2.new(0,134,0,0), T.DIM, 9)
statusLbl.Font = Enum.Font.Gotham; statusLbl.TextTruncate = Enum.TextTruncate.AtEnd
local function onHatchToggle(val)
if val then
if hatchRunning then return end
hatchRunning = true
HatchTrack.hatchRunning = true
VeliumNotify("Auto Hatch", true)
statusLbl.Text = "RUNNING"
statusLbl.TextColor3 = T.SUCCESS
dot.BackgroundColor3 = T.SUCCESS
addLog("=== AUTO HATCH START ===", T.ACCENT)
hatchThread = task.spawn(function()
local cycle = 0
while hatchRunning do
cycle = cycle + 1
statusLbl.Text = "Cycle " .. cycle
statusLbl.TextColor3 = T.SUCCESS
addLog(string.format("--- Cycle %d ---", cycle), T.ACCENT)
local ok, err = pcall(runHatchCycle, function(t,c) statusLbl.Text = t; statusLbl.TextColor3 = c end, addLog)
if not ok then addLog("Error: " .. tostring(err), T.ERROR); print("[Velium Hub] HATCH FAIL phase=" .. tostring(HatchTrack.phase) .. " err=" .. tostring(err)) end
if not hatchRunning then break end
task.wait(1)
end
addLog("--- Stopped ---", T.ERROR)
statusLbl.Text = "● IDLE"
statusLbl.TextColor3 = T.DIM
dot.BackgroundColor3 = T.ERROR
hatchRunning = false
end)
else
hatchRunning = false
HatchTrack.hatchRunning = false
VeliumNotify("Auto Hatch", false)
statusLbl.Text = "STOPPED"
statusLbl.TextColor3 = T.ERROR
dot.BackgroundColor3 = T.ERROR
addLog("---- Stopped by user ----", T.ERROR)
task.delay(1, function()
statusLbl.Text = "● IDLE"
statusLbl.TextColor3 = T.DIM
end)
end
end
local hatchToggle = UI:toggle(statusRow, UDim2.new(1,-48,0.5,-11), false, onHatchToggle)
end
-- ── Special pet → Bronto ──
spLabel(hatchSec, 51, "⭐ SPECIAL PET TO BRONTO")
spToggle(hatchSec, 52, "Enable Special Pet to Bronto", "", cfg.autoHatch.specialBronto and cfg.autoHatch.specialBronto.enabled or false, function(val)
if not cfg.autoHatch.specialBronto then cfg.autoHatch.specialBronto = {enabled=false, pets={}} end
cfg.autoHatch.specialBronto.enabled = val; saveConfig()
end)
do
local thrInp
thrInp = spInput(hatchSec, 53, "Bronto threshold (kg)", "", tostring(cfg.autoHatch.brontoThresh or 4), function(v)
local n = tonumber(v)
if n and n >= 0 then cfg.autoHatch.brontoThresh = n; saveConfig()
elseif thrInp then thrInp:Set(tostring(cfg.autoHatch.brontoThresh or 4)) end
end)
end
local spCountLbl
do
local spOpen
local function spUpdate()
local cn = 0; if cfg.autoHatch.specialBronto and cfg.autoHatch.specialBronto.pets then
for _ in pairs(cfg.autoHatch.specialBronto.pets) do cn = cn + 1 end end
spCountLbl:Set("Select Special Pets", cn == 0 and "NONE" or (cn .. " selected"))
spCountLbl.Content.TextColor3 = cn == 0 and T.DIM or T.ACCENT
end
spCountLbl = spButton(hatchSec, 54, "Select Special Pets", "NONE", "", function() if spOpen then spOpen() end end)
local ov = UI:frame(PageHatch, UDim2.new(1,0,1,0), nil, T.BG)
ov.Visible = false; ov.ZIndex = 25
local oh = UI:frame(ov, UDim2.new(1,0,0,30), nil, T.PANEL)
UI:stroke(oh, T.STROKE, 1)
UI:label(oh, "Select Special Pets to Bronto", UDim2.new(1,-90,1,0), UDim2.new(0,8,0,0), T.ACCENT, 10)
local selAllBtn = UI:button(oh, "Select All", UDim2.new(0,60,0,22), UDim2.new(1,-92,0.5,-11), T.BTN, T.ACCENT, 9)
UI:stroke(selAllBtn, T.ACCENT, 1)
local ox = UI:button(oh, "X", UDim2.new(0,24,0,22), UDim2.new(1,-28,0.5,-11), T.ERROR, T.TEXT, 10)
UI:stroke(ox, T.ERROR, 1)
ox.MouseButton1Click:Connect(function() ov.Visible = false; spUpdate() end)
local osp = UI:input(ov, "", "Search pet or egg..", UDim2.new(1,-8,0,22), UDim2.new(0,4,0,34))
osp.TextColor3 = T.TEXT; osp.Font = Enum.Font.Gotham
local ofr = UI:scroll(ov, UDim2.new(1,0,1,-60), UDim2.new(0,0,0,58))
UI:list(ofr, 3); UI:pad(ofr, 3,4,4,3)
local function rebuild()
for _, c in ipairs(ofr:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
local q = string.lower(osp.Text)
local filtered = {}
for _, pet in ipairs(PetJSON) do
if q ~= "" and not string.lower(pet.name):find(q,1,true) and not string.lower(pet.egg or ""):find(q,1,true) then continue end
table.insert(filtered, pet) end
local n = 0
for _, pet in ipairs(filtered) do
n = n + 1
local sel = cfg.autoHatch.specialBronto and cfg.autoHatch.specialBronto.pets and cfg.autoHatch.specialBronto.pets[pet.name]==true
local b = UI:button(ofr, " ", UDim2.new(1,0,0,34), nil, sel and T.SEL_BG or Color3.fromRGB(13,13,13), sel and T.SEL_TXT or T.TEXT, 9)
b.LayoutOrder = n; b.TextXAlignment = Enum.TextXAlignment.Left
UI:pad(b,0,8,2,0); UI:stroke(b, sel and T.ACCENT or T.STROKE, 1)
local nm = UI:label(b, pet.name, UDim2.new(1,0,0,16), UDim2.new(0,0,0,2), sel and T.SEL_TXT or T.TEXT, 10)
nm.Font = Enum.Font.GothamBold; nm.TextXAlignment = Enum.TextXAlignment.Left
local eg = UI:label(b, pet.egg or "", UDim2.new(1,0,0,14), UDim2.new(0,0,0,18), T.DIM, 8)
eg.TextXAlignment = Enum.TextXAlignment.Left
b.MouseButton1Click:Connect(function()
if not cfg.autoHatch.specialBronto then cfg.autoHatch.specialBronto = {enabled=false, pets={}} end
if not cfg.autoHatch.specialBronto.pets then cfg.autoHatch.specialBronto.pets = {} end
if cfg.autoHatch.specialBronto.pets[pet.name] then cfg.autoHatch.specialBronto.pets[pet.name]=nil
else cfg.autoHatch.specialBronto.pets[pet.name]=true end
saveConfig(); rebuild() end) end
end
local function selectAllFiltered()
if not cfg.autoHatch.specialBronto then cfg.autoHatch.specialBronto = {enabled=false, pets={}} end
if not cfg.autoHatch.specialBronto.pets then cfg.autoHatch.specialBronto.pets = {} end
local q = string.lower(osp.Text)
local allSel = true
for _, pet in ipairs(PetJSON) do
if q ~= "" and not string.lower(pet.name):find(q,1,true) and not string.lower(pet.egg or ""):find(q,1,true) then continue end
if not cfg.autoHatch.specialBronto.pets[pet.name] then allSel = false; break end end
for _, pet in ipairs(PetJSON) do
if q ~= "" and not string.lower(pet.name):find(q,1,true) and not string.lower(pet.egg or ""):find(q,1,true) then continue end
cfg.autoHatch.specialBronto.pets[pet.name] = not allSel end
saveConfig(); rebuild() end
selAllBtn.MouseButton1Click:Connect(selectAllFiltered)
osp:GetPropertyChangedSignal("Text"):Connect(rebuild)
spOpen = function() ov.Visible=true; rebuild() end
spUpdate()
end
do
local sellSec = spSection(tabHatch, "SELL SETTINGS", true)
local sellInner = sellSec:GetContainer()
do
local a
a = spInput(sellSec, 3, "Sell below (kg)", "", tostring(cfg.autoHatch.sellThresh or 0), function(v)
local n = tonumber(v)
if n and n >= 0 then cfg.autoHatch.sellThresh = n; saveConfig()
elseif a then a:Set(tostring(cfg.autoHatch.sellThresh or 0)) end
end)
local b
b = spInput(sellSec, 5, "Fav delay (sec)", "", tostring(cfg.autoHatch.favDelay or 0.1), function(v)
local n = tonumber(v)
if n and n >= 0 then cfg.autoHatch.favDelay = n; saveConfig()
elseif b then b:Set(tostring(cfg.autoHatch.favDelay or 0.1)) end
end)
end
do
local invInp
invInp = spInput(sellSec, 7, "Auto Sell ONLY When Inventory Full", "Max pets before selling", tostring(cfg.autoHatch.petInvMax or 200), function(v)
local n = tonumber(v)
if n and n >= 1 then cfg.autoHatch.petInvMax = n; saveConfig()
elseif invInp then invInp:Set(tostring(cfg.autoHatch.petInvMax or 200)) end
end)
spToggle(sellSec, 8, "SELL ALL PETS (off = one by one)", "", cfg.autoHatch.sellAll, function(val)
cfg.autoHatch.sellAll = val; saveConfig()
end)
spToggle(sellSec, 9, "Enable Selling", "", cfg.autoHatch.sellEnabled ~= false, function(val)
cfg.autoHatch.sellEnabled = val; saveConfig()
end)
end
-- ── Sell-pet picker (custom overlay, kept) ──
local sellCount = 0
for _ in pairs(cfg.autoHatch.sellPets or {}) do sellCount = sellCount + 1 end
local sellLbl
do
local sellOpen
local function refreshSellCount()
sellCount = 0; for _ in pairs(cfg.autoHatch.sellPets or {}) do sellCount = sellCount + 1 end
sellLbl:Set("Select Pets to Sell", sellCount == 0 and "NONE" or (sellCount .. " selected"))
sellLbl.Content.TextColor3 = sellCount == 0 and T.DIM or T.ACCENT
end
sellLbl = spButton(sellSec, 10, "Select Pets to Sell", "NONE", "", function() if sellOpen then sellOpen() end end)
local sellOverlay = UI:frame(PageHatch, UDim2.new(1,0,1,0), nil, T.BG)
sellOverlay.Visible = false; sellOverlay.ZIndex = 25
local soBar = UI:frame(sellOverlay, UDim2.new(1,0,0,26), nil, T.PANEL)
UI:stroke(soBar, T.STROKE, 1)
UI:label(soBar, "Select pets to SELL", UDim2.new(1,-96,1,0), UDim2.new(0,8,0,0), T.ACCENT, 10)
local soSelAll = UI:button(soBar, "Select All", UDim2.new(0,64,0,20), UDim2.new(1,-92,0.5,-10), T.BTN, T.ACCENT, 8)
UI:stroke(soSelAll, T.STROKE, 1)
local soClose = UI:button(soBar, "X", UDim2.new(0,24,0,20), UDim2.new(1,-28,0.5,-10), T.ERROR, T.TEXT, 10)
UI:stroke(soClose, T.ERROR, 1)
soClose.MouseButton1Click:Connect(function() sellOverlay.Visible = false; refreshSellCount() end)
local soSearch = UI:input(sellOverlay, "", "Search pet or egg...",
UDim2.new(1,-8,0,22), UDim2.new(0,4,0,28))
soSearch.TextColor3 = T.TEXT; soSearch.Font = Enum.Font.Gotham
local soSF = UI:scroll(sellOverlay, UDim2.new(1,0,1,-56), UDim2.new(0,0,0,54))
UI:list(soSF, 3); UI:pad(soSF, 3,4,4,3)
local function getFilteredPets()
local q = string.lower(soSearch.Text)
local result = {}
for _, pet in ipairs(PetJSON) do
if q == "" or pet.name:lower():find(q,1,true) or (pet.egg or ""):lower():find(q,1,true) then
table.insert(result, pet)
end
end
return result
end
local function rebuildSellOverlay()
for _, c in ipairs(soSF:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
local filtered = getFilteredPets()
local allSelected = #filtered > 0
for _, pet in ipairs(filtered) do
if not (cfg.autoHatch.sellPets or {})[pet.name] then allSelected = false; break end
end
soSelAll.Text = #filtered == 0 and "Select All" or (allSelected and "Unselect All" or "Select All")
for i, pet in ipairs(filtered) do
local isSel = (cfg.autoHatch.sellPets or {})[pet.name] == true
local b = UI:button(soSF, pet.name, UDim2.new(1,0,0,30), nil,
(isSel and T.SEL_BG) or Color3.fromRGB(13,13,13),
(isSel and T.SEL_TXT) or T.TEXT, 10)
b.LayoutOrder = i; b.TextXAlignment = Enum.TextXAlignment.Left
UI:pad(b, 0,8,4,0); UI:corner(b, 5)
UI:stroke(b, (isSel and T.ACCENT) or T.STROKE, 1)
local sub = UI:label(b, pet.egg or "", UDim2.new(1,-8,0,12), UDim2.new(0,8,1,-13),
(isSel and Color3.fromRGB(60,40,0)) or T.DIM, 8)
sub.Font = Enum.Font.Gotham
b.MouseButton1Click:Connect(function()
if not cfg.autoHatch.sellPets then cfg.autoHatch.sellPets = {} end
if cfg.autoHatch.sellPets[pet.name] then cfg.autoHatch.sellPets[pet.name] = nil
else cfg.autoHatch.sellPets[pet.name] = true end
saveConfig(); refreshSellCount(); rebuildSellOverlay()
end)
end
end
soSelAll.MouseButton1Click:Connect(function()
if not cfg.autoHatch.sellPets then cfg.autoHatch.sellPets = {} end
local filtered = getFilteredPets()
local allSel = true
for _, pet in ipairs(filtered) do
if not cfg.autoHatch.sellPets[pet.name] then allSel = false; break end
end
for _, pet in ipairs(filtered) do
cfg.autoHatch.sellPets[pet.name] = allSel and nil or true
end
saveConfig(); refreshSellCount(); rebuildSellOverlay()
end)
soSearch:GetPropertyChangedSignal("Text"):Connect(rebuildSellOverlay)
sellOpen = function() sellOverlay.Visible = true; rebuildSellOverlay() end
refreshSellCount()
end
end
local boostSec = spSection(tabHatch, "PET BOOST", false)
local boostInner = boostSec:GetContainer()
do
spToggle(boostSec, 1, "Mode 1: Boost selected pets", "Auto-apply toys to the chosen pets", cfg.toggles.mode1boost, function(val)
cfg.toggles.mode1boost = val; saveConfig(); VeliumNotify("Mode 1 Boost", val)
end)
local toyTypes = { "Small Toy", "Medium Toy", "Large Toy" }
local toyDefault = {}
for _, toyName in ipairs(toyTypes) do
if cfg.petboost.mode1.boostOptions and cfg.petboost.mode1.boostOptions[toyName] then
table.insert(toyDefault, toyName)
end
end
spDropdown(boostSec, 2, "Toy Type", "Which toys to apply", true, toyTypes, toyDefault, function(v)
local newOpts = {}
for _, name in ipairs(v) do newOpts[name] = true end
cfg.petboost.mode1.boostOptions = newOpts
saveConfig()
end)
-- ── Boost pet picker (custom overlay, kept) ──
local spCount = 0
for _ in pairs(cfg.petboost.mode1.selPets or {}) do spCount = spCount + 1 end
local spLbl
do
local spOpen
local function refreshSpCount()
local cn = 0; for _ in pairs(cfg.petboost.mode1.selPets or {}) do cn = cn + 1 end
spLbl:Set("Select Pets to Boost", cn == 0 and "ALL (no filter)" or (cn .. " selected"))
spLbl.Content.TextColor3 = cn == 0 and T.DIM or T.ACCENT
end
spLbl = spButton(boostSec, 3, "Select Pets to Boost", "ALL (no filter)", "", function() if spOpen then spOpen() end end)
local spOv = UI:frame(PageHatch, UDim2.new(1,0,1,0), nil, T.BG)
spOv.Visible = false; spOv.ZIndex = 25
local spBar = UI:frame(spOv, UDim2.new(1,0,0,30), nil, T.PANEL)
UI:stroke(spBar, T.STROKE, 1)
UI:label(spBar, "Select Pets to Boost", UDim2.new(1,-90,1,0), UDim2.new(0,8,0,0), T.ACCENT, 10)
local spSelAll = UI:button(spBar, "All", UDim2.new(0,40,0,22), UDim2.new(1,-92,0.5,-11), T.BTN, T.ACCENT, 9)
UI:stroke(spSelAll, T.ACCENT, 1)
local spX = UI:button(spBar, "X", UDim2.new(0,24,0,22), UDim2.new(1,-28,0.5,-11), T.ERROR, T.TEXT, 10)
UI:stroke(spX, T.ERROR, 1)
spX.MouseButton1Click:Connect(function()
spOv.Visible = false
refreshSpCount()
end)
local spSearch = UI:input(spOv, "", "Search pet..", UDim2.new(1,-8,0,22), UDim2.new(0,4,0,34))
spSearch.TextColor3 = T.TEXT; spSearch.Font = Enum.Font.Gotham
local spSF = UI:scroll(spOv, UDim2.new(1,0,1,-60), UDim2.new(0,0,0,58))
UI:list(spSF, 3); UI:pad(spSF, 3,4,4,3)
local function rebuildSpOverlay()
for _, c in ipairs(spSF:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
local q = string.lower(spSearch.Text)
local n = 0
for _, pet in ipairs(PetJSON) do
if q ~= "" and not string.lower(pet.name):find(q,1,true) then continue end
n = n + 1
local sel = cfg.petboost.mode1.selPets and cfg.petboost.mode1.selPets[pet.name] == true
local b = UI:button(spSF, pet.name, UDim2.new(1,0,0,30), nil,
sel and T.SEL_BG or Color3.fromRGB(13,13,13), sel and T.SEL_TXT or T.TEXT, 9)
b.LayoutOrder = n; b.TextXAlignment = Enum.TextXAlignment.Left
UI:pad(b,0,8,2,0); UI:corner(b,5); UI:stroke(b, sel and T.ACCENT or T.STROKE, 1)
local sub = UI:label(b, pet.egg or "", UDim2.new(1,-8,0,11), UDim2.new(0,8,1,-12),
sel and Color3.fromRGB(60,40,0) or T.DIM, 8)
sub.Font = Enum.Font.Gotham
b.MouseButton1Click:Connect(function()
if not cfg.petboost.mode1.selPets then cfg.petboost.mode1.selPets = {} end
if cfg.petboost.mode1.selPets[pet.name] then cfg.petboost.mode1.selPets[pet.name] = nil
else cfg.petboost.mode1.selPets[pet.name] = true end
saveConfig()
end)
end
end
spSearch:GetPropertyChangedSignal("Text"):Connect(rebuildSpOverlay)
spSelAll.MouseButton1Click:Connect(function()
if not cfg.petboost.mode1.selPets then cfg.petboost.mode1.selPets = {} end
local allSel = true
for _, pet in ipairs(PetJSON) do
if not cfg.petboost.mode1.selPets[pet.name] then allSel = false; break end end
for _, pet in ipairs(PetJSON) do
cfg.petboost.mode1.selPets[pet.name] = allSel and nil or true end
saveConfig()
end)
spOpen = function() spOv.Visible = true; rebuildSpOverlay() end
refreshSpCount()
end
spToggle(boostSec, 10, "Mode 2: Boost pet pairs", "Pairs: pet + toy type. Auto-apply boost when ready.", cfg.toggles.mode2boost, function(val)
cfg.toggles.mode2boost = val; saveConfig(); VeliumNotify("Mode 2 Boost", val)
end)
end
do
spToggle(boostSec, 20, "FEED PETS", "Auto feed equipped pets when hunger is low", cfg.toggles.autoFeed, function(val)
cfg.toggles.autoFeed = val; saveConfig(); VeliumNotify("Auto Feed", val)
end)
local hInp
hInp = spInput(boostSec, 21, "Hunger %", "Feed when hunger drops below this", tostring(cfg.autoFeed.hungerThreshold or 50), function(v)
local n = tonumber(v)
if n and n >= 0 and n <= 100 then cfg.autoFeed.hungerThreshold = n; saveConfig()
elseif hInp then hInp:Set(tostring(cfg.autoFeed.hungerThreshold or 50)) end
end)
end
local RNG = Random.new()
local function getMyFarm()
local farmFolder = workspace:FindFirstChild("Farm")
if not farmFolder then return nil end
for _, oFarm in ipairs(farmFolder:GetChildren()) do
local ok, owner = pcall(function() return oFarm.Important.Data.Owner.Value end)
if ok and owner == LocalPlayer.Name then return oFarm end
end
return nil
end
local function getPlot()
local myFarm = getMyFarm()
if not myFarm then return {} end
local plantLoc = myFarm.Important:FindFirstChild("Plant_Locations")
if not plantLoc then return {} end
local plots = {}
for _, plate in ipairs(plantLoc:GetChildren()) do
if plate:IsA("Part") then
table.insert(plots, plate)
end
end
return plots
end
local function getBoundary(plot)
if not plot then return nil end
local bCf = plot.CFrame
local size = plot.Size
return {
cf = bCf,
minX = -size.X / 2 + 1,
maxX = size.X / 2 - 1,
minZ = -size.Z / 2 + 1,
maxZ = size.Z / 2 - 1,
}
end
local function getRandomPlotPos()
local plots = getPlot()
if #plots == 0 then return nil end
local targetPart = plots[math.random(1, #plots)]
local size = targetPart.Size
local cframe = targetPart.CFrame
local randomX = RNG:NextNumber(-size.X / 2, size.X / 2)
local randomZ = RNG:NextNumber(-size.Z / 2, size.Z / 2)
local floatDistance = 1
local localOffset = CFrame.new(randomX, floatDistance, randomZ)
local worldCFrame = cframe * localOffset
return CFrame.new(worldCFrame.Position.X, cframe.Position.Y, worldCFrame.Position.Z)
end
local function getSetPlotPos()
local state = cfg.plotState or {plotNum = 1, order = 0, currentX = nil}
local plots = getPlot()
if #plots == 0 then return nil end
local targetPart = plots[state.plotNum]
if not targetPart then
state.plotNum = 1
targetPart = plots[1]
if not targetPart then return nil end
end
local b = getBoundary(targetPart)
local cframe = b.cf
local x = state.currentX or b.maxX
local y = 0.15
local z = b.minZ + (state.order * 4)
state.order = state.order + 1
if z > b.maxZ then
x = x - 4
z = b.minZ
state.order = 0
end
if x < b.minX then
state.plotNum = state.plotNum == 1 and 2 or 1
state.order = 0
state.currentX = nil
cfg.plotState = state
return getSetPlotPos()
end
state.currentX = x
cfg.plotState = state
local localOffset = CFrame.new(x, y, z)
local worldCFrame = cframe * localOffset
return CFrame.new(worldCFrame.Position.X, cframe.Position.Y, worldCFrame.Position.Z)
end
local function getEggPlacePos()
if cfg.placeEggs.method == "Set" then
return getSetPlotPos()
else
return getRandomPlotPos()
end
end
local function countEggsOnFarm()
local myFarm = getMyFarm()
if not myFarm then return 0 end
local objects = myFarm.Important:FindFirstChild("Objects_Physical")
if not objects then return 0 end
local count = 0
for _, obj in ipairs(objects:GetChildren()) do
if obj:GetAttribute("OBJECT_TYPE") == "PetEgg" then
count = count + 1
end
end
return count
end
local EGG_GROUND_Y = 0.3605
local function eggMatches(tool, eggName)
if not tool:IsA("Tool") then return false end
if not CS:HasTag(tool, "PetEggTool") then return false end
if not eggName or eggName == "" then return true end
return tool:GetAttribute("h") == eggName
end
local function holdHatchEggTool(eggName)
local char = LocalPlayer.Character or Character
local hum = char and char:FindFirstChildOfClass("Humanoid")
local bp = LocalPlayer:FindFirstChild("Backpack") or Backpack
if not (char and hum and bp) then return false end
local function holdingEggNow()
for _, t in ipairs(char:GetChildren()) do
if eggMatches(t, eggName) then return true end
end
return false
end
if holdingEggNow() then return true end
for try = 1, 4 do
pcall(function() hum:UnequipTools() end)
task.wait(0.08)
local egg = nil
for _, t in ipairs(bp:GetChildren()) do
if eggMatches(t, eggName) then egg = t; break end
end
if not egg then
if holdingEggNow() then return true end
return false
end
pcall(function() hum:EquipTool(egg) end)
task.wait(0.18)
if holdingEggNow() then return true end
task.wait(0.12)
end
return holdingEggNow()
end
local function getGardenArea()
local myFarm = getMyFarm()
if not myFarm then return nil end
local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
local found = 0
pcall(function()
for _, d in ipairs(myFarm:GetDescendants()) do
if d.Name:lower():find("can_plant") and d:IsA("BasePart") then
found = found + 1
local sx, sz = d.Size.X / 2, d.Size.Z / 2
minX = math.min(minX, d.Position.X - sx)
maxX = math.max(maxX, d.Position.X + sx)
minZ = math.min(minZ, d.Position.Z - sz)
maxZ = math.max(maxZ, d.Position.Z + sz)
end
end
end)
if found == 0 then return nil end
return {minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ, count = found}
end
local function maxEggReached()
local found = false
pcall(function()
local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
if not pg then return end
for _, d in ipairs(pg:GetDescendants()) do
if d:IsA("TextLabel") and d.Visible then
local tx = (d.Text or ""):lower()
if tx:find("max egg") or tx:find("egg limit") or tx:find("maximum egg") then
found = true; break
end
end
end
end)
return found
end
local function countEggPlaced()
local seen = {}
local count = 0
local function addEgg(o)
if o and not seen[o] then seen[o] = true; count = count + 1 end
end
pcall(function()
local myFarm = getMyFarm()
local objects = myFarm and myFarm.Important:FindFirstChild("Objects_Physical")
if objects then
for _, obj in ipairs(objects:GetChildren()) do
if obj:GetAttribute("OBJECT_TYPE") == "PetEgg" and tostring(obj:GetAttribute("OWNER") or "") == LocalPlayer.Name then
addEgg(obj)
end
end
end
end)
pcall(function()
for _, obj in ipairs(CS:GetTagged("PetEggServer")) do
if obj:GetAttribute("OWNER") == LocalPlayer.Name then addEgg(obj) end
end
end)
if count == 0 then
pcall(function()
for _, d in ipairs(workspace:GetDescendants()) do
if d.Name == "PetEgg" and d:GetAttribute("OBJECT_TYPE") == "PetEgg" then
local owner = d:GetAttribute("OWNER")
if owner ~= nil and tostring(owner) == LocalPlayer.Name then addEgg(d) end
end
end
end)
end
return count
end
local function hitPetLimit()
local hit = false
pcall(function()
local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
if not pg then return end
for _, d in ipairs(pg:GetDescendants()) do
if d:IsA("TextLabel") and d.Visible then
local tx = (d.Text or ""):lower()
if tx:find("cannot open this pet") or tx:find("limit of pet") or tx:find("reached the limit") or tx:find("inventory is full") then
hit = true; break
end
end
end
end)
return hit
end
HatchTrack.EggESP = {on = cfg.autoHatch.espEnabled ~= false, billboards = {}}
local function fmtEggTime(s)
s = math.max(0, math.floor(s or 0))
if s <= 0 then return "READY" end
if s >= 3600 then return string.format("%dh %dm", math.floor(s / 3600), math.floor((s % 3600) / 60)) end
if s >= 60 then return string.format("%dm %ds", math.floor(s / 60), s % 60) end
return s .. "s"
end
local _eggESPcache = {list = {}, t = 0}
local function getMyPlacedEggs()
if (os.clock() - _eggESPcache.t) < 2 and _eggESPcache.list then return _eggESPcache.list end
local list = {}
local seen = {}
pcall(function()
for _, obj in ipairs(CS:GetTagged("PetEggServer")) do
if obj:GetAttribute("OWNER") == LocalPlayer.Name then
seen[obj] = true
table.insert(list, obj)
end
end
end)
pcall(function()
for _, d in ipairs(workspace:GetDescendants()) do
if d.Name == "PetEgg" and d:GetAttribute("OBJECT_TYPE") == "PetEgg" and not seen[d] then
local owner = d:GetAttribute("OWNER")
if owner ~= nil and tostring(owner) == LocalPlayer.Name then
seen[d] = true
table.insert(list, d)
end
end
end
end)
_eggESPcache.list = list; _eggESPcache.t = os.clock()
return list
end
local function makeEggBillboard(egg)
local bb = Instance.new("BillboardGui")
bb.Name = "VeliumEggESP"
bb.Size = UDim2.new(0, 150, 0, 40)
bb.StudsOffset = Vector3.new(0, 3, 0)
bb.AlwaysOnTop = true
bb.MaxDistance = 1000
bb.Adornee = egg
bb.Parent = egg
local nameL = Instance.new("TextLabel")
nameL.Size = UDim2.new(1, 0, 0.5, 0)
nameL.BackgroundTransparency = 1
nameL.Font = Enum.Font.GothamBold
nameL.TextSize = 13
nameL.TextColor3 = Color3.fromRGB(255, 255, 255)
nameL.TextStrokeTransparency = 0
nameL.Text = tostring(egg:GetAttribute("EggName") or egg:GetAttribute("h") or cfg.autoHatch.eggName or "Egg")
nameL.Parent = bb
local timeL = Instance.new("TextLabel")
timeL.Size = UDim2.new(1, 0, 0.5, 0)
timeL.Position = UDim2.new(0, 0, 0.5, 0)
timeL.BackgroundTransparency = 1
timeL.Font = Enum.Font.GothamBold
timeL.TextSize = 12
timeL.TextStrokeTransparency = 0
timeL.Text = "..."
timeL.Parent = bb
return bb, timeL
end
local function updateEggESP()
if not HatchTrack.EggESP.on then return end
pcall(function()
local seenNow = {}
for _, d in ipairs(getMyPlacedEggs()) do
if d and d.Parent then
seenNow[d] = true
local bb = d:FindFirstChild("VeliumEggESP")
local timeL = HatchTrack.EggESP.billboards[d]
if not bb then
bb, timeL = makeEggBillboard(d)
HatchTrack.EggESP.billboards[d] = timeL
end
if timeL then
local tth = tonumber(d:GetAttribute("TimeToHatch")) or 0
local rdy = tth <= 0
timeL.Text = fmtEggTime(tth)
timeL.TextColor3 = rdy and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(255, 210, 80)
end
end
end
for egg, _ in pairs(HatchTrack.EggESP.billboards) do
if not seenNow[egg] then HatchTrack.EggESP.billboards[egg] = nil end
end
end)
end
local function clearEggESP()
pcall(function()
for _, d in ipairs(workspace:GetDescendants()) do
if d.Name == "VeliumEggESP" then d:Destroy() end
end
end)
HatchTrack.EggESP.billboards = {}
end
HatchTrack.clearEggESP = clearEggESP
task.spawn(function()
while true do
if HatchTrack.EggESP.on then updateEggESP() end
task.wait(1)
end
end)
local function placeEggs(eggName, count, spacing, logFn)
local function plog(m, c) if logFn then logFn(m, c) end end
if not PetEggService then plog("No PetEggService!", T.ERROR); return 0 end
if HatchTrack.hatchRunning == false then return 0 end
local char = LocalPlayer.Character or Character
local hrp = char and char:FindFirstChild("HumanoidRootPart")
if not hrp then plog("No character/HRP (respawning?)", T.ERROR); return 0 end
count = count or 6
local area = getGardenArea()
if not area then plog("No garden area (no Can_Plant plots found)", T.ERROR); return 0 end
if not holdHatchEggTool(eggName) then plog("No '" .. tostring(eggName) .. "' egg tool to hold", T.ERROR); return 0 end
task.wait(0.15)
local target = cfg.placeEggs.maxEggs or 20
local placed = 0
local stuck = 0
local useGarden = false
for attempt = 1, count * 8 + 30 do
if HatchTrack.hatchRunning == false then return placed end
if placed >= count then break end
local before = countEggPlaced()
if before >= target then plog("Egg target reached (" .. before .. "/" .. target .. ")", T.DIM); break end
if maxEggReached() then plog("Max egg notice on screen, stopping place", T.ERROR); break end
holdHatchEggTool(eggName)
local pos = nil
if not useGarden then pos = getEggPlacePos() end
if not pos then
local px = area.minX + math.random() * (area.maxX - area.minX)
local pz = area.minZ + math.random() * (area.maxZ - area.minZ)
pos = CFrame.new(px, EGG_GROUND_Y, pz)
end
if placed == 0 then
pcall(function()
local heldName = "?"
local ch = LocalPlayer.Character or Character
if ch then for _, t in ipairs(ch:GetChildren()) do if eggMatches(t, eggName) then heldName = t.Name; break end end end
plog("Firing CreateEgg '" .. heldName .. "' @ " .. tostring(pos), T.DIM)
end)
end
pcall(function() PetEggService:FireServer("CreateEgg", pos) end)
placed = placed + 1
task.wait(0.25)
local after = countEggPlaced()
if after <= before then
stuck = stuck + 1
if stuck == 6 and not useGarden then useGarden = true; plog("Plot positions rejected, switching to garden random", T.ERROR) end
if stuck >= 20 then plog("Place stuck (server not spawning eggs)", T.ERROR); break end
task.wait(0.1)
else
stuck = 0
end
end
plog(string.format("Place done: %d fired (stuck %d)", placed, stuck), T.DIM)
return placed
end
local function countEggs(eggName)
local n = 0
for _, tool in ipairs(Backpack:GetChildren()) do
if tool:IsA("Tool") and CS:HasTag(tool, "PetEggTool") then
if tool:GetAttribute("h") == eggName then
n = n + (tonumber(tool.Name:match("x(%d+)$")) or 1)
end
end
end
return n
end
local function hatchAllEggs()
if not PetEggService then return 0 end
if HatchTrack.hatchRunning == false then return 0 end
local eggBefore = totalEggNow()
local ready = {}
pcall(function()
for _, obj in ipairs(CS:GetTagged("PetEggServer")) do
if obj:GetAttribute("OWNER") == LocalPlayer.Name then
local tt = obj:GetAttribute("TimeToHatch")
if tt ~= nil and tonumber(tt) and tonumber(tt) <= 0 then
table.insert(ready, obj)
end
end
end
end)
pcall(function()
for _, d in ipairs(workspace:GetDescendants()) do
if d.Name == "PetEgg" and d:GetAttribute("OBJECT_TYPE") == "PetEgg" then
local owner = d:GetAttribute("OWNER")
if owner ~= nil and tostring(owner) == LocalPlayer.Name then
local tth = d:GetAttribute("TimeToHatch")
if tth ~= nil and tonumber(tth) and tonumber(tth) <= 0 then
local dup = false
for _, e in ipairs(ready) do if e == d then dup = true; break end end
if not dup then table.insert(ready, d) end
end
end
end
end
end)
local n = 0
for _, egg in ipairs(ready) do
pcall(function() PetEggService:FireServer("HatchPet", egg) end)
n = n + 1
end
if n > 0 then
HatchTrack.cycleCount = HatchTrack.cycleCount + 1
HatchTrack.totalHatched = HatchTrack.totalHatched + n
task.wait(0.6)
local eggAfter = totalEggNow()
local delta = eggAfter - eggBefore
HatchTrack.lastEggBefore = eggBefore
HatchTrack.lastEggAfter = eggAfter
HatchTrack.lastEggDelta = delta
local back = math.max(0, delta)
HatchTrack.luckyHatch = HatchTrack.luckyHatch + back
if hitPetLimit() then
HatchTrack.bpFullFlag = true
else
HatchTrack.bpFullFlag = false
end
end
return n
end
local function trackSellResult(eggBefore, petBefore)
task.wait(1.2)
local petAfter = 0
pcall(function() local inv = getInventory(); for _ in pairs(inv) do petAfter = petAfter + 1 end end)
local sold = math.max(0, petBefore - petAfter)
HatchTrack.totalSold = HatchTrack.totalSold + sold
local eggAfter = totalEggNow()
local delta = eggAfter - eggBefore
HatchTrack.lastEggBefore = eggBefore
HatchTrack.lastEggAfter = eggAfter
HatchTrack.lastEggDelta = delta
if delta > 0 then HatchTrack.luckySell = HatchTrack.luckySell + delta end
HatchTrack.lastSellInv = petAfter
HatchTrack.sellExhausted = (sold == 0)
return sold
end
local function sellAllPets(logFn)
local eggBefore = totalEggNow()
local petBefore = 0
pcall(function() local inv = getInventory(); for _ in pairs(inv) do petBefore = petBefore + 1 end end)
if HatchTrack.sellExhausted and petBefore == (HatchTrack.lastSellInv or 0) then
if logFn then logFn("Sell skipped (nothing new to sell)", T.DIM) end
return 0
end
if not SellAllPetsRE then
if logFn then logFn("SellAllPets_RE not found!", T.ERROR) end
return 0
end
pcall(function() SellAllPetsRE:FireServer() end)
local sold = trackSellResult(eggBefore, petBefore)
if logFn then
local sign = HatchTrack.lastEggDelta >= 0 and "+" or ""
logFn(string.format("SELL ALL fired: %d sold (eggs %s%d)", sold, sign, HatchTrack.lastEggDelta), sold > 0 and T.SUCCESS or T.DIM)
end
return sold
end
local function sellSelectedOneByOne(logFn)
local sellList = cfg.autoHatch.sellPets or {}
local thresh = tonumber(cfg.autoHatch.sellThresh) or 0
if not SellOnePetRE then
if logFn then logFn("SellPetShopSelected not found!", T.ERROR) end
return 0
end
local sold = 0
local inv = getInventory()
for uuid, pet in pairs(inv) do
if HatchTrack.hatchRunning == false then break end
local petName = pet.PetType or ""
if sellList[petName] then
local kg = (pet.PetData and pet.PetData.BaseWeight) or 0
if thresh <= 0 or kg < thresh then
local tool = nil
for _, holder in ipairs({Character, Backpack}) do
if holder and not tool then
for _, tr in ipairs(holder:GetChildren()) do
if tr:IsA("Tool") and tr:GetAttribute(PET_UUID_KEY) == uuid then tool = tr; break end
end
end
end
if tool then
pcall(function() SellOnePetRE:FireServer(tool) end)
sold = sold + 1
if logFn then logFn(string.format("Sold %s (%.2f kg) [%d]", petName, kg, sold), T.DIM) end
task.wait(0.3)
end
end
end
end
HatchTrack.totalSold = HatchTrack.totalSold + sold
if logFn then logFn(string.format("One-by-one done: %d sold", sold), sold > 0 and T.SUCCESS or T.DIM) end
return sold
end
local function favAllPets()
local hum = Character and Character:FindFirstChildOfClass("Humanoid")
if not hum then return end
pcall(function() hum:UnequipTools() end)
task.wait(0.2)
local function isFaved(tool) return tool:GetAttribute(FAV_KEY) == true end
local totalFav = 0
local pass = 0
while true do
pass = pass + 1
if HatchTrack.hatchRunning == false then break end
if pass > 30 then print("[Velium Hub] favAllPets: pass cap reached, stopping"); break end
local unfaved = {}
for _, tool in ipairs(Backpack:GetChildren()) do
if tool:IsA("Tool") and (tool:FindFirstChild("PetToolLocal") or tool:FindFirstChild("PetToolServer")) then
if not isFaved(tool) then
table.insert(unfaved, tool)
end
end
end
if #unfaved == 0 then
break
end
for _, pet in ipairs(unfaved) do
if HatchTrack.hatchRunning == false then break end
pcall(function() FavItemRemote:FireServer(pet) end)
task.wait(0.15)
if not isFaved(pet) then
hum:EquipTool(pet)
task.wait(0.15)
pcall(function() FavItemRemote:FireServer(pet) end)
task.wait(0.15)
hum:UnequipTools()
task.wait(0.15)
end
if isFaved(pet) then totalFav = totalFav + 1 end
end
task.wait(0.3)
end
pcall(function() hum:UnequipTools() end)
end
local function unfavSellPets(delay)
local sellList = cfg.autoHatch.sellPets or {}
local allTools = {}
for _, tool in ipairs(Character:GetChildren()) do
if tool:IsA("Tool") and not CS:HasTag(tool, "PetEggTool") then
table.insert(allTools, tool)
end
end
for _, tool in ipairs(Backpack:GetChildren()) do
if tool:IsA("Tool") and not CS:HasTag(tool, "PetEggTool") then
table.insert(allTools, tool)
end
end
for _, tool in ipairs(allTools) do
if HatchTrack.hatchRunning == false then break end
if tool.Parent ~= Character then
tool.Parent = Character
task.wait(0.05)
end
local petName = tool:GetAttribute("PetType") or tool.Name
if sellList[petName] then
pcall(function() FavItemRemote:FireServer(tool) end)
task.wait(delay or 0.1)
end
end
local humU = Character and Character:FindFirstChildOfClass("Humanoid")
if humU then pcall(function() humU:UnequipTools() end) end
end
local function uuidKey(u) return tostring(u or ""):gsub("[{}]", ""):lower() end
local function waitTeamEquipped(teamName, timeoutSec)
local want = getTeamUUIDs(teamName)
if #want == 0 then return false end
timeoutSec = timeoutSec or 10
local t0 = os.clock()
while os.clock() - t0 < timeoutSec do
local have = {}
pcall(function() for _, u in ipairs(getActivePets()) do have[uuidKey(u)] = true end end)
local okAll = true
for _, u in ipairs(want) do if not have[uuidKey(u)] then okAll = false; break end end
if okAll then return true end
task.wait(1)
end
return false
end
local function wearTeam(teamName)
if not teamName then return end
local uuids = getTeamUUIDs(teamName)
if #uuids == 0 then return end
unequipAll()
task.wait(0.1)
local cf = getFarmCF()
for _, uuid in ipairs(uuids) do
pcall(function() PetsRemote:FireServer("EquipPet", uuid, cf) end)
task.wait(TIMING.EQUIP_DELAY)
end
end
runHatchCycle = function(statusFn, logFn)
local a = cfg.autoHatch
if HatchTrack.hatchRunning == false then logFn("---- Stopped by user ----", T.ERROR); return end
HatchTrack.phase = "sell"
local hasSellPets = a.sellPets and next(a.sellPets)
local sellAllMode = a.sellAll == true
if a.sellEnabled ~= false and (hasSellPets or sellAllMode) then
if sellAllMode then
logFn("SELL ALL PETS mode...", T.ACCENT)
if a.teamSeal then
logFn("Equipping Seal team...", T.DIM)
wearTeam(a.teamSeal)
task.wait(1)
end
sellAllPets(logFn)
else
logFn("Favoriting all pets...", T.DIM)
favAllPets(0.05)
task.wait(0.5)
logFn("Unfavoriting sell pets...", T.DIM)
unfavSellPets(0.05)
task.wait(0.5)
if a.teamSeal then
logFn("Equipping Seal team...", T.DIM)
wearTeam(a.teamSeal)
task.wait(1)
end
logFn("Selling selected pets one by one...", T.ACCENT)
sellSelectedOneByOne(logFn)
end
end
if HatchTrack.hatchRunning == false then logFn("---- Stopped by user ----", T.ERROR); return end
HatchTrack.phase = "cd"
if a.teamCD then logFn("Equipping CD team...", T.DIM); wearTeam(a.teamCD) end
local existingEggs = 0
for _, obj in ipairs(CS:GetTagged("PetEggServer")) do
if obj:GetAttribute("OWNER") == LocalPlayer.Name then
existingEggs = existingEggs + 1
end
end
local placed = 0
if existingEggs > 0 then
logFn(string.format("Found %d existing eggs, skipping place", existingEggs), T.DIM)
else
logFn("Placing eggs...", T.ACCENT)
if HatchTrack.hatchRunning == false then logFn("---- Stopped by user ----", T.ERROR); return end
HatchTrack.phase = "place"
placed = placeEggs(a.eggName, a.eggCount, a.eggSpacing, logFn)
if placed == 0 then logFn("No eggs to place!", T.ERROR); return end
logFn(string.format("Placed %d eggs, waiting for hatch...", placed), T.ACCENT)
end
task.wait(2)
if HatchTrack.hatchRunning == false then logFn("---- Stopped by user ----", T.ERROR); return end
HatchTrack.phase = "wait"
local timeout = os.clock() + 120
local zeroHits = 0
while os.clock() < timeout do
local eggCount = 0
local allReady = true
local seenEggs = {}
local function noteEgg(o)
if o and not seenEggs[o] then
seenEggs[o] = true
eggCount = eggCount + 1
local tth = o:GetAttribute("TimeToHatch")
if tth ~= nil and tonumber(tth) and tonumber(tth) > 0 then allReady = false end
end
end
for _, obj in ipairs(CS:GetTagged("PetEggServer")) do
if obj:GetAttribute("OWNER") == LocalPlayer.Name then noteEgg(obj) end
end
pcall(function()
for _, d in ipairs(workspace:GetDescendants()) do
if d.Name == "PetEgg" and d:GetAttribute("OBJECT_TYPE") == "PetEgg" then
local owner = d:GetAttribute("OWNER")
if owner ~= nil and tostring(owner) == LocalPlayer.Name then noteEgg(d) end
end
end
end)
if eggCount > 0 and allReady then break end
if eggCount == 0 and placed > 0 then
zeroHits = zeroHits + 1
if zeroHits == 3 or zeroHits == 6 then
logFn("No eggs detected, re-placing (try " .. zeroHits .. ")...", T.ERROR)
placed = placed + placeEggs(a.eggName, a.eggCount, a.eggSpacing, logFn)
elseif zeroHits >= 10 then
logFn("Eggs still not detected, skipping hatch", T.ERROR)
break
elseif zeroHits % 3 == 1 then
logFn("No eggs detected, waiting...", T.DIM)
end
else
zeroHits = 0
end
if HatchTrack.hatchRunning == false then logFn("---- Stopped by user ----", T.ERROR); return end
task.wait(1)
end
if HatchTrack.hatchRunning == false then logFn("---- Stopped by user ----", T.ERROR); return end
HatchTrack.phase = "koi"
if a.teamKoi then
logFn("Equipping Koi team...", T.ACCENT)
wearTeam(a.teamKoi)
if waitTeamEquipped(a.teamKoi, 10) then
logFn("Koi team verified in garden", T.SUCCESS)
else
logFn("Koi team incomplete, proceeding anyway", T.DIM)
end
task.wait(1)
end
local beforeHatch = {}
pcall(function() for uuid in pairs(getInventory()) do beforeHatch[uuid] = true end end)
hatchAllEggs()
task.wait(1)
if HatchTrack.hatchRunning == false then logFn("---- Stopped by user ----", T.ERROR); return end
HatchTrack.phase = "fire"
local hatchedNow = {}
pcall(function()
local invNow = getInventory()
for uuid, pet in pairs(invNow) do
if not beforeHatch[uuid] then
table.insert(hatchedNow, {uuid = uuid, name = pet.PetType or "Unknown", kg = (pet.PetData and pet.PetData.BaseWeight) or 0, age = (pet.PetData and pet.PetData.Level) or 0})
end
end
end)
if #hatchedNow > 0 then
logFn(string.format("Hatched %d pet(s) from %s!", #hatchedNow, a.eggName or "egg"), T.SUCCESS)
logFn(string.format("Eggs %d -> %d (%s%d) | Lucky back %d", HatchTrack.lastEggBefore, HatchTrack.lastEggAfter, HatchTrack.lastEggDelta >= 0 and "+" or "", HatchTrack.lastEggDelta, HatchTrack.luckyHatch), T.DIM)
for _, h in ipairs(hatchedNow) do
local sp = HatchTrack.species[h.name]
if not sp then sp = {n = 0, minKg = h.kg, maxKg = h.kg}; HatchTrack.species[h.name] = sp end
sp.n = sp.n + 1
if h.kg < sp.minKg then sp.minKg = h.kg end
if h.kg > sp.maxKg then sp.maxKg = h.kg end
end
local teamLines = {}
local teamMap = {Core = a.teamCD, Hatch = a.teamKoi, Special = a.teamBronto, Sell = a.teamSeal}
for label, tname in pairs(teamMap) do
teamLines[label] = "-"
if tname then
local members = getTeamUUIDs(tname)
if #members > 0 then
local byDisp = {}
for _, uuid in ipairs(members) do
local mut = getMutName(uuid)
local disp = (mut ~= "" and (mut .. " ") or "") .. getPType(uuid)
byDisp[disp] = (byDisp[disp] or 0) + 1
end
local parts = {}
for disp, c in pairs(byDisp) do table.insert(parts, c .. " " .. disp) end
table.sort(parts)
teamLines[label] = table.concat(parts, ", ")
end
end
end
if HatchTrack.hatchRunning == false then logFn("---- Stopped by user ----", T.ERROR); return end
HatchTrack.phase = "webhook"
pcall(function() sendHatchWebhook(a.eggName, hatchedNow, teamLines) end)
end
if HatchTrack.hatchRunning == false then logFn("---- Stopped by user ----", T.ERROR); return end
HatchTrack.phase = "special"
if a.specialBronto and a.specialBronto.enabled then
local brontoThresh = a.brontoThresh or 4
local selPets = a.specialBronto.pets or {}
local activePets = {}
pcall(function() activePets = getActivePets() end)
local inv = getInventory()
local kept = 0
for _, uuid in ipairs(activePets) do
if HatchTrack.hatchRunning == false then logFn("---- Stopped by user ----", T.ERROR); return end
local pet = inv[uuid]
if pet then
local kg = (pet.PetData and pet.PetData.BaseWeight) or 0
local name = pet.PetType or ""
local isSpecial = selPets[name] == true
local isHeavy = kg >= brontoThresh
if isHeavy or isSpecial then
pcall(function() PetsRemote:FireServer("UnequipPet", uuid) end)
kept = kept + 1
if isSpecial then
local ageNow = (pet.PetData and pet.PetData.Level) or 0
HatchTrack.specialTotal = HatchTrack.specialTotal + 1
if kg >= 9 then HatchTrack.godly = HatchTrack.godly + 1
elseif kg >= 7 then HatchTrack.titan = HatchTrack.titan + 1
elseif kg >= 5 then HatchTrack.huge = HatchTrack.huge + 1 end
pcall(function() sendSpecialWebhook(name, kg, kg, ageNow, a.eggName) end)
end
task.wait(0.1)
end
end
end
if kept > 0 then
logFn(string.format("Kept %d pets for Bronto (heavy >= %.1fg or special)", kept, brontoThresh), T.ACCENT)
end
end
if HatchTrack.hatchRunning == false then logFn("---- Stopped by user ----", T.ERROR); return end
HatchTrack.phase = "fav"
if a.favDelay and a.favDelay > 0 then
favAllPets(a.favDelay)
end
if HatchTrack.hatchRunning == false then logFn("---- Stopped by user ----", T.ERROR); return end
HatchTrack.phase = "autosell"
if a.sellEnabled ~= false and a.autoSellWhenFull then
local inv = getInventory()
local count = 0
for _ in pairs(inv) do count = count + 1 end
if count >= (a.petInvMax or 200) then
logFn("Inventory full - selling all...", T.ERROR)
sellAllPets(logFn)
task.wait(2)
end
end
end
end
print("[Velium Hub] TAB done: HATCH")
-- ============================================================
-- SHARED GLOBALS FOR EXTERNAL SCRIPTS
-- (Leveling page removed; outerScroll/PageLeveling assigned later in AUTOMATION tab)
-- ============================================================
do
_G.HH_Shared = {
	V = UI, UI = UI, T = T, D = cfg, CFG = TIMING,
	Player = LocalPlayer, Backpack = Backpack, Char = Character,
	MUTATION_MAP = MutJSON,
	saveD = saveConfig,
	getInv = getInventory, getKG = getKG, getAge = getAge, getBase = getBase,
	getPType = getPType, isFav = isFav, findPetTool = findPetTool,
	getMutName = getMutName,
	unequipAll = unequipAll, equipList = equipList,
	buildEquip = buildEquip, waitUntilEquipped = waitUntilEquipped,
	sendWebhook = sendWebhook, sendCycleWebhook = sendCycleWebhook,
	sendPetFinishedWebhook = sendPetFinishedWebhook, sendSpecialWebhook = sendSpecialWebhook,
	sendHatchWebhook = sendHatchWebhook,
	getActivePets = getActivePets, getFarmCF = getFarmCF,
	PetsRemote = PetsRemote, FavItemRemote = FavItemRemote,
	SellAllRemote = SellPetRE, DataService = DataService,
	outerScroll = nil,      -- assigned after AUTOMATION tab exists
	PageLeveling = nil,     -- assigned after AUTOMATION tab exists
	modalRoot = modalRoot,  -- fullscreen modal layer for module overlays
	_buildTeamDD = buildTeamDD, getTeamUUIDs = getTeamUUIDs,
}
end
-- NOTE: AutoLeveling / AutoNightmare loadstring calls moved to the end of the AUTOMATION tab
-- ============================================================
-- TEAMS TAB
-- ============================================================
print("[Velium Hub] TAB build: TEAMS")
do
local tmSection = spSection(tabTeams, "PET TEAMS", true)
local tmScroll = tmSection:GetContainer()

-- Title
spLabel(tmSection, 0, "Pet Teams")

-- Save row
local teamNameInp
teamNameInp = spInput(tmSection, 1, "Team Name", "Nama team baru...", "", function() end)
local saveBtn
saveBtn = spButton(tmSection, 2, "Save Active Pets", "Simpan pet yang sedang di-equip", "", function() end)

-- Status message
local saveMsg
local function setSaveMsg(text, color)
saveMsg:Set(text ~= "" and text or " ", "")
saveMsg.Title.TextColor3 = color or T.DIM
end

-- ── BUILT-IN TEAMS label + container (rendered ABOVE saved teams)
spLabel(tmSection, 3, "Built-In Teams")

local builtinContainer = Instance.new("Frame")
builtinContainer.BackgroundTransparency = 1
builtinContainer.Size = UDim2.new(1,0,0,0)
builtinContainer.LayoutOrder = 4
builtinContainer.AutomaticSize = Enum.AutomaticSize.Y
builtinContainer.Parent = tmScroll
UI:list(builtinContainer, 4)

-- ── SAVED TEAMS label + container (rendered BELOW built-ins)
spLabel(tmSection, 5, "Saved Teams")

local teamsContainer = Instance.new("Frame")
teamsContainer.BackgroundTransparency = 1
teamsContainer.Size = UDim2.new(1,0,0,0)
teamsContainer.LayoutOrder = 6
teamsContainer.AutomaticSize = Enum.AutomaticSize.Y
teamsContainer.Parent = tmScroll
UI:list(teamsContainer, 4)

saveMsg = spLabel(tmSection, 7, " ")

-- ── Inline card builders — pixel-matched to old Velium Hub design ──
-- Layout per card:
--   [32px logo, no background] [content: BUILT-IN pill + name bold + desc dim] [right: swap btn]
-- Card height: 56px. Logo left-anchored at 10px. Content starts at 46px. Right btn at -36px.

local VELIUM_ICON = "rbxassetid://118973578063038"
local CARD_BG    = Color3.fromRGB(24, 24, 31)

local function makeVeliumIcon(card)
	-- Logo only: plain image, no circle, no rings, no tint
	local img = Instance.new("ImageLabel", card)
	img.Size = UDim2.new(0, 32, 0, 32)
	img.Position = UDim2.new(0, 10, 0.5, -16)
	img.BackgroundTransparency = 1
	img.BorderSizePixel = 0
	img.Image = VELIUM_ICON
	img.ScaleType = Enum.ScaleType.Fit
	img.ImageTransparency = 0
	img.ImageColor3 = Color3.fromRGB(255, 255, 255)
end

local function makeBadge(card, x, y)
	-- BUILT-IN pill badge
	local badge = Instance.new("Frame", card)
	badge.Size = UDim2.new(0, 62, 0, 15)
	badge.Position = UDim2.new(0, x, 0, y)
	badge.BackgroundColor3 = Color3.fromRGB(24, 66, 60)
	badge.BorderSizePixel = 0
	local c = Instance.new("UICorner", badge); c.CornerRadius = UDim.new(1, 0)
	local stroke = Instance.new("UIStroke", badge)
	stroke.Color = Color3.fromRGB(52, 160, 150)
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	-- Icon prefix inside badge
	local icon = Instance.new("TextLabel", badge)
	icon.Size = UDim2.new(0, 14, 1, 0)
	icon.Position = UDim2.new(0, 2, 0, 0)
	icon.BackgroundTransparency = 1
	icon.Text = "⚡"
	icon.TextColor3 = Color3.fromRGB(128, 255, 234)
	icon.Font = Enum.Font.GothamBold
	icon.TextSize = 8
	icon.TextXAlignment = Enum.TextXAlignment.Center
	icon.TextYAlignment = Enum.TextYAlignment.Center
	local lbl = Instance.new("TextLabel", badge)
	lbl.Size = UDim2.new(1, -14, 1, 0)
	lbl.Position = UDim2.new(0, 14, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = "BUILT-IN"
	lbl.TextColor3 = Color3.fromRGB(245, 243, 236)
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 8
	lbl.TextXAlignment = Enum.TextXAlignment.Center
	lbl.TextYAlignment = Enum.TextYAlignment.Center
end

local function makeSwapBtn(card, onEquip)
	-- Purple swap button — right side, vertically centered
	local btn = Instance.new("TextButton", card)
	btn.Size = UDim2.new(0, 30, 0, 30)
	btn.Position = UDim2.new(1, -36, 0.5, -15)
	btn.BackgroundColor3 = Color3.fromRGB(24, 66, 60)
	btn.BorderSizePixel = 0
	btn.Text = "⇄"
	btn.TextColor3 = Color3.fromRGB(128, 255, 234)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	local c = Instance.new("UICorner", btn); c.CornerRadius = UDim.new(0, 7)
	btn.MouseButton1Click:Connect(onEquip)
	return btn
end

local function makeDeleteBtn(card, onDelete)
	-- Red circle delete button — right side
	local btn = Instance.new("TextButton", card)
	btn.Size = UDim2.new(0,28,0,28)
	btn.Position = UDim2.new(1,-70,0.5,-14)
	btn.BackgroundColor3 = Color3.fromRGB(160,30,30)
	btn.BorderSizePixel = 0
	btn.Text = "X"
	btn.TextColor3 = Color3.fromRGB(255,255,255)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 12
	btn.TextXAlignment = Enum.TextXAlignment.Center
	btn.TextYAlignment = Enum.TextYAlignment.Center
	local c = Instance.new("UICorner", btn); c.CornerRadius = UDim.new(1,0)
	local s = Instance.new("UIStroke", btn)
	s.Color = Color3.fromRGB(200,60,60); s.Thickness = 1
	btn.MouseButton1Click:Connect(onDelete)
	return btn
end

local function buildBuiltinCard(parent, teamName, teamDesc, order, onEquip)
	local singleDesc = tostring(teamDesc or ""):gsub("\n", " | ")
	local card = Instance.new("Frame", parent)
	card.Size = UDim2.new(1, 0, 0, 58)
	card.BackgroundColor3 = Color3.fromRGB(24, 24, 31)
	card.BorderSizePixel = 0
	card.LayoutOrder = order
	local co = Instance.new("UICorner", card); co.CornerRadius = UDim.new(0, 7)
	local st = Instance.new("UIStroke", card)
	st.Color = Color3.fromRGB(24, 66, 60); st.Thickness = 1
	-- Left purple accent bar
	local accentBar = Instance.new("Frame", card)
	accentBar.Size = UDim2.new(0, 3, 1, -10)
	accentBar.Position = UDim2.new(0, 0, 0, 5)
	accentBar.BackgroundColor3 = Color3.fromRGB(128, 255, 234)
	accentBar.BorderSizePixel = 0
	local ab = Instance.new("UICorner", accentBar); ab.CornerRadius = UDim.new(0, 4)

	makeVeliumIcon(card)

	-- BUILT-IN badge — sits top of content column, x=52 to clear the new wider icon
	makeBadge(card, 62, 5)

	-- Team name — below badge, bold
	local nameLbl = Instance.new("TextLabel", card)
	nameLbl.Size = UDim2.new(1, -96, 0, 15)
	nameLbl.Position = UDim2.new(0, 62, 0, 22)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = tostring(teamName or "?")
	nameLbl.TextColor3 = Color3.fromRGB(245, 243, 236)
	nameLbl.Font = Enum.Font.GothamBold
	nameLbl.TextSize = 11
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.TextTruncate = Enum.TextTruncate.AtEnd

	-- Description — dim, small, below name
	local descLbl = Instance.new("TextLabel", card)
	descLbl.Size = UDim2.new(1, -96, 0, 12)
	descLbl.Position = UDim2.new(0, 62, 0, 39)
	descLbl.BackgroundTransparency = 1
	descLbl.Text = singleDesc
	descLbl.TextColor3 = Color3.fromRGB(166, 164, 160)
	descLbl.Font = Enum.Font.Gotham
	descLbl.TextSize = 9
	descLbl.TextXAlignment = Enum.TextXAlignment.Left
	descLbl.TextTruncate = Enum.TextTruncate.AtEnd

	makeSwapBtn(card, onEquip)
end

local function buildSavedCard(parent, teamName, petNamesStr, petCount, order, onEquip, onDelete)
	local card = Instance.new("Frame", parent)
	card.Size = UDim2.new(1,0,0,56)
	card.BackgroundColor3 = CARD_BG
	card.BorderSizePixel = 0
	card.LayoutOrder = order
	local co = Instance.new("UICorner", card); co.CornerRadius = UDim.new(0,6)
	local st = Instance.new("UIStroke", card); st.Color = T.STROKE; st.Thickness = 1

	makeVeliumIcon(card)

	-- Team name — bold, vertically offset so it sits upper-center of card
	local nameLbl = Instance.new("TextLabel", card)
	nameLbl.Size = UDim2.new(1,-124,0,16)
	nameLbl.Position = UDim2.new(0,62,0,14)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = tostring(teamName or "?")
	nameLbl.TextColor3 = T.TEXT
	nameLbl.Font = Enum.Font.GothamBold
	nameLbl.TextSize = 11
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.TextTruncate = Enum.TextTruncate.AtEnd

	-- Pet list — dim, small, below name
	local descLbl = Instance.new("TextLabel", card)
	descLbl.Size = UDim2.new(1,-124,0,13)
	descLbl.Position = UDim2.new(0,62,0,33)
	descLbl.BackgroundTransparency = 1
	descLbl.Text = petNamesStr
	descLbl.TextColor3 = T.DIM
	descLbl.Font = Enum.Font.Gotham
	descLbl.TextSize = 9
	descLbl.TextXAlignment = Enum.TextXAlignment.Left
	descLbl.TextTruncate = Enum.TextTruncate.AtEnd

	makeDeleteBtn(card, onDelete)
	makeSwapBtn(card, onEquip)
end

local ddRefs = {}

local function rebuildTeams()
	-- Clear built-in container
	for _, c in ipairs(builtinContainer:GetChildren()) do
		if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end
	end
	-- Clear saved container
	for _, c in ipairs(teamsContainer:GetChildren()) do
		if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end
	end

	-- ── Render built-in teams (always in builtinContainer)
	local builtins = (function() local s = _G._NH_BUILTIN_TEAMS; if type(s) ~= "table" then return builtInTeams end; for _, t in ipairs(s) do if type(t) ~= "table" or type(t.name) ~= "string" then return builtInTeams end end; return s end)()
	for i, team in ipairs(builtins) do
		local idx = i
		local okCard, cardErr = pcall(function()
			buildBuiltinCard(builtinContainer, team.name, team.desc, i, function()
				task.spawn(function()
					local uuids = getTeamUUIDs(team.name)
					if #uuids == 0 then return end
					unequipAll()
					task.wait(0.1)
					local cf = getFarmCF()
					for _, uuid in ipairs(uuids) do
						pcall(function() PetsRemote:FireServer("EquipPet", uuid, cf) end)
						task.wait(TIMING.EQUIP_DELAY)
					end
				end)
			end)
		end)
		if not okCard then warn("[Velium Hub] builtin card " .. tostring(i) .. " failed: " .. tostring(cardErr)) end
	end

	-- ── Render saved teams (always in teamsContainer)
	local teamNames = {}
	for name in pairs(cfg.petTeams) do table.insert(teamNames, name) end
	table.sort(teamNames)

	if #teamNames == 0 then
		local lbl = UI:label(teamsContainer, "(no teams saved yet)", UDim2.new(1,0,0,22), nil, T.TEXT, 11)
		lbl.Font = Enum.Font.Gotham; lbl.LayoutOrder = 1
		return
	end

	local inv = {}
	pcall(function() inv = getInventory() end)

	for i, name in ipairs(teamNames) do
		local teamData = cfg.petTeams[name]
		local petNames = {}
		for _, uuid in ipairs(teamData.uuids or {}) do
			local pet = inv[uuid]
			if pet and pet.PetType then
				local mut = (pet.PetData and pet.PetData.MutationType) or ""
				local mutName = (mut ~= "" and mut ~= "m" and (MutJSON and MutJSON[mut]) or "") or ""
				local display = mutName ~= "" and (pet.PetType .. " [" .. mutName .. "]") or pet.PetType
				table.insert(petNames, display)
			end
		end
		local petNamesStr = #petNames > 0 and table.concat(petNames, ", ") or "No pets found"
		local capturedName = name
		local capturedData = teamData
		local okCard2, cardErr2 = pcall(function() buildSavedCard(teamsContainer, name, petNamesStr, #(teamData.uuids or {}), i,
			function()
				task.spawn(function()
					local ok2, active = pcall(getActivePets)
					if not ok2 then return end
					local uuids = capturedData.uuids or {}
					local allActive = true
					for _, uuid in ipairs(uuids) do
						local found = false
						for _, a in ipairs(active) do if a == uuid then found = true; break end end
						if not found then allActive = false; break end
					end
					if allActive and #uuids > 0 then
						for _, uuid in ipairs(uuids) do
							pcall(function() PetsRemote:FireServer("UnequipPet", uuid) end)
							task.wait(TIMING.EQUIP_DELAY)
						end
					else
						unequipAll()
						task.wait(0.1)
						local cf = getFarmCF()
						for _, uuid in ipairs(uuids) do
							pcall(function() PetsRemote:FireServer("EquipPet", uuid, cf) end)
							task.wait(TIMING.EQUIP_DELAY)
						end
					end
				end)
			end,
			function()
				cfg.petTeams[capturedName] = nil
				if cfg.leveling.mainTeam == capturedName then cfg.leveling.mainTeam = nil end
				if cfg.leveling.optTeam == capturedName then cfg.leveling.optTeam = nil end
				if cfg.elephant.levelingTeam == capturedName then cfg.elephant.levelingTeam = nil end
				if cfg.elephant.elephantTeam == capturedName then cfg.elephant.elephantTeam = nil end
				if cfg.elephant.phase2Team == capturedName then cfg.elephant.phase2Team = nil end
				saveConfig(); rebuildTeams()
				for _, ref in ipairs(ddRefs) do pcall(function() ref.Refresh() end) end
			end
		)
		end)
		if not okCard2 then warn("[Velium Hub] saved card " .. tostring(name) .. " failed: " .. tostring(cardErr2)) end
	end

	-- Force the PET TEAMS section to re-measure so cards aren't clipped
	task.defer(function() pcall(function() tmSection:Resize() end) end)
end

saveBtn.ButtonButton.Activated:Connect(function()
	local name = teamNameInp.Value
	if name == nil or name == "" then name = "Team_" .. (os.time() % 10000) end
	local ok, active = pcall(getActivePets)
	if not ok or #active == 0 then
		setSaveMsg("No active pets found! Equip pets first.", T.ERROR)
		task.delay(3, function() setSaveMsg("") end)
		return
	end
	cfg.petTeams[name] = {uuids = active}
	saveConfig()
	teamNameInp:Set("")
	setSaveMsg("Saved '" .. name .. "' (" .. #active .. " pets)", T.SUCCESS)
	task.delay(3, function() setSaveMsg("") end)
	local ok2, err = pcall(rebuildTeams)
	if not ok2 then warn("[Velium Hub] rebuildTeams error: " .. tostring(err)) end
	for _, ref in ipairs(ddRefs) do pcall(function() ref.Refresh() end) end
end)

_G._NH_BUILTIN_TEAMS = builtInTeams
_G._NH_rebuildTeams = rebuildTeams
_G._NH_ddRefs = ddRefs
local okBuild, buildErr = pcall(rebuildTeams)
if not okBuild then warn("[Velium Hub] rebuildTeams failed: " .. tostring(buildErr)) end
end
print("[Velium Hub] TAB done: TEAMS")

-- ============================================================
-- MISC TAB
-- ============================================================
print("[Velium Hub] TAB build: MISC")
do
local visSec = spSection(tabMisc, "VISIBILITY", true)
local visConnections = {}
local function hidePart(obj)
if obj:IsA("BasePart") or obj:IsA("UnionOperation") or obj:IsA("MeshPart") then
pcall(function() obj.Transparency = 1 end)
end
if obj:IsA("Decal") or obj:IsA("Texture") then
pcall(function() obj.Transparency = 1 end)
end
if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then
pcall(function() obj.Enabled = false end)
end
if obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
pcall(function() obj.Enabled = false end)
end
end
local function hideFarmPlants()
local farm = workspace:FindFirstChild("Farm")
if not farm then return end
local function processPlot(plot)
local important = plot:FindFirstChild("Important")
if not important then return end
local plants = important:FindFirstChild("Plants_Physical")
if not plants then return end
for _, desc in ipairs(plants:GetDescendants()) do hidePart(desc) end
table.insert(visConnections, plants.DescendantAdded:Connect(function(d) task.wait(); hidePart(d) end))
end
for _, plot in ipairs(farm:GetChildren()) do processPlot(plot) end
table.insert(visConnections, farm.ChildAdded:Connect(function(p) task.wait(0.5); processPlot(p) end))
end
spToggle(visSec, 1, "Hide Farm Plants", "", cfg.toggles.hidePlants, function(val)
cfg.toggles.hidePlants = val; saveConfig(); VeliumNotify("Hide Plants", val)
if val then hideFarmPlants()
else
for _, c in ipairs(visConnections) do pcall(function() c:Disconnect() end) end
table.clear(visConnections)
end
end)
spToggle(visSec, 2, "Hide Notification", "", cfg.toggles.hideNotif, function(val)
cfg.toggles.hideNotif = val; saveConfig()
end)
end
do
local arSec = spSection(tabMisc, "AUTO RENEW SERVER", true)
spLabel(arSec, 1, "Job: " .. tostring(game.JobId))
spLabel(arSec, 2, "Version: " .. tostring(game.PlaceVersion))
local rsInterval = cfg.misc.rsInterval
do
local intInput
intInput = spInput(arSec, 3, "Interval (min)", "Auto rejoin countdown", tostring(rsInterval), function(v)
local val = tonumber(v)
if val and val >= 1 then rsInterval = val; cfg.misc.rsInterval = val; saveConfig()
elseif intInput then intInput:Set(tostring(rsInterval)) end
end)
end
local cdLbl
do
local cdRow = UI:frame(arSec:GetContainer(), UDim2.new(1,0,0,22), nil, T.DARK_CARD)
cdRow.LayoutOrder = 4
UI:corner(cdRow,5); UI:stroke(cdRow,T.STROKE,1)
cdLbl = UI:label(cdRow, "Next rejoin: --:--", UDim2.new(1,0,1,0), UDim2.new(0,8,0,0), T.DIM, 9)
cdLbl.Font = Enum.Font.Gotham; cdLbl.TextXAlignment = Enum.TextXAlignment.Left
end
local running = false
spToggle(arSec, 5, "AUTO RENEW", "", cfg.toggles.autoRefresh, function(val)
cfg.toggles.autoRefresh = val; saveConfig(); VeliumNotify("Auto Renew", val)
if val then
running = true
task.spawn(function()
while running do
local total = rsInterval * 60
local elapsed = 0
while elapsed < total and running do
local rem = total - elapsed
cdLbl.Text = string.format("Next rejoin: %02d:%02d", math.floor(rem/60), math.floor(rem%60))
task.wait(1); elapsed = elapsed + 1
end
if running then
cdLbl.Text = "Rejoining..."
task.wait(0.5)
pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
end
end
end)
else
running = false; cdLbl.Text = "Next rejoin: --:--"
end
end)
end
do
local twSec = spSection(tabMisc, "TRADE WORLD", true)
local statusLabel
do
local row = UI:frame(twSec:GetContainer(), UDim2.new(1,0,0,22), nil, T.DARK_CARD)
row.LayoutOrder = 1
UI:corner(row,5); UI:stroke(row,T.STROKE,1)
statusLabel = UI:label(row, "Trade World: IDLE", UDim2.new(1,0,1,0), UDim2.new(0,8,0,0), T.DIM, 9)
statusLabel.Font = Enum.Font.Gotham
end
local tradeRunning = false
local TravelToTradeWorld = RS:WaitForChild("GameEvents"):WaitForChild("TradeWorld"):FindFirstChild("TravelToTradeWorld")
local TravelToMainWorld = RS:WaitForChild("GameEvents"):FindFirstChild("TravelToMainWorld")
spToggle(twSec, 2, "Auto Go To Trade World", "Cycle between trade world and main world", cfg.toggles.autoTradeWorld, function(val)
cfg.toggles.autoTradeWorld = val; saveConfig(); VeliumNotify("Trade World", val)
if val then
tradeRunning = true
statusLabel.Text = "Trade World: TRADING"
statusLabel.TextColor3 = T.SUCCESS
task.spawn(function()
while tradeRunning do
if TravelToTradeWorld then pcall(function() TravelToTradeWorld:FireServer() end) end
task.wait(5)
if not tradeRunning then break end
if TravelToMainWorld then pcall(function() TravelToMainWorld:FireServer() end) end
task.wait(5)
end
end)
else
tradeRunning = false
statusLabel.Text = "Trade World: IDLE"
statusLabel.TextColor3 = T.DIM
end
end)
end
do
local buySec = spSection(tabMisc, "AUTO BUY", true)
local buyOv = UI:frame(modalRoot, UDim2.new(1,0,1,0), nil, T.BG)
buyOv.Visible = false; buyOv.ZIndex = 25
local buyBar = UI:frame(buyOv, UDim2.new(1,0,0,30), nil, T.PANEL)
UI:stroke(buyBar, T.STROKE, 1)
local buyTitle = UI:label(buyBar, "Select items", UDim2.new(1,-100,1,0), UDim2.new(0,8,0,0), T.ACCENT, 10)
local buyAllBtn = UI:button(buyBar, "All", UDim2.new(0,40,0,22), UDim2.new(1,-92,0.5,-11), T.BTN, T.ACCENT, 9)
UI:stroke(buyAllBtn, T.ACCENT, 1)
local buyX = UI:button(buyBar, "X", UDim2.new(0,24,0,22), UDim2.new(1,-28,0.5,-11), T.ERROR, T.TEXT, 10)
UI:stroke(buyX, T.ERROR, 1)
local buySearch = UI:input(buyOv, "", "Search...", UDim2.new(1,-8,0,22), UDim2.new(0,4,0,34))
buySearch.TextColor3 = T.TEXT
local buySF = UI:scroll(buyOv, UDim2.new(1,0,1,-60), UDim2.new(0,0,0,58))
UI:list(buySF, 3); UI:pad(buySF, 3,4,4,3)
local buyKind, buyKindDK = "egg", "PetEggData"
local buyLbls = {}
local function refreshBuyLbl()
for k, btn in pairs(buyLbls) do
local st = cfg.autoBuy and cfg.autoBuy[k]
local n = 0
if st and st.items then for _ in pairs(st.items) do n = n + 1 end end
local txt = n == 0 and "NONE" or (n .. " selected")
btn:Set(nil, txt)
btn.Content.TextColor3 = n == 0 and T.DIM or T.ACCENT
end
end
local function rebuildBuy()
for _, c in ipairs(buySF:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
local q = string.lower(buySearch.Text)
local st = cfg.autoBuy and cfg.autoBuy[buyKind]
if not st then return end
if not st.items then st.items = {} end
local n = 0
for _, name in ipairs(BuySys.getBuyItemList(buyKindDK)) do
if q ~= "" and not string.lower(name):find(q, 1, true) then continue end
n = n + 1
local sel = st.items[name] == true
local b = UI:button(buySF, name, UDim2.new(1,0,0,26), nil,
sel and T.SEL_BG or Color3.fromRGB(13,13,13), sel and T.SEL_TXT or T.TEXT, 9)
b.LayoutOrder = n; b.TextXAlignment = Enum.TextXAlignment.Left
UI:pad(b, 0, 8, 2, 0); UI:corner(b, 5); UI:stroke(b, sel and T.ACCENT or T.STROKE, 1)
local nm = name
b.MouseButton1Click:Connect(function()
if st.items[nm] then st.items[nm] = nil else st.items[nm] = true end
saveConfig(); refreshBuyLbl(); rebuildBuy()
end)
end
end
local function openBuyPicker(kind, title, dk)
buyKind, buyKindDK = kind, dk
buyTitle.Text = title
buySearch.Text = ""
rebuildBuy()
buyOv.Visible = true
end
buyX.MouseButton1Click:Connect(function() buyOv.Visible = false; refreshBuyLbl() end)
buySearch:GetPropertyChangedSignal("Text"):Connect(rebuildBuy)
buyAllBtn.MouseButton1Click:Connect(function()
local st = cfg.autoBuy and cfg.autoBuy[buyKind]
if not st then return end
if not st.items then st.items = {} end
local allSel = true
for _, name in ipairs(BuySys.getBuyItemList(buyKindDK)) do
if not st.items[name] then allSel = false; break end
end
for _, name in ipairs(BuySys.getBuyItemList(buyKindDK)) do
st.items[name] = allSel and nil or true
end
saveConfig(); refreshBuyLbl(); rebuildBuy()
end)
local buySpecs = {
{key = "seed", label = "Auto Buy Seeds", pick = "Seeds", dk = "SeedData"},
{key = "egg", label = "Auto Buy Eggs", pick = "Eggs", dk = "PetEggData"},
{key = "gear", label = "Auto Buy Gears", pick = "Gears", dk = "GearData"},
}
for bi, spec in ipairs(buySpecs) do
local kk = spec.key
if not cfg.autoBuy[kk] then cfg.autoBuy[kk] = {on=false, items={}} end
spToggle(buySec, bi * 2 - 1, spec.label, "", cfg.autoBuy[kk].on, function(val)
cfg.autoBuy[kk].on = val; saveConfig()
end)
local dk2, tt2 = spec.dk, "Select " .. spec.pick
local selBtn = spButton(buySec, bi * 2, "Select " .. spec.pick, "NONE", "", function()
openBuyPicker(kk, tt2, dk2)
end)
buyLbls[kk] = selBtn
end
refreshBuyLbl()
end
print("[Velium Hub] Building INTERFACE accordion...")
local ifSec = spSection(tabMisc, "INTERFACE", true)
do
local scaleNames = {"SMALL", "MEDIUM", "BIG", "MASSIVE"}
spDropdown(ifSec, 1, "Interface Scale", "Resize the whole hub UI", false, scaleNames, {cfg.uiScale or "MEDIUM"}, function(v)
cfg.uiScale = v[1] or "MEDIUM"; saveConfig()
applyInterfaceScale()
end)
end
print("[Velium Hub] INTERFACE accordion built.")
print("[Velium Hub] TAB done: MISC")

-- ============================================================
-- WEBHOOK TAB
-- ============================================================
print("[Velium Hub] TAB build: WEBHOOK")
do
local whSec = spSection(tabWebhook, "WEBHOOK", true)

-- URL input
spInput(whSec, 1, "Webhook URL", "Paste Discord webhook URL...", cfg.webhook.url or "", function(v)
cfg.webhook.url = v; saveConfig()
end)

-- Continue Session toggle
spToggle(whSec, 3, "🔄 Continue Session (after rejoin)", "", cfg.webhook.continueSession, function(val)
cfg.webhook.continueSession = val; saveConfig()
end)

-- Reset Session Data button
local resetBtn = spButton(whSec, 4, "Reset Session Data", "Clear stored session + cycle data", "🔄", function()
cfg.webhook.sessionData = nil
cfg.webhook.lastCycle = nil
cfg.webhook.lastPet = nil
cfg.webhook.lastSync = nil
saveConfig()
resetBtn:Set("✅ Session Data Reset!", "Cleared")
task.delay(2, function()
resetBtn:Set("Reset Session Data", "Clear stored session + cycle data")
end)
end)

-- Send Test button
local testBtn = spButton(whSec, 9, "Send Test", "Send a test embed to your webhook", "📡", function()
testBtn:Set("Sending...", "")
sendTestWebhook()
task.delay(2, function() testBtn:Set("Send Test", "Send a test embed to your webhook") end)
end)
end
print("[Velium Hub] TAB done: WEBHOOK")

-- ============================================================
-- AUTOMATION TAB (hosts Leveling, Nightmare, Elephant, Mutation, Gift)
-- ============================================================
print("[Velium Hub] TAB build: AUTOMATION")
do
local levelBox = spSection(tabAuto, "LEVELING", true):GetContainer()
local nightmareBox = spSection(tabAuto, "NIGHTMARE", false):GetContainer()
-- u2500u2500 Placeholder containers for external modules (fixed LayoutOrder) u2500u2500
_G.HH_Shared.lvContainer = levelBox
_G.HH_Shared.nmContainer = nightmareBox
-- ============ AUTO ELEPHANT (moved from old ELEPHANT tab) ============
do
local eleSec = spSection(tabAuto, "AUTO ELEPHANT", true)
local eleInner = eleSec:GetContainer()
spTeamDD(eleSec, 1, "Select pet team for leveling 1-50", cfg.elephant, "levelingTeam")
spTeamDD(eleSec, 4, "Select team for elephant", cfg.elephant, "elephantTeam")
spToggle(eleSec, 10, "Level to 100 after target weight", "", cfg.elephant.levelTo100, function(val)
cfg.elephant.levelTo100 = val; saveConfig()
end)
do
local opts = {"1 Pet", "2 Pets", "3 Pets"}
local keyOf = {["1 Pet"]="1",["2 Pets"]="2",["3 Pets"]="3"}
local nameOf = {["1"]="1 Pet",["2"]="2 Pets",["3"]="3 Pets"}
local cur = nameOf[tostring(cfg.elephant.gardenSlots or 1)] or "1 Pet"
spDropdown(eleSec, 11, "Target in Garden", "Berapa pet target diproses sekaligus", false, opts, {cur}, function(v)
cfg.elephant.gardenSlots = tonumber(keyOf[v[1]] or "1"); saveConfig()
end)
end
do
local opts = {"Mode A - All Target", "Mode B - One By one"}
local keyOf = {["Mode A - All Target"]="A",["Mode B - One By one"]="B"}
local nameOf = {A="Mode A - All Target", B="Mode B - One By one"}
local cur = nameOf[cfg.elephant.gardenMode or "A"] or "Mode A - All Target"
spDropdown(eleSec, 12, "Garden Mode", "Cara equip target pet", false, opts, {cur}, function(v)
cfg.elephant.gardenMode = keyOf[v[1]] or "A"; saveConfig()
end)
end
spToggle(eleSec, 13, "Extra Filler Pets (swap saat capai threshold)", "", cfg.elephant.useExtraPets or false, function(val)
cfg.elephant.useExtraPets = val; saveConfig()
end)
local efCountLbl
do
local efOpen
local function efUpdate()
local n = 0; for _ in pairs(cfg.elephant.extraPets) do n = n + 1 end
local txt = n == 0 and "NONE" or (n .. " selected")
efCountLbl:Set("Select Extra Filler Pets", txt)
efCountLbl.Content.TextColor3 = n == 0 and T.DIM or T.ACCENT
end
efCountLbl = spButton(eleSec, 14, "Select Extra Filler Pets", "NONE", "", function() if efOpen then efOpen() end end)
local ov = UI:frame(modalRoot, UDim2.new(1,0,1,0), nil, T.BG)
ov.Visible = false; ov.ZIndex = 20
local oh = UI:frame(ov, UDim2.new(1,0,0,26), nil, T.PANEL)
UI:stroke(oh, T.STROKE, 1)
UI:label(oh, "Select Extra Filler Pets", UDim2.new(1,-36,1,0), UDim2.new(0,8,0,0), T.ACCENT, 10)
local ox = UI:button(oh, "X", UDim2.new(0,24,0,20), UDim2.new(1,-28,0.5,-10), T.ERROR, T.TEXT, 10)
UI:stroke(ox, T.ERROR, 1)
ox.MouseButton1Click:Connect(function() ov.Visible = false; efUpdate() end)
local oSearch = UI:input(ov, "", "Search pet...", UDim2.new(1,-8,0,22), UDim2.new(0,4,0,28))
oSearch.TextColor3 = T.TEXT; oSearch.Font = Enum.Font.Gotham
local ofr = UI:scroll(ov, UDim2.new(1,0,1,-56), UDim2.new(0,0,0,54))
UI:list(ofr, 3); UI:pad(ofr, 3,4,4,3)
local function rebuild()
for _, c in ipairs(ofr:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
local inv = getInventory(); local q = string.lower(oSearch.Text)
local us = {}; for u in pairs(inv) do table.insert(us, u) end
table.sort(us, function(a,b) return getKG(a) > getKG(b) end)
local n = 0
for _, uuid in ipairs(us) do
local pet = inv[uuid]
if not pet then continue end
if q ~= "" and not string.lower(pet.PetType or ""):find(q,1,true) then continue end
if table.find(cfg.targets, uuid) then continue end
local sel = cfg.elephant.extraPets[uuid] == true
local txt = string.format("%s | Age %d | %.2f KG", pet.PetType or "?", getAge(uuid), getKG(uuid))
local b = UI:button(ofr, txt, UDim2.new(1,0,0,22), nil, sel and T.SEL_BG or Color3.fromRGB(13,13,13), sel and T.SEL_TXT or T.TEXT, 9)
b.LayoutOrder = n; b.TextXAlignment = Enum.TextXAlignment.Left
UI:pad(b,0,8,4,0); UI:stroke(b, sel and T.ACCENT or T.STROKE, 1)
b.MouseButton1Click:Connect(function()
if cfg.elephant.extraPets[uuid] then cfg.elephant.extraPets[uuid] = nil else cfg.elephant.extraPets[uuid] = true end
saveConfig(); efUpdate(); rebuild() end)
n = n + 1 end
end
oSearch:GetPropertyChangedSignal("Text"):Connect(rebuild)
efOpen = function() ov.Visible = true; rebuild() end
efUpdate()
end
spToggle(eleSec, 15, "Extra Ele Filler Pets (swap saat capai target KG)", "", cfg.elephant.useExtraElePets or false, function(val)
cfg.elephant.useExtraElePets = val; saveConfig()
end)
local eefCountLbl
do
local eefOpen
local function eefUpdate()
local n = 0; for _ in pairs(cfg.elephant.extraElePets) do n = n + 1 end
local txt = n == 0 and "NONE" or (n .. " selected")
eefCountLbl:Set("Select Extra Ele Filler Pets", txt)
eefCountLbl.Content.TextColor3 = n == 0 and T.DIM or T.ACCENT
end
eefCountLbl = spButton(eleSec, 16, "Select Extra Ele Filler Pets", "NONE", "", function() if eefOpen then eefOpen() end end)
local ov = UI:frame(modalRoot, UDim2.new(1,0,1,0), nil, T.BG)
ov.Visible = false; ov.ZIndex = 20
local oh = UI:frame(ov, UDim2.new(1,0,0,26), nil, T.PANEL)
UI:stroke(oh, T.STROKE, 1)
UI:label(oh, "Select Extra Ele Filler Pets", UDim2.new(1,-36,1,0), UDim2.new(0,8,0,0), T.ACCENT, 10)
local ox = UI:button(oh, "X", UDim2.new(0,24,0,20), UDim2.new(1,-28,0.5,-10), T.ERROR, T.TEXT, 10)
UI:stroke(ox, T.ERROR, 1)
ox.MouseButton1Click:Connect(function() ov.Visible = false; eefUpdate() end)
local oSearch2 = UI:input(ov, "", "Search pet...", UDim2.new(1,-8,0,22), UDim2.new(0,4,0,28))
oSearch2.TextColor3 = T.TEXT; oSearch2.Font = Enum.Font.Gotham
local ofr = UI:scroll(ov, UDim2.new(1,0,1,-56), UDim2.new(0,0,0,54))
UI:list(ofr, 3); UI:pad(ofr, 3,4,4,3)
local function rebuild()
for _, c in ipairs(ofr:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
local inv = getInventory(); local q = string.lower(oSearch2.Text)
local us = {}; for u in pairs(inv) do table.insert(us, u) end
table.sort(us, function(a,b) return getKG(a) > getKG(b) end)
local n = 0
for _, uuid in ipairs(us) do
local pet = inv[uuid]
if not pet then continue end
if q ~= "" and not string.lower(pet.PetType or ""):find(q,1,true) then continue end
if table.find(cfg.targets, uuid) then continue end
local sel = cfg.elephant.extraElePets[uuid] == true
local txt = string.format("%s | Age %d | %.2f KG", pet.PetType or "?", getAge(uuid), getKG(uuid))
local b = UI:button(ofr, txt, UDim2.new(1,0,0,22), nil, sel and T.SEL_BG or Color3.fromRGB(13,13,13), sel and T.SEL_TXT or T.TEXT, 9)
b.LayoutOrder = n; b.TextXAlignment = Enum.TextXAlignment.Left
UI:pad(b,0,8,4,0); UI:stroke(b, sel and T.ACCENT or T.STROKE, 1)
b.MouseButton1Click:Connect(function()
if cfg.elephant.extraElePets[uuid] then cfg.elephant.extraElePets[uuid] = nil else cfg.elephant.extraElePets[uuid] = true end
saveConfig(); eefUpdate(); rebuild() end)
n = n + 1 end
end
oSearch2:GetPropertyChangedSignal("Text"):Connect(rebuild)
eefOpen = function() ov.Visible = true; rebuild() end
eefUpdate()
end
spToggle(eleSec, 20, "[ Optional ] Phase 2 team (X - 100)", "", cfg.elephant.phase2Enabled, function(val)
cfg.elephant.phase2Enabled = val; saveConfig()
end)
spTeamDD(eleSec, 23, "Select phase 2 team (after target weight)", cfg.elephant, "phase2Team")
do
local p2Inp
p2Inp = spInput(eleSec, 26, "Use phase 2 team from level", "", tostring(cfg.elephant.phase2Threshold), function(v)
local val = tonumber(v)
if val and val >= 1 then cfg.elephant.phase2Threshold = val; saveConfig()
elseif p2Inp then p2Inp:Set(tostring(cfg.elephant.phase2Threshold)) end
end)
end
do
local twInp
twInp = spInput(eleSec, 30, "Target KG", "Berat target sebelum balik ke leveling", tostring(cfg.elephant.targetWeight), function(v)
local val = tonumber(v)
if val and val > 0 then cfg.elephant.targetWeight = val; saveConfig()
elseif twInp then twInp:Set(tostring(cfg.elephant.targetWeight)) end
end)
end
do
local mlInp
mlInp = spInput(eleSec, 33, "Max Level (P1 switch)", "", tostring(cfg.elephant.levelThreshold), function(v)
local val = tonumber(v)
if val and val >= 1 then cfg.elephant.levelThreshold = val; saveConfig()
elseif mlInp then mlInp:Set(tostring(cfg.elephant.levelThreshold)) end
end)
end
local tgtCountLabel
local function setTgtCount()
local n = #cfg.targets
tgtCountLabel:Set("Select Target Pets", "Target pets: " .. n)
tgtCountLabel.Content.TextColor3 = n == 0 and T.DIM or T.ACCENT
end
do
local tgtOpen
tgtCountLabel = spButton(eleSec, 36, "Select Target Pets", "Target pets: 0", "", function() if tgtOpen then tgtOpen() end end)
local ov = UI:frame(modalRoot, UDim2.new(1,0,1,0), nil, T.BG)
ov.Visible = false; ov.ZIndex = 20
local oh = UI:frame(ov, UDim2.new(1,0,0,26), nil, T.PANEL)
UI:stroke(oh, T.STROKE, 1)
UI:label(oh, "Select Target Pets", UDim2.new(1,-80,1,0), UDim2.new(0,8,0,0), T.ACCENT, 10)
local sa = UI:button(oh, "Select All", UDim2.new(0,64,0,20), UDim2.new(1,-118,0.5,-10), T.BTN, T.ACCENT, 8)
UI:stroke(sa, T.STROKE, 1)
local ox = UI:button(oh, "X", UDim2.new(0,24,0,20), UDim2.new(1,-28,0.5,-10), T.ERROR, T.TEXT, 10)
UI:stroke(ox, T.ERROR, 1)
ox.MouseButton1Click:Connect(function() ov.Visible = false; setTgtCount() end)
local oSearch3 = UI:input(ov, "", "Search pet name...", UDim2.new(1,-8,0,22), UDim2.new(0,4,0,28))
oSearch3.TextColor3 = T.TEXT; oSearch3.Font = Enum.Font.Gotham
local ofr = UI:scroll(ov, UDim2.new(1,0,1,-56), UDim2.new(0,0,0,54))
UI:list(ofr, 3); UI:pad(ofr, 3,4,4,3)
local function rebuild()
for _, c in ipairs(ofr:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
local inv = getInventory(); local q = string.lower(oSearch3.Text)
local us = {}; for u in pairs(inv) do table.insert(us, u) end
table.sort(us, function(a,b) return getKG(a) > getKG(b) end)
local allSel = true
for _, uuid in ipairs(us) do
if not table.find(cfg.targets, uuid) then allSel = false; break end
end
sa.Text = allSel and "None" or "Select All"
local n = 0
for _, uuid in ipairs(us) do
local pet = inv[uuid]
if not pet then continue end
if q ~= "" and not string.lower(pet.PetType or ""):find(q,1,true) then continue end
local sel = table.find(cfg.targets, uuid) ~= nil
local mut = getMutName(uuid)
local ms = (mut ~= "" and (" [" .. mut .. "]")) or ""
local txt = string.format("%s%s | Age %d | %.2f KG", pet.PetType or "?", ms, getAge(uuid), getKG(uuid))
local b = UI:button(ofr, txt, UDim2.new(1,0,0,22), nil, sel and T.SEL_BG or Color3.fromRGB(13,13,13), sel and T.SEL_TXT or T.TEXT, 9)
b.LayoutOrder = n; b.TextXAlignment = Enum.TextXAlignment.Left
UI:pad(b,0,8,4,0); UI:stroke(b, sel and T.ACCENT or T.STROKE, 1)
b.MouseButton1Click:Connect(function()
local i = table.find(cfg.targets, uuid)
if i then table.remove(cfg.targets, i) else table.insert(cfg.targets, uuid) end
saveConfig(); setTgtCount(); rebuild() end)
n = n + 1 end
end
sa.MouseButton1Click:Connect(function()
local inv = getInventory(); local q = string.lower(oSearch3.Text)
local us = {}; for u in pairs(inv) do table.insert(us, u) end
local allSel = true
for _, uuid in ipairs(us) do
if not table.find(cfg.targets, uuid) then allSel = false; break end
end
if allSel then cfg.targets = {} else
for _, uuid in ipairs(us) do
local pet = inv[uuid]
if pet and (q == "" or string.lower(pet.PetType or ""):find(q,1,true)) then
if not table.find(cfg.targets, uuid) then table.insert(cfg.targets, uuid) end
end end
end
saveConfig(); setTgtCount(); rebuild()
end)
oSearch3:GetPropertyChangedSignal("Text"):Connect(rebuild)
tgtOpen = function() ov.Visible = true; rebuild() end
setTgtCount()
end
local logScroll, logCount, doneCount, doneLabel
do
local lf = UI:frame(eleInner, UDim2.new(1,0,0,52), nil, T.PANEL)
lf.LayoutOrder = 86
UI:stroke(lf, T.STROKE, 1)
local lh = UI:frame(lf, UDim2.new(1,0,0,14), nil, T.BG, 1)
UI:label(lh, "LOGS", UDim2.new(1,-60,1,0), UDim2.new(0,6,0,0), T.ACCENT, 8).Font = Enum.Font.GothamBold
doneLabel = UI:label(lh, "Done: 0", UDim2.new(0,54,1,0), UDim2.new(1,-58,0,0), T.DIM, 8, Enum.TextXAlignment.Right)
doneLabel.Font = Enum.Font.Gotham
logScroll = UI:scroll(lf, UDim2.new(1,-4,1,-16), UDim2.new(0,2,0,15))
UI:list(logScroll, 1); UI:pad(logScroll, 1,4,4,1)
logCount = 0; doneCount = 0
end
local function logFn(msg, color)
logCount = logCount + 1
local lbl = Instance.new("TextLabel")
lbl.Size = UDim2.new(1,0,0,12); lbl.BackgroundTransparency = 1
lbl.Text = os.date("%H:%M:%S") .. " " .. msg
lbl.TextColor3 = color or T.DIM; lbl.Font = Enum.Font.Gotham; lbl.TextSize = 8
lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.TextTruncate = Enum.TextTruncate.AtEnd
lbl.LayoutOrder = logCount; lbl.Parent = logScroll
local all = {}
for _, c in ipairs(logScroll:GetChildren()) do if c:IsA("TextLabel") then table.insert(all, c) end end
while #all > 35 do all[1]:Destroy(); table.remove(all, 1) end
task.defer(function() logScroll.CanvasPosition = Vector2.new(0, math.huge) end)
end
local kgStatus
local bar = UI:frame(eleInner, UDim2.new(1,0,0,38), nil, T.PANEL)
bar.LayoutOrder = 999
UI:stroke(bar, T.STROKE, 1)
UI:label(bar, "AUTO KG", UDim2.new(0,70,0,20), UDim2.new(0,8,0.5,-10), T.TEXT, 10).Font = Enum.Font.GothamBold
kgStatus = UI:label(bar, "", UDim2.new(1,-120,1,0), UDim2.new(0,60,0,0), T.DIM, 9)
kgStatus.Font = Enum.Font.Gotham; kgStatus.TextTruncate = Enum.TextTruncate.AtEnd
local function statusFn(msg, color)
kgStatus.Text = msg; kgStatus.TextColor3 = color or T.DIM
end
local function startAutoKG(tog, status, log, doneLbl)
local inv = getInventory()
local cleaned = {}
for _, uuid in ipairs(cfg.targets) do
if inv[uuid] then table.insert(cleaned, uuid) end
end
cfg.targets = cleaned
if #cfg.targets == 0 then status("No targets!", T.ERROR); tog.Set(false); return end
isKGRunning = true; doneCount = 0
status("Running...", T.SUCCESS)
log("=== AUTO KG START ===", T.ACCENT)
startTeamWatcher()
task.spawn(function()
local teamLev = getTeamUUIDs(cfg.elephant.levelingTeam)
local teamEle = getTeamUUIDs(cfg.elephant.elephantTeam)
local teamP2 = getTeamUUIDs(cfg.elephant.phase2Team)
local targetKG = tonumber(cfg.elephant.targetWeight) or 2
local maxLvl = cfg.elephant.levelThreshold
local p2Enabled = cfg.elephant.phase2Enabled
local p2Thresh = cfg.elephant.phase2Threshold
local lvlTo100 = cfg.elephant.levelTo100
local gardenSlots = math.max(1, math.min(3, tonumber(cfg.elephant.gardenSlots) or 1))
local gardenMode = cfg.elephant.gardenMode or "A"
local startTime = os.clock()
local targetsCopy = {}
for _, uuid in ipairs(cfg.targets) do table.insert(targetsCopy, uuid) end
local totalPets = #targetsCopy
local function buildEquipList(targetPets, teamPets)
local list = {}
for _, uuid in ipairs(targetPets) do
if #list < 8 then table.insert(list, uuid) end
end
for _, uuid in ipairs(teamPets or {}) do
if #list >= 8 then break end
local found = false
for _, e in ipairs(list) do if e == uuid then found = true; break end end
if not found then table.insert(list, uuid) end
end
return list
end
local idx = 1
while idx <= #targetsCopy and isKGRunning do
local batch = {}
for bi = idx, math.min(idx + gardenSlots - 1, #targetsCopy) do
table.insert(batch, targetsCopy[bi])
end
if #batch == 0 then break end
idx = idx + #batch
local batchAtTarget = {}
for _, uuid in ipairs(batch) do batchAtTarget[uuid] = getBase(uuid) end
do
local used = {}
for _, uuid in ipairs(batch) do used[uuid] = true end
for _, uuid in ipairs(teamLev) do used[uuid] = true end
local finalEquip = {}
for _, uuid in ipairs(batch) do if #finalEquip < 8 then table.insert(finalEquip, uuid) end end
for _, uuid in ipairs(teamLev) do
if #finalEquip >= 8 then break end; table.insert(finalEquip, uuid)
end
if cfg.elephant.useExtraPets and #finalEquip < 8 then
local extras = getExtraPets(used, 8 - #finalEquip)
for _, uuid in ipairs(extras) do
if #finalEquip >= 8 then break end
table.insert(finalEquip, uuid); used[uuid] = true
end
end
setDesiredPets(finalEquip, teamLev)
unequipAll(); task.wait(0.5)
equipList(finalEquip)
while isKGRunning do
task.wait(TIMING.POLL_RATE)
local allDone = true
for uuid in pairs(batchAtTarget) do
if getAge(uuid) < maxLvl then allDone = false; break end
end
if allDone then setDesiredPets({}, {}); unequipAll(); task.wait(0.3); break end
local needRebuild = false
for uuid in pairs(batchAtTarget) do
if getAge(uuid) >= maxLvl then
log(string.format(" > %s lv%d swap out", getPType(uuid), getAge(uuid)), T.SUCCESS)
batchAtTarget[uuid] = nil; needRebuild = true
end
end
if not next(batchAtTarget) then setDesiredPets({}, {}); unequipAll(); task.wait(0.3); break end
if needRebuild then
local used2 = {}
for uuid in pairs(batchAtTarget) do used2[uuid] = true end
for _, uuid in ipairs(teamLev) do used2[uuid] = true end
local final2 = {}
for uuid in pairs(batchAtTarget) do if #final2 < 8 then table.insert(final2, uuid) end end
for _, uuid in ipairs(teamLev) do
if #final2 >= 8 then break end; table.insert(final2, uuid)
end
setDesiredPets(final2, teamLev)
equipState.IsEquipping = true
local targetSet = {}; for _, uuid in ipairs(final2) do targetSet[uuid] = true end
for _, uuid in ipairs(getActivePets()) do
if not targetSet[uuid] then
pcall(function() PetsRemote:FireServer("UnequipPet", uuid) end)
task.wait(TIMING.UNEQUIP_DELAY)
end
end
task.wait(TIMING.UNEQUIP_BUFFER)
local cf = getFarmCF()
local nowSet = {}; for _, uuid in ipairs(getActivePets()) do nowSet[uuid] = true end
for _, uuid in ipairs(final2) do
if not nowSet[uuid] then
pcall(function() PetsRemote:FireServer("EquipPet", uuid, cf) end)
task.wait(TIMING.EQUIP_DELAY)
end
end
equipState.IsEquipping = false
end
local sts = {}
for uuid in pairs(batchAtTarget) do
table.insert(sts, string.format("Lv%d %.2f/%.2fkg", getAge(uuid), getBase(uuid), targetKG))
end
status("P1: " .. table.concat(sts, " | "), T.DIM)
end
end
if not isKGRunning then break end
if #teamEle > 0 then
if gardenMode == "A" then
local preW = {}
local actSet = {}
for _, uuid in ipairs(batch) do preW[uuid] = getBase(uuid); actSet[uuid] = true end
local function buildEleEquip()
local used = {}
for uuid in pairs(actSet) do used[uuid] = true end
for _, uuid in ipairs(teamEle) do used[uuid] = true end
local final = {}
for uuid in pairs(actSet) do if #final < 8 then table.insert(final, uuid) end end
for _, uuid in ipairs(teamEle) do
if #final >= 8 then break end; table.insert(final, uuid)
end
if cfg.elephant.useExtraElePets and #final < 8 then
local extras = getExtraElePets(used, 8 - #final)
for _, uuid in ipairs(extras) do
if #final >= 8 then break end
table.insert(final, uuid)
end
end
return final
end
local eleEquip = buildEleEquip()
setDesiredPets(eleEquip, teamEle)
unequipAll(); task.wait(0.5); equipList(eleEquip)
local elePhaseStart = os.clock()
local eleLastGain = {}
while isKGRunning do
task.wait(TIMING.POLL_RATE)
local anyUp = false
for uuid in pairs(actSet) do
local nw = getBase(uuid)
if nw > preW[uuid] then
local gainedFrom = preW[uuid]
log(string.format(" > %s %.2f -> %.2fkg", getPType(uuid), gainedFrom, nw), Color3.fromRGB(255,180,80))
preW[uuid] = nw; actSet[uuid] = nil; anyUp = true
local nowT = os.clock()
local cycT = nowT - (eleLastGain[uuid] or elePhaseStart)
eleLastGain[uuid] = nowT
pcall(function() sendCycleWebhook(getPType(uuid), gainedFrom, nw, targetKG, cycT, "Elephant", doneCount + 1, totalPets, uuid) end)
end
end
if not next(actSet) then setDesiredPets({}, {}); unequipAll(); task.wait(0.3); break end
if anyUp then
local newEq = buildEleEquip()
setDesiredPets(newEq, teamEle)
equipState.IsEquipping = true
local tgtSet = {}; for _, uuid in ipairs(newEq) do tgtSet[uuid] = true end
for _, uuid in ipairs(getActivePets()) do
if not tgtSet[uuid] then
pcall(function() PetsRemote:FireServer("UnequipPet", uuid) end)
task.wait(TIMING.UNEQUIP_DELAY)
end
end
task.wait(TIMING.UNEQUIP_BUFFER)
local cf = getFarmCF()
local ns = {}; for _, uuid in ipairs(getActivePets()) do ns[uuid] = true end
for _, uuid in ipairs(newEq) do
if not ns[uuid] then
pcall(function() PetsRemote:FireServer("EquipPet", uuid, cf) end)
task.wait(TIMING.EQUIP_DELAY)
end
end
equipState.IsEquipping = false
end
local sts = {}
for uuid in pairs(actSet) do table.insert(sts, string.format("%.2f/%.2fkg", getBase(uuid), targetKG)) end
status("Ele A: " .. table.concat(sts, " | "), T.DIM)
end
else
for _, uuid in ipairs(batch) do
if not isKGRunning then break end
local preW = getBase(uuid)
local set = {[uuid] = true}
for _, te in ipairs(teamEle) do set[te] = true end
local final = {uuid}
for _, te in ipairs(teamEle) do
if #final >= 8 then break end; table.insert(final, te)
end
if cfg.elephant.useExtraElePets and #final < 8 then
local extras = getExtraElePets(set, 8 - #final)
for _, e in ipairs(extras) do
if #final >= 8 then break end; table.insert(final, e)
end
end
setDesiredPets({uuid}, teamEle)
unequipAll(); task.wait(0.5); equipList(final)
local eleStartB = os.clock()
while isKGRunning do
task.wait(TIMING.POLL_RATE)
local nw = getBase(uuid)
status(string.format("Ele B: %s %.2f/%.2fkg", getPType(uuid), nw, targetKG), T.DIM)
if nw > preW then
local gainedFromB = preW
log(string.format(" > %s %.2f -> %.2fkg", getPType(uuid), gainedFromB, nw), Color3.fromRGB(255,180,80))
pcall(function() sendCycleWebhook(getPType(uuid), gainedFromB, nw, targetKG, os.clock() - eleStartB, "Elephant", doneCount + 1, totalPets, uuid) end)
setDesiredPets({}, {}); unequipAll(); break
end
end
end
end
end
if not isKGRunning then break end
for _, uuid in ipairs(batch) do batchAtTarget[uuid] = getBase(uuid) end
for _, uuid in ipairs(batch) do
if not isKGRunning then break end
if not getInventory()[uuid] then
local idx2 = table.find(cfg.targets, uuid)
if idx2 then table.remove(cfg.targets, idx2) end
else
local petName = getPType(uuid)
if not lvlTo100 then
doneCount = doneCount + 1; doneLbl.Text = "Done: " .. doneCount
log(string.format(" DONE %s %.2fkg", petName, getBase(uuid)), T.SUCCESS)
status(string.format("%s done!", petName), T.SUCCESS)
pcall(function() sendPetFinishedWebhook(petName, getBase(uuid), os.clock() - startTime, 0, doneCount, totalPets) end)
local idx2 = table.find(cfg.targets, uuid)
if idx2 then table.remove(cfg.targets, idx2) end
if tgtCountLabel then setTgtCount() end
else
log(string.format(" P2: %s lvl 100", petName), T.ACCENT)
status(string.format("P2 Lv%d/100 | %s", getAge(uuid), petName), T.ACCENT)
local useP2 = p2Enabled and #teamP2 > 0 and (getAge(uuid) >= p2Thresh)
local supportTeam = useP2 and teamP2 or teamLev
currentTarget = uuid; currentTeam = supportTeam
unequipAll(); task.wait(0.5)
equipList(buildEquipList({uuid}, supportTeam))
local p2Start = os.clock()
while isKGRunning do
task.wait(TIMING.POLL_RATE)
local age = getAge(uuid)
status(string.format("P2 Lv%d/100 | %s", age, petName), T.ACCENT)
if p2Enabled and #teamP2 > 0 and not useP2 and (age >= p2Thresh) then
useP2 = true; currentTeam = teamP2
unequipAll(); task.wait(0.5)
equipList(buildEquipList({uuid}, teamP2))
end
if age >= 100 then
unequipAll()
doneCount = doneCount + 1; doneLbl.Text = "Done: " .. doneCount
log(string.format(" DONE %s Lv100 %.2fkg", petName, getBase(uuid)), T.SUCCESS)
pcall(function() sendPetFinishedWebhook(petName, getBase(uuid), os.clock() - startTime, os.clock() - p2Start, doneCount, totalPets) end)
status(string.format("%s done!", petName), T.SUCCESS)
local idx2 = table.find(cfg.targets, uuid)
if idx2 then table.remove(cfg.targets, idx2) end
if tgtCountLabel then setTgtCount() end
break
end
end
end
end
end
end
isKGRunning = false
tog.Set(false)
stopTeamWatcher()
statusFn("IDLE", T.DIM)
cfg.toggles.autoKG = false; saveConfig()
local elapsed = string.format("%.0fs", os.clock() - startTime)
log("", T.ACCENT)
log(string.format("ALL DONE %d/%d pets (%s)", doneCount, totalPets, elapsed), T.SUCCESS)
pcall(function() sendWebhook({{title = "All Pets Finished!", color = 5763719,
description = string.format("%d/%d pets done (%s)", doneCount, totalPets, elapsed),
fields = {
{name = "Queue", value = string.format("%d / %d done", doneCount, totalPets), inline = true},
{name = "Total Time", value = elapsed, inline = true},
},
footer = {text = "Velium Hub " .. os.date("%d/%m/%Y %H:%M:%S")},
thumbnail = {url = "https://raw.githubusercontent.com/wardz25/library-ui/main/VeliumHub.png"},
}}) end)
end)
end
local kgToggle = UI:toggle(bar, UDim2.new(1,-52,0.5,-11), cfg.toggles.autoKG,
function(val)
cfg.toggles.autoKG = val; saveConfig(); VeliumNotify("Auto KG", val)
if val then startAutoKG(kgToggle, statusFn, logFn, doneLabel)
else isKGRunning = false; stopTeamWatcher()
logFn("--- Stopped ---", T.ERROR); statusFn("IDLE", T.DIM)
end
end)
kgToggle.LayoutOrder = 998
if cfg.toggles.autoKG then
task.defer(function() startAutoKG(kgToggle, statusFn, logFn, doneLabel) end)
end
end
-- ============ AUTO MUTATIONS (order 4) ============
local mutSec = spSection(tabAuto, "AUTO MUTATIONS", false)
local mutInner = mutSec:GetContainer()
spToggle(mutSec, 1, "Enable Auto Mutation", "", cfg.toggles.autoMutation, function(val)
cfg.toggles.autoMutation = val; saveConfig(); VeliumNotify("Auto Mutation", val)
end)
do
local methods = { "Level", "Nightmare", "Venom", "Ember", "Everchanted" }
spDropdown(mutSec, 2, "Method", "Mutation method", false, methods, {cfg.autoMutation.method or "Level"}, function(v)
cfg.autoMutation.method = v[1] or "Level"; saveConfig()
end)
end
local mutPetBtn
local function updateMutPetBtn()
local uuid = cfg.autoMutation.targetUUID
local p = uuid and getInventory()[uuid]
mutPetBtn:Set("Target Pet", (p and ((p.PetType or "?"):sub(1,15) .. "...")) or "Select >")
end
do
local mutPetOpen
mutPetBtn = spButton(mutSec, 3, "Target Pet", "Select >", "", function() if mutPetOpen then mutPetOpen() end end)
local ov = UI:frame(modalRoot, UDim2.new(1,0,1,0), nil, T.BG)
ov.Visible = false; ov.ZIndex = 25
local bar2 = UI:frame(ov, UDim2.new(1,0,0,30), nil, T.PANEL)
UI:stroke(bar2, T.STROKE, 1)
UI:label(bar2, "Select Pet to Mutate", UDim2.new(1,-30,1,0), UDim2.new(0,8,0,0), T.ACCENT, 10)
local xBtn = UI:button(bar2, "X", UDim2.new(0,24,0,22), UDim2.new(1,-28,0.5,-11), T.ERROR, T.TEXT, 10)
UI:stroke(xBtn, T.ERROR, 1)
local search = UI:input(ov, "", "Search pet..", UDim2.new(1,-8,0,22), UDim2.new(0,4,0,34))
search.TextColor3 = T.TEXT; search.Font = Enum.Font.Gotham
local sf = UI:scroll(ov, UDim2.new(1,0,1,-60), UDim2.new(0,0,0,58))
UI:list(sf, 3); UI:pad(sf, 3,4,4,3)
local function rebuildPetList()
for _, c in ipairs(sf:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
local q = string.lower(search.Text)
local inv = getInventory()
local uuids = {}
for u in pairs(inv) do table.insert(uuids, u) end
table.sort(uuids, function(a,b) return getAge(a) < getAge(b) end)
local n = 0
for _, uuid in ipairs(uuids) do
local pet = inv[uuid]
if not pet then continue end
local name = pet.PetType or "?"
if q ~= "" and not string.lower(name):find(q,1,true) then continue end
local isSel = cfg.autoMutation.targetUUID == uuid
local level = (pet.PetData and (pet.PetData.Level or 0)) or 0
local kg = getKG(uuid)
local txt = string.format("%s | Age %d | %.2f KG", name, level, kg)
local b = UI:button(sf, txt, UDim2.new(1,0,0,26), nil,
isSel and T.SEL_BG or Color3.fromRGB(13,13,13), isSel and T.SEL_TXT or T.TEXT, 9)
b.LayoutOrder = n; b.TextXAlignment = Enum.TextXAlignment.Left
UI:pad(b,0,8,2,0); UI:corner(b,5); UI:stroke(b, isSel and T.ACCENT or T.STROKE, 1)
b.MouseButton1Click:Connect(function()
cfg.autoMutation.targetUUID = uuid; saveConfig()
updateMutPetBtn()
ov.Visible = false
end)
n = n + 1
end
end
xBtn.MouseButton1Click:Connect(function() ov.Visible = false end)
search:GetPropertyChangedSignal("Text"):Connect(rebuildPetList)
mutPetOpen = function()
ov.Visible = true
updateMutPetBtn()
rebuildPetList()
end
end
do
local taInp
taInp = spInput(mutSec, 4, "Target Age", "", tostring(cfg.autoMutation.targetAge or 100), function(v)
local val = tonumber(v)
if val and val >= 1 then cfg.autoMutation.targetAge = val; saveConfig()
elseif taInp then taInp:Set(tostring(cfg.autoMutation.targetAge or 100)) end
end)
end
spInput(mutSec, 5, "Target Mut", "Mutasi target", cfg.autoMutation.targetMutant or "Normal", function(v)
cfg.autoMutation.targetMutant = v; saveConfig()
end)
do
local function makeLoadoutBtn(label, configKey, order)
local btn
btn = spButton(mutSec, order, label, tostring(cfg.autoMutation[configKey] or 1), "", function()
local cur = tonumber(btn.Content.Text) or 1
cur = cur + 1
if cur > 6 then cur = 1 end
cfg.autoMutation[configKey] = cur
btn:Set(nil, tostring(cur))
saveConfig()
end)
end
makeLoadoutBtn("Farm Loadout", "farmLoadout", 6)
makeLoadoutBtn("Tim Loadout", "timeLoadout", 7)
makeLoadoutBtn("Claim Loadout", "claimLoadout", 8)
end
do
local dlInp
dlInp = spInput(mutSec, 9, "Delay (s)", "Delay antar mutasi", tostring(cfg.autoMutation.delay or 10), function(v)
local val = tonumber(v)
if val and val >= 1 then cfg.autoMutation.delay = val; saveConfig()
elseif dlInp then dlInp:Set(tostring(cfg.autoMutation.delay or 10)) end
end)
end
local function getPetData()
local ok, data = pcall(function() return DataService:GetData() end)
if not ok or not data then return nil end
return data.PetsData and data.PetsData.PetInventory
end
local function findPetForMutation()
local targetUUID = cfg.autoMutation.targetUUID
local targetAge = cfg.autoMutation.targetAge or 100
if not targetUUID then return nil end
local inv = getPetData()
if not inv then return nil end
local pet = inv.Data[targetUUID]
if not pet then return nil end
local level = tonumber(pet.PetData and pet.PetData.Level) or 0
local isFav = pet.PetData and pet.PetData.IsFavorite
if level >= 100 and level < targetAge and not isFav then
return pet.UUID
end
return nil
end
local function runMutation()
if not cfg.toggles.autoMutation then return end
local method = cfg.autoMutation.method or "Level"
local targetUUID = cfg.autoMutation.targetUUID
if not targetUUID then return end
local ok, data = pcall(function() return DataService:GetData() end)
if not ok or not data then return end
local machineData = data.PetMutationMachine
if not machineData then return end
if machineData.PetReady then
pcall(function()
PetMutationMachine:FireServer("ClaimMutatedPet")
end)
task.wait(2)
return
end
if machineData.IsRunning then return end
if machineData.SubmittedPet and not machineData.IsRunning then
pcall(function()
PetMutationMachine:FireServer("CancelMachine")
end)
task.wait(1)
end
local inv = data.PetsData and data.PetsData.PetInventory
if not inv then return end
local targetAge = cfg.autoMutation.targetAge or 100
local uuid = nil
local pet = inv.Data[targetUUID]
if pet then
local level = tonumber(pet.PetData and pet.PetData.Level) or 0
local isFav = pet.PetData and pet.PetData.IsFavorite
if level >= 100 and level < targetAge and not isFav then
uuid = pet.UUID
end
end
if not uuid then return end
for _, tool in ipairs(Backpack:GetChildren()) do
if tool:IsA("Tool") and tool:GetAttribute("PET_UUID") == uuid then
pcall(function() local hum = getHumanoid() if hum then hum:EquipTool(tool) end end)
task.wait(0.5)
break
end
end
pcall(function()
PetMutationMachine:FireServer("SubmitHeldPet")
end)
task.wait(1)
pcall(function()
PetMutationMachine:FireServer("StartMachine")
end)
task.wait(1)
end
task.spawn(function()
while true do
task.wait(cfg.autoMutation.delay or 10)
if cfg.toggles.autoMutation then
pcall(runMutation)
end
end
end)
-- ============ AUTO GIFT PET (order 5) ============
local giftSec = spSection(tabAuto, "AUTO GIFT PET", false)
local giftInner = giftSec:GetContainer()
spToggle(giftSec, 1, "Enable Auto Gift", "", cfg.toggles.autoGift, function(val)
cfg.toggles.autoGift = val; saveConfig(); VeliumNotify("Auto Gift", val)
end)
local friendBtn
local function updateFriendBtn()
local n = cfg.autoGift.friendName
friendBtn:Set("Friend", (n and n ~= "" and ("@" .. n)) or "Select Player")
end
do
local friendOpen
friendBtn = spButton(giftSec, 2, "Friend", "Select Player", "", function() if friendOpen then friendOpen() end end)
local friendOv = UI:frame(modalRoot, UDim2.new(1,0,1,0), nil, T.BG)
friendOv.Visible = false; friendOv.ZIndex = 25
local friendBar = UI:frame(friendOv, UDim2.new(1,0,0,30), nil, T.PANEL)
UI:stroke(friendBar, T.STROKE, 1)
UI:label(friendBar, "Select Player", UDim2.new(1,-30,1,0), UDim2.new(0,8,0,0), T.ACCENT, 10)
local friendX = UI:button(friendBar, "X", UDim2.new(0,24,0,22), UDim2.new(1,-28,0.5,-11), T.ERROR, T.TEXT, 10)
UI:stroke(friendX, T.ERROR, 1)
friendX.MouseButton1Click:Connect(function() friendOv.Visible = false end)
local friendSF = UI:scroll(friendOv, UDim2.new(1,0,1,-36), UDim2.new(0,0,0,32))
UI:list(friendSF, 3); UI:pad(friendSF, 3,4,4,3)
local function rebuildFriendList()
for _, c in ipairs(friendSF:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
local n = 0
for _, plr in ipairs(Players:GetPlayers()) do
if plr ~= LocalPlayer then
n = n + 1
local isSel = cfg.autoGift.friendName == plr.Name
local txt = string.format("@%s (%s)", plr.Name, plr.DisplayName)
local b = UI:button(friendSF, txt, UDim2.new(1,0,0,26), nil,
isSel and T.SEL_BG or Color3.fromRGB(13,13,13), isSel and T.SEL_TXT or T.TEXT, 9)
b.LayoutOrder = n; b.TextXAlignment = Enum.TextXAlignment.Left
UI:pad(b,0,8,2,0); UI:corner(b,5); UI:stroke(b, isSel and T.ACCENT or T.STROKE, 1)
b.MouseButton1Click:Connect(function()
cfg.autoGift.friendName = plr.Name; saveConfig()
updateFriendBtn()
friendOv.Visible = false
end)
end
end
end
friendOpen = function()
friendOv.Visible = true
rebuildFriendList()
end
end
local giftPetsBtn
local function updateGiftPetsBtn()
local c = 0; for _ in pairs(cfg.autoGift.petTypes or {}) do c = c + 1 end
giftPetsBtn:Set("Pets to Gift", c == 0 and "None" or (c .. " selected"))
giftPetsBtn.Content.TextColor3 = c == 0 and T.DIM or T.ACCENT
end
do
local giftOpen
giftPetsBtn = spButton(giftSec, 3, "Pets to Gift", "None", "", function() if giftOpen then giftOpen() end end)
local ov = UI:frame(modalRoot, UDim2.new(1,0,1,0), nil, T.BG)
ov.Visible = false; ov.ZIndex = 25
local bar3 = UI:frame(ov, UDim2.new(1,0,0,30), nil, T.PANEL)
UI:stroke(bar3, T.STROKE, 1)
UI:label(bar3, "Select Pets to Gift", UDim2.new(1,-30,1,0), UDim2.new(0,8,0,0), T.ACCENT, 10)
local xBtn = UI:button(bar3, "X", UDim2.new(0,24,0,22), UDim2.new(1,-28,0.5,-11), T.ERROR, T.TEXT, 10)
UI:stroke(xBtn, T.ERROR, 1)
xBtn.MouseButton1Click:Connect(function()
ov.Visible = false
updateGiftPetsBtn()
end)
local search = UI:input(ov, "", "Search pet..", UDim2.new(1,-8,0,22), UDim2.new(0,4,0,34))
search.TextColor3 = T.TEXT; search.Font = Enum.Font.Gotham
local sf = UI:scroll(ov, UDim2.new(1,0,1,-60), UDim2.new(0,0,0,58))
UI:list(sf, 3); UI:pad(sf, 3,4,4,3)
local function rebuildGiftList()
for _, c in ipairs(sf:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
local q = string.lower(search.Text)
local n = 0
for _, pet in ipairs(PetJSON) do
if q ~= "" and not string.lower(pet.name):find(q,1,true) then continue end
n = n + 1
local sel = cfg.autoGift.petTypes and cfg.autoGift.petTypes[pet.name] == true
local b = UI:button(sf, pet.name, UDim2.new(1,0,0,26), nil,
sel and T.SEL_BG or Color3.fromRGB(13,13,13), sel and T.SEL_TXT or T.TEXT, 9)
b.LayoutOrder = n; b.TextXAlignment = Enum.TextXAlignment.Left
UI:pad(b,0,8,2,0); UI:corner(b,5); UI:stroke(b, sel and T.ACCENT or T.STROKE, 1)
b.MouseButton1Click:Connect(function()
if not cfg.autoGift.petTypes then cfg.autoGift.petTypes = {} end
if cfg.autoGift.petTypes[pet.name] then cfg.autoGift.petTypes[pet.name] = nil
else cfg.autoGift.petTypes[pet.name] = true end
saveConfig()
end)
end
end
search:GetPropertyChangedSignal("Text"):Connect(rebuildGiftList)
giftOpen = function() ov.Visible = true; rebuildGiftList() end
end
do
local wmBtn
wmBtn = spButton(giftSec, 4, "Weight Mode", cfg.autoGift.weightMode or "Below", "", function()
cfg.autoGift.weightMode = cfg.autoGift.weightMode == "Below" and "Above" or "Below"
wmBtn:Set(nil, cfg.autoGift.weightMode); saveConfig()
end)
local wtInp
wtInp = spInput(giftSec, 5, "Weight Threshold", "Batas berat untuk gift", tostring(cfg.autoGift.weightThreshold or 0), function(v)
local val = tonumber(v)
if val and val >= 0 then cfg.autoGift.weightThreshold = val; saveConfig()
elseif wtInp then wtInp:Set(tostring(cfg.autoGift.weightThreshold or 0)) end
end)
end
local function runGift()
if not cfg.toggles.autoGift then return end
local friendName = cfg.autoGift.friendName
if not friendName or friendName == "" then return end
local targetPlayer = Players:FindFirstChild(friendName)
if not targetPlayer then return end
local petTypes = cfg.autoGift.petTypes or {}
if not next(petTypes) then return end
local inv = getPetData()
if not inv then return end
for _, tData in pairs(inv) do
if type(tData) == "table" then
for _, pet in pairs(tData) do
if type(pet) == "table" then
local petType = pet.PetType
local weight = tonumber(pet.PetData and pet.PetData.BaseWeight) or 0
local isFav = pet.PetData and pet.PetData.IsFavorite
local meetsWeight = false
if cfg.autoGift.weightMode == "Below" then
meetsWeight = weight < cfg.autoGift.weightThreshold
else
meetsWeight = weight > cfg.autoGift.weightThreshold
end
if petTypes[petType] and not isFav and meetsWeight then
for _, tool in ipairs(Backpack:GetChildren()) do
if tool:IsA("Tool") and tool:GetAttribute("PET_UUID") == pet.UUID then
pcall(function() local hum = getHumanoid() if hum then hum:EquipTool(tool) end end)
task.wait(0.5)
break
end
end
pcall(function()
PetGiftingService:FireServer("GivePet", targetPlayer)
end)
task.wait(7)
end
end
end
end
end
end
task.spawn(function()
while true do
task.wait(2)
if cfg.toggles.autoGift then
pcall(runGift)
end
end
end)
-- ============ External Leveling & Nightmare modules (web load) ============
_G.HH_Shared.PageLeveling = levelBox

local function loadExternalModule(name, url)
	local ok, src = pcall(function() return game:HttpGet(url) end)
	if not ok or type(src) ~= "string" or src == "" then
		warn("[Velium Hub] " .. name .. ": HTTP fetch failed -> " .. tostring(src))
		return false
	end
	local fn, cerr = loadstring(src)
	if not fn then
		warn("[Velium Hub] " .. name .. ": compile error -> " .. tostring(cerr))
		return false
	end
	local ok2, rerr = pcall(fn)
	if not ok2 then
		warn("[Velium Hub] " .. name .. ": runtime error -> " .. tostring(rerr))
		return false
	end
	print("[Velium Hub] " .. name .. " loaded OK")
	return true
end

-- Point outerScroll to the Leveling container so it injects at LayoutOrder 1
_G.HH_Shared.outerScroll = levelBox
local gotL = loadExternalModule("Leveling", "https://raw.githubusercontent.com/wardz25/library-ui/main/modules/leveling.lua")
-- Point outerScroll to the Nightmare container so it injects at LayoutOrder 2
_G.HH_Shared.outerScroll = nightmareBox
local gotN = loadExternalModule("Nightmare", "https://raw.githubusercontent.com/wardz25/library-ui/main/modules/nightmare.lua")
-- Restore outerScroll to aScroll for any other use
_G.HH_Shared.outerScroll = levelBox
if not (gotL and gotN) then
	warn("[Velium Hub] Some modules unavailable -> accordions may not appear.")
end
-- Refresh team dropdowns now that external modules may have registered built-in teams
pcall(refreshTeamDropdowns)
end
print("[Velium Hub] TAB done: AUTOMATION")
-- ======================== PET BOOST LOOP ========================
task.spawn(function()
	local PET_BOOST_INTERVAL = 1
	while true do
		task.wait(PET_BOOST_INTERVAL)
		if cfg.toggles.mode1boost then
			local pets = cfg.petboost.mode1.selPets or {}
			local hasFilter = next(pets) ~= nil
			local toyOpts = cfg.petboost.mode1.boostOptions or {}
			for _, tool in ipairs(Backpack:GetChildren()) do
				if tool:IsA("Tool") and (tool:FindFirstChild("PetToolLocal") or tool:FindFirstChild("PetToolServer")) then
					local uuid = tool:GetAttribute("PET_UUID")
					if uuid then
						if hasFilter then
							local petName = tool.Name:match("^(.-)%s*%[") or tool.Name
							if not pets[petName] then continue end
						end
						for toyName in pairs(toyOpts) do
							pcall(function() applyBoost(uuid, toyName, tool.Name) end)
							task.wait(0.3)
						end
					end
				end
			end
		end
	end
end)

task.spawn(function()
local ok, vu = pcall(function() return game:GetService("VirtualUser") end)
if ok and vu then
pcall(function()
LocalPlayer.Idled:Connect(function()
pcall(function() vu:CaptureController(); vu:ClickButton2(Vector2.new()) end)
end)
end)
end
end)
notifyReady = true
-- Velium: content was built while tabs were hidden (size read as 0); force a
-- full re-measure now that every tab/section exists.
task.defer(function()
pcall(function() if speedTabs.RefreshAllSections then speedTabs:RefreshAllSections() end end)
end)
print(string.format("[Velium Hub] Loaded successfully in %.2fs. Build %s-speed6.", os.clock() - tStart, VELIUM_BUILD))
