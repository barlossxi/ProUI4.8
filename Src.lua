local Wally = {}

local cloneref = cloneref or function(value)
    return value
end

local getgenv = getgenv or function()
    return _G
end

local TweenService = cloneref(game:GetService("TweenService"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local Players = cloneref(game:GetService("Players"))
local CoreGui = cloneref(game:GetService("CoreGui"))
local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

local Environment = getgenv()
local ProtectGui = protect_gui or protectgui or (syn and syn.protect_gui) or function(gui)
    return gui
end

local function GetGuiParent()
    local ok, gui = pcall(function()
        if gethui then
            return gethui()
        end

        if get_hidden_gui then
            return get_hidden_gui()
        end
    end)

    if ok and gui then
        return gui
    end

    if LocalPlayer then
        return LocalPlayer:WaitForChild("PlayerGui")
    end

    return CoreGui
end

local function PickColor(...)
    for _, color in next, { ... } do
        if typeof(color) == "Color3" then
            return color
        end
    end
end

local Theme = {
    Main = PickColor(Environment.MainColor, Color3.fromRGB(20, 20, 20)),
    Secondary = PickColor(Environment.SecondaryColor, Color3.fromRGB(26, 26, 26)),
    Tertiary = PickColor(Environment.TertiaryColor, Color3.fromRGB(38, 38, 38)),
    Accent = PickColor(Environment.WallyAccentColor, Environment.SliderColor, Environment.ButtonColor, Environment.ToggleColor, Color3.fromRGB(255, 184, 0)),
    Text = PickColor(Environment.MainTextColor, Color3.fromRGB(245, 245, 245)),
    SubText = PickColor(Environment.TextColor, Color3.fromRGB(170, 170, 170)),
    Muted = PickColor(Environment.ArrowColor, Color3.fromRGB(85, 85, 85)),
    Stroke = Color3.fromRGB(50, 50, 50),
}

local GuiParent = GetGuiParent()
local ScreenGuiName = "ProUI48_Wally"
local ExistingGui = GuiParent and GuiParent:FindFirstChild(ScreenGuiName)

if ExistingGui then
    ExistingGui:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = ScreenGuiName
ScreenGui.IgnoreGuiInset = true
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
pcall(ProtectGui, ScreenGui)
ScreenGui.Parent = GuiParent

Wally.ScreenGui = ScreenGui
Wally.Theme = Theme
Wally.Flags = {}
Wally.Windows = {}
Wally.GlobalSignals = {}
Wally.UnloadEnabled = true
Wally.Count = 0
Wally.Scales = {
    Compact = UDim2.fromOffset(260, 0),
    PC = UDim2.fromOffset(420, 0),
    Mobile = UDim2.fromOffset(320, 0),
}

local DefaultTween = TweenInfo.new(0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local FastTween = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function AddSignal(signal)
    table.insert(Wally.GlobalSignals, signal)
    return signal
end

function Wally:AddSignal(signal)
    return AddSignal(signal)
end

local function SafeCall(callback, ...)
    if callback then
        local ok, err = pcall(callback, ...)
        if not ok then
            warn("[ProUI4.8]", err)
        end
    end
end

local function Tween(object, properties, info)
    local tween = TweenService:Create(object, info or DefaultTween, properties)
    tween:Play()
    return tween
end

local function New(className, properties)
    local object = Instance.new(className)
    local parent = properties and properties.Parent

    for key, value in next, properties or {} do
        if key ~= "Parent" then
            object[key] = value
        end
    end

    object.Parent = parent
    return object
end

local function Corner(parent, radius)
    return New("UICorner", {
        CornerRadius = UDim.new(0, radius or 6),
        Parent = parent,
    })
end

local function Stroke(parent, color, transparency)
    return New("UIStroke", {
        Color = color or Theme.Stroke,
        Transparency = transparency or 0.35,
        Parent = parent,
    })
end

local function Padding(parent, left, top, right, bottom)
    return New("UIPadding", {
        PaddingLeft = UDim.new(0, left or 0),
        PaddingTop = UDim.new(0, top or 0),
        PaddingRight = UDim.new(0, right or left or 0),
        PaddingBottom = UDim.new(0, bottom or top or 0),
        Parent = parent,
    })
end

local function NormalizeControlConfig(config, fallbackName)
    if typeof(config) == "table" then
        config.Name = config.Name or config.Text or config.Title or fallbackName
        return config
    end

    return {
        Name = tostring(config or fallbackName or "Control"),
    }
end

local function ToArray(value)
    local array = {}

    if typeof(value) ~= "table" then
        if value ~= nil then
            table.insert(array, value)
        end

        return array
    end

    for key, item in next, value do
        if item == true then
            table.insert(array, key)
        elseif typeof(key) == "number" and item ~= nil then
            table.insert(array, item)
        end
    end

    return array
end

local function ToSelectedMap(value)
    local selected = {}

    for _, item in next, ToArray(value) do
        selected[tostring(item)] = true
    end

    return selected
end

local function RegisterFlag(flag, control)
    if flag then
        Wally.Flags[flag] = control
    end
end

local function GetWidth(value, fallback)
    if typeof(value) == "UDim2" and value.X.Offset > 0 then
        return value.X.Offset
    end

    if typeof(value) == "number" then
        return value
    end

    return fallback
end

local function ResolveKeyCode(value, fallback)
    if typeof(value) == "EnumItem" then
        return value
    end

    if typeof(value) == "string" then
        local ok, keyCode = pcall(function()
            return Enum.KeyCode[value]
        end)

        if ok and keyCode then
            return keyCode
        end
    end

    return Enum.KeyCode[fallback or "RightControl"]
end

local function MakeDraggable(handle, frame)
    local dragging = false
    local dragInput = nil
    local dragStart = nil
    local startPosition = nil

    AddSignal(handle.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        dragging = true
        dragStart = input.Position
        startPosition = frame.Position

        AddSignal(input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end))
    end))

    AddSignal(handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end))

    AddSignal(UserInputService.InputChanged:Connect(function(input)
        if input ~= dragInput or not dragging then
            return
        end

        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end))
