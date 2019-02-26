function cost_function(ps_m::CanonicalModel,
                       devices::Array{T,1},
                       device_formulation::Type{D},
                       system_formulation::Type{S}) where {T <: PSY.ThermalGen,
                                                           D <: AbstractThermalDispatchForm,
                                                           S <: PM.AbstractPowerFormulation}

    add_to_cost(ps_m, devices, "Pth", :variablecost)

end

function cost_function(ps_m::CanonicalModel,
                       devices::Array{T,1},
                       device_formulation::Type{D},
                       system_formulation::Type{S}) where {T <: PSY.ThermalGen,
                                                           D <: AbstractThermalFormulation,
                                                           S <: PM.AbstractPowerFormulation}

    #Variable Cost component
    add_to_cost(ps_m, devices, "Pth", :variablecost)

    #Commitment Cost Components
    add_to_cost(ps_m, devices, "start_th", :startupcost)
    add_to_cost(ps_m, devices, "stop_th", :shutdncost)
    add_to_cost(ps_m, devices, "on_th", :fixedcost)

end