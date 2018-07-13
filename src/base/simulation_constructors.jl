export construct_model

"""
The constructor takes the information from the PowerSimulationModel to build the variables and the constraints.
"""


function construct_model(model::PowerSimulationModel{T}, data) where T<:AbstractPowerSimulationType

    add_variables(m::JuMP.Model, data)
    power_limits(m::JuMP.Model, data)
    network(m::JuMP.Model, data)

end


