function constructdevice!(ps_m::CanonicalModel, category::Type{PSY.RenewableGen}, category_formulation::Type{D}, system_formulation::Type{S}, sys::PSY.PowerSystem; kwargs...) where {D <: AbstractRenewableDispatchForm, S <: PM.AbstractPowerFormulation}

    #Defining this outside in order to enable time slicing later
    time_range = 1:sys.time_periods
    
    #Variables
    activepowervariables(ps_m, sys.generators.renewable, time_range);

    reactivepowervariables(ps_m, sys.generators.renewable, time_range);

    #Constraints
    activepower(ps_m, sys.generators.renewable, category_formulation, system_formulation, time_range)

    reactivepower(ps_m, sys.generators.renewable, category_formulation, system_formulation, time_range)

    #Cost Function
    cost_function(ps_m, sys.generators.renewable, category_formulation, system_formulation)
    

end

function constructdevice!(ps_m::CanonicalModel, category::Type{PSY.RenewableGen}, category_formulation::Type{RenewableConstantPowerFactor}, system_formulation::Type{S}, sys::PSY.PowerSystem; kwargs...) where {S <: PM.AbstractPowerFormulation}

    #Defining this outside in order to enable time slicing later
    time_range = 1:sys.time_periods
    
    #Variables
    activepowervariables(ps_m, sys.generators.renewable, time_range);

    reactivepowervariables(ps_m, sys.generators.renewable, time_range);

    #Constraints
    activepower(ps_m, sys.generators.renewable, category_formulation, system_formulation, time_range)

    reactivepower(ps_m, sys.generators.renewable, category_formulation, system_formulation, time_range)

    #Cost Function
    cost_function(ps_m, sys.generators.renewable, category_formulation, system_formulation)
    

end


function constructdevice!(ps_m::CanonicalModel, category::Type{PSY.RenewableGen}, category_formulation::Type{D}, system_formulation::Type{S}, sys::PSY.PowerSystem; kwargs...) where {D <: AbstractRenewableDispatchForm, S <: PM.PM.AbstractActivePowerFormulation}

    #Defining this outside in order to enable time slicing later
    time_range = 1:sys.time_periods
    
    #Variables
    activepowervariables(ps_m, sys.generators.renewable, time_range);

    #Constraints
    activepower(ps_m, sys.generators.renewable, category_formulation, system_formulation, time_range)

    #Cost Function
    cost_function(ps_m, sys.generators.renewable, category_formulation, system_formulation)

end
