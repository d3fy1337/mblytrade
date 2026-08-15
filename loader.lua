local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local API_URL = "https://mbly-license.d3fy1337.workers.dev"

-- HTTP request
local request =
    (syn and syn.request)
    or (http and http.request)
    or http_request
    or request
    or (fluxus and fluxus.request)

if not request then
    warn("[MBLYTRADE] HTTP request is not supported")
    return
end

-- GUI
local GUI = Instance.new("ScreenGui")
GUI.Name = "MBLYTRADE_LOADER"
GUI.ResetOnSpawn = false
GUI.IgnoreGuiInset = true
GUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
GUI.Parent = PlayerGui

local Main = Instance.new("Frame")
Main.Size = UDim2.fromOffset(320, 190)
Main.Position = UDim2.new(0.5, -160, 0.5, -95)
Main.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
Main.BorderSizePixel = 0
Main.Parent = GUI

Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 14)

local Stroke = Instance.new("UIStroke", Main)
Stroke.Color = Color3.fromRGB(255, 205, 70)
Stroke.Transparency = 0.35

local Title = Instance.new("TextLabel")
Title.BackgroundTransparency = 1
Title.Position = UDim2.fromOffset(20, 15)
Title.Size = UDim2.new(1, -40, 0, 28)
Title.Font = Enum.Font.GothamBlack
Title.Text = "MBLYTRADE"
Title.TextSize = 20
Title.TextColor3 = Color3.fromRGB(255, 210, 75)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Main

local Sub = Instance.new("TextLabel")
Sub.BackgroundTransparency = 1
Sub.Position = UDim2.fromOffset(20, 43)
Sub.Size = UDim2.new(1, -40, 0, 20)
Sub.Font = Enum.Font.GothamMedium
Sub.Text = "Enter your license key"
Sub.TextSize = 10
Sub.TextColor3 = Color3.fromRGB(130, 130, 140)
Sub.TextXAlignment = Enum.TextXAlignment.Left
Sub.Parent = Main

local Box = Instance.new("TextBox")
Box.Position = UDim2.fromOffset(20, 75)
Box.Size = UDim2.new(1, -40, 0, 38)
Box.BackgroundColor3 = Color3.fromRGB(23, 23, 29)
Box.BorderSizePixel = 0
Box.ClearTextOnFocus = false
Box.Font = Enum.Font.GothamMedium
Box.PlaceholderText = "MBLY-XXXX-XXXX-XXXX"
Box.PlaceholderColor3 = Color3.fromRGB(80, 80, 90)
Box.Text = ""
Box.TextColor3 = Color3.fromRGB(235, 235, 240)
Box.TextSize = 12
Box.Parent = Main

Instance.new("UICorner", Box).CornerRadius = UDim.new(0, 8)

local Button = Instance.new("TextButton")
Button.Position = UDim2.fromOffset(20, 122)
Button.Size = UDim2.new(1, -40, 0, 35)
Button.BackgroundColor3 = Color3.fromRGB(255, 205, 70)
Button.BorderSizePixel = 0
Button.Font = Enum.Font.GothamBold
Button.Text = "VERIFY LICENSE"
Button.TextColor3 = Color3.fromRGB(20, 20, 20)
Button.TextSize = 11
Button.Parent = Main

Instance.new("UICorner", Button).CornerRadius = UDim.new(0, 8)

local Status = Instance.new("TextLabel")
Status.BackgroundTransparency = 1
Status.Position = UDim2.fromOffset(20, 160)
Status.Size = UDim2.new(1, -40, 0, 20)
Status.Font = Enum.Font.GothamMedium
Status.Text = ""
Status.TextSize = 9
Status.TextColor3 = Color3.fromRGB(150, 150, 160)
Status.TextXAlignment = Enum.TextXAlignment.Center
Status.TextWrapped = true
Status.Parent = Main

local function SetStatus(text, color)
    Status.Text = tostring(text)
    Status.TextColor3 = color
end

local function SetButtonEnabled(enabled)
    Button.Active = enabled
    Button.AutoButtonColor = enabled
    Box.TextEditable = enabled
end

local function MakeRequest(options)
    local response

    local success, err = pcall(function()
        response = request(options)
    end)

    if not success then
        return nil, "Request error: " .. tostring(err)
    end

    if not response then
        return nil, "Empty response"
    end

    return response
