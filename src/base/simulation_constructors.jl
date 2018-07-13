export construct_model

"""
The constructor takes the information from the AbstractPowerSimulationModel to build the variables and the constraints.
"""


function construct_model(model::AbstractPowerSimulationModel, data)

    add_variables(m::JuMP.Model, data)
    power_limits(m::JuMP.Model, data)
    network(m::JuMP.Model, data)

end


