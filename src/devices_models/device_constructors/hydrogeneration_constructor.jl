function construct_device!(psi_container::PSIContainer, sys::PSY.System,
                           model::DeviceModel{H, D},
                           ::Type{S};
                           kwargs...) where {H<:PSY.HydroGen,
                                             D<:AbstractHydroDispatchFormulation,
                                             S<:PM.AbstractPowerModel}
    devices = PSY.get_components(H, sys)

    if validate_available_devices(devices, H)
        return
    end

    #Variables
    activepower_variables!(psi_container, devices);
    reactivepower_variables!(psi_container, devices);

    #Constraints
    activepower_constraints!(psi_container, devices, D, S, model.feed_forward)
    reactivepower_constraints!(psi_container, devices, D, S, model.feed_forward)
    feed_forward!(psi_container, H, model.feed_forward)

    #Cost Function
    cost_function(psi_container, devices, D, S)

    return
end

function construct_device!(psi_container::PSIContainer, sys::PSY.System,
                           model::DeviceModel{H, HydroDispatchSeasonalFlow},
                           ::Type{S};
                           kwargs...) where {H<:PSY.HydroGen,
                                             S<:PM.AbstractPowerModel}
    devices = PSY.get_components(H, sys)

    if validate_available_devices(devices, H)
        return
    end

    #Variables
    activepower_variables!(psi_container, devices);
    reactivepower_variables!(psi_container, devices);

    #Constraints
    activepower_constraints!(psi_container, devices, model.formulation, S, model.feed_forward)
    reactivepower_constraints!(psi_container, devices, model.formulation, S, model.feed_forward)
    energylimit_constraints!(psi_container, devices, model.formulation, S, model.feed_forward)
    feed_forward!(psi_container, H, model.feed_forward)

    #Cost Function
    cost_function(psi_container, devices, model.formulation, S)

    return
end

function construct_device!(psi_container::PSIContainer, sys::PSY.System,
                           model::DeviceModel{H, HydroCommitmentSeasonalFlow},
                           ::Type{S};
                           kwargs...) where {H<:PSY.HydroGen,
                                             S<:PM.AbstractPowerModel}
    devices = PSY.get_components(H, sys)

    if validate_available_devices(devices, H)
        return
    end

    #Variables
    activepower_variables!(psi_container, devices);
    reactivepower_variables!(psi_container, devices);
    commitment_variables!(psi_container, devices)

    #Initial Conditions
    initial_conditions!(psi_container, devices, model.formulation)

    #Constraints
    activepower_constraints!(psi_container, devices, model.formulation, S, model.feed_forward)
    reactivepower_constraints!(psi_container, devices, model.formulation, S, model.feed_forward)
    energylimit_constraints!(psi_container, devices, model.formulation, S, model.feed_forward)
    commitment_constraints!(psi_container, devices, model.formulation, S, model.feed_forward)
    feed_forward!(psi_container, H, model.feed_forward)

    #Cost Function
    cost_function(psi_container, devices, model.formulation, S)

    return
end


function construct_device!(psi_container::PSIContainer, sys::PSY.System,
                           model::DeviceModel{H, D},
                           ::Type{S};
                           kwargs...) where {H<:PSY.HydroGen,
                                             D<:AbstractHydroUnitCommitment,
                                             S<:PM.AbstractPowerModel}
    devices = PSY.get_components(H, sys)

    if validate_available_devices(devices, H)
        return
    end

    #Variables
    activepower_variables!(psi_container, devices);
    reactivepower_variables!(psi_container, devices);
    commitment_variables!(psi_container, devices)

    #Initial Conditions
    initial_conditions!(psi_container, devices, D)

    #Constraints
    activepower_constraints!(psi_container, devices, D, S, model.feed_forward)
    reactivepower_constraints!(psi_container, devices, D, S, model.feed_forward)
    commitment_constraints!(psi_container, devices, D, S, model.feed_forward)
    feed_forward!(psi_container, H, model.feed_forward)

    #Cost Function
    cost_function(psi_container, devices, D, S)

    return
end

function construct_device!(psi_container::PSIContainer, sys::PSY.System,
                           model::DeviceModel{H, D},
                           ::Type{S};
                           kwargs...) where {H<:PSY.HydroGen,
                                             D<:AbstractHydroDispatchFormulation,
                                             S<:PM.AbstractActivePowerModel}
    devices = PSY.get_components(H, sys)

    if validate_available_devices(devices, H)
        return
    end

    #Variables
    activepower_variables!(psi_container, devices);

    #Constraints
    activepower_constraints!(psi_container, devices, D, S, model.feed_forward)
    feed_forward!(psi_container, H, model.feed_forward)

    #Cost Function
    cost_function(psi_container, devices, D, S)

    return
