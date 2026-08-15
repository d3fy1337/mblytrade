local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local API_URL = "https://mbly-license.d3fy1337.workers.dev"

local request = (syn and syn.request)
    or (http and http.request)
    or http_request
    or request
    or (fluxus and fluxus.request)

if not request then
    warn("MBLYTRADE: HTTP request is not supported")
    return
end

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
Status.Parent = Main

local function SetStatus(text, color)
    Status.Text = text
    Status.TextColor3 = color
end

local function Verify(key)
    local response

    local success, requestError = pcall(function()
        response = request({
            Url = API_URL .. "/verify",
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode({
                key = key,
                userId = tostring(Player.UserId)
            })
        })
    end)

    if not success or not response then
        warn("MBLYTRADE VERIFY REQUEST ERROR:", requestError)
        return false, "Connection failed"
    end

    warn("MBLYTRADE /verify STATUS:", response.StatusCode)
    warn("MBLYTRADE /verify BODY:", response.Body)

    if tonumber(response.StatusCode) ~= 200 then
        return false, "Server error"
    end

    local data

    local decoded, decodeError = pcall(function()
        data = HttpService:JSONDecode(response.Body)
    end)

    if not decoded or not data then
        warn("MBLYTRADE VERIFY JSON ERROR:", decodeError)
        return false, "Invalid server response"
    end

    if data.valid ~= true then
        return false, data.error or "Invalid license"
    end

    return true, data.expires or "lifetime"
end

local function LoadScript(key)
    local response

    local success, requestError = pcall(function()
        response = request({
            Url = API_URL .. "/script",
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode({
                key = key,
                userId = tostring(Player.UserId)
            })
        })
    end)

    if not success or not response then
        warn("MBLYTRADE SCRIPT REQUEST ERROR:", requestError)
        return false, "Connection failed"
    end

    warn("MBLYTRADE /script STATUS:", response.StatusCode)
    warn("MBLYTRADE /script BODY:", response.Body)

    if tonumber(response.StatusCode) ~= 200 then
        local serverMessage

        pcall(function()
            local data = HttpService:JSONDecode(response.Body)

            if data and data.error then
                serverMessage = tostring(data.error)
            end
        end)

        return false, serverMessage or "Script access denied"
    end

    if not response.Body or response.Body == "" then
        return false, "Empty script"
    end

    local loaded, compileError = loadstring(response.Body)

    if not loaded then
        warn("MBLYTRADE COMPILE ERROR:", compileError)
        return false, "Script compilation failed"
    end

    local executed, executeError = pcall(loaded)

    if not executed then
        warn("MBLYTRADE EXECUTION ERROR:", executeError)
        return false, "Script execution failed"
    end

    return true
end

local function Start()
    local key = Box.Text:gsub("%s+", "")

    if key == "" then
        SetStatus(
            "Enter a license key",
            Color3.fromRGB(255, 100, 100)
        )
        return
    end

    Button.Active = false
    Button.AutoButtonColor = false
    Box.TextEditable = false

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

        Button.Active = true
        Button.AutoButtonColor = true
        Box.TextEditable = true

        return
    end

    SetStatus(
        "License verified",
        Color3.fromRGB(100, 255, 145)
    )

    task.wait(0.5)

    SetStatus(
        "Loading MBLYTRADE...",
        Color3.fromRGB(255, 210, 75)
    )

    local loaded, errorMessage = LoadScript(key)

    if not loaded then
        SetStatus(
            errorMessage,
            Color3.fromRGB(255, 100, 100)
        )

        Button.Active = true
        Button.AutoButtonColor = true
        Box.TextEditable = true

        return
    end

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
