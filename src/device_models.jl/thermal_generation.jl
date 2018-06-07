"""
This function add the variables for power generation output to the model
"""

function GenerationVariables(m::JuMP.Model, devices::Array{T,1}, time_periods::Int) where T<:Generator
    on_set = [d.name for d in devices if d.status == true]
    t = 1:time_periods
    @variable(m::JuMP.Model, Pg[on_set,t]) # Power output of generators
    return true
end


"""
This function add the variables for power generation commitment to the model
"""
function CommitmentVariables(m::JuMP.Model, devices::Array{T,1}, time_periods::Int) where T<:Generator
    on_set = [d.name for d in devices if d.status == true]
    t = 1:T
    @variable(m::JuMP.Model, on_th[on_set,t]) # Power output of generators
    @variable(m::JuMP.Model, start_th[on_set,t]) # Power output of generators
    @variable(m::JuMP.Model, stop_th[on_set,t]) # Power output of generators
    return true
end


function powerconstraints(Pg::JuMP.JuMPArray{JuMP.Variable}, devices::Array{T,1}, T) where T <: Thermal

    for (ix, name) in enumerate(Pg.indexsets[1])
        if name == devices[ix].name
            powerconstraints(EconomicDispatch, P_g[name,:], generators5[ix])

        else
            error("Bus name in Array and variable do not match")
        end
    end

    end
function RampConstraints(m::JuMP.Model, P_g::JuMP.JuMPArray{JuMP.Variable}, source::ThermalGen)


end

function TimeConstraints(m::JuMP.Model, UC_g::JuMP.JuMPArray{JuMP.Variable}, source::Thermalgen)


end
