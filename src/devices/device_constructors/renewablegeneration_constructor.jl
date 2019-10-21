function construct_device!(canonical::CanonicalModel, sys::PSY.System,
                           model::DeviceModel{R, D},
                           ::Type{S};
                           kwargs...) where {R<:PSY.RenewableGen,
                                             D<:AbstractRenewableDispatchFormulation,
                                             S<:PM.AbstractPowerModel}





    devices = PSY.get_components(R, sys)

    if validate_available_devices(devices, R)
        return
    end

    #Variables
    activepower_variables!(canonical, devices);

    reactivepower_variables!(canonical, devices);

    #Constraints
    activepower_constraints!(canonical, devices, D, S)

    reactivepower_constraints!(canonical, devices, D, S)

    feedforward!(canonical, R, model.feedforward)

    #Cost Function
    cost_function(canonical, devices, D, S)

    return

end

function construct_device!(canonical::CanonicalModel, sys::PSY.System,
                           model::DeviceModel{R, D},
                           ::Type{S};
                           kwargs...) where {R<:PSY.RenewableGen,
                                             D<:AbstractRenewableDispatchFormulation,
                                             S<:PM.AbstractActivePowerModel}




    devices = PSY.get_components(R, sys)

    if validate_available_devices(devices, R)
        return
    end

    #Variables
    activepower_variables!(canonical, devices)

    #Constraints
    activepower_constraints!(canonical, devices, D, S)

    feedforward!(canonical, R, model.feedforward)

    #Cost Function
    cost_function(canonical, devices, D, S)

    return

end

function construct_device!(canonical::CanonicalModel, sys::PSY.System,
                           model::DeviceModel{R, RenewableFixed},
                           system_formulation::Type{S};
                           kwargs...) where {R<:PSY.RenewableGen,
                                             S<:PM.AbstractPowerModel}




    devices = PSY.get_components(R, sys)

    if validate_available_devices(devices, R)
        return
    end

    nodal_expression!(canonical, devices, system_formulation)

    return

end

function construct_device!(canonical::CanonicalModel, sys::PSY.System,
                           model::DeviceModel{PSY.RenewableFix, D},
                           system_formulation::Type{S};
                           kwargs...) where {D<:AbstractRenewableDispatchFormulation,
                                             S<:PM.AbstractPowerModel}

    @warn("The Formulation $(D) only applies to FormulationControllable Renewable Resources, \n Consider Changing the Device Formulation to RenewableFixed")

    construct_device!(canonical,
                      sys,
                      DeviceModel(PSY.RenewableFix,RenewableFixed),
                      system_formulation;
                      kwargs...)

    return

end


function construct_device!(canonical::CanonicalModel, sys::PSY.System,
                           model::DeviceModel{PSY.RenewableFix, RenewableFixed},
                           system_formulation::Type{S};
                           kwargs...) where {S<:PM.AbstractPowerModel}




    devices = PSY.get_components(PSY.RenewableFix, sys)

    if validate_available_devices(devices, PSY.RenewableFix)
        return
    end

    nodal_expression!(canonical, devices, system_formulation)

    return

end
