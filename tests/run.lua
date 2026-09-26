-- Runs every test in this directory, each in its own interpreter process so
-- that stubbed globals cannot leak from one test into another.
--
-- Usage: lua5.1 tests/run.lua
--    or: luajit tests/run.lua
local testsDir = arg[0]:match("^(.*)[/\\][^/\\]*$") or "."
package.path = testsDir .. "/?.lua;" .. package.path
io.stdout:setvbuf("no") -- keep the headers in order with the child output
require("helpers") -- exits with a clear message on an unsupported Lua version

local tests = {
  "aura_list_test.lua",
  "aura_list_review_test.lua",
  "aura_list_async_test.lua",
  "aura_list_editor_test.lua",
  "aura_list_actions_test.lua",
  "aura_list_thumbnail_test.lua",
  "aura_list_interaction_test.lua",
  "aura_list_model_test.lua",
  "aura_list_ordering_test.lua",
  "display_menu_test.lua",
  "options_navigation_test.lua",
  "animations_test.lua",
  "auto_hide_test.lua",
  "aura_environment_test.lua",
  "aura_environment_stack_test.lua",
  "aura_scan_test.lua",
  "character_stats_test.lua",
  "common_options_test.lua",
  "cooldown_test.lua",
  "encounter_browser_test.lua",
  "encounter_reference_test.lua",
  "health_test.lua",
  "instance_test.lua",
  "pvp_flag_test.lua",
  "raid_role_test.lua",
  "ruleset_load_test.lua",
  "spell_cache_test.lua",
  "spell_usable_test.lua",
  "talent_cache_test.lua",
  "talent_load_test.lua",
  "talent_trigger_test.lua",
  "threat_test.lua",
  "totem_test.lua",
  "vehicle_test.lua",
}

local interpreter = arg[-1]
local failed = {}
for _, name in ipairs(tests) do
  print("==> " .. name)
  local status = os.execute(string.format('"%s" "%s/%s"', interpreter, testsDir, name))
  if status ~= 0 then
    failed[#failed + 1] = name
  end
  print("")
end

if #failed > 0 then
  print("FAILED: " .. table.concat(failed, ", "))
  os.exit(1)
end
print("All test files passed.")