end

local function CreateItem(folder, name, height)
    local root = New("Frame", {
        Name = tostring(name or "Item"),
        BackgroundColor3 = Theme.Tertiary,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Size = UDim2.new(1, 0, 0, height or 32),
        Parent = folder.Content,
    })

    Corner(root, 5)
    Stroke(root, Color3.fromRGB(45, 45, 45), 0.45)

    local title = New("TextLabel", {
        BackgroundTransparency = 1,
        Font = Enum.Font.SourceSansSemibold,
        Position = UDim2.fromOffset(8, 0),
        Size = UDim2.new(1, -58, 0, 32),
        Text = tostring(name or "Item"),
        TextColor3 = Theme.SubText,
        TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = root,
    })

    task.defer(function()
        folder:Update()
    end)

    return root, title
end

local function CreateButtonInRow(row, text, callback)
    local button = New("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Font = Enum.Font.SourceSansBold,
        Position = UDim2.fromOffset(7, 5),
        Size = UDim2.new(1, -14, 0, 22),
        Text = tostring(text or "Button"),
        TextColor3 = Color3.fromRGB(20, 20, 20),
        TextSize = 17,
        Parent = row,
    })

    Corner(button, 5)

    local pointer = New("TextLabel", {
        BackgroundTransparency = 1,
        Font = Enum.Font.SourceSansBold,
        Position = UDim2.fromOffset(7, 0),
        Size = UDim2.fromOffset(16, 22),
        Text = ">",
        TextColor3 = Color3.fromRGB(20, 20, 20),
        TextSize = 16,
        Parent = button,
    })

    AddSignal(button.MouseButton1Click:Connect(function()
        Tween(button, {
            BackgroundColor3 = Theme.Text,
        }, FastTween)

        task.delay(0.08, function()
            if button.Parent then
                Tween(button, {
                    BackgroundColor3 = Theme.Accent,
                }, FastTween)
            end
        end)

        SafeCall(callback)
    end))

    return {
        Root = row,
        Button = button,
        Pointer = pointer,
        Fire = function()
            SafeCall(callback)
        end,
    }
end

local function CreateToggleInRow(row, title, config)
    local control = {
        Value = config.Default == true,
    }

    local click = New("TextButton", {
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Text = "",
        Parent = row,
    })

    local box = New("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        BackgroundColor3 = Color3.fromRGB(64, 64, 64),
        BorderSizePixel = 0,
        Position = UDim2.new(1, -8, 0, 7),
        Size = UDim2.fromOffset(18, 18),
        Parent = row,
    })

    Corner(box, 4)
    Stroke(box, Theme.Muted, 0.35)

    local fill = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(0, 0),
        Parent = box,
    })

    Corner(fill, 3)

    function control:SetValue(value, silent)
        control.Value = value == true

        Tween(box, {
            BackgroundColor3 = control.Value and Theme.Accent or Color3.fromRGB(64, 64, 64),
        }, FastTween)

        Tween(fill, {
            BackgroundTransparency = control.Value and 0 or 1,
            Size = control.Value and UDim2.new(1, -6, 1, -6) or UDim2.fromOffset(0, 0),
        }, FastTween)

        if not silent then
            SafeCall(config.Callback, control.Value)
        end
    end

    function control:GetValue()
        return control.Value
    end

    AddSignal(click.MouseButton1Click:Connect(function()
        control:SetValue(not control.Value)
    end))

    control:SetValue(control.Value, true)
    RegisterFlag(config.Flag, control)

    return control
end

