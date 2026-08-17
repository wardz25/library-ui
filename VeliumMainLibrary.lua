local VoidUI = {}
VoidUI.__index = VoidUI

local TweenSvc = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")

function VoidUI.new(theme)
	local self = setmetatable({}, VoidUI)
	self.T = theme
	return self
end

function VoidUI:corner(parent, radius)
	local c = Instance.new("UICorner", parent)
	c.CornerRadius = UDim.new(0, radius or 6)
	return c
end

function VoidUI:stroke(parent, col, th)
	local s = Instance.new("UIStroke", parent)
	s.Color = col or self.T.STROKE
	s.Thickness = th or 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	return s
end

function VoidUI:frame(parent, size, pos, bg, tr)
	local f = Instance.new("Frame")
	f.Size = size or UDim2.new(1, 0, 1, 0)
	f.Position = pos or UDim2.new(0, 0, 0, 0)
	f.BackgroundColor3 = bg or self.T.PANEL
	f.BackgroundTransparency = tr or 0
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

function VoidUI:label(parent, text, size, pos, col, fs, xa)
	local l = Instance.new("TextLabel")
	l.Size = size or UDim2.new(1, 0, 0, 16)
	l.Position = pos or UDim2.new(0, 0, 0, 0)
	l.BackgroundTransparency = 1
	l.Text = text or ""
	l.TextColor3 = col or self.T.TEXT
	l.Font = Enum.Font.GothamBold
	l.TextSize = fs or 11
	l.TextXAlignment = xa or Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Parent = parent
	return l
end

function VoidUI:button(parent, text, size, pos, bg, tc, fs)
	local b = Instance.new("TextButton")
	b.Size = size or UDim2.new(0, 80, 0, 26)
	b.Position = pos or UDim2.new(0, 0, 0, 0)
	b.BackgroundColor3 = bg or self.T.BTN
	b.BorderSizePixel = 0
	b.Text = text or ""
	b.TextColor3 = tc or self.T.TEXT
	b.Font = Enum.Font.GothamBold
	b.TextSize = fs or 11
	b.AutoButtonColor = false
	b.RichText = true
	b.Parent = parent
	self:corner(b, 5)
	return b
end

function VoidUI:input(parent, default, ph, size, pos)
	local b = Instance.new("TextBox")
	b.Size = size or UDim2.new(0, 80, 0, 22)
	b.Position = pos or UDim2.new(0, 0, 0, 0)
	b.BackgroundColor3 = self.T.BTN
	b.BorderSizePixel = 0
	b.Text = tostring(default or "")
	b.PlaceholderText = ph or ""
	b.TextColor3 = self.T.ACCENT
	b.PlaceholderColor3 = self.T.DIM
	b.Font = Enum.Font.GothamBold
	b.TextSize = 11
	b.ClearTextOnFocus = false
	b.Parent = parent
	self:corner(b, 4)
	self:stroke(b, self.T.STROKE, 1)
	return b
end

function VoidUI:scroll(parent, size, pos)
	local sf = Instance.new("ScrollingFrame")
	sf.Size = size or UDim2.new(1, 0, 1, 0)
	sf.Position = pos or UDim2.new(0, 0, 0, 0)
	sf.BackgroundTransparency = 1
	sf.BorderSizePixel = 0
	sf.ScrollBarThickness = 3
	sf.ScrollBarImageColor3 = self.T.ACCENT
	sf.CanvasSize = UDim2.new(0, 0, 0, 0)
	sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sf.Parent = parent
	return sf
end

function VoidUI:list(parent, pad)
	local l = Instance.new("UIListLayout", parent)
	l.Padding = UDim.new(0, pad or 4)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	return l
end

function VoidUI:pad(parent, t, l, r, b_)
	local p = Instance.new("UIPadding", parent)
	p.PaddingTop = UDim.new(0, t or 0)
	p.PaddingLeft = UDim.new(0, l or 0)
	p.PaddingRight = UDim.new(0, r or 0)
	p.PaddingBottom = UDim.new(0, b_ or 0)
	return p
end

function VoidUI:divider(parent, lo)
	local d = self:frame(parent, UDim2.new(1, 0, 0, 1), nil, Color3.fromRGB(58, 45, 10))
	d.LayoutOrder = lo
	return d
end

function VoidUI:toggle(parent, pos, initState, onChange)
	local T = self.T
	local box = self:frame(parent, UDim2.new(0, 44, 0, 22), pos, T.TOGGLE_OFF)
	self:corner(box, 11)
	self:stroke(box, T.STROKE, 1)
	local knob = self:frame(box, UDim2.new(0, 16, 0, 16), UDim2.new(0, 3, 0.5, -8), Color3.fromRGB(220, 220, 220))
	self:corner(knob, 8)
	local state = initState and true or false
	local function apply(s)
		TweenSvc:Create(box, TweenInfo.new(0.15), { BackgroundColor3 = s and T.TOGGLE_ON or T.TOGGLE_OFF }):Play()
		TweenSvc:Create(knob, TweenInfo.new(0.15), { Position = s and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8) }):Play()
		if typeof(onChange) == "function" then onChange(s) end
	end
	apply(state)
	local hit = self:button(box, "", UDim2.new(1, 0, 1, 0), nil, T.BTN, T.TEXT)
	hit.BackgroundTransparency = 1
	hit.ZIndex = 5
	hit.MouseButton1Click:Connect(function() state = not state; apply(state) end)
	return { Set = function(v) state = v and true or false; apply(state) end, Get = function() return state end, Frame = box }
end

