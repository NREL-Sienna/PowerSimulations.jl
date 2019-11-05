function construct_device!(canonical::Canonical, sys::PSY.System,
                           model::DeviceModel{H, D},
                           ::Type{S};
                           kwargs...) where {H<:PSY.HydroGen,
                                             D<:AbstractHydroFormulation,
                                             S<:PM.AbstractPowerModel}




    devices = PSY.get_components(H, sys)

    if validate_available_devices(devices, H)
        return
    end

    #Variables
    activepower_variables!(canonical, devices);

    reactivepower_variables!(canonical, devices);

    #Constraints
    activepower_constraints!(canonical, devices, D, S)

    reactivepower_constraints!(canonical, devices, D, S)

    feedforward!(canonical, H, model.feedforward)

    #Cost Function
    cost_function(canonical, devices, D, S)

    return

end

function construct_device!(canonical::Canonical, sys::PSY.System,
                           model::DeviceModel{H, D},
                           ::Type{S};
                           kwargs...) where {H<:PSY.HydroGen,
                                             D<:AbstractHydroFormulation,
                                             S<:PM.AbstractActivePowerModel}




    devices = PSY.get_components(H, sys)

    if validate_available_devices(devices, H)
        return
    end

    #Variables
    activepower_variables!(canonical, devices);

    #Constraints
    activepower_constraints!(canonical, devices, D, S)

    feedforward!(canonical, H, model.feedforward)

    #Cost Function
    cost_function(canonical, devices, D, S)

    return

end

function construct_device!(canonical::Canonical, sys::PSY.System,
                           model::DeviceModel{H, HydroFixed},
                           ::Type{S};
                           kwargs...) where {H<:PSY.HydroGen,
                                             S<:PM.AbstractPowerModel}




    devices = PSY.get_components(H, sys)

    if validate_available_devices(devices, H)
        return
    end

    nodal_expression!(canonical, devices, S)

    return

end

function construct_device!(canonical::Canonical, sys::PSY.System,
                           model::DeviceModel{PSY.HydroFix, D},
                           ::Type{S};
                           kwargs...) where {D<:AbstractHydroFormulation,
                                             S<:PM.AbstractPowerModel}

    @warn("The Formulation $(D) only applies to Dispatchable Hydro, *
               Consider Changing the Device Formulation to HydroFixed")

    construct_device!(canonical,
                      DeviceModel(PSY.HydroFix, HydroFixed),
                      S;
                      kwargs...)


end

function construct_device!(canonical::Canonical, sys::PSY.System,
                           model::DeviceModel{PSY.HydroFix, HydroFixed},
                           ::Type{S};
                           kwargs...) where {S<:PM.AbstractActivePowerModel}




    devices = PSY.get_components(PSY.HydroFix, sys)

    if validate_available_devices(devices, PSY.HydroFix)
        return
    end

    nodal_expression!(canonical, devices, S)

    return

end