local function CreateSliderInRow(row, title, config)
    row.Size = UDim2.new(1, 0, 0, 46)
    title.Size = UDim2.new(1, -58, 0, 24)

    local min = tonumber(config.Min or config.min) or 1
    local max = tonumber(config.Max or config.max) or 100
    local rounding = tonumber(config.Rounding or config.rounding)

    if rounding == nil then
        rounding = config.Precise and 1 or 0
    end

    local suffix = config.Type or config.type or ""
    local dragging = false
    local control = {
        Value = tonumber(config.Default or config.default) or min,
    }

    local valueBox = New("TextBox", {
        AnchorPoint = Vector2.new(1, 0),
        BackgroundColor3 = Color3.fromRGB(55, 55, 55),
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Font = Enum.Font.SourceSansSemibold,
        Position = UDim2.new(1, -7, 0, 5),
        Size = UDim2.fromOffset(42, 18),
        Text = "",
        TextColor3 = Theme.SubText,
        TextSize = 14,
        Parent = row,
    })

    Corner(valueBox, 4)

    local track = New("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = Color3.fromRGB(46, 46, 46),
        BorderSizePixel = 0,
        Position = UDim2.new(0, 7, 0, 34),
        Size = UDim2.new(1, -14, 0, 4),
        Text = "",
        Parent = row,
    })

    Corner(track, 4)

    local fill = New("Frame", {
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(0, 1),
        Parent = track,
    })

    Corner(fill, 4)

    local dragger = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromOffset(10, 10),
        Parent = track,
    })

    Corner(dragger, 10)

    local function Round(value)
        value = math.clamp(tonumber(value) or min, min, max)

        if rounding and rounding > 0 then
            local mult = 10 ^ rounding
            return math.floor(value * mult + 0.5) / mult
        end

        return math.floor(value + 0.5)
    end

    local function SetFromX(x)
        local percent = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        control:SetValue(min + ((max - min) * percent))
    end

    function control:SetValue(value, silent)
        control.Value = Round(value)
        local percent = (control.Value - min) / math.max(max - min, 1)

        valueBox.Text = tostring(control.Value) .. suffix
        Tween(fill, {
            Size = UDim2.fromScale(percent, 1),
        }, FastTween)
        Tween(dragger, {
            Position = UDim2.fromScale(percent, 0.5),
        }, FastTween)

        if not silent then
            SafeCall(config.Callback, control.Value)
        end
    end

    function control:GetValue()
        return control.Value
    end

    AddSignal(track.MouseButton1Down:Connect(function()
        dragging = true
        SetFromX(UserInputService:GetMouseLocation().X)
    end))

    AddSignal(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))

    AddSignal(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            SetFromX(input.Position.X)
        end
    end))

    AddSignal(valueBox.FocusLost:Connect(function()
        local numberValue = tonumber(tostring(valueBox.Text):match("[-%d%.]+"))
        control:SetValue(numberValue or control.Value)
    end))

    control:SetValue(control.Value, true)
    RegisterFlag(config.Flag, control)

    return control
end

local function CreateTextInputInRow(row, title, config)
    local control = {
        Value = config.Default or config.default or "",
    }

    local input = New("TextBox", {
        AnchorPoint = Vector2.new(1, 0),
        BackgroundColor3 = Color3.fromRGB(55, 55, 55),
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Font = Enum.Font.SourceSansSemibold,
        PlaceholderText = config.Placeholder or config.placeholder or "Value",
        Position = UDim2.new(1, -7, 0, 5),
        Size = UDim2.fromOffset(config.Size or 88, 22),
        Text = tostring(control.Value),
        TextColor3 = Theme.SubText,
        TextSize = 15,
        Parent = row,
    })

    Corner(input, 4)

    function control:SetValue(value, silent)
        if config.Numeric then
            value = tonumber(value) or 0
        end

        control.Value = value
        input.Text = tostring(value)

        if not silent then
            SafeCall(config.Callback, value)
        end
    end

    function control:GetValue()
        return control.Value
    end

    AddSignal(input.FocusLost:Connect(function()
        control:SetValue(input.Text)
    end))

    RegisterFlag(config.Flag, control)
    return control
end

local function CreateKeybindInRow(row, title, config)
    local control = {
        Value = tostring(config.Default or config.default or "RightControl"),
        Binding = false,
    }

    local button = New("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        AutoButtonColor = false,
        BackgroundColor3 = Color3.fromRGB(55, 55, 55),
        BorderSizePixel = 0,
        Font = Enum.Font.SourceSansSemibold,
        Position = UDim2.new(1, -7, 0, 5),
        Size = UDim2.fromOffset(config.Size or 88, 22),
        Text = control.Value,
        TextColor3 = Theme.SubText,
        TextSize = 15,
        Parent = row,
    })

    Corner(button, 4)

    function control:SetValue(value, silent)
        if typeof(value) == "EnumItem" then
            value = value.Name
        end

        control.Value = tostring(value or control.Value)
        button.Text = control.Value

        if not silent then
            SafeCall(config.Callback, control.Value)
        end
    end

    function control:GetValue()
        return control.Value
    end

    AddSignal(button.MouseButton1Click:Connect(function()
        control.Binding = true
        button.Text = "..."
    end))

    AddSignal(UserInputService.InputBegan:Connect(function(input)
        if not control.Binding then
            return
        end

        control.Binding = false

        if input.UserInputType == Enum.UserInputType.Keyboard then
            control:SetValue(input.KeyCode.Name)
        else
            control:SetValue(input.UserInputType.Name)
        end
    end))

    RegisterFlag(config.Flag, control)
    return control
