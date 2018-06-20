export construct_model

"""
The constructor takes de information from the AbstractPowerModel to build the variables and the constraints.
"""


function construct_model(model::AbstractPowerModel, data)

    add_variables(m::JuMP.Model, data)
    power_limits(m::JuMP.Model, data)
    network(m::JuMP.Model, data)

end


