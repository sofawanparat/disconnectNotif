local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

local WebhookURL = ""
local WebhookEnabled = false
local AutoReconnectEnabled = false
local startTime = os.time()
local ConfigFile = "WebhookNotif_Config.txt"
local hasDisconnected = false

-- ระบบดึงลิงก์เก่าที่เคยเซฟไว้ (เขียนแบบป้องกัน Error 100%)
if isfile and readfile then
    pcall(function()
        if isfile(ConfigFile) then
            WebhookURL = readfile(ConfigFile)
        end
    end)
end

local function FormatTime(seconds)
    local hours = math.floor(seconds / 3600)
    local mins = math.floor((seconds - (hours * 3600)) / 60)
    local secs = seconds - (hours * 3600) - (mins * 60)
    return string.format("%02d:%02d:%02d", hours, mins, secs)
end

-- โหลด Wind UI 
local WindUI = loadstring(game:HttpGet("https://tree-hub.vercel.app/api/UI/WindUI"))()

local Window = WindUI:CreateWindow({
    Title = "Disconnect Notifier",
    Icon = "bell",
    Author = "System",
    Folder = "WebhookNotif",
    Size = UDim2.fromOffset(500, 400),
    Transparent = true,
    Theme = "Dark"
})

local function SendWebhook(reasonString, isTest)
    if WebhookURL == "" or not WebhookURL:match("http") then 
        if isTest then
            WindUI:Notify({
                Title = "Error",
                Content = "Please paste a valid Webhook URL first!",
                Duration = 3
            })
        end
        return 
    end
    
    if not WebhookEnabled and not isTest then return end

    local sessionTime = FormatTime(os.time() - startTime)
    local cleanReason = tostring(reasonString):gsub("^%s*(.-)%s*$", "%1")
    
    local data = {
        ["content"] = "@everyone", 
        ["embeds"] = {
            {
                ["title"] = "Disconnected",
                ["color"] = 16711680,
                ["thumbnail"] = {
                    ["url"] = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. LocalPlayer.UserId .. "&width=420&height=420&format=png"
                },
                ["fields"] = {
                    {
                        ["name"] = "Player",
                        ["value"] = "||" .. LocalPlayer.Name .. "||\n(||" .. LocalPlayer.UserId .. "||)",
                        ["inline"] = false
                    },
                    {
                        ["name"] = "Session",
                        ["value"] = sessionTime,
                        ["inline"] = false
                    },
                    {
                        ["name"] = "Reason",
                        ["value"] = cleanReason,
                        ["inline"] = false
                    }
                },
                ["footer"] = {
                    ["text"] = os.date("%d/%m/%Y %H:%M")
                }
            }
        }
    }

    task.spawn(function()
        local requestFunc = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
        if requestFunc then
            local success = pcall(function()
                requestFunc({
                    Url = WebhookURL,
                    Method = "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = HttpService:JSONEncode(data)
                })
            end)

            if isTest and success then
                WindUI:Notify({
                    Title = "Success",
                    Content = "Webhook sent! Check your Discord.",
                    Duration = 4
                })
            end
        end
    end)
end

local Tab = Window:Tab({
    Title = "Settings",
    Icon = "settings"
})

Tab:Input({
    Title = "Discord Webhook URL",
    Desc = "Paste your URL (tap outside to save)",
    PlaceholderText = "https://discord.com/api/webhooks/...",
    Default = WebhookURL,
    Callback = function(Text)
        if Text:match("http") then
            WebhookURL = Text
            if writefile then 
                pcall(function() writefile(ConfigFile, WebhookURL) end)
            end
        end
    end
})

Tab:Toggle({
    Title = "Enable Webhook Notification",
    Value = false,
    Callback = function(Value)
        WebhookEnabled = Value
    end
})

Tab:Toggle({
    Title = "Auto Reconnect (New Server)",
    Value = false,
    Callback = function(Value)
        AutoReconnectEnabled = Value
    end
})

Tab:Button({
    Title = "Test Notification",
    Callback = function()
        SendWebhook("This is a test disconnection message. (Error Code: Test)", true) 
    end
})

local function TriggerDisconnect(message)
    if not hasDisconnected then
        hasDisconnected = true
        SendWebhook(message, false)
        
        if AutoReconnectEnabled then
            task.spawn(function()
                task.wait(3)
                pcall(function()
                    TeleportService:Teleport(game.PlaceId, LocalPlayer)
                end)
            end)
        end
    end
end

-- ชั้นที่ 1: ดักจับจาก GuiService 
GuiService.ErrorMessageChanged:Connect(function(errorMessage)
    if errorMessage and errorMessage ~= "" then
        TriggerDisconnect(errorMessage)
    end
end)

-- ชั้นที่ 2: ดักจับจากหน้าจอโดยตรง (ปลอดภัยไม่ทำให้แอปเด้ง)
task.spawn(function()
    pcall(function()
        local promptOverlay = CoreGui:WaitForChild("RobloxPromptGui", 5)
        if promptOverlay then
            local overlay = promptOverlay:WaitForChild("promptOverlay", 5)
            if overlay then
                overlay.ChildAdded:Connect(function(child)
                    if child.Name == "ErrorPrompt" then
                        task.wait(0.5)
                        pcall(function()
                            local errorMsg = child.MessageArea.ErrorFrame.ErrorMessage.Text
                            if errorMsg and errorMsg ~= "" then
                                TriggerDisconnect(errorMsg)
                            end
                        end)
                    end
                end)
            end
        end
    end)
end)
