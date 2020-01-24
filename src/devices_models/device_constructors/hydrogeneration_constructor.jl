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
    activepower_constraints!(psi_container, devices, model, S, model.feed_forward)
    reactivepower_constraints!(psi_container, devices, model, S, model.feed_forward)
    feed_forward!(psi_container, H, model.feed_forward)

    #Cost Function
    cost_function(psi_container, devices, D, S)

    return
end

function construct_device!(psi_container::PSIContainer, sys::PSY.System,
                           model::DeviceModel{H, HydroDispatchReservoirFlow},
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
    activepower_constraints!(psi_container, devices, model, S, model.feed_forward)
    reactivepower_constraints!(psi_container, devices, model, S, model.feed_forward)
    energy_limit_constraints!(psi_container, devices, model, S, model.feed_forward)
    feed_forward!(psi_container, H, model.feed_forward)

    #Cost Function
    cost_function(psi_container, devices, HydroDispatchReservoirFlow, S)

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

    #Initial Conditions
    initial_conditions!(psi_container, devices, model.formulation)

    #Constraints
    activepower_constraints!(psi_container, devices, model, S, model.feed_forward)
    reactivepower_constraints!(psi_container, devices, model, S, model.feed_forward)
    commitment_constraints!(psi_container, devices, model, S, model.feed_forward)
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
    activepower_constraints!(psi_container, devices, model, S, model.feed_forward)
    feed_forward!(psi_container, H, model.feed_forward)

    #Cost Function
    cost_function(psi_container, devices, D, S)

    return
end

function construct_device!(psi_container::PSIContainer, sys::PSY.System,
                           model::DeviceModel{H, HydroDispatchReservoirFlow},
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
    activepower_constraints!(psi_container, devices, model, S, model.feed_forward)
    energy_limit_constraints!(psi_container, devices, model, S, model.feed_forward)
    feed_forward!(psi_container, H, model.feed_forward)

    #Cost Function
    cost_function(psi_container, devices, HydroDispatchReservoirFlow, S)

    return
end

function construct_device!(psi_container::PSIContainer, sys::PSY.System,
                           model::DeviceModel{H, HydroDispatchReservoirStorage},
                           ::Type{S};
                           kwargs...) where {H<:PSY.HydroGen,
                                             S<:PM.AbstractActivePowerModel}
    devices = PSY.get_components(H, sys)

    if validate_available_devices(devices, H)
        return
    end

    #Variables
    activepower_variables!(psi_container, devices);
    energy_storage_variables!(psi_container, devices)
    inflow_variables!(psi_container, devices)
    spillage_variables!(psi_container, devices)

    #Initial Conditions
    storage_energy_init(psi_container, devices)

    #Constraints
    activepower_constraints!(psi_container, devices, model, S, model.feed_forward)
    inflow_constraints!(psi_container, devices, model, S, model.feed_forward)
    energy_balance_constraint!(psi_container, devices, model, S, model.feed_forward)
    feed_forward!(psi_container, H, model.feed_forward)

    #Cost Function
    cost_function(psi_container, devices, HydroDispatchReservoirFlow, S)

    return
end


function construct_device!(psi_container::PSIContainer, sys::PSY.System,
                           model::DeviceModel{H, HydroCommitmentReservoirFlow},
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
    activepower_constraints!(psi_container, devices, model, S, model.feed_forward)
    commitment_constraints!(psi_container, devices, model, S, model.feed_forward)
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
    devices = PSY.get_components(PSY.HydroFix, sys)

    if validate_available_devices(devices, PSY.HydroFix)
        return
    end

    nodal_expression!(psi_container, devices, S)

    return
end
