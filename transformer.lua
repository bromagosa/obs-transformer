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

    origin.rotation = obs.obs_data_get_int(settings, 'origin rotation')
    origin.position = obs.vec2()
    obs.vec2_set(
        origin.position,
        obs.obs_data_get_int(settings, 'origin x'),
        obs.obs_data_get_int(settings, 'origin y'))
    origin.dimensions = obs.vec2()
    obs.vec2_set(
        origin.dimensions,
        obs.obs_data_get_int(settings, 'origin width'),
        obs.obs_data_get_int(settings, 'origin height'))

    destination.position = obs.vec2()
    destination.rotation = obs.obs_data_get_int(settings, 'destination rotation')
    obs.vec2_set(
        destination.position,
        obs.obs_data_get_int(settings, 'destination x'),
        obs.obs_data_get_int(settings, 'destination y'))
    destination.dimensions = obs.vec2()
    obs.vec2_set(
        destination.dimensions,
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
        obs.obs_sceneitem_set_rot(sceneItem, get_new_rotation(seconds))
        -- obs.obs_sceneitem_set_pos(sceneItem, get_new_position(seconds))
        if (effect.elapsed_time >= effect.duration) then
            active = false
            effect.elapsed_time = 0
            obs.obs_sceneitem_set_rot(sceneItem, destination.rotation)
        end
    end
end


--
-- Transformer Code
--

function trigger(pressed)
    if not pressed then return end
    if sceneItem then
        obs.obs_sceneitem_set_rot(sceneItem, origin.rotation)
        obs.obs_sceneitem_set_pos(sceneItem, origin.position)
        obs.obs_sceneitem_set_bounds_type(sceneItem, obs.OBS_BOUNDS_STRETCH)
        obs.obs_sceneitem_set_bounds(sceneItem, origin.dimensions)
        effect.elapsed_time = 0
        active = true
    else
        obs.remove_current_callback()
    end
end

function get_new_rotation(seconds)
    local delta = rotation_at_second(seconds)
    return obs.obs_sceneitem_get_rot(sceneItem) + delta
end

function rotation_at_second(seconds)
    if effect.easing == 'linear' then
        return ((destination.rotation - origin.rotation) / effect.duration) * seconds
    elseif effect.easing == 'cut' then
        return 0
    end
end

function get_new_position(seconds)
    local new_pos = obs.vec2()
    obs.vec2_add(
        new_pos,
        obs.obs_sceneitem_get_pos(sceneItem),
        position_at_second(seconds))
    return new_pos
end

function position_at_second(seconds)
    local delta = obs.vec2()
    if effect.easing == 'linear' then
        obs.vec2_set(
            delta,
            ((destination.position.x / effect.duration) * seconds),
            ((destination.position.y / effect.duration) * seconds))
    elseif effect.easing == 'cut' then
        obs.vec2_set(delta, 0, 0)
    end
    return delta
end