-- FIXED: Simple left/right cycle picker — no floating dropdown, no scroll-overlap bug
function VoidUI:inlinePicker(parent, options, currentVal, onSelect, size, pos)
	local T = self.T
	local container = self:frame(parent, size or UDim2.new(1, 0, 0, 28), pos, T.BTN)
	self:corner(container, 5)
	self:stroke(container, T.STROKE, 1)

	local selectedIdx = 1
	for i, v in ipairs(options) do
		if v == currentVal then selectedIdx = i; break end
	end

	-- Left arrow button
	local leftBtn = self:button(container, "<", UDim2.new(0, 28, 1, -2), UDim2.new(0, 1, 0, 1), T.PANEL, T.ACCENT, 13)
	self:corner(leftBtn, 4)
	leftBtn.Font = Enum.Font.GothamBold

	-- Center display label
	local display = self:label(
		container,
		options[selectedIdx] or "",
		UDim2.new(1, -62, 1, 0),
		UDim2.new(0, 30, 0, 0),
		T.ACCENT, 9,
		Enum.TextXAlignment.Center
	)
	display.Font = Enum.Font.GothamBold
	display.TextTruncate = Enum.TextTruncate.AtEnd

	-- Right arrow button
	local rightBtn = self:button(container, ">", UDim2.new(0, 28, 1, -2), UDim2.new(1, -29, 0, 1), T.PANEL, T.ACCENT, 13)
	self:corner(rightBtn, 4)
	rightBtn.Font = Enum.Font.GothamBold

	local function pick(idx)
		selectedIdx = ((idx - 1) % #options) + 1
		display.Text = options[selectedIdx]
		if typeof(onSelect) == "function" then onSelect(options[selectedIdx]) end
	end

	leftBtn.MouseButton1Click:Connect(function() pick(selectedIdx - 1) end)
	rightBtn.MouseButton1Click:Connect(function() pick(selectedIdx + 1) end)

	return {
		Get = function() return options[selectedIdx] end,
		Set = function(v)
			for i, opt in ipairs(options) do
				if opt == v then selectedIdx = i; display.Text = v; break end
			end
		end,
		Frame = container,
		Close = function() end,
		DropFrame = nil,
	}
end

function VoidUI:accordion(parent, title, lo, startOpen)
	local T = self.T
	local header = self:frame(parent, UDim2.new(1, 0, 0, 32), nil, Color3.fromRGB(17, 17, 22))
	header.LayoutOrder = lo
	self:corner(header, 6)
	self:stroke(header, T.ACCENT, 1)
	self:label(header, title, UDim2.new(1, -40, 1, 0), UDim2.new(0, 12, 0, 0), T.ACCENT, 10)
	local arrow = self:label(header, startOpen and "v" or ">", UDim2.new(0, 20, 1, 0), UDim2.new(1, -26, 0, 0), T.DIM, 11, Enum.TextXAlignment.Center)
	local hitBtn = self:button(header, "", UDim2.new(1, 0, 1, 0), nil, T.BTN, T.TEXT)
	hitBtn.BackgroundTransparency = 1
	hitBtn.ZIndex = 5
	local body = self:frame(parent, UDim2.new(1, 0, 0, 0), nil, Color3.fromRGB(17, 17, 22))
	body.LayoutOrder = lo + 1
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.Visible = startOpen ~= false
	self:corner(body, 6)
	self:stroke(body, T.ACCENT, 1)
	local inner = self:frame(body, UDim2.new(1, 0, 1, 0), nil, Color3.fromRGB(17, 17, 22), 0)
	inner.AutomaticSize = Enum.AutomaticSize.Y
	self:list(inner, 5)
	self:pad(inner, 8, 8, 8, 8)
	local isOpen = startOpen ~= false
	hitBtn.MouseButton1Click:Connect(function()
		isOpen = not isOpen
		body.Visible = isOpen
		arrow.Text = isOpen and "v" or ">"
	end)
	return { Header = header, Body = body, Inner = inner, Arrow = arrow }
end




function VoidUI:inlinePickerDropdown(rowParent, overlayParent, config)
	local zIdx = config.zIndex or 70
	local strokeCol = config.strokeColor or self.T.ACCENT
	local multi = config.multiSelect or false
	local selected = multi and {} or (config.default or nil)
	local _cb = config.onSelect
	local isStatic = config.staticLabel ~= nil

	-- Row container
	local row = self:frame(rowParent, config.size or UDim2.new(1, 0, 0, 28), config.pos, self.T.BTN)
	self:corner(row, 5)
	self:stroke(row, self.T.STROKE, 1)

	if not isStatic then
		local lblLeft = self:label(row, config.label or "Mode", UDim2.new(0, 70, 1, 0), UDim2.new(0, 6, 0, 0), self.T.TEXT, 10)
		lblLeft.Font = Enum.Font.GothamBold
	end

	local valLblX = isStatic and 6 or 78
	local valLblW = isStatic and UDim2.new(1, -20, 1, 0) or UDim2.new(1, -92, 1, 0)
	local valLbl = self:label(row, isStatic and config.staticLabel or (config.default or "Select..."),
		valLblW, UDim2.new(0, valLblX, 0, 0), self.T.ACCENT, 10)
	valLbl.Font = Enum.Font.GothamBold
	valLbl.TextXAlignment = Enum.TextXAlignment.Right

	self:label(row, "▼", UDim2.new(0, 14, 1, 0), UDim2.new(1, -15, 0, 0), self.T.DIM, 8, Enum.TextXAlignment.Center)

	-- Overlay dropdown
	local overlay = self:frame(overlayParent, UDim2.new(0, 230, 0, 210), UDim2.new(0, 0, 0, 0), self.T.PANEL)
	overlay.Visible = false
	overlay.ZIndex = zIdx
	self:corner(overlay, 6)
	self:stroke(overlay, strokeCol, 1)

	-- Header overlay (draggable)
	local ohdr = self:frame(overlay, UDim2.new(1, 0, 0, 24), nil, Color3.fromRGB(17, 17, 22))
	self:corner(ohdr, 6)
	local otitle = self:label(ohdr, config.label or "Select", UDim2.new(1, -28, 1, 0), UDim2.new(0, 8, 0, 0), strokeCol, 10)
	otitle.Font = Enum.Font.GothamBold
	otitle.ZIndex = zIdx + 1
	local xBtn = self:button(ohdr, "x", UDim2.new(0, 18, 0, 18), UDim2.new(1, -20, 0.5, -9), self.T.BTN, self.T.TEXT, 10)
	xBtn.ZIndex = zIdx + 1
	self:stroke(xBtn, self.T.STROKE, 1)

	-- Drag logic
	local UIS = game:GetService("UserInputService")
	do
		local dragging, dragStart, startPos = false, nil, nil
		ohdr.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1
			or i.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				dragStart = i.Position
				startPos = overlay.Position
				i.Changed:Connect(function()
					if i.UserInputState == Enum.UserInputState.End then dragging = false end
				end)
			end
		end)
		UIS.InputChanged:Connect(function(i)
			if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
			or i.UserInputType == Enum.UserInputType.Touch) then
				local delta = i.Position - dragStart
				overlay.Position = UDim2.new(
					startPos.X.Scale, startPos.X.Offset + delta.X,
					startPos.Y.Scale, startPos.Y.Offset + delta.Y
				)
			end
		end)
	end

	-- Search box di overlay
	local searchBox = self:input(overlay, "", "Search...", UDim2.new(1, -8, 0, 20), UDim2.new(0, 4, 0, 28))
	searchBox.TextColor3 = self.T.TEXT
	searchBox.TextSize = 9
	searchBox.ZIndex = zIdx + 1

	-- Scroll list
	local scrl = self:scroll(overlay, UDim2.new(1, -4, 1, -52), UDim2.new(0, 2, 0, 50))
	scrl.ZIndex = zIdx
	self:list(scrl, 3)
	self:pad(scrl, 3, 3, 3, 3)

	local function getSelName()
		if multi then
			local names = {}
			for _, item in ipairs(config.items or {}) do
				if selected[item.key] then table.insert(names, item.name) end
			end
			return #names > 0 and table.concat(names, ", ") or "Select..."
		else
			for _, item in ipairs(config.items or {}) do
				if item.key == selected then return item.name end
			end
			return "Select..."
		end
	end

	local function rebuild(q)
		for _, c in ipairs(scrl:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
		local ql = string.lower(q or "")
		for i, item in ipairs(config.items or {}) do
			if ql ~= "" and not string.lower(item.name):find(ql, 1, true) then continue end
			local isSel = multi and (selected[item.key] == true) or (selected == item.key)
			local btn = self:button(scrl, item.name, UDim2.new(1, 0, 0, 24), nil,
				isSel and strokeCol or self.T.BTN,
				isSel and self.T.SEL_TXT or self.T.TEXT, 10)
			btn.Font = Enum.Font.GothamBold
			btn.LayoutOrder = i
			btn.ZIndex = zIdx + 2
			self:corner(btn, 4)
			self:stroke(btn, isSel and strokeCol or self.T.STROKE, 1)
			local kc = item.key
			btn.MouseButton1Click:Connect(function()
				if multi then
					if selected[kc] then selected[kc] = nil else selected[kc] = true end
					rebuild(searchBox.Text)
					if not isStatic then valLbl.Text = getSelName() end
					if _cb then
						local res = {}
						for k in pairs(selected) do table.insert(res, k) end
						_cb(res)
					end
				else
					selected = kc
					if not isStatic then valLbl.Text = getSelName() end
					overlay.Visible = false
					searchBox.Text = ""
					if _cb then _cb(kc) end
				end
			end)
		end
	end

	searchBox:GetPropertyChangedSignal("Text"):Connect(function() rebuild(searchBox.Text) end)
	xBtn.MouseButton1Click:Connect(function() overlay.Visible = false; searchBox.Text = "" end)

	-- Hit button buat buka overlay
	local hitBtn = self:button(row, "", UDim2.new(1, 0, 1, 0), nil, self.T.BTN, self.T.TEXT, 10)
	hitBtn.BackgroundTransparency = 1
	hitBtn.ZIndex = 5
	hitBtn.MouseButton1Click:Connect(function()
		if overlay.Visible then
			overlay.Visible = false
			searchBox.Text = ""
		else
			task.defer(function()
				local parentSize = overlayParent.AbsoluteSize
				local overlaySize = overlay.AbsoluteSize
				local centerX = math.max(0, (parentSize.X - overlaySize.X) / 2)
				local centerY = math.max(0, (parentSize.Y - overlaySize.Y) / 2)
				overlay.Position = UDim2.new(0, centerX, 0, centerY)
			end)
			rebuild("")
			overlay.Visible = true
		end
	end)

	return {
		row = row,
		overlay = overlay,
		Set = function(v)
			if multi and type(v) == "table" then
				table.clear(selected)
				for _, k in ipairs(v) do selected[k] = true end
			else
				selected = v
			end
			if not isStatic then valLbl.Text = getSelName() end
		end,
		Get = function()
			if multi then
				local res = {}
				for k in pairs(selected) do table.insert(res, k) end
				return res
			end
			return selected
		end,
	}
end

function VoidUI:accordionScroll(parent, title, lo, startOpen, config)
	local cfg = config or {}
	local T = self.T
	local header = self:frame(parent, UDim2.new(1,0,0,32), nil, Color3.fromRGB(17, 17, 22))
	header.LayoutOrder = lo
	self:corner(header, 6)
	self:stroke(header, T.ACCENT, 1)
	self:label(header, title, UDim2.new(1,-40,1,0), UDim2.new(0,12,0,0), T.ACCENT, 10)
	local arrow = self:label(header, startOpen and "v" or ">", UDim2.new(0,20,1,0), UDim2.new(1,-26,0,0), T.DIM, 11, Enum.TextXAlignment.Center)
	local hitBtn = self:button(header, "", UDim2.new(1,0,1,0), nil, T.BTN, T.TEXT)
	hitBtn.BackgroundTransparency = 1
	hitBtn.ZIndex = 5

	local body = self:frame(parent, UDim2.new(1,0,0,0), nil, Color3.fromRGB(17, 17, 22))
	body.LayoutOrder = lo + 1
	body.Visible = startOpen ~= false
	self:corner(body, 6)
	self:stroke(body, T.ACCENT, 1)

	local inner = self:scroll(body, UDim2.new(1,0,0,0))
	inner.Size = UDim2.new(1,0,0, cfg.height or 300)
	inner.AutomaticCanvasSize = Enum.AutomaticSize.Y
	inner.ScrollBarThickness = 3
	inner.ScrollBarImageColor3 = T.ACCENT

	self:list(inner, cfg.gap or 5)
	self:pad(inner, cfg.pt or 8, cfg.pl or 8, cfg.pr or 8, cfg.pb or 8)

	local isOpen = startOpen ~= false
	hitBtn.MouseButton1Click:Connect(function()
		isOpen = not isOpen
		body.Visible = isOpen
		arrow.Text = isOpen and "v" or ">"
	end)
	return { Header=header, Body=body, Inner=inner, Arrow=arrow }
end



function VoidUI:updateRowVisual(row, isSel, selBG, selTxt, defaultBG, defaultTxt, accentStroke, dimStroke)
    row.BackgroundColor3 = isSel and selBG or defaultBG
    row.TextColor3 = isSel and selTxt or defaultTxt
    local s = row:FindFirstChildOfClass("UIStroke")
    if s then s.Color = isSel and accentStroke or dimStroke end
end


function VoidUI:updateRowVisualWithSub(row, isSel, selBG, selTxt, defaultBG, defaultTxt, accentStroke, dimStroke, subSelColor, subDefaultColor)
    row.BackgroundColor3 = isSel and selBG or defaultBG
    row.TextColor3 = isSel and selTxt or defaultTxt
    local s = row:FindFirstChildOfClass("UIStroke")
    if s then s.Color = isSel and accentStroke or dimStroke end
    local sub = row:FindFirstChildOfClass("TextLabel")
    if sub then sub.TextColor3 = isSel and subSelColor or subDefaultColor end
end



function VoidUI.fmtTime(secs)
    secs = math.floor(secs)
    local h = math.floor(secs/3600)
    local m = math.floor((secs%3600)/60)
    local s = secs % 60
    if h > 0 then return string.format("%dh %dm %ds", h, m, s)
    elseif m > 0 then return string.format("%dm %ds", m, s)
    else return string.format("%ds", s) end
end



function VoidUI:sidebar(parent)
	local scroll = Instance.new("ScrollingFrame", parent)
	scroll.Size = UDim2.new(1,0,1,0)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 0
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new(0,0,0,0)

	local list = Instance.new("Frame", scroll)
	list.Size = UDim2.new(1,0,0,0)
	list.BackgroundTransparency = 1
	list.AutomaticSize = Enum.AutomaticSize.Y

	local layout = Instance.new("UIListLayout", list)
	layout.Padding = UDim.new(0,2)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local pad = Instance.new("UIPadding", list)
	pad.PaddingTop = UDim.new(0,6)
	pad.PaddingBottom = UDim.new(0,6)

	return list
end

function VoidUI:iconBtn(parent, icon, label)
	local T = self.T
	local b = Instance.new("TextButton", parent)
	b.Size = UDim2.new(1,-8,0,38)
	b.BackgroundColor3 = T.BTN
	b.BackgroundTransparency = 1
	b.BorderSizePixel = 0
	b.Text = ""
	b.AutoButtonColor = false
	self:corner(b,7)

	local accentBar = Instance.new("Frame",b)
	accentBar.Size = UDim2.new(0,2,0,20)
	accentBar.Position = UDim2.new(0,0,0.5,-10)
	accentBar.BackgroundColor3 = T.ACCENT
	accentBar.BorderSizePixel = 0
	accentBar.Visible = false
	self:corner(accentBar,2)

	local iconLbl = Instance.new("TextLabel",b)
	iconLbl.Size = UDim2.new(1,0,0,20)
	iconLbl.Position = UDim2.new(0,0,0,5)
	iconLbl.BackgroundTransparency = 1
	iconLbl.Text = icon
	iconLbl.TextColor3 = T.DIM
	iconLbl.Font = Enum.Font.GothamBold
	iconLbl.TextSize = 14
	iconLbl.TextXAlignment = Enum.TextXAlignment.Center

	local textLbl = Instance.new("TextLabel",b)
	textLbl.Size = UDim2.new(1,0,0,10)
	textLbl.Position = UDim2.new(0,0,0,25)
	textLbl.BackgroundTransparency = 1
	textLbl.Text = label
	textLbl.TextColor3 = T.DIM
	textLbl.Font = Enum.Font.Gotham
	textLbl.TextSize = 7
	textLbl.TextXAlignment = Enum.TextXAlignment.Center

	b.MouseEnter:Connect(function()
		if not accentBar.Visible then
			b.BackgroundTransparency = 0.85
			b.BackgroundColor3 = T.ACCENT
			iconLbl.TextColor3 = Color3.fromRGB(247, 177, 2)
			textLbl.TextColor3 = Color3.fromRGB(247, 177, 2)
		end
	end)
	b.MouseLeave:Connect(function()
		if not accentBar.Visible then
			b.BackgroundTransparency = 1
			b.BackgroundColor3 = T.BTN
			iconLbl.TextColor3 = T.DIM
			textLbl.TextColor3 = T.DIM
		end
	end)

	local function setActive(s)
		accentBar.Visible = s
		if s then
			b.BackgroundColor3 = Color3.fromRGB(58, 45, 10)
			b.BackgroundTransparency = 0
			iconLbl.TextColor3 = T.ACCENT
			textLbl.TextColor3 = T.ACCENT
		else
			b.BackgroundColor3 = T.BTN
			b.BackgroundTransparency = 1
			iconLbl.TextColor3 = T.DIM
			textLbl.TextColor3 = T.DIM
		end
	end

	return { Button=b, SetActive=setActive }
end

function VoidUI:sidebarDivider(parent)
	local d = Instance.new("Frame", parent)
	d.Size = UDim2.new(0,30,0,1)
	d.BackgroundColor3 = Color3.fromRGB(58, 45, 10)
	d.BorderSizePixel = 0
	return d
end

function VoidUI:labelWrap(parent, text, size, pos, col, fs, xa)
	local l = Instance.new("TextLabel")
	l.Size = size or UDim2.new(1, 0, 0, 0)
	l.Position = pos or UDim2.new(0, 0, 0, 0)
	l.BackgroundTransparency = 1
	l.Text = text or ""
	l.TextColor3 = col or self.T.TEXT
	l.Font = Enum.Font.GothamBold
	l.TextSize = fs or 11
	l.TextXAlignment = xa or Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.None
	l.TextWrapped = true
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.Parent = parent
	return l
end

function VoidUI:teamCard(parent, teamName, petNames, count, lo, onSwap, onDelete)
	local T = self.T
	local PETS_PER_ROW = 3
	local rows = math.ceil(#petNames / PETS_PER_ROW)
	local cardH = 26 + math.max(1, rows) * 14 + 8

	local card = self:frame(parent, UDim2.new(1,0,0,cardH), nil, T.BTN)
	card.LayoutOrder = lo
	self:corner(card, 6)
	self:stroke(card, T.STROKE, 1)

	local nameH = 20
	self:label(card, teamName, UDim2.new(1,-60,0,nameH), UDim2.new(0,8,0,4), T.TEXT, 10)

	
	local badgeLbl = self:label(card, count.." pet(s)", UDim2.new(0,50,0,14), UDim2.new(0,8,0,nameH+4), T.ACCENT, 8)
	badgeLbl.Font = Enum.Font.GothamBold

	
	local yOff = nameH + 4
	for rowIdx = 1, rows do
		local startI = (rowIdx-1)*PETS_PER_ROW + 1
		local endI   = math.min(rowIdx*PETS_PER_ROW, #petNames)
		local chunk  = {}
		for k = startI, endI do table.insert(chunk, petNames[k]) end
		local line = table.concat(chunk, "  ·  ")
		local lbl = self:label(card, line, UDim2.new(1,-68,0,14), UDim2.new(0,8,0,yOff), T.TEXT, 8)
		lbl.Font = Enum.Font.Gotham
		lbl.TextTruncate = Enum.TextTruncate.AtEnd
		yOff = yOff + 14
	end

	local swapBtn = self:button(card, "⇄", UDim2.new(0,26,0,22), UDim2.new(1,-58,0.5,-11), T.ACCENT, T.SEL_TXT, 12)
	self:stroke(swapBtn, T.ACCENT, 1)
	swapBtn.MouseButton1Click:Connect(onSwap)

	
	local delBtn = self:button(card, "-", UDim2.new(0,26,0,22), UDim2.new(1,-28,0.5,-11), T.ERROR, T.TEXT, 14)
	self:stroke(delBtn, T.ERROR, 1)
	delBtn.MouseButton1Click:Connect(onDelete)

	return card
end


function VoidUI:builtinTeamCard(parent, name, desc, lo, onEquip)
	local T = self.T
	local card = self:frame(parent, UDim2.new(1, 0, 0, 52), nil, Color3.fromRGB(24, 24, 31))
	card.LayoutOrder = lo
	self:corner(card, 6)
	local stroke = Instance.new("UIStroke", card)
	stroke.Color = Color3.fromRGB(58, 45, 10)
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	
	local badge = self:frame(card, UDim2.new(0, 74, 0, 14), UDim2.new(0, 58, 0, 4), Color3.fromRGB(58, 45, 10))
	self:corner(badge, 4)
	local badgeIcon = Instance.new("ImageLabel", badge)
	badgeIcon.Size = UDim2.new(0, 10, 0, 10)
	badgeIcon.Position = UDim2.new(0, 2, 0.5, -5)
	badgeIcon.BackgroundTransparency = 1
	badgeIcon.Image = "rbxthumb://type=Asset&id=5669312251&w=150&h=150"
	badgeIcon.ScaleType = Enum.ScaleType.Fit
	local badgeLbl = self:label(badge, "BUILT-IN", UDim2.new(1, -14, 1, 0), UDim2.new(0, 13, 0, 0), Color3.fromRGB(247, 177, 2), 7, Enum.TextXAlignment.Center)
	badgeLbl.Font = Enum.Font.GothamBold

	
	local nameLbl = self:label(card, name, UDim2.new(1, -100, 0, 16), UDim2.new(0, 8, 0, 18), Color3.fromRGB(245, 243, 236), 10)
	nameLbl.Font = Enum.Font.GothamBold
	local descLbl = self:label(card, desc, UDim2.new(1, -100, 0, 13), UDim2.new(0, 8, 0, 35), T.DIM, 8)
	descLbl.Font = Enum.Font.Gotham

	
	local veliumLogo = Instance.new("ImageLabel", card)
	veliumLogo.Size = UDim2.new(0, 32, 0, 32)
	veliumLogo.Position = UDim2.new(1, -68, 0.5, -16)
	veliumLogo.BackgroundTransparency = 1
	veliumLogo.Image = "rbxthumb://type=Asset&id=115906524559615&w=150&h=150"
	veliumLogo.ScaleType = Enum.ScaleType.Fit
	veliumLogo.ImageTransparency = 0.2

	
	local equipBtn = self:button(card, "⇄", UDim2.new(0, 28, 0, 28), UDim2.new(1, -36, 0.5, -14), Color3.fromRGB(58, 45, 10), Color3.fromRGB(247, 177, 2), 12)
	self:stroke(equipBtn, Color3.fromRGB(58, 45, 10), 1)
	equipBtn.MouseButton1Click:Connect(function() if onEquip then onEquip() end end)
	return card
end
function VoidUI:teamCard(parent, name, petNames, count, lo, onEquip, onDelete)
	local T = self.T
	local mutCount = {}
	for _, pt in ipairs(petNames) do
		mutCount[pt] = (mutCount[pt] or 0) + 1
	end
	local summaryParts = {}
	for ptype, cnt in pairs(mutCount) do
		local baseName, mutName = ptype:match("^(.-)%s*%[(.+)%]%s*$")
		if baseName and mutName then
			table.insert(summaryParts, { key = baseName .. mutName, text = cnt .. " [" .. mutName .. "] " .. baseName })
		else
			table.insert(summaryParts, { key = ptype, text = cnt .. " " .. ptype })
		end
	end
	table.sort(summaryParts, function(a, b) return a.key < b.key end)
	local card = self:frame(parent, UDim2.new(1, 0, 0, 52), nil, T.BTN)
	card.LayoutOrder = lo
	self:corner(card, 6)
	self:stroke(card, T.STROKE, 1)
	local nameLbl = self:label(card, name, UDim2.new(1, -72, 0, 18), UDim2.new(0, 10, 0, 4), T.ACCENT, 10)
	nameLbl.Font = Enum.Font.GothamBold
	local subContainer = Instance.new("ScrollingFrame", card)
	subContainer.Size = UDim2.new(1, -72, 0, 14)
	subContainer.Position = UDim2.new(0, 10, 0, 24)
	subContainer.BackgroundTransparency = 1
	subContainer.BorderSizePixel = 0
	subContainer.ScrollBarThickness = 2
	subContainer.ScrollBarImageColor3 = Color3.fromRGB(247, 177, 2)
	subContainer.ScrollingDirection = Enum.ScrollingDirection.X
	subContainer.AutomaticCanvasSize = Enum.AutomaticSize.X
	subContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
	local subLayout = Instance.new("UIListLayout", subContainer)
	subLayout.FillDirection = Enum.FillDirection.Horizontal
	subLayout.Padding = UDim.new(0, 4)
	subLayout.SortOrder = Enum.SortOrder.LayoutOrder
	subLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	for i, entry in ipairs(summaryParts) do
		local countStr, mutStr, petStr = entry.text:match("^(%d+ )%[(.-)%] (.+)$")
		if mutStr then
			local lblPet = Instance.new("TextLabel", subContainer)
			lblPet.Size = UDim2.new(0, 0, 1, 0)
			lblPet.AutomaticSize = Enum.AutomaticSize.X
			lblPet.BackgroundTransparency = 1
			lblPet.Font = Enum.Font.Gotham
			lblPet.TextSize = 8
			lblPet.Text = countStr .. petStr
			lblPet.TextColor3 = Color3.fromRGB(250, 222, 2)
			lblPet.LayoutOrder = i * 3 - 2
			local lblMut = Instance.new("TextLabel", subContainer)
			lblMut.Size = UDim2.new(0, 0, 1, 0)
			lblMut.AutomaticSize = Enum.AutomaticSize.X
			lblMut.BackgroundTransparency = 1
			lblMut.Font = Enum.Font.GothamBold
			lblMut.TextSize = 8
			lblMut.Text = "[" .. mutStr .. "]"
			lblMut.TextColor3 = Color3.fromRGB(199, 120, 2)
			lblMut.LayoutOrder = i * 3 - 1
		else
			local lbl = Instance.new("TextLabel", subContainer)
			lbl.Size = UDim2.new(0, 0, 1, 0)
			lbl.AutomaticSize = Enum.AutomaticSize.X
			lbl.BackgroundTransparency = 1
			lbl.Font = Enum.Font.Gotham
			lbl.TextSize = 8
			lbl.Text = entry.text
			lbl.TextColor3 = T.DIM
			lbl.LayoutOrder = i * 3 - 2
		end
		if i < #summaryParts then
			local sep = Instance.new("TextLabel", subContainer)
			sep.Size = UDim2.new(0, 6, 1, 0)
			sep.BackgroundTransparency = 1
			sep.Font = Enum.Font.Gotham
			sep.TextSize = 8
			sep.Text = "·"
			sep.TextColor3 = T.DIM
			sep.LayoutOrder = i * 3
		end
	end
	local equipBtn = self:button(card, "⇄", UDim2.new(0, 28, 0, 28), UDim2.new(1, -62, 0.5, -14), T.PANEL, T.ACCENT, 14)
	self:stroke(equipBtn, T.ACCENT, 1)
	local delBtn = self:button(card, "-", UDim2.new(0, 28, 0, 28), UDim2.new(1, -30, 0.5, -14), T.ERROR, T.TEXT, 16)
	self:stroke(delBtn, T.ERROR, 1)
	equipBtn.MouseButton1Click:Connect(function() if onEquip then onEquip() end end)
	delBtn.MouseButton1Click:Connect(function() if onDelete then onDelete() end end)
	return card
end




function VoidUI:timingEditor(acInner, pageFrame, CFG, D, saveD)
	local T = self.T

	local defaults = {
		ahEquipDelay       = 0.15,
		ahUnequipDelay     = 0.10,
		postUnequipBuffer  = 0.50,
		koiSafeDelay       = 1.00,
		koiPostHatch       = 1.50,
		sealSafeDelay      = 1.00,
		sealPostSell       = 2.00,
	}
	for k, v in pairs(defaults) do
		if D.autoHatch[k] == nil then D.autoHatch[k] = v end
	end

	local function syncCFG()
		CFG.AH_EQUIP_DELAY          = D.autoHatch.ahEquipDelay
		CFG.AH_UNEQUIP_DELAY        = D.autoHatch.ahUnequipDelay
		CFG.AH_POST_UNEQUIP_BUFFER  = D.autoHatch.postUnequipBuffer
		CFG.AH_KOI_SAFE_DELAY       = D.autoHatch.koiSafeDelay
		CFG.AH_KOI_POST_HATCH       = D.autoHatch.koiPostHatch
		CFG.AH_SEAL_SAFE_DELAY      = D.autoHatch.sealSafeDelay
		CFG.AH_SEAL_POST_SELL       = D.autoHatch.sealPostSell
	end
	syncCFG()

	local teBtn = self:button(
		acInner,
		"⏱  Timing Editor",
		UDim2.new(1, 0, 0, 24),
		nil,
		Color3.fromRGB(58, 45, 10),
		Color3.fromRGB(247, 177, 2),
		9
	)
	self:stroke(teBtn, Color3.fromRGB(58, 45, 10), 1)
	teBtn.TextXAlignment = Enum.TextXAlignment.Left
	self:pad(teBtn, 0, 8, 8, 0)
	local teBtnArrow = self:label(teBtn, ">", UDim2.new(0, 16, 1, 0), UDim2.new(1, -20, 0, 0), Color3.fromRGB(199, 120, 2), 11, Enum.TextXAlignment.Center)
	teBtnArrow.Font = Enum.Font.GothamBold

	local overlay = self:frame(pageFrame, UDim2.new(1, 0, 1, 0), nil, T.BG)
	overlay.Visible = false
	overlay.ZIndex  = 20

	local ohdr = self:frame(overlay, UDim2.new(1, 0, 0, 26), nil, T.PANEL)
	self:stroke(ohdr, T.STROKE, 1)
	self:label(ohdr, "⏱  TIMING EDITOR", UDim2.new(1, -80, 1, 0), UDim2.new(0, 8, 0, 0), T.ACCENT, 10)
	local closeBtn = self:button(ohdr, "← Back", UDim2.new(0, 54, 0, 20), UDim2.new(1, -58, 0.5, -10), T.BTN, T.DIM, 8)
	self:stroke(closeBtn, T.STROKE, 1)
	closeBtn.MouseButton1Click:Connect(function() overlay.Visible = false end)

	local sc = self:scroll(overlay, UDim2.new(1, 0, 1, -26), UDim2.new(0, 0, 0, 26))
	sc.ScrollBarThickness = 3
	sc.ScrollBarImageColor3 = T.ACCENT
	local inner = Instance.new("Frame", sc)
	inner.Size = UDim2.new(1, 0, 0, 0)
	inner.BackgroundTransparency = 1
	inner.AutomaticSize = Enum.AutomaticSize.Y
	self:list(inner, 4)
	self:pad(inner, 6, 6, 6, 20)

	local function secHdr(label, lo)
		local f = self:frame(inner, UDim2.new(1, 0, 0, 14), nil, T.BG, 1)
		f.LayoutOrder = lo
		local l = self:label(f, label, UDim2.new(1, 0, 1, 0), nil, Color3.fromRGB(166, 164, 160), 8)
		l.Font = Enum.Font.GothamBold
		return f
	end

	local totalLabels = {}

	local function kvRow(label, badge, badgeColor, dataKey, lo)
		local row = self:frame(inner, UDim2.new(1, 0, 0, 24), nil, T.BTN)
		row.LayoutOrder = lo
		self:corner(row, 4)
		self:stroke(row, T.STROKE, 1)

		local lbl = self:label(row, label, UDim2.new(1, -110, 1, 0), UDim2.new(0, 8, 0, 0), T.DIM, 9)
		lbl.Font = Enum.Font.Gotham

		local bdg = self:frame(row, UDim2.new(0, 34, 0, 14), UDim2.new(1, -104, 0.5, -7), badgeColor)
		self:corner(bdg, 3)
		local bdgLbl = self:label(bdg, badge, UDim2.new(1, 0, 1, 0), nil, Color3.fromRGB(245, 243, 236), 7, Enum.TextXAlignment.Center)
		bdgLbl.Font = Enum.Font.GothamBold

		local inp = self:input(row, string.format("%.2f", D.autoHatch[dataKey]), "", UDim2.new(0, 46, 0, 18), UDim2.new(1, -58, 0.5, -9))
		inp.ZIndex = 5

		local secLbl = self:label(row, " sec", UDim2.new(0, 24, 1, 0), UDim2.new(1, -24, 0, 0), Color3.fromRGB(166, 164, 160), 8, Enum.TextXAlignment.Left)
		secLbl.Font = Enum.Font.Gotham

		local valLbl = self:label(row, string.format("%.2f", D.autoHatch[dataKey]), UDim2.new(0, 0, 1, 0), UDim2.new(0, 0, 0, 0), T.ACCENT, 1)
		valLbl.Visible = false

		inp.FocusLost:Connect(function()
			local v = tonumber(inp.Text)
			if v and v >= 0 then
				D.autoHatch[dataKey] = v
				inp.Text = string.format("%.2f", v)
				syncCFG()
				saveD()
			else
				inp.Text = string.format("%.2f", D.autoHatch[dataKey])
			end
		end)

		return row, valLbl
	end

	local function totalRow(label, id, lo, accent)
		local row = self:frame(inner, UDim2.new(1, 0, 0, 22), nil, Color3.fromRGB(17, 17, 22))
		row.LayoutOrder = lo
		self:corner(row, 4)
		self:stroke(row, accent and T.ACCENT or T.STROKE, 1)
		local lbl = self:label(row, label, UDim2.new(1, -60, 1, 0), UDim2.new(0, 8, 0, 0), accent and Color3.fromRGB(180, 180, 210) or T.DIM, 8)
		lbl.Font = Enum.Font.Gotham
		local val = self:label(row, "–", UDim2.new(0, 52, 1, 0), UDim2.new(1, -56, 0, 0), accent and Color3.fromRGB(200, 180, 255) or T.ACCENT, accent and 10 or 9, Enum.TextXAlignment.Right)
		val.Font = Enum.Font.GothamBold
		totalLabels[id] = val
		return row
	end

	local function recalc()
		local n    = 8
		local eq   = D.autoHatch.ahEquipDelay      or 0.15
		local uneq = D.autoHatch.ahUnequipDelay     or 0.10
		local buf  = D.autoHatch.postUnequipBuffer  or 0.50
		local ks   = D.autoHatch.koiSafeDelay       or 1.00
		local kp   = D.autoHatch.koiPostHatch        or 1.50
		local ss   = D.autoHatch.sealSafeDelay      or 1.00
		local sp   = D.autoHatch.sealPostSell        or 2.00
		local koi  = (uneq * n) + buf + (eq * n) + ks + kp
		local seal = (uneq * n) + buf + (eq * n) + ss + sp
		if totalLabels["koi"]   then totalLabels["koi"].Text   = string.format("%.2f sec", koi)        end
		if totalLabels["seal"]  then totalLabels["seal"].Text  = string.format("%.2f sec", seal)       end
		if totalLabels["grand"] then totalLabels["grand"].Text = string.format("%.2f sec", koi + seal) end
	end

	local COLOR_ALL  = Color3.fromRGB(58, 45, 10)
	local COLOR_KOI  = Color3.fromRGB(24, 24, 31)
	local COLOR_SEAL = Color3.fromRGB(17, 17, 22)

	secHdr("EQUIP / UNEQUIP", 1)
	kvRow("Equip delay (per pet)",   "ALL", COLOR_ALL,  "ahEquipDelay",     2)
	kvRow("Unequip delay (per pet)", "ALL", COLOR_ALL,  "ahUnequipDelay",   3)
	kvRow("Post-unequip buffer",     "ALL", COLOR_ALL,  "postUnequipBuffer", 4)

	secHdr("KOI TEAM", 5)
	kvRow("Safety delay (post-verified)", "KOI",  COLOR_KOI,  "koiSafeDelay", 6)
	kvRow("Post-hatch delay",             "KOI",  COLOR_KOI,  "koiPostHatch", 7)

	secHdr("SEAL TEAM", 8)
	kvRow("Safety delay (post-verified)", "SEAL", COLOR_SEAL, "sealSafeDelay", 9)
	kvRow("Post-sell delay",              "SEAL", COLOR_SEAL, "sealPostSell",  10)

	self:divider(inner, 11)

	totalRow("Koi fixed total (8 pet)",  "koi",   12, false)
	totalRow("Seal fixed total (8 pet)", "seal",  13, false)
	totalRow("Grand total (Koi + Seal)", "grand", 14, true)

	recalc()

	teBtn.MouseButton1Click:Connect(function()
		recalc()
		overlay.Visible = true
	end)

	return teBtn, overlay
end


function VoidUI:logPanel(parent, lo, maxLines)
	local T = self.T
	maxLines = maxLines or 45
	local panel = self:frame(parent, UDim2.new(1,0,0,64), nil, T.PANEL)
	panel.LayoutOrder = lo
	self:stroke(panel, T.STROKE, 1)
	local hdr = self:frame(panel, UDim2.new(1,0,0,14), nil, T.BG, 1)
	self:label(hdr, "LOGS", UDim2.new(1,0,1,0), UDim2.new(0,6,0,0), T.ACCENT, 8).Font = Enum.Font.GothamBold
	local scroll = self:scroll(panel, UDim2.new(1,-4,1,-16), UDim2.new(0,2,0,15))
	self:list(scroll, 1); self:pad(scroll, 1,4,4,1)
	local count = 0
	local function addLog(msg, col)
		count = count + 1
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1,0,0,12)
		row.BackgroundTransparency = 1
		row.Text = os.date("%H:%M:%S").."  "..msg
		row.TextColor3 = col or T.DIM
		row.Font = Enum.Font.Gotham
		row.TextSize = 8
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextTruncate = Enum.TextTruncate.AtEnd
		row.LayoutOrder = count
		row.Parent = scroll
		local kids = {}
		for _, c in ipairs(scroll:GetChildren()) do
			if c:IsA("TextLabel") then table.insert(kids, c) end
		end
		while #kids > maxLines do kids[1]:Destroy(); table.remove(kids, 1) end
		task.defer(function() scroll.CanvasPosition = Vector2.new(0, math.huge) end)
	end
	return panel, addLog, hdr
end


function VoidUI:boostStatusRow(parent, lo)
	local T = self.T
	local row = self:frame(parent, UDim2.new(1,0,0,24), nil, T.PANEL)
	row.LayoutOrder = lo
	self:stroke(row, T.STROKE, 1)
	local lbl = self:label(row, "BOOST STATUS", UDim2.new(0,100,1,0), UDim2.new(0,8,0,0), T.DIM, 8)
	lbl.Font = Enum.Font.Gotham
	local val = self:label(row, "—", UDim2.new(1,-112,1,0), UDim2.new(0,114,0,0), T.DIM, 8, Enum.TextXAlignment.Right)
	val.Font = Enum.Font.Gotham
	val.TextTruncate = Enum.TextTruncate.AtEnd
	return row, val
end


function VoidUI:modePickerRow(parent, config)

	local T = self.T
	local modes     = config.modes or {}
	local selectedKey = config.default or (modes[1] and modes[1].key)
	local _cb       = config.onSelect
	local overlayParent = config.overlayParent or parent

	local row = self:frame(parent, config.size or UDim2.new(1,0,0,28), config.pos, T.BTN)
	self:corner(row, 5)
	self:stroke(row, T.STROKE, 1)

	local labelW = 0
	if config.label then
		local lbl = self:label(row, config.label, UDim2.new(0,90,1,0), UDim2.new(0,6,0,0), T.DIM, 9)
		lbl.Font = Enum.Font.Gotham
		labelW = 96
	end

	local function getSelName()
		for _, m in ipairs(modes) do
			if m.key == selectedKey then return m.name end
		end
		return "Select..."
	end
	local valLbl = self:label(row,
		getSelName(),
		UDim2.new(1, -(labelW+22), 1, 0),
		UDim2.new(0, labelW+2, 0, 0),
		T.ACCENT, 9, Enum.TextXAlignment.Left)
	valLbl.Font = Enum.Font.GothamBold

	local arrowLbl = self:label(row, "▼", UDim2.new(0,14,1,0), UDim2.new(1,-18,0,0), T.DIM, 8, Enum.TextXAlignment.Center)

	local overlay = self:frame(overlayParent, UDim2.new(1,0,0,0), UDim2.new(0,0,0,0), Color3.fromRGB(17, 17, 22))
	overlay.AutomaticSize = Enum.AutomaticSize.Y
	overlay.Visible = false
	overlay.ZIndex = 40
	self:corner(overlay, 6)
	self:stroke(overlay, T.ACCENT, 1)

	local ovScroll = self:scroll(overlay, UDim2.new(1,0,0,0), UDim2.new(0,0,0,0))
	ovScroll.AutomaticSize = Enum.AutomaticSize.Y
	ovScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	ovScroll.ScrollBarThickness = 3
	ovScroll.ScrollBarImageColor3 = T.ACCENT
	ovScroll.ZIndex = 40

	local innerList = self:frame(ovScroll, UDim2.new(1,0,0,0), nil, Color3.fromRGB(17, 17, 22), 0)
	innerList.AutomaticSize = Enum.AutomaticSize.Y
	self:list(innerList, 4)
	self:pad(innerList, 6, 6, 6, 6)
	innerList.ZIndex = 40

	local cardRefs = {}

	local function refreshCards()
		for _, ref in ipairs(cardRefs) do
			local isSel = ref.key == selectedKey
			ref.card.BackgroundColor3   = isSel and Color3.fromRGB(247, 177, 2) or Color3.fromRGB(24, 24, 31)
			local s = ref.card:FindFirstChildOfClass("UIStroke")
			if s then s.Color = isSel and T.ACCENT or T.STROKE end
			ref.badge.BackgroundColor3  = isSel and Color3.fromRGB(22, 22, 22) or T.STROKE
			ref.nameLbl.TextColor3      = isSel and Color3.fromRGB(22, 22, 22) or T.TEXT
		end
	end

	for i, mode in ipairs(modes) do
		local isSel = mode.key == selectedKey
		local card = self:frame(innerList, UDim2.new(1,0,0,46), nil,
			isSel and Color3.fromRGB(247, 177, 2) or Color3.fromRGB(24, 24, 31))
		card.LayoutOrder = i
		card.ZIndex = 41
		self:corner(card, 5)
		self:stroke(card, isSel and T.ACCENT or T.STROKE, 1)

		local badge = self:frame(card, UDim2.new(0,22,0,22), UDim2.new(0,6,0.5,-11),
			isSel and Color3.fromRGB(22, 22, 22) or T.STROKE)
		badge.ZIndex = 42
		self:corner(badge, 4)
		local badgeLbl = self:label(badge, tostring(mode.key), UDim2.new(1,0,1,0), nil,
			Color3.fromRGB(22, 22, 22), 10, Enum.TextXAlignment.Center)
		badgeLbl.Font = Enum.Font.GothamBold
		badgeLbl.ZIndex = 42

		local nameLbl = self:label(card, mode.name,
			UDim2.new(1,-36,0,16), UDim2.new(0,34,0,4),
			isSel and T.ACCENT or T.TEXT, 9)
		nameLbl.Font = Enum.Font.GothamBold
		nameLbl.ZIndex = 42

		local descLbl = self:label(card, mode.desc,
			UDim2.new(1,-36,0,14), UDim2.new(0,34,0,22),
			T.DIM, 8)
		descLbl.Font = Enum.Font.Gotham
		descLbl.ZIndex = 42
		descLbl.TextWrapped = true
		descLbl.TextTruncate = Enum.TextTruncate.None

		local hit = self:button(card, "", UDim2.new(1,0,1,0), nil, T.BTN, T.TEXT)
		hit.BackgroundTransparency = 1
		hit.ZIndex = 43
		local capturedKey = mode.key
		hit.MouseButton1Click:Connect(function()
			selectedKey = capturedKey
			valLbl.Text = getSelName()
			refreshCards()
			overlay.Visible = false
			arrowLbl.Text = "▼"
			if _cb then _cb(capturedKey) end
		end)

		table.insert(cardRefs, {
			key     = mode.key,
			card    = card,
			badge   = badge,
			nameLbl = nameLbl,
		})
	end

	local hitRow = self:button(row, "", UDim2.new(1,0,1,0), nil, T.BTN, T.TEXT)
	hitRow.BackgroundTransparency = 1
	hitRow.ZIndex = 5
	hitRow.MouseButton1Click:Connect(function()
		overlay.Visible = not overlay.Visible
		arrowLbl.Text = overlay.Visible and "▲" or "▼"
		if overlay.Visible then
			local rowAbsY = row.AbsolutePosition.Y
			local parentAbsY = overlayParent.AbsolutePosition.Y
			local relY = (rowAbsY - parentAbsY) + row.AbsoluteSize.Y + 2
			overlay.Position = UDim2.new(0, 0, 0, relY)
		end
	end)

	return {
		row     = row,
		overlay = overlay,
		Get     = function() return selectedKey end,
		Set     = function(k)
			selectedKey = k
			valLbl.Text = getSelName()
			refreshCards()
		end,
	}
end

return VoidUI



