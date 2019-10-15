function construct_device!(op_model::OperationModel,
                           model::DeviceModel{H, D},
                           ::Type{S};
                           kwargs...) where {H<:PSY.HydroGen,
                                             D<:AbstractHydroFormulation,
                                             S<:PM.AbstractPowerModel}

    forecast = get(kwargs, :forecast, true)

    sys = get_system(op_model)

    devices = PSY.get_components(H, sys)

    if validate_available_devices(devices, H)
        return
    end

    error("Currently only HydroFixed Formulation is Enabled")

    return

end


function construct_device!(op_model::OperationModel,
                           model::DeviceModel{H, HydroFixed},
                           ::Type{S};
                           kwargs...) where {H<:PSY.HydroGen,
                                             S<:PM.AbstractPowerModel}

    forecast = get(kwargs, :forecast, true)

    sys = get_system(op_model)

    devices = PSY.get_components(H, sys)

    if validate_available_devices(devices, H)
        return
    end

    nodal_expression(op_model.canonical, devices, S)

    return

end

function construct_device!(op_model::OperationModel,
                           model::DeviceModel{PSY.HydroFix, D},
                           ::Type{S};
                           kwargs...) where {D<:AbstractHydroFormulation,
                                             S<:PM.AbstractPowerModel}

    @warn("The Formulation $(D) only applies to Dispatchable Hydro, *
               Consider Changing the Device Formulation to HydroFixed")

    construct_device!(op_model.canonical,
                      DeviceModel(PSY.HydroFix, HydroFixed),
                      S;
                      kwargs...)

end

function construct_device!(op_model::OperationModel,
                           model::DeviceModel{PSY.HydroFix, HydroFixed},
                           ::Type{S};
                           kwargs...) where {S<:PM.AbstractPowerModel}

    forecast = get(kwargs, :forecast, true)

    sys = get_system(op_model)

    devices = PSY.get_components(PSY.HydroFix, sys)

    if validate_available_devices(devices, PSY.HydroFix)
        return
    end

    nodal_expression(op_model.canonical, devices, S)

    return

end
