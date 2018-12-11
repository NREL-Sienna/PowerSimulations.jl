function anglevariables(m::JuMP.AbstractModel, system_formulation::Type{S}, sys::PowerSystems.PowerSystem) where {S <: Union{PM.AbstractDCPForm, PM.AbstractACPForm}}

    on_set = [d.name for d in sys.buses if d.available == true]

    time_range = 1:sys.time_periods

    theta = @variable(m, theta[on_set,time_range])

end

function voltagevariables(m::JuMP.AbstractModel, system_formulation::Type{S}, sys::PowerSystems.PowerSystem) where {S <: PM.AbstractACPForm}

    on_set = [d.name for d in sys.buses if d.available == true]

    time_range = 1:sys.time_periods

    vm = @variable(m, vm[on_set,time_range])
end

function voltagevariables(m::JuMP.AbstractModel, system_formulation::Type{S}, sys::PowerSystems.PowerSystem) where {S <: PM.AbstractACRForm}

    on_set = [d.name for d in sys.buses if d.available == true]

    time_range = 1:sys.time_periods

    vm_re = @variable(m, vm_re[on_set,time_range])
    
    vm_im = @variable(m, vm_re[on_set,time_range])

end

