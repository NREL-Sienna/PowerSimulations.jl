function construct_device!(ps_m::CanonicalModel,
                           device::Type{R},
                           device_formulation::Type{D},
                           system_formulation::Type{S},
                           sys::PSY.PowerSystem,
                           time_range::UnitRange{Int64};
                           kwargs...) where {R <: PSY.RenewableGen,
                                             D <: AbstractRenewableDispatchForm,
                                             S <: PM.AbstractPowerFormulation}


    # TODO: Remove the use of two loops to classify resource types

    if !isa(sys.generators.renewable, Nothing)

        fixed_resources = [fs for fs in sys.generators.renewable if isa(fs,PSY.RenewableFix)]

        controllable_resources = [fs for fs in sys.generators.renewable if !isa(fs,PSY.RenewableFix)]

        if !isempty(controllable_resources)

            #Variables
            activepower_variables(ps_m, controllable_resources, time_range);

            reactivepower_variables(ps_m, controllable_resources, time_range);

            #Constraints
            activepower_constraints(ps_m, controllable_resources, device_formulation, system_formulation, time_range)

            reactivepower_constraints(ps_m, controllable_resources, device_formulation, system_formulation, time_range)

            #Cost Function
            cost_function(ps_m, controllable_resources, device_formulation, system_formulation)

        else
            @warn("The Data Doesn't Contain Controllable Renewable Resources, Consider Changing the Device Formulation to RenewableFixed")
        end

        #add to expression

        if !isempty(fixed_resources)
            nodal_expression(ps_m, fixed_resources, system_formulation, time_range)
        end

    end

    return

end

function construct_device!(ps_m::CanonicalModel,
                           device::Type{R},
                           device_formulation::Type{D},
                           system_formulation::Type{S},
                           sys::PSY.PowerSystem,
                           time_range::UnitRange{Int64};
                           kwargs...) where {R <: PSY.RenewableGen,
                                             D <: AbstractRenewableDispatchForm,
                                             S <: PM.AbstractActivePowerFormulation}

    if !isa(sys.generators.renewable, Nothing)

        fixed_resources = [fs for fs in sys.generators.renewable if isa(fs,PSY.RenewableFix)]

        controllable_resources = [fs for fs in sys.generators.renewable if !isa(fs,PSY.RenewableFix)]

        if !isempty(controllable_resources)

            #Variables
            activepower_variables(ps_m, controllable_resources, time_range)

            #Constraints
            activepower_constraints(ps_m, controllable_resources, device_formulation, system_formulation, time_range)

            #Cost Function
            cost_function(ps_m, controllable_resources, device_formulation, system_formulation)

        else
            @warn("The Data Doesn't Contain Controllable Renewable Resources, Consider Changing the Device Formulation to RenewableFixed")

        end

        #add to expression

        if !isempty(fixed_resources)
            nodal_expression(ps_m, fixed_resources, system_formulation, time_range)
        end

    end

    return

end

function construct_device!(ps_m::CanonicalModel,
                           device::Type{R},
                           device_formulation::Type{PSI.RenewableFixed},
                           system_formulation::Type{S},
                           sys::PSY.PowerSystem,
                           time_range::UnitRange{Int64};
                           kwargs...) where {R <: PSY.RenewableGen,
                                             S <: PM.AbstractPowerFormulation}


    if !isa(sys.generators.renewable, Nothing)
        nodal_expression(ps_m, sys.generators.renewable, system_formulation, time_range)
    end

    return

end