end

local function CreateDropdownInRow(row, title, folder, config)
    local values = config.Values or config.values or {}
    local multi = config.Multi == true
    local opened = false
    local control = {
        Values = values,
        Value = multi and ToSelectedMap(config.Default) or (config.Default or values[1]),
    }

    local button = New("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        AutoButtonColor = false,
        BackgroundColor3 = Color3.fromRGB(55, 55, 55),
        BorderSizePixel = 0,
        Font = Enum.Font.SourceSansSemibold,
        Position = UDim2.new(1, -7, 0, 5),
        Size = UDim2.fromOffset(config.Size or 100, 22),
        Text = "",
        TextColor3 = Theme.SubText,
        TextSize = 15,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = row,
    })

    Corner(button, 4)

    local optionFrame = New("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(7, 33),
        Size = UDim2.new(1, -14, 0, 0),
        Visible = false,
        Parent = row,
    })

    local optionLayout = New("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 3),
        Parent = optionFrame,
    })

    local function GetDisplay()
        if not multi then
            return tostring(control.Value or "Select")
        end

        local selected = ToArray(control.Value)
        if #selected == 0 then
            return "Select"
        end

        return table.concat(selected, ", ")
    end

    local function UpdateHeight()
        local height = opened and (32 + optionLayout.AbsoluteContentSize.Y + 7) or 32
        row.Size = UDim2.new(1, 0, 0, height)
        optionFrame.Size = UDim2.new(1, -14, 0, optionLayout.AbsoluteContentSize.Y)
        optionFrame.Visible = opened
        folder:Update()
    end

    local function Refresh()
        button.Text = GetDisplay()

        for _, child in next, optionFrame:GetChildren() do
            if child:IsA("GuiObject") then
                child:Destroy()
            end
        end

        for _, value in next, control.Values do
            local valueText = tostring(value)
            local selected = multi and control.Value[valueText] == true or control.Value == value
            local option = New("TextButton", {
                AutoButtonColor = false,
                BackgroundColor3 = selected and Theme.Accent or Color3.fromRGB(46, 46, 46),
                BorderSizePixel = 0,
                Font = Enum.Font.SourceSansSemibold,
                Size = UDim2.new(1, 0, 0, 24),
                Text = (multi and ((selected and "[x] ") or "[ ] ") or "") .. valueText,
                TextColor3 = selected and Color3.fromRGB(20, 20, 20) or Theme.SubText,
                TextSize = 15,
                Parent = optionFrame,
            })

            Corner(option, 4)

            AddSignal(option.MouseButton1Click:Connect(function()
                if multi then
                    control.Value[valueText] = not control.Value[valueText]
                else
                    control.Value = value
                    opened = false
                end

                Refresh()
                UpdateHeight()
                SafeCall(config.Callback, control:GetValue())
            end))
        end

        task.defer(UpdateHeight)
    end

    function control:SetValue(value, silent)
        control.Value = multi and ToSelectedMap(value) or value
        Refresh()

        if not silent then
            SafeCall(config.Callback, control:GetValue())
        end
    end

    function control:GetValue()
        return control.Value
    end

    function control:SetValues(nextValues)
        control.Values = nextValues or {}
        Refresh()
    end

    AddSignal(button.MouseButton1Click:Connect(function()
        opened = not opened
        Refresh()
        UpdateHeight()
    end))

    AddSignal(optionLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateHeight))

    Refresh()
    RegisterFlag(config.Flag, control)

    return control
end

local function CreateColorPickerInRow(row, title, config)
    local palette = config.Palette or {
        Color3.fromRGB(255, 184, 0),
        Color3.fromRGB(255, 85, 85),
        Color3.fromRGB(85, 170, 255),
        Color3.fromRGB(85, 255, 130),
        Color3.fromRGB(255, 255, 255),
    }
    local index = 1
    local control = {
        Value = config.Default or palette[1],
    }

    local button = New("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        AutoButtonColor = false,
        BackgroundColor3 = control.Value,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -8, 0, 7),
        Size = UDim2.fromOffset(18, 18),
        Text = "",
        Parent = row,
    })

    Corner(button, 4)
    Stroke(button, Color3.fromRGB(230, 230, 230), 0.5)

    function control:SetValue(value, silent)
        if typeof(value) == "Color3" then
            control.Value = value
            Tween(button, {
                BackgroundColor3 = value,
            }, FastTween)

            if not silent then
                SafeCall(config.Callback, value)
            end
        end
    end

    function control:GetValue()
        return control.Value
    end

    AddSignal(button.MouseButton1Click:Connect(function()
        index = index + 1
        if index > #palette then
            index = 1
        end

        control:SetValue(palette[index])
    end))

    RegisterFlag(config.Flag, control)
    return control
end

