local _Gm = game
local _Pl = _Gm:GetService("Players")
local _Ui = _Gm:GetService("UserInputService")
local _Hs = _Gm:GetService("HttpService")

local _Lp = _Pl.LocalPlayer
local _Pg = _Lp:WaitForChild("PlayerGui")

local _u = "https://mbly-license."
    .. "d3fy1337.workers.dev"

local _rq =
    (syn and syn.request)
    or (http and http.request)
    or http_request
    or request
    or (fluxus and fluxus.request)

if not _rq then
    warn("MBLYTRADE: HTTP request is not supported")
    return
end

local function _n(class, props, parent)
    local o = Instance.new(class)

    for k, v in pairs(props or {}) do
        o[k] = v
    end

    if parent then
        o.Parent = parent
    end

    return o
end

local _gui = _n("ScreenGui", {
    Name = "MBLYTRADE_LOADER",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling
}, _Pg)

local _main = _n("Frame", {
    Size = UDim2.fromOffset(320, 190),
    Position = UDim2.new(.5, -160, .5, -95),
    BackgroundColor3 = Color3.fromRGB(14, 14, 18),
    BorderSizePixel = 0
}, _gui)

_n("UICorner", {
    CornerRadius = UDim.new(0, 14)
}, _main)

_n("UIStroke", {
    Color = Color3.fromRGB(255, 205, 70),
    Transparency = .35
}, _main)

local _title = _n("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(20, 15),
    Size = UDim2.new(1, -40, 0, 28),
    Font = Enum.Font.GothamBlack,
    Text = "MBLYTRADE",
    TextSize = 20,
    TextColor3 = Color3.fromRGB(255, 210, 75),
    TextXAlignment = Enum.TextXAlignment.Left
}, _main)

local _sub = _n("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(20, 43),
    Size = UDim2.new(1, -40, 0, 20),
    Font = Enum.Font.GothamMedium,
    Text = "Enter your license key",
    TextSize = 10,
    TextColor3 = Color3.fromRGB(130, 130, 140),
    TextXAlignment = Enum.TextXAlignment.Left
}, _main)

local _box = _n("TextBox", {
    Position = UDim2.fromOffset(20, 75),
    Size = UDim2.new(1, -40, 0, 38),
    BackgroundColor3 = Color3.fromRGB(23, 23, 29),
    BorderSizePixel = 0,
    ClearTextOnFocus = false,
    Font = Enum.Font.GothamMedium,
    PlaceholderText = "MBLY-" .. "XXXX-" .. "XXXX-" .. "XXXX",
    PlaceholderColor3 = Color3.fromRGB(80, 80, 90),
    Text = "",
    TextColor3 = Color3.fromRGB(235, 235, 240),
    TextSize = 12
}, _main)

_n("UICorner", {
    CornerRadius = UDim.new(0, 8)
}, _box)

local _btn = _n("TextButton", {
    Position = UDim2.fromOffset(20, 122),
    Size = UDim2.new(1, -40, 0, 35),
    BackgroundColor3 = Color3.fromRGB(255, 205, 70),
    BorderSizePixel = 0,
    Font = Enum.Font.GothamBold,
    Text = "VERIFY LICENSE",
    TextColor3 = Color3.fromRGB(20, 20, 20),
    TextSize = 11
}, _main)

_n("UICorner", {
    CornerRadius = UDim.new(0, 8)
}, _btn)

local _status = _n("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(20, 160),
    Size = UDim2.new(1, -40, 0, 20),
    Font = Enum.Font.GothamMedium,
    Text = "",
    TextSize = 9,
    TextColor3 = Color3.fromRGB(150, 150, 160),
    TextXAlignment = Enum.TextXAlignment.Center
}, _main)

local function _st(t, c)
    _status.Text = t
    _status.TextColor3 = c
end

local function _post(path, payload)
    local r

    local ok = pcall(function()
        r = _rq({
            Url = _u .. path,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = _Hs:JSONEncode(payload)
        })
    end)

    if not ok or not r then
        return nil, "Connection failed"
    end

    return r
end

local function _verify(k)
    local r, e = _post("/verify", {
        key = k,
        userId = tostring(_Lp.UserId)
    })

    if not r then
        return false, e
    end

    if tonumber(r.StatusCode) ~= 200 then
        return false, "Server error"
    end

    local d

    local ok = pcall(function()
        d = _Hs:JSONDecode(r.Body)
    end)

    if not ok or not d then
        return false, "Invalid server response"
    end

    if d.valid ~= true then
        return false, "Invalid license"
    end

    return true, d.expires or "lifetime"
end

local function _load(k)
    local r, e = _post("/script", {
        key = k,
        userId = tostring(_Lp.UserId)
    })

    if not r then
        return false, e
    end

    if tonumber(r.StatusCode) ~= 200 then
        return false, "Script access denied"
    end

    local body = r.Body

    if not body or body == "" then
        return false, "Empty script"
    end

    local fn, err = loadstring(body)

    if not fn then
        warn("MBLYTRADE:", err)
        return false, "Script compilation failed"
    end

    local ok, runtimeErr = pcall(fn)

    if not ok then
        warn("MBLYTRADE:", runtimeErr)
        return false, "Script execution failed"
    end

    return true
end

local function _start()
    local k = (_box.Text or ""):gsub("%s+", "")

    if k == "" then
        _st(
            "Enter a license key",
            Color3.fromRGB(255, 100, 100)
        )
        return
    end

    _btn.Active = false
    _btn.AutoButtonColor = false
    _box.TextEditable = false

    _st(
        "Checking license...",
        Color3.fromRGB(255, 210, 75)
    )

    local valid, result = _verify(k)

    if not valid then
        _st(
            result,
            Color3.fromRGB(255, 100, 100)
        )

        _btn.Active = true
        _btn.AutoButtonColor = true
        _box.TextEditable = true

        return
    end

    _st(
        "License verified",
        Color3.fromRGB(100, 255, 145)
    )

    task.wait(.5)

    _st(
        "Loading MBLYTRADE...",
        Color3.fromRGB(255, 210, 75)
    )

    local loaded, err = _load(k)

    if not loaded then
        _st(
            err,
            Color3.fromRGB(255, 100, 100)
        )

        _btn.Active = true
        _btn.AutoButtonColor = true
        _box.TextEditable = true

        return
    end

    _gui:Destroy()
end

_btn.MouseButton1Click:Connect(_start)

_box.FocusLost:Connect(function(enter)
    if enter then
        _start()
    end
end)

_Ui.InputBegan:Connect(function(input, processed)
    if processed then
        return
    end

    if input.KeyCode == Enum.KeyCode.G then
        return
    end
end)
