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
    obs.obs_property_list_add_string(effects, 'Ease-in-quad', 'ease-in-quad')
    obs.obs_property_list_add_string(effects, 'Ease-out-quad', 'ease-out-quad')
    obs.obs_property_list_add_string(effects, 'Ease-in-out-quad', 'ease-in-out-quad')
    obs.obs_property_list_add_string(effects, 'Ease-out-in-quad', 'ease-out-in-quad')
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

function easing(function_name, time, change, initial_value)
    if function_name == 'linear' then
        return change * time / effect.duration + initial_value
    elseif function_name == 'ease-in-quad' then
        time = time / effect.duration
        return change * math.pow(time, 2) + initial_value
    elseif function_name == 'ease-out-quad' then
        time = time / effect.duration
        return - change * time * (time - 2) + initial_value
    elseif function_name == 'ease-in-out-quad' then
        time = time / effect.duration * 2
        if time < 1 then
            return change / 2 * math.pow(time, 2) + initial_value
        else
            return -change / 2 * ((time - 1) * (time - 3) - 1) + initial_value
        end
    elseif function_name == 'ease-out-in-quad' then
        if time < effect.duration / 2 then
            return easing(
                'ease-out-quad',
                time * 2,
                change / 2,
                initial_value)
        else
            return easing(
                'ease-in-quad',
                (time * 2) - effect.duration,
                change / 2,
                initial_value + change / 2)
        end
    elseif function_name == 'cut' then
        return 0
    end
end

function get_new_scalar(scalar_name)
    return easing(
        effect.easing,
        effect.elapsed_time,
        destination[scalar_name] - origin[scalar_name],
        origin[scalar_name])
end

function get_new_vector(vector_name)
    local delta = obs.vec2()

    obs.vec2_set(
        delta,
        easing(
            effect.easing,
            effect.elapsed_time,
            destination[vector_name].x - origin[vector_name].x,
            origin[vector_name].x),
        easing(
            effect.easing,
            effect.elapsed_time,
            destination[vector_name].y - origin[vector_name].y,
            origin[vector_name].y))

    return delta
end