local function AttachLabelMethods(label, folder)
    function label:AddButton(config)
        config = NormalizeControlConfig(config, label.Name)
        label.Title.Visible = false
        return CreateButtonInRow(label.Root, config.Name, config.Callback)
    end

    function label:AddToggle(config)
        config = NormalizeControlConfig(config, label.Name)
        return CreateToggleInRow(label.Root, label.Title, config)
    end

    function label:AddSlider(config)
        config = NormalizeControlConfig(config, label.Name)
        return CreateSliderInRow(label.Root, label.Title, config)
    end

    function label:AddDropdown(config)
        config = NormalizeControlConfig(config, label.Name)
        return CreateDropdownInRow(label.Root, label.Title, folder, config)
    end

    function label:AddTextInput(config)
        config = NormalizeControlConfig(config, label.Name)
        return CreateTextInputInRow(label.Root, label.Title, config)
    end

    function label:AddKeybind(config)
        config = NormalizeControlConfig(config, label.Name)
        return CreateKeybindInRow(label.Root, label.Title, config)
    end

    function label:AddColorPicker(config)
        config = NormalizeControlConfig(config, label.Name)
        return CreateColorPickerInRow(label.Root, label.Title, config)
    end

    function label:SetText(text)
        label.Name = tostring(text)
        label.Title.Text = label.Name
    end

    function label:GetValue()
        return label.Name
    end

    label.AddTextbox = label.AddTextInput
    label.AddInput = label.AddTextInput
    label.AddBind = label.AddKeybind

    return label
end

local function AttachFolderMethods(folder)
    function folder:Update()
        local contentHeight = folder.Layout.AbsoluteContentSize.Y
        local height = folder.Open and (35 + contentHeight + 8) or 35
        folder.Content.Size = UDim2.new(1, -10, 0, contentHeight)

        Tween(folder.Root, {
            Size = UDim2.new(1, 0, 0, height),
        }, FastTween)

        if folder.Window then
            task.defer(function()
                folder.Window:Update()
            end)
        end
    end

    function folder:SetOpen(value)
        folder.Open = value == true
        folder.Content.Visible = folder.Open
        folder.Arrow.Text = folder.Open and "-" or "+"
        folder:Update()
    end

    function folder:Toggle()
        folder:SetOpen(not folder.Open)
    end

    function folder:AddLabel(name)
        local root, title = CreateItem(folder, name, 32)
        local label = {
            Root = root,
            Title = title,
            Name = tostring(name or "Label"),
        }

        return AttachLabelMethods(label, folder)
    end

    function folder:AddButton(config)
        config = NormalizeControlConfig(config, "Button")
        return folder:AddLabel(config.Name):AddButton(config)
    end

    function folder:AddToggle(config)
        config = NormalizeControlConfig(config, "Toggle")
        return folder:AddLabel(config.Name):AddToggle(config)
    end

    function folder:AddSlider(config)
        config = NormalizeControlConfig(config, "Slider")
        return folder:AddLabel(config.Name):AddSlider(config)
    end

    function folder:AddDropdown(config)
        config = NormalizeControlConfig(config, "Dropdown")
        return folder:AddLabel(config.Name):AddDropdown(config)
    end

    function folder:AddTextInput(config)
        config = NormalizeControlConfig(config, "TextInput")
        return folder:AddLabel(config.Name):AddTextInput(config)
    end

    function folder:AddKeybind(config)
        config = NormalizeControlConfig(config, "Keybind")
        return folder:AddLabel(config.Name):AddKeybind(config)
    end

    function folder:AddColorPicker(config)
        config = NormalizeControlConfig(config, "Color")
        return folder:AddLabel(config.Name):AddColorPicker(config)
    end

    function folder:Button(name, callback)
        return folder:AddButton({
            Name = name,
            Callback = callback,
        })
    end

    function folder:Toggle(name, default, callback)
        if typeof(default) == "function" then
            callback = default
            default = false
        end

        return folder:AddToggle({
            Name = name,
            Default = default,
            Callback = callback,
        })
    end

    function folder:Slider(name, data, callback)
        data = data or {}

        return folder:AddSlider({
            Name = name,
            Min = data.Min or data.min,
            Max = data.Max or data.max,
            Default = data.Default or data.default,
            Rounding = data.Rounding or data.rounding,
            Precise = data.Precise or data.precise,
            Type = data.Type or data.type,
            Callback = callback or data.Callback,
        })
    end

    function folder:Dropdown(name, values, default, callback)
        if typeof(default) == "function" then
            callback = default
            default = nil
        end

        if typeof(values) == "table" and values.Values then
            values.Name = name
            values.Callback = values.Callback or callback
            return folder:AddDropdown(values)
        end

        return folder:AddDropdown({
            Name = name,
            Values = values or {},
            Default = default,
            Callback = callback,
        })
    end

    function folder:Bind(name, default, callback)
        if typeof(default) == "function" then
            callback = default
            default = "RightControl"
        end

        return folder:AddKeybind({
            Name = name,
            Default = default,
            Callback = callback,
        })
    end

    function folder:Textbox(name, default, callback)
        if typeof(default) == "function" then
            callback = default
            default = ""
        end

        return folder:AddTextInput({
            Name = name,
            Default = default,
            Callback = callback,
        })
    end

    function folder:ColorPicker(name, default, callback)
        if typeof(default) == "function" then
            callback = default
            default = Theme.Accent
        end

        return folder:AddColorPicker({
            Name = name,
            Default = default,
            Callback = callback,
        })
    end

    function folder:Label(name)
        return folder:AddLabel(name)
    end

    folder.AddTextbox = folder.AddTextInput
    folder.AddInput = folder.AddTextInput
    folder.AddBind = folder.AddKeybind
    folder.CreateLabel = folder.AddLabel

    return folder
