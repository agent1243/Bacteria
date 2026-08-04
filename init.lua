local use_mesecons = minetest.get_modpath("mesecons")

local spread_interval = tonumber(minetest.settings:get("bacteria_interval")) or 0.2

local directions = {}
for dx = -1, 1 do
    for dy = -1, 1 do
        for dz = -1, 1 do
            if not (dx == 0 and dy == 0 and dz == 0) then
                table.insert(directions, {x = dx, y = dy, z = dz})
            end
        end
    end
end

local function run_bacteria_tick(pos)
    local meta = minetest.get_meta(pos)
    local active = meta:get_int("active") == 1
    local target_block = meta:get_string("target_block")
    local blocks_eaten = meta:get_int("blocks_eaten") or 0
    local idle_time = meta:get_float("idle_time") or 0.0

    if not active then
        if use_mesecons and mesecon.is_powered(pos) then
            meta:set_int("active", 1)
            active = true
        else
            return false
        end
    end

    if target_block == "" then
        local pos_above = {x = pos.x, y = pos.y + 1, z = pos.z}
        local node_above = minetest.get_node(pos_above)
        local block_above_name = node_above.name

        local immune_nodes = {
            ["air"] = true,
            ["ignore"] = true,
            ["bacteria:bacteria"] = true,
            ["mesecons:wire"] = true,
            ["mesecons_button:button"] = true,
            ["mesecons_walllever:wall_lever"] = true,
        }

        if not immune_nodes[block_above_name] then
            target_block = block_above_name
            meta:set_string("target_block", target_block)
            meta:set_int("blocks_eaten", 0)
            meta:set_float("idle_time", 0.0)
        else
            idle_time = idle_time + spread_interval
            if idle_time >= 3.0 then
                minetest.remove_node(pos)
                return false
            end
            meta:set_float("idle_time", idle_time)
            return true
        end
    end

    local dirs_shuffled = {unpack(directions)}

    for i = #dirs_shuffled, 2, -1 do
        local j = math.random(i)
        dirs_shuffled[i], dirs_shuffled[j] = dirs_shuffled[j], dirs_shuffled[i]
    end

    local food_positions = {}
    for _, dir in ipairs(dirs_shuffled) do
        local check_pos = {x = pos.x + dir.x, y = pos.y + dir.y, z = pos.z + dir.z}
        local node = minetest.get_node(check_pos)
        if node.name == target_block then
            table.insert(food_positions, check_pos)
        end
    end

    if #food_positions == 0 then
        idle_time = idle_time + spread_interval
        if idle_time >= 3.0 then
            minetest.add_particlespawner({
                amount = 4,
                time = 0.1,
                minpos = {x = pos.x - 0.2, y = pos.y - 0.2, z = pos.z - 0.2},
                maxpos = {x = pos.x + 0.2, y = pos.y + 0.2, z = pos.z + 0.2},
                minvel = {x = -0.1, y = -0.1, z = -0.1},
                maxvel = {x = 0.1, y = 0.1, z = 0.1},
                minexptime = 0.2,
                maxexptime = 0.4,
                minsize = 0.5,
                maxsize = 1,
                texture = "bacteria.png",
            })
            minetest.remove_node(pos)
            return false
        end
        meta:set_float("idle_time", idle_time)
        return true
    end

    meta:set_float("idle_time", 0.0)
    blocks_eaten = blocks_eaten + 1

    if blocks_eaten >= 3 then
        local spawn_count = math.min(#food_positions, 3)
        for i = 1, spawn_count do
            local spawn_pos = food_positions[i]
            minetest.set_node(spawn_pos, {name = "bacteria:bacteria"})
            
            local new_meta = minetest.get_meta(spawn_pos)
            new_meta:set_int("active", 1)
            new_meta:set_string("target_block", target_block)
            new_meta:set_int("blocks_eaten", 0)
            new_meta:set_float("idle_time", 0.0)
            
            minetest.get_node_timer(spawn_pos):start(spread_interval)
            
            minetest.add_particlespawner({
                amount = 12,
                time = 0.15,
                minpos = {x = spawn_pos.x - 0.2, y = spawn_pos.y - 0.2, z = spawn_pos.z - 0.2},
                maxpos = {x = spawn_pos.x + 0.2, y = spawn_pos.y + 0.2, z = spawn_pos.z + 0.2},
                minvel = {x = -0.4, y = 0.4, z = -0.4},
                maxvel = {x = 0.4, y = 1.2, z = 0.4},
                minexptime = 0.3,
                maxexptime = 0.5,
                minsize = 1.5,
                maxsize = 3,
                texture = "bacteria.png",
            })
        end

        meta:set_int("blocks_eaten", 0)
        return true
    else
        local target_pos = food_positions[1]
        minetest.set_node(target_pos, {name = "bacteria:bacteria"})
        
        local new_meta = minetest.get_meta(target_pos)
        new_meta:set_int("active", 1)
        new_meta:set_string("target_block", target_block)
        new_meta:set_int("blocks_eaten", blocks_eaten)
        new_meta:set_float("idle_time", 0.0)
        
        minetest.get_node_timer(target_pos):start(spread_interval)
        minetest.remove_node(pos)
        return false
    end
end

minetest.register_node("bacteria:bacteria", {
    description = "Bacteria",
    tiles = {"bacteria.png"},
    groups = {cracky = 3, oddly_breakable_by_hand = 3},
    sounds = {footstep = {name = "default_gravel_footstep", gain = 0.5}},
    
    on_construct = function(pos)
        local meta = minetest.get_meta(pos)
        meta:set_int("active", 0)
        meta:set_string("target_block", "")
        meta:set_int("blocks_eaten", 0)
        meta:set_float("idle_time", 0.0)
        minetest.get_node_timer(pos):start(spread_interval)
    end,

    on_timer = function(pos, elapsed)
        return run_bacteria_tick(pos)
    end,

    mesecons = {
        effector = {
            rules = mesecon.rules.default,
            action_on = function(pos, node)
                local meta = minetest.get_meta(pos)
                meta:set_int("active", 1)
                minetest.get_node_timer(pos):start(spread_interval)
            end
        }
    }
})

minetest.register_craftitem("bacteria:remover", {
    description = "Bacteria Remover (Instant Cleanup)",
    inventory_image = "bacteria_remover.png",
    stack_max = 1,

    on_use = function(itemstack, user, pointed_thing)
        if not user then return end
        
        local player_pos = user:get_pos()
        local radius = 150
        
        local positions = minetest.find_nodes_in_area(
            {x = player_pos.x - radius, y = player_pos.y - radius, z = player_pos.z - radius},
            {x = player_pos.x + radius, y = player_pos.y + radius, z = player_pos.z + radius},
            {"bacteria:bacteria"}
        )

        local count = #positions

        if count > 0 then
            for _, pos in ipairs(positions) do
                minetest.remove_node(pos)
                minetest.add_particle({
                    pos = pos,
                    velocity = {x = 0, y = 0.5, z = 0},
                    acceleration = {x = 0, y = 0, z = 0},
                    expirationtime = 0.4,
                    size = math.random(2, 4),
                    collisiondetection = false,
                    vertical = false,
                    texture = "heart.png^[colorize:#888888:255",
                })
            end
            
            minetest.chat_send_player(user:get_player_name(), "🧹 " .. count .. " bacteria were successfully disintegrated!")
        else
            minetest.chat_send_player(user:get_player_name(), "🔍 No bacteria found nearby.")
        end

        return itemstack
    end
})

minetest.register_craft({
    output = "bacteria:bacteria 1",
    recipe = {
        {"default:leaves", "default:leaves",       "default:leaves"},
        {"default:leaves", "default:copper_ingot", "default:leaves"},
        {"default:leaves", "default:leaves",       "default:leaves"}
    }
})

minetest.register_craft({
    output = "bacteria:remover 1",
    recipe = {
        {"default:steel_ingot", "",                    "default:steel_ingot"},
        {"default:steel_ingot", "default:coal_lump",   "default:steel_ingot"},
        {"",                    "default:steel_ingot", ""}
    }
})

-- Convert old "bacteria_green" blocks/items automatically into the new "bacteria"
minetest.register_alias("bacteria:bacteria_green", "bacteria:bacteria")

print("[Bacteria Mod] Loaded successfully with crafting recipes.")
