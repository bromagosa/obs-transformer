local obs = obslua
local active = false
local origin = {}
local destination = {}
local effect = { elapsed_time = 0 }
local source_name = ''
local sceneItem = nil
local hotkey_id = obs.OBS_INVALID_HOTKEY_ID


--
-- Utility functions based on @MacTartan's HotKeyRotate.lua
--

local function currentSceneName()
    local src = obs.obs_frontend_get_current_scene()
    local name = obs.obs_source_get_name(src)
    obs.obs_source_release(src)
    return name
end

local function findSceneItem()
    local src = obs.obs_get_source_by_name(currentSceneName())
    if src then
        local scene = obs.obs_scene_from_source(src)
        obs.obs_source_release(src)
        if scene then
            sceneItem = obs.obs_scene_find_source(scene, source_name)
            return true
        end
    end
end


--
-- OBS Script Overrides
--
function script_properties()
    local props = obs.obs_properties_create()
    obs.obs_properties_add_int(
        props, 'origin x', 'Origin x:', -100000, 100000, 1)
    obs.obs_properties_add_int(
        props, 'origin y', 'Origin y:', -100000, 100000, 1)

    obs.obs_properties_add_int(
        props, 'destination x', 'Destination x:', -100000, 100000, 1)
    obs.obs_properties_add_int(
        props, 'destination y', 'Destination y:', -100000, 100000, 1)

    obs.obs_properties_add_int(
        props, 'origin width', 'Origin width:', 0, 100000, 1)
    obs.obs_properties_add_int(
        props, 'origin height', 'Origin height:', 0, 100000, 1)

    obs.obs_properties_add_int(
        props, 'destination width', 'Destination width:', 0, 100000, 1)
    obs.obs_properties_add_int(
        props, 'destination height', 'Destination height:', 0, 100000, 1)

    obs.obs_properties_add_int(
        props, 'origin rotation', 'Origin rotation:', -360, 360, 1)
    obs.obs_properties_add_int(
        props, 'destination rotation', 'Destination rotation:',
            -100000, 100000, 1)

    obs.obs_properties_add_float(
        props, 'duration', 'Duration (seconds):', 0, 100000, 1)

    local effects =
        obs.obs_properties_add_list(
            props,
            'easing',
            'Easing function',
            obs.OBS_COMBO_TYPE_LIST,
            obs.OBS_COMBO_FORMAT_STRING)
    obs.obs_property_list_add_string(effects, 'Linear', 'linear')
    obs.obs_property_list_add_string(effects, 'Ease-in-out', 'ease-in-out')
    obs.obs_property_list_add_string(effects, 'Cut', 'cut')

    local p =
        obs.obs_properties_add_list(
            props,
            'source',
            'Source',
            obs.OBS_COMBO_TYPE_EDITABLE,
            obs.OBS_COMBO_FORMAT_STRING)
    local sources = obs.obs_enum_sources()
    if sources then
        for _, source in ipairs(sources) do
            local name = obs.obs_source_get_name(source)
            obs.obs_property_list_add_string(p, name, name)
        end
    end
    obs.source_list_release(sources)
    return props
end

function script_description()
    return 'Transform a source\'s position and scale.\n\n' ..
        'By Bernat Romagosa & Mun Films 2019'
end

function script_update(settings)
    source_name = obs.obs_data_get_string(settings, 'source')

    origin.rot = obs.obs_data_get_int(settings, 'origin rotation')
    origin.pos = obs.vec2()
    obs.vec2_set(
        origin.pos,
        obs.obs_data_get_int(settings, 'origin x'),
        obs.obs_data_get_int(settings, 'origin y'))
    origin.bounds = obs.vec2()
    obs.vec2_set(
        origin.bounds,
        obs.obs_data_get_int(settings, 'origin width'),
        obs.obs_data_get_int(settings, 'origin height'))

    destination.pos = obs.vec2()
    destination.rot = obs.obs_data_get_int(settings, 'destination rotation')
    obs.vec2_set(
        destination.pos,
        obs.obs_data_get_int(settings, 'destination x'),
        obs.obs_data_get_int(settings, 'destination y'))
    destination.bounds = obs.vec2()
    obs.vec2_set(
        destination.bounds,
        obs.obs_data_get_int(settings, 'destination width'),
        obs.obs_data_get_int(settings, 'destination height'))

    effect.duration = obs.obs_data_get_double(settings, 'duration')
    effect.easing = obs.obs_data_get_string(settings, 'easing')

    findSceneItem()
end

function script_defaults(settings)
end

function script_save(settings)
    local hotkey_save_array = obs.obs_hotkey_save(hotkey_id)
    obs.obs_data_set_array(settings, 'trigger_hotkey', hotkey_save_array)
    obs.obs_data_array_release(hotkey_save_array)
end

function script_load(settings)
    hotkey_id = obs.obs_hotkey_register_frontend(
        'trigger_resizer', 'Trigger Resizer', trigger)
    local hotkey_save_array = obs.obs_data_get_array(settings, 'trigger_hotkey')
    obs.obs_hotkey_load(hotkey_id, hotkey_save_array)
    obs.obs_data_array_release(hotkey_save_array)
end

function script_tick(seconds)
    if (active) then
        effect.elapsed_time = effect.elapsed_time + seconds
        obs.obs_sceneitem_set_rot(sceneItem, get_new_scalar('rot', seconds))
        obs.obs_sceneitem_set_pos(sceneItem, get_new_vector('pos', seconds))
        obs.obs_sceneitem_set_bounds(sceneItem, get_new_vector('bounds', seconds))
        if (effect.elapsed_time >= effect.duration) then
            active = false
            effect.elapsed_time = 0
            obs.obs_sceneitem_set_rot(sceneItem, destination.rot)
            obs.obs_sceneitem_set_pos(sceneItem, destination.pos)
            obs.obs_sceneitem_set_bounds(sceneItem, destination.bounds)
        end
    end
end


--
-- Transformer Code
--

function trigger(pressed)
    if not pressed then return end
    if sceneItem then
        obs.obs_sceneitem_set_rot(sceneItem, origin.rot)
        obs.obs_sceneitem_set_pos(sceneItem, origin.pos)
        obs.obs_sceneitem_set_bounds_type(sceneItem, obs.OBS_BOUNDS_STRETCH)
        obs.obs_sceneitem_set_bounds(sceneItem, origin.bounds)
        effect.elapsed_time = 0
        active = true
    else
        obs.remove_current_callback()
    end
end

function get_new_scalar(scalar_name, seconds)
    local function scalar_at_second(seconds)
        if effect.easing == 'linear' then
            return (
                (destination[scalar_name] - origin[scalar_name]) /
                    effect.duration) * seconds
        elseif effect.easing == 'cut' then
            return 0
        end
    end

    return obs['obs_sceneitem_get_' .. scalar_name](sceneItem) +
                scalar_at_second(seconds)
end

function get_new_vector(vector_name, seconds)
    local new_vector = obs.vec2()
    local function vector_at_second(seconds)
        local delta = obs.vec2()
        if effect.easing == 'linear' then
            obs.vec2_set(
                delta,
                ((destination[vector_name].x / effect.duration) * seconds),
                ((destination[vector_name].y / effect.duration) * seconds))
        elseif effect.easing == 'cut' then
            obs.vec2_set(delta, 0, 0)
        end
        return delta
    end

    obs['obs_sceneitem_get_' .. vector_name](sceneItem, new_vector)
    obs.vec2_add(
    new_vector,
    new_vector,
    vector_at_second(seconds))
    return new_vector
end
