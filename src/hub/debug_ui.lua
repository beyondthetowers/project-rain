local State = require("@src/hub/criminality/state")
local UI = require("@src/hub/criminality/ui")

State.define("dbg.toggle", false)
State.define("dbg.slider", 5)
State.define("dbg.drop", "x")
State.define("dbg.key", "Y")
State.define("dbg.text", "")
State.define("config.name", "default")

print("[dbg] modules loaded")

local ok, err = xpcall(function()
    local window = UI.new({ title = "debug" })
    print("[dbg] window ok")

    local tab = window:tab("a", "A")
    print("[dbg] tab ok, tabs=" .. tostring(#window.tabs))

    local section = tab:section("S")
    print("[dbg] section ok rows=" .. tostring(type(section.rows)) .. " body=" .. tostring(section.body ~= nil))

    section:toggle("dbg.toggle", "Toggle")
    print("[dbg] toggle ok")

    section:slider("dbg.slider", "Slider", 1, 10, 1)
    print("[dbg] slider ok")

    section:dropdown("dbg.drop", "Drop", { "x", "y" })
    print("[dbg] dropdown ok")

    section:keybind("dbg.key", "Key")
    print("[dbg] keybind ok")

    section:text("dbg.text", "Text", "hint")
    print("[dbg] text ok")

    section:button("Button", function() end)
    print("[dbg] button ok")

    local tab2 = window:tab("b", "B")
    print("[dbg] tab2 ok tabs=" .. tostring(#window.tabs))

    local s2 = tab2:section("S2", "sub")
    s2:toggle("dbg.toggle", "T2")
    print("[dbg] tab2 section ok")
end, function(e)
    return tostring(e) .. "\n" .. debug.traceback("", 2)
end)

print("[dbg] result=" .. tostring(ok) .. "  err=" .. tostring(err))

return ok
