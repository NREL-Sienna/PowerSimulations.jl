function construct_device!(canonical::Canonical,
                           sys::PSY.System,
                           model::DeviceModel{L, D},
                           ::Type{S};
                           kwargs...) where {L<:PSY.ControllableLoad,
                                             D<:AbstractControllablePowerLoadFormulation,
                                             S<:PM.AbstractPowerModel}




    devices = PSY.get_components(L, sys)

    if validate_available_devices(devices, L)
        return
    end

    #Variables
    activepower_variables!(canonical, devices)

    reactivepower_variables!(canonical, devices)

    #Constraints
    activepower_constraints!(canonical, devices, D, S)

    reactivepower_constraints!(canonical, devices, D, S)

    feedforward!(canonical, L, model.feedforward)

    #Cost Function
    cost_function(canonical, devices, D, S)

    return

end

function construct_device!(canonical::Canonical,
                           sys::PSY.System,
                           model::DeviceModel{L, D},
                           ::Type{S};
                           kwargs...) where {L<:PSY.ControllableLoad,
                                             D<:AbstractControllablePowerLoadFormulation,
                                             S<:PM.AbstractActivePowerModel}




    devices = PSY.get_components(L, sys)

    if validate_available_devices(devices, L)
        return
    end

    #Variables
    activepower_variables!(canonical, devices)

    #Constraints
    activepower_constraints!(canonical, devices, D, S)

    feedforward!(canonical, L, model.feedforward)

    #Cost Function
    cost_function(canonical, devices, D, S)

    return

end

function construct_device!(canonical::Canonical,
                           sys::PSY.System,
                           model::DeviceModel{L, InterruptiblePowerLoad},
                           ::Type{S};
                           kwargs...) where {L<:PSY.ControllableLoad,
                                             S<:PM.AbstractPowerModel}




    devices = PSY.get_components(L, sys)

    if validate_available_devices(devices, L)
        return
    end

    #Variables
    activepower_variables!(canonical, devices)

    reactivepower_variables!(canonical, devices)

    commitment_variables!(canonical, devices)

    #Constraints
    activepower_constraints!(canonical, devices, model.formulation, S)

    reactivepower_constraints!(canonical, devices, model.formulation, S)

    feedforward!(canonical, L, model.feedforward)

    #Cost Function
    cost_function(canonical, devices, model.formulation, S)

    return

end

function construct_device!(canonical::Canonical,
                           sys::PSY.System,
                           model::DeviceModel{L, InterruptiblePowerLoad},
                           ::Type{S};
                           kwargs...) where {L<:PSY.ControllableLoad,
                                             S<:PM.AbstractActivePowerModel}




    devices = PSY.get_components(L, sys)

    if validate_available_devices(devices, L)
        return
    end

    #Variables
    activepower_variables!(canonical, devices)

    commitment_variables!(canonical, devices)

    #Constraints
    activepower_constraints!(canonical, devices, model.formulation, S)

    feedforward!(canonical, L, model.feedforward)

    #Cost Function
    cost_function(canonical, devices, model.formulation, S)

    return

end

function construct_device!(canonical::Canonical,
                           sys::PSY.System,
                           model::DeviceModel{L, StaticPowerLoad},
                           ::Type{S};
                           kwargs...) where {L<:PSY.ElectricLoad,
                                             S<:PM.AbstractPowerModel}




    devices = PSY.get_components(L, sys)

    if validate_available_devices(devices, L)
        return
    end

    nodal_expression!(canonical, devices, S)

    return

end

function construct_device!(canonical::Canonical,
                           sys::PSY.System,
                           model::DeviceModel{L, D},
                           ::Type{S};
                           kwargs...) where {L<:PSY.StaticLoad,
                                             D<:AbstractControllablePowerLoadFormulation,
                                             S<:PM.AbstractPowerModel}

    if D != StaticPowerLoad
        @warn("The Formulation $(D) only applies to FormulationControllable Loads, \n Consider Changing the Device Formulation to StaticPowerLoad")
    end

    construct_device!(canonical,
                      sys,
                      DeviceModel(L, StaticPowerLoad),
                      S;
                      kwargs...)

end