end

function construct_device!(psi_container::PSIContainer, sys::PSY.System,
                           model::DeviceModel{H, HydroDispatchSeasonalFlow},
                           ::Type{S};
                           kwargs...) where {H<:PSY.HydroGen,
                                             S<:PM.AbstractActivePowerModel}
    devices = PSY.get_components(H, sys)

    if validate_available_devices(devices, H)
        return
    end

    #Variables
    activepower_variables!(psi_container, devices);

    #Constraints
    activepower_constraints!(psi_container, devices, model.formulation, S, model.feed_forward)
    energylimit_constraints!(psi_container, devices, model.formulation, S, model.feed_forward)
    feed_forward!(psi_container, H, model.feed_forward)

    #Cost Function
    cost_function(psi_container, devices, model.formulation, S)

    return
end

function construct_device!(psi_container::PSIContainer, sys::PSY.System,
                           model::DeviceModel{H, HydroCommitmentSeasonalFlow},
                           ::Type{S};
                           kwargs...) where {H<:PSY.HydroGen,
                                             S<:PM.AbstractActivePowerModel}
    devices = PSY.get_components(H, sys)

    if validate_available_devices(devices, H)
        return
    end

    #Variables
    activepower_variables!(psi_container, devices);
    commitment_variables!(psi_container, devices)

    #Initial Conditions
    initial_conditions!(psi_container, devices, model.formulation)

    #Constraints
    activepower_constraints!(psi_container, devices, model.formulation, S, model.feed_forward)
    energylimit_constraints!(psi_container, devices, model.formulation, S, model.feed_forward)
    commitment_constraints!(psi_container, devices, model.formulation, S, model.feed_forward)
    feed_forward!(psi_container, H, model.feed_forward)

    #Cost Function
    cost_function(psi_container, devices, model.formulation, S)

    return
end


function construct_device!(psi_container::PSIContainer, sys::PSY.System,
                           model::DeviceModel{H, D},
                           ::Type{S};
                           kwargs...) where {H<:PSY.HydroGen,
                                             D<:AbstractHydroUnitCommitment,
                                             S<:PM.AbstractActivePowerModel}

    devices = PSY.get_components(H, sys)

    if validate_available_devices(devices, H)
        return
    end

    #Variables
    activepower_variables!(psi_container, devices);
    commitment_variables!(psi_container, devices)

    #Initial Conditions
    initial_conditions!(psi_container, devices, D)

    #Constraints
    activepower_constraints!(psi_container, devices, D, S, model.feed_forward)
    commitment_constraints!(psi_container, devices, D, S, model.feed_forward)
    feed_forward!(psi_container, H, model.feed_forward)

    #Cost Function
    cost_function(psi_container, devices, D, S)

    return
end


function construct_device!(psi_container::PSIContainer, sys::PSY.System,
                           model::DeviceModel{H, HydroFixed},
                           ::Type{S};
                           kwargs...) where {H<:PSY.HydroGen,
                                             S<:PM.AbstractPowerModel}
    devices = PSY.get_components(H, sys)

    if validate_available_devices(devices, H)
        return
    end

    nodal_expression!(psi_container, devices, S)

    return
end

function construct_device!(psi_container::PSIContainer, sys::PSY.System,
                           model::DeviceModel{PSY.HydroFix, D},
                           ::Type{S};
                           kwargs...) where {D<:AbstractHydroFormulation,
                                             S<:PM.AbstractPowerModel}
    @warn("The Formulation $(D) only applies to Dispatchable Hydro, *
               Consider Changing the Device Formulation to HydroFixed")

    construct_device!(psi_container,
                      DeviceModel(PSY.HydroFix, HydroFixed),
                      S;
                      kwargs...)
end

function construct_device!(psi_container::PSIContainer, sys::PSY.System,
                           model::DeviceModel{PSY.HydroFix, HydroFixed},
                           ::Type{S};
                           kwargs...) where {S<:PM.AbstractPowerModel}
    devices = PSY.get_components(model.device_type, sys)

    if validate_available_devices(devices, model.device_type)
        return
    end

    nodal_expression!(psi_container, devices, S)

    return
end
