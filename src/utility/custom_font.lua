local custom_font = {}




function custom_font.make_lexend_font()
    local font_custom_asset = getcustomasset("Decay/fonts/Lexend.ttf")
    local font_custom_asset_bold = getcustomasset("Decay/fonts/Lexend-Bold.ttf")
    local font_custom_asset_medium = getcustomasset("Decay/fonts/Lexend-Medium.ttf")

    writefile("Decay/fonts/Lexend.json", game:GetService("HttpService"):JSONEncode({
        name = "Lexend",
        faces = {
            {
                name = "Regular",
                weight = 400,      
                style = "normal",
                assetId = font_custom_asset
            },
            {
                name = "Medium",
                weight = 500,
                style = "normal",
                assetId = font_custom_asset_medium
            },
            {
                name = "Bold",
                weight = 700,
                style = "normal",
                assetId = font_custom_asset_bold
            }
        }
    }))

    local path_asset = getcustomasset("Decay/fonts/Lexend.json");
    local fonts = {
        regular = Font.new(
            path_asset,
            Enum.FontWeight.Regular,
            Enum.FontStyle.Normal
        ),
        medium = Font.new(
            path_asset,
            Enum.FontWeight.Medium,
            Enum.FontStyle.Normal
        ),
        bold = Font.new(
            path_asset,
            Enum.FontWeight.Bold,
            Enum.FontStyle.Normal
        )
    };

    
    
    local done = 0;
    for _, font in pairs(fonts) do
        task.spawn(function()
            -- pcall'd so `done` always advances. An uncaught throw in here used
            -- to leave the counter permanently short of 3.
            pcall(function()
                local params = Instance.new("GetTextBoundsParams")
                params.Text = "Preload"
                params.Font = font
                params.Size = 16
                game:GetService("TextService"):GetTextBoundsAsync(params)
                params:Destroy()
            end)
            done += 1;
        end)
    end

    -- Bounded wait. The original was an unbounded
    --     repeat task.wait() until done == 3
    -- which never returned if a preload thread threw — hanging the entire
    -- script at init with no error and no path out. A font that fails to
    -- preload is not worth a dead client.
    local deadline = tick() + 5;
    repeat task.wait() until done == 3 or tick() > deadline;
    return fonts
end

return custom_font.make_lexend_font()