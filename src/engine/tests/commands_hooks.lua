--- @module commands_hooks_test
--- @file src/engine/tests/commands_hooks.lua
--- @description Combined test module for modit.commands and modit.hooks subsystems.

return function(modit)
    local log = modit.log
    local commands = modit.commands
    local hooks = modit.hooks

    log.info("[test] Initializing Commands and Hooks test suite...")

    -- 1. Test Built-in Commands Registration
    commands.register_builtins("client", { help = true, mods = false })

    -- 2. Register a Custom Game Command
    commands.register("test_cmd", function(args)
        local arg1 = args[1] or "default"
        log.success("[test] Command 'test_cmd' executed successfully with argument: " .. arg1)
        
        -- Fire a hook from inside the command to test integration between the two systems
        hooks.fire("on_test_triggered", arg1)
    end, "Executes the test action and fires a hook. Usage: test_cmd <arg>")

    -- 3. Register Event Hooks and Listeners
    hooks.register("on_test_triggered", "Triggered when the test_cmd console command runs.")

    hooks.listen("on_test_triggered", function(payload)
        log.info("[test] Hook listener #1 received payload: " .. tostring(payload))
    end, "test_owner")

    hooks.listen("on_test_triggered", function(payload)
        log.info("[test] Hook listener #2 (second listener) processed payload: " .. tostring(payload))
    end, "test_owner")

    -- 4. Execute Simulation Checks via Code
    log.info("[test] Simulating console input execution...")
    
    commands.run("test_cmd hello_modit_world")
    commands.run("help")

    -- 5. Test Owner Cleanup (Simulating Mod/System Unload)
    log.info("[test] Testing hook ownership cleanup...")
    hooks.remove_owner("test_owner")
    
    log.info("[test] Firing hook post-cleanup (expecting zero listener logs):")
    hooks.fire("on_test_triggered", "should_not_print")

    log.success("[test] Commands and Hooks test suite completed successfully!")

    --- @section Draw Test Loop
    local function draw_test()
        local draw = modit.draw
        draw.clear(22, 22, 22, 255)
        draw.set_colour(255, 255, 255, 255)
        draw.text("commands & hooks test complete (see console)", 20, 20, 24)
    end

    return draw_test
end