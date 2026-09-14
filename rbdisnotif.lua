local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local LocalPlayer = Players.LocalPlayer

local WebhookURL = ""
local WebhookEnabled = false
local startTime = os.time()
local ConfigFile = "Webhook_Disconnect_Save.txt"

-- โหลด Webhook ที่เคยบันทึกไว้อัตโนมัติ
if isfile and isfile(ConfigFile) then
    WebhookURL = readfile(ConfigFile)
end

-- ฟังก์ชันแปลงเวลาให้อยู่ในรูปแบบ 00:00:00 (Session)
local function FormatTime(seconds)
    local hours = math.floor(seconds / 3600)
    local mins = math.floor((seconds - (hours * 3600)) / 60)
    local secs = seconds - (hours * 3600) - (mins * 60)
    return string.format("%02d:%02d:%02d", hours, mins, secs)
end

-- ฟังก์ชันส่ง Webhook 
local function SendWebhook(reasonString, isTest)
    if WebhookURL == "" then 
        if isTest then
            Rayfield:Notify({
                Title = "Error",
                Content = "Please paste a valid Webhook URL first!",
                Duration = 3,
                Image = 4483362458
            })
        end
        return 
    end
    
    if not WebhookEnabled and not isTest then return end

    local sessionTime = FormatTime(os.time() - startTime)
    
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
                        ["value"] = reasonString or "Unknown Reason",
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
        local requestFunc = syn and syn.request or http and http.request or http_request or fluxus and fluxus.request or request
        if requestFunc then
            local success, response = pcall(function()
                return requestFunc({
                    Url = WebhookURL,
                    Method = "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = HttpService:JSONEncode(data)
                })
            end)

            if isTest and success then
                Rayfield:Notify({
                    Title = "Success",
                    Content = "Webhook sent! Check your Discord.",
                    Duration = 4,
                    Image = 4483362458
                })
            end
        end
    end)
end

-- สร้าง UI ด้วย Rayfield
local Window = Rayfield:CreateWindow({
    Name = "Disconnect Notifier",
    LoadingTitle = "Discord Webhook Setup",
    LoadingSubtitle = "Notification System",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "WebhookNotif",
        FileName = "Config"
    }
})

local Tab = Window:CreateTab("Settings", 4483362458) 

local WebhookInput = Tab:CreateInput({
    Name = "Discord Webhook URL",
    PlaceholderText = "Paste your Webhook URL here...",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        if Text:match("http") then
            WebhookURL = Text
            if writefile then writefile(ConfigFile, WebhookURL) end
        end
    end,
})

-- ใส่ค่าเก่าที่เคยเซฟไว้ใน UI อัตโนมัติ
if WebhookURL ~= "" then
    pcall(function() WebhookInput:Set(WebhookURL) end)
end

Tab:CreateToggle({
    Name = "Enable Webhook Notification",
    CurrentValue = false,
    Flag = "EnableWebhookToggle",
    Callback = function(Value)
        WebhookEnabled = Value
    end,
})

Tab:CreateButton({
    Name = "Test Notification",
    Callback = function()
        -- บังคับดึงข้อความจาก UI โดยตรงเมื่อกดปุ่ม (แก้ปัญหาที่ต้องกดหลายรอบ/ต้องกด Enter)
        local guiBase = gethui and gethui() or game:GetService("CoreGui")
        pcall(function()
            for _, v in pairs(guiBase:GetDescendants()) do
                if v:IsA("TextBox") and v.PlaceholderText == "Paste your Webhook URL here..." then
                    if v.Text:match("http") then
                        WebhookURL = v.Text
                        if writefile then writefile(ConfigFile, WebhookURL) end
                    end
                end
            end
        end)
        
        SendWebhook("DisconnectClientInitiated (Test)", true) 
    end,
})

-- ดักจับการ Disconnect จากเกม
local hasDisconnected = false
GuiService.ErrorMessageChanged:Connect(function(errorMessage)
    if errorMessage and errorMessage ~= "" and not hasDisconnected then
        hasDisconnected = true
        SendWebhook(errorMessage, false)
    end
end)