end

function Wally:CreateNotification()
    if Wally.__Notification then
        return Wally.__Notification
    end

    local root = New("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -16, 0, 16),
        Size = UDim2.fromOffset(260, 10),
        Parent = ScreenGui,
    })

    New("UIListLayout", {
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
        Parent = root,
    })

    local notifier = {}

    function notifier.new(config, content, duration)
        if typeof(config) ~= "table" then
            config = {
                Title = tostring(config or "Notification"),
                Content = tostring(content or ""),
                Duration = duration,
            }
        end

        local frame = New("Frame", {
            BackgroundColor3 = Theme.Main,
            BackgroundTransparency = 0.05,
            BorderSizePixel = 0,
            ClipsDescendants = true,
            Size = UDim2.fromOffset(0, 56),
            Parent = root,
        })

        Corner(frame, 8)
        Stroke(frame, Theme.Stroke, 0.35)

        local line = New("Frame", {
            BackgroundColor3 = Theme.Accent,
            BorderSizePixel = 0,
            Size = UDim2.new(0, 4, 1, 0),
            Parent = frame,
        })

        Corner(line, 8)

        New("TextLabel", {
            BackgroundTransparency = 1,
            Font = Enum.Font.SourceSansBold,
            Position = UDim2.fromOffset(14, 6),
            Size = UDim2.new(1, -24, 0, 22),
            Text = tostring(config.Title or "Notification"),
            TextColor3 = Theme.Text,
            TextSize = 18,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = frame,
        })

        New("TextLabel", {
            BackgroundTransparency = 1,
            Font = Enum.Font.SourceSansSemibold,
            Position = UDim2.fromOffset(14, 29),
            Size = UDim2.new(1, -24, 0, 18),
            Text = tostring(config.Content or ""),
            TextColor3 = Theme.SubText,
            TextSize = 15,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = frame,
        })

        Tween(frame, {
            Size = UDim2.fromOffset(240, 56),
        })

        task.delay(config.Duration or 4, function()
            if not frame.Parent then
                return
            end

            Tween(frame, {
                BackgroundTransparency = 1,
                Size = UDim2.fromOffset(0, 56),
            }, DefaultTween)

            task.wait(0.18)
            if frame.Parent then
                frame:Destroy()
            end
        end)
    end

    Wally.__Notification = notifier
    return notifier
end