end

local function Verify(key)
    local body

    local success, encodeError = pcall(function()
        body = HttpService:JSONEncode({
            key = key,
            userId = tostring(Player.UserId)
        })
    end)

    if not success then
        return false, "JSON error: " .. tostring(encodeError)
    end

    local response, requestError = MakeRequest({
        Url = API_URL .. "/verify",
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json"
        },
        Body = body
    })

    if not response then
        return false, requestError
    end

    local statusCode = tonumber(response.StatusCode)

    if statusCode ~= 200 then
        return false,
            "Verify HTTP " ..
            tostring(statusCode) ..
            ": " ..
            tostring(response.Body or "")
    end

    local data

    local decoded, decodeError = pcall(function()
        data = HttpService:JSONDecode(response.Body)
    end)

    if not decoded then
        return false, "Invalid JSON: " .. tostring(decodeError)
    end

    if not data then
        return false, "Empty JSON response"
    end

    if data.valid ~= true then
        return false, tostring(data.error or "Invalid license")
    end

    return true, data.expires or "lifetime"
end

local function LoadScript(key)
    local body

    local success, encodeError = pcall(function()
        body = HttpService:JSONEncode({
            key = key,
            userId = tostring(Player.UserId)
        })
    end)

    if not success then
        return false, "JSON error: " .. tostring(encodeError)
    end

    SetStatus(
        "Requesting script...",
        Color3.fromRGB(255, 210, 75)
    )

    local response, requestError = MakeRequest({
        Url = API_URL .. "/script",
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json"
        },
        Body = body
    })

    if not response then
        return false, requestError
    end

    local statusCode = tonumber(response.StatusCode)
    local responseBody = response.Body or ""

    if statusCode ~= 200 then
        return false,
            "Script HTTP " ..
            tostring(statusCode) ..
            ": " ..
            responseBody
    end

    if responseBody == "" then
        return false, "Server returned empty script"
    end

    SetStatus(
        "Compiling...",
        Color3.fromRGB(255, 210, 75)
    )

    if not loadstring then
        return false, "loadstring is not supported"
    end

    local loadedFunction, compileError =
        loadstring(responseBody)

    if not loadedFunction then
        return false,
            "Compilation error: " ..
            tostring(compileError)
    end

    SetStatus(
        "Starting MBLYTRADE...",
        Color3.fromRGB(255, 210, 75)
    )

    local executed, runtimeError =
        pcall(loadedFunction)

    if not executed then
        warn(
            "[MBLYTRADE] Runtime error:",
            runtimeError
        )

        return false,
            "Runtime error: " ..
            tostring(runtimeError)
    end

    return true
end

local busy = false

local function Start()
    if busy then
        return
    end

    local key = Box.Text
        :gsub("%s+", "")
        :upper()

    if key == "" then
        SetStatus(
            "Enter a license key",
            Color3.fromRGB(255, 100, 100)
        )
        return
    end

    busy = true
    SetButtonEnabled(false)

    SetStatus(
        "Checking license...",
        Color3.fromRGB(255, 210, 75)
    )

    local valid, result = Verify(key)

    if not valid then
        SetStatus(
            result,
            Color3.fromRGB(255, 100, 100)
        )

        warn(
            "[MBLYTRADE] Verification failed:",
            result
        )

        busy = false
        SetButtonEnabled(true)
        return
    end

    print(
        "[MBLYTRADE] License verified. Expires:",
        result
    )

    SetStatus(
        "License verified",
        Color3.fromRGB(100, 255, 145)
    )

    task.wait(0.5)

    local loaded, errorMessage =
        LoadScript(key)

    if not loaded then
        SetStatus(
            errorMessage,
            Color3.fromRGB(255, 100, 100)
        )

        warn(
            "[MBLYTRADE] Loader error:",
            errorMessage
        )

        busy = false
        SetButtonEnabled(true)
        return
    end

    print("[MBLYTRADE] Script loaded successfully")

    GUI:Destroy()
end

Button.MouseButton1Click:Connect(Start)

Box.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        Start()
    end
end)

UIS.InputBegan:Connect(function(input, processed)
    if processed then
        return
    end

    if input.KeyCode == Enum.KeyCode.G then
        return
    end
end)

print("[MBLYTRADE] Loader initialized")
