local feature = Feature:new("auto_equip_weapon");

-- The weapon's name, as the game records it. Same source titus_echofarm uses to
-- decide what to equip.
local function current_weapon_name()
    local backpack = local_player.instance:FindFirstChild("Backpack");
    if not backpack then return nil end;

    local marker = backpack:FindFirstChild("Weapon");
    local value = marker and marker:FindFirstChild("Weapon");
    return value and value.Value or nil;
end

-- A utility tool is a Tool that is NOT the player's weapon.
--
-- This used to be "the character has any Tool at all", which is wrong in
-- exactly the case that matters: the weapon is a Tool, and after you die and
-- respawn the game re-adds it to the character. So the check returned true,
-- draw_weapon returned early, DrawWeapon was never fired, and the weapon could
-- not be held -- every life after a death.
local function is_using_utility_tool()
    local character = local_player.character;
    if not character then return false end;

    local tool = character:FindFirstChildOfClass("Tool");
    if not tool then return false end;

    local weapon = current_weapon_name();
    if weapon and tool.Name:find(weapon, 1, true) then
        -- plain find, not :match -- the weapon name is data, and :match would
        -- treat any % or - in it as a pattern and raise "malformed pattern"
        return false;
    end;

    return true;
end

local function draw_weapon()
    if is_using_utility_tool() then return end;

    local character = local_player.character;
    local character_handler = character and character:FindFirstChild("CharacterHandler");
    local requests = character_handler and character_handler:FindFirstChild("Requests");
    local draw_weapon_remote = requests and requests:FindFirstChild("DrawWeapon");

    if draw_weapon_remote then
        draw_weapon_remote:FireServer(true);
    end
end

function feature:enable()
	self.removed_hook = EffectReplicatorHandler:hook("removed", function(effect)
		if effect.Class ~= "Equipped" then return end;

        task.delay(0.1, function()
            if EffectReplicator:FindEffect("Equipped") then return end;
            draw_weapon();
        end);
	end);

    self.running = true;
    task.spawn(function()
        while self.running do
            if not EffectReplicator:FindEffect("Equipped") then
                draw_weapon();
            end;

            task.wait(1);
        end;
    end);
end;

function feature:disable()
	if self.removed_hook then
		self.removed_hook:remove();
	end;

    self.running = false;
end;

return feature