function Wally:CreateLogger()
    if Wally.__Logger then
        return Wally.__Logger
    end

    local root = New("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(16, 16),
        Size = UDim2.fromOffset(260, 10),
        Parent = ScreenGui,
    })

    New("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
        Parent = root,
    })

    local logger = {}

    function logger.new(icon, message, duration)
        local text = tostring(message or icon or "Log")
        local frame = New("Frame", {
            BackgroundColor3 = Theme.Main,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ClipsDescendants = true,
            Size = UDim2.fromOffset(0, 22),
            Parent = root,
        })

        Corner(frame, 5)
        Stroke(frame, Theme.Stroke, 0.6)

        New("Frame", {
            BackgroundColor3 = Theme.Accent,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(0, 2),
            Size = UDim2.new(0, 3, 1, -4),
            Parent = frame,
        })

        New("TextLabel", {
            BackgroundTransparency = 1,
            Font = Enum.Font.SourceSansSemibold,
            Position = UDim2.fromOffset(11, 1),
            Size = UDim2.new(1, -18, 1, -2),
            Text = text,
            TextColor3 = Theme.SubText,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = frame,
        })

        local width = math.clamp((#text * 7) + 26, 80, 260)
        Tween(frame, {
            BackgroundTransparency = 0.08,
            Size = UDim2.fromOffset(width, 22),
        }, FastTween)

        task.delay(duration or 3, function()
            if not frame.Parent then
                return
            end

            Tween(frame, {
                BackgroundTransparency = 1,
                Size = UDim2.fromOffset(0, 22),
            }, FastTween)

            task.wait(0.12)
            if frame.Parent then
                frame:Destroy()
            end
        end)
    end

    Wally.__Logger = logger
    return logger
end

function Wally:CreateWindow(config, legacyName)
    if typeof(config) ~= "table" then
        config = {
            Name = legacyName or config,
        }
    end

    Wally.Count = Wally.Count + 1

    local window = {
        Name = tostring(config.Name or "Pro UI 4.8"),
        Content = tostring(config.Content or "Wally V4"),
        Keybind = config.Keybind or "RightControl",
        Open = true,
        Visible = true,
        Width = GetWidth(config.Size, UserInputService.TouchEnabled and 320 or 420),
        Folders = {},
    }

    local root = New("Frame", {
        BackgroundColor3 = Theme.Main,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Position = config.Position or UDim2.fromOffset(15 + ((Wally.Count - 1) * 225), 15),
        Size = UDim2.fromOffset(window.Width, 36),
        Parent = ScreenGui,
    })

    Corner(root, 8)
    Stroke(root, Theme.Stroke, 0.25)

    local header = New("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = Theme.Main,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 36),
        Text = "",
        Parent = root,
    })

    local title = New("TextLabel", {
        BackgroundTransparency = 1,
        Font = Enum.Font.SourceSansBold,
        Position = UDim2.fromOffset(10, 1),
        Size = UDim2.new(1, -42, 0, 20),
        Text = window.Name,
        TextColor3 = Theme.Text,
        TextSize = 19,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = header,
    })

    local subtitle = New("TextLabel", {
        BackgroundTransparency = 1,
        Font = Enum.Font.SourceSansSemibold,
        Position = UDim2.fromOffset(10, 19),
        Size = UDim2.new(1, -42, 0, 14),
        Text = window.Content,
        TextColor3 = Theme.Muted,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = header,
    })

    local arrow = New("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        Font = Enum.Font.SourceSansBold,
        Position = UDim2.new(1, -10, 0, 8),
        Size = UDim2.fromOffset(20, 20),
        Text = "-",
        TextColor3 = Theme.Muted,
        TextSize = 20,
        Parent = header,
    })

    local body = New("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 36),
        Size = UDim2.new(1, 0, 0, 0),
        Parent = root,
    })

    Padding(body, 5, 4, 5, 6)

    local bodyLayout = New("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 5),
        Parent = body,
    })

    window.Root = root
    window.Header = header
    window.Body = body
    window.Layout = bodyLayout
    window.Title = title
    window.Subtitle = subtitle
    window.Arrow = arrow

    function window:Update()
        local contentHeight = bodyLayout.AbsoluteContentSize.Y + 10
        body.Size = UDim2.new(1, 0, 0, contentHeight)

        if window.Open then
            body.Visible = true
            Tween(root, {
                Size = UDim2.fromOffset(window.Width, 36 + contentHeight),
            }, FastTween)
        else
            Tween(root, {
                Size = UDim2.fromOffset(window.Width, 36),
            }, FastTween)

            task.delay(0.1, function()
                if not window.Open and body.Parent then
                    body.Visible = false
                end
            end)
        end
    end

    function window:SetOpen(value)
        window.Open = value == true
        arrow.Text = window.Open and "-" or "+"

        if window.Open then
            body.Visible = true
        end

        window:Update()
    end

    function window:Toggle()
        window:SetOpen(not window.Open)
    end

    function window:SetRender(value)
        window.Visible = value == true
        root.Visible = window.Visible
    end

    function window:ToggleInterface()
        window:SetRender(not window.Visible)
    end

    function window:SetSize(size)
        window.Width = GetWidth(size, window.Width)
        window:Update()
    end

    function window:SetAccount(account)
        account = account or {}
        if account.Username then
            subtitle.Text = tostring(account.Username) .. " | " .. tostring(account.Expires or "Never")
        end
    end

    function window:AddTab(configTab)
        configTab = NormalizeControlConfig(configTab, "Tab")

        local tab = {
            Window = window,
            Name = configTab.Name,
            Sections = {},
        }

        function tab:AddSection(sectionConfig)
            sectionConfig = NormalizeControlConfig(sectionConfig, tab.Name)
            local section = window:CreateFolder(sectionConfig.Name)
            table.insert(tab.Sections, section)
            return section
        end

        function tab:AddLabel(...)
            local section = tab.Sections[1] or tab:AddSection({
                Name = tab.Name,
            })

            return section:AddLabel(...)
        end

        return tab
    end

    function window:AddTabLabel(name)
        return window:CreateFolder(name)
    end

    function window:CreateFolder(folderConfig)
        folderConfig = NormalizeControlConfig(folderConfig, "Folder")
        local folderOpen = folderConfig.Open == true or folderConfig.DefaultOpen == true

        local folderRoot = New("Frame", {
            BackgroundTransparency = 1,
            ClipsDescendants = true,
            LayoutOrder = #window.Folders + 1,
            Size = UDim2.new(1, 0, 0, 35),
            Parent = body,
        })

        local folderHeader = New("TextButton", {
            AutoButtonColor = false,
            BackgroundColor3 = Theme.Secondary,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 35),
            Text = "",
            Parent = folderRoot,
        })

        Corner(folderHeader, 6)
        Stroke(folderHeader, Color3.fromRGB(42, 42, 42), 0.35)

        local folderTitle = New("TextLabel", {
            BackgroundTransparency = 1,
            Font = Enum.Font.SourceSansBold,
            Position = UDim2.fromOffset(9, 0),
            Size = UDim2.new(1, -54, 1, 0),
            Text = folderConfig.Name,
            TextColor3 = Theme.Text,
            TextSize = 18,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = folderHeader,
        })

        local folderArrow = New("TextButton", {
            AnchorPoint = Vector2.new(1, 0),
            AutoButtonColor = false,
            BackgroundColor3 = Theme.Tertiary,
            BackgroundTransparency = 0.15,
            BorderSizePixel = 0,
            Font = Enum.Font.SourceSansBold,
            Position = UDim2.new(1, -7, 0, 5),
            Size = UDim2.fromOffset(30, 25),
            Text = folderOpen and "-" or "+",
            TextColor3 = Theme.Muted,
            TextSize = 20,
            Parent = folderHeader,
        })

        Corner(folderArrow, 5)
        Stroke(folderArrow, Color3.fromRGB(50, 50, 50), 0.55)

        local content = New("Frame", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(5, 39),
            Size = UDim2.new(1, -10, 0, 0),
            Visible = folderOpen,
            Parent = folderRoot,
        })

        local layout = New("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 4),
            Parent = content,
        })

        local folder = {
            Window = window,
            Root = folderRoot,
            Header = folderHeader,
            Title = folderTitle,
            Arrow = folderArrow,
            Content = content,
            Layout = layout,
            Open = folderOpen,
        }

        AttachFolderMethods(folder)

        AddSignal(folderArrow.MouseButton1Click:Connect(function()
            folder:Toggle()
        end))

        AddSignal(layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            folder:Update()
        end))

        table.insert(window.Folders, folder)
        task.defer(function()
            folder:Update()
            window:Update()
        end)

        return folder
    end

    function window:AddSection(configSection)
        return window:CreateFolder(configSection)
    end

    function window:CreateFolderLabel(name)
        return window:CreateFolder(name)
    end

    function window:Watermark()
        if Wally.__Watermark then
            return Wally.__Watermark
        end

        local watermarkRoot = New("Frame", {
            AnchorPoint = Vector2.new(1, 0),
            BackgroundColor3 = Theme.Main,
            BackgroundTransparency = 0.08,
            BorderSizePixel = 0,
            ClipsDescendants = true,
            Position = UDim2.new(1, -12, 0, 12),
            Size = UDim2.fromOffset(120, 28),
            Parent = ScreenGui,
        })

        Corner(watermarkRoot, 7)
        Stroke(watermarkRoot, Theme.Stroke, 0.35)

        local layout = New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 6),
            Parent = watermarkRoot,
        })

        Padding(watermarkRoot, 8, 0, 8, 0)

        local watermark = {
            Root = watermarkRoot,
            Renders = {},
            Status = true,
        }

        function watermark:SetRender(value)
            watermark.Status = value == true
            watermarkRoot.Visible = watermark.Status
        end

        function watermark:AddBlock(icon, name)
            local block = New("TextButton", {
                AutoButtonColor = false,
                BackgroundTransparency = 1,
                Font = Enum.Font.SourceSansBold,
                Size = UDim2.fromOffset(90, 28),
                Text = tostring(name or icon or "Block"),
                TextColor3 = Theme.SubText,
                TextSize = 15,
                Parent = watermarkRoot,
            })

            local item = {
                Root = block,
            }

            function item:SetVisible(value)
                block.Visible = value == true
            end

            function item:SetText(text)
                block.Text = tostring(text)
            end

            function item:Input(callback)
                AddSignal(block.MouseButton1Click:Connect(callback))
                return block
            end

            task.defer(function()
                local width = 28
                for _, child in next, watermarkRoot:GetChildren() do
                    if child:IsA("GuiObject") and child.Visible then
                        width = width + child.AbsoluteSize.X + 6
                    end
                end

                watermarkRoot.Size = UDim2.fromOffset(math.max(width, 120), 28)
            end)

            return item
        end

        Wally.__Watermark = watermark
        return watermark
    end

    window.CreateFolder = window.CreateFolder
    window.AddFolder = window.CreateFolder

    MakeDraggable(header, root)

    AddSignal(arrow.MouseButton1Click:Connect(function()
        window:Toggle()
    end))

    AddSignal(bodyLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        window:Update()
    end))

    AddSignal(UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed or input.UserInputType ~= Enum.UserInputType.Keyboard then
            return
        end

        if input.KeyCode == ResolveKeyCode(window.Keybind) then
            window:ToggleInterface()
        end
    end))

    window.UserSettings = window:CreateFolder("Settings")
    window.UserSettings.Root.LayoutOrder = 999

    table.insert(Wally.Windows, window)
    task.defer(function()
        window:Update()
    end)

    return window
end

function Wally:Unload()
    if not Wally.UnloadEnabled then
        return
    end

    if ScreenGui then
        ScreenGui:Destroy()
    end

    for _, signal in next, Wally.GlobalSignals do
        pcall(function()
            signal:Disconnect()
        end)
    end
end

assert(type(Wally.CreateWindow) == "function", "ProUI4.8 Wally failed to load")

return Wally
