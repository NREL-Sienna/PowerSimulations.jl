function constructdevice!(ps_m::CanonicalModel, category::Type{R}, category_formulation::Type{D}, system_formulation::Type{S}, sys::PSY.PowerSystem; kwargs...) where {R <: PSY.RenewableGen, D <: AbstractRenewableDispatchForm, S <: PM.AbstractPowerFormulation}

    #Defining this outside in order to enable time slicing later
    time_range = 1:sys.time_periods

    fixed_resources = [fs for fs in sys.generators.renewable if isa(fs,PSY.RenewableFix)]

    controllable_resources = [fs for fs in sys.generators.renewable if !isa(fs,PSY.RenewableFix)]
    
    if !isempty(controllable_resources) 

        #Variables
        activepower_variables(ps_m, controllable_resources, time_range);

        reactivepower_variables(ps_m, controllable_resources, time_range);

        #Constraints
        activepower_constraints(ps_m, controllable_resources, category_formulation, system_formulation, time_range)

        reactivepower_constraints(ps_m, controllable_resources, category_formulation, system_formulation, time_range)

        #Cost Function
        cost_function(ps_m, controllable_resources, category_formulation, system_formulation)
    
    else 
        @warn("The Data Doesn't Contain Controllable Renewable Resources, Consider Changing the Device Formulation to RenewableFixed")

    end
    
    #add to expression

    !isempty(fixed_resources) ? nodal_expression(ps_m, fixed_resources, system_formulation, time_range) : true
     
end

function constructdevice!(ps_m::CanonicalModel, category::Type{R}, category_formulation::Type{D}, system_formulation::Type{S}, sys::PSY.PowerSystem; kwargs...) where {R <: PSY.RenewableGen, D <: AbstractRenewableDispatchForm, S <: PM.AbstractActivePowerFormulation}

    #Defining this outside in order to enable time slicing later
    time_range = 1:sys.time_periods

    fixed_resources = [fs for fs in sys.generators.renewable if isa(fs,PSY.RenewableFix)]

    controllable_resources = [fs for fs in sys.generators.renewable if !isa(fs,PSY.RenewableFix)]
    
    if !isempty(controllable_resources) 

        #Variables
        activepower_variables(ps_m, controllable_resources, time_range)

        #Constraints
        activepower_constraints(ps_m, controllable_resources, category_formulation, system_formulation, time_range)

        #Cost Function
        cost_function(ps_m, controllable_resources, category_formulation, system_formulation)
    
    else 
        @warn("The Data Doesn't Contain Controllable Renewable Resources, Consider Changing the Device Formulation to RenewableFixed")

    end
    
    #add to expression

    !isempty(fixed_resources) ? nodal_expression(ps_m, fixed_resources, system_formulation, time_range) : true
     
end

function constructdevice!(ps_m::CanonicalModel, category::Type{R}, category_formulation::Type{PSI.RenewableFixed}, system_formulation::Type{S}, sys::PSY.PowerSystem; kwargs...) where {R <: PSY.RenewableGen, S <: PM.AbstractPowerFormulation}

    #Defining this outside in order to enable time slicing later
    time_range = 1:sys.time_periods
    
    nodal_expression(ps_m, sys.generators.renewable, system_formulation, time_range)

end

