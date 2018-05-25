export construct_model

"""
The constructor takes de information from the AbstractPowerModel to build the variables and the constraints. 
"""




function construct_model(model::AbstractPowerModel, data)

    #Get all on devices in the system
    t = 1:PowerSystem.timesteps
    g_on_set = [g.name for g in PowerSystem.generators if g.status == true]
    e_on_set = [e.name for e in PowerSystem.storage if e.status == true]
    cl_on_set = [cl.name for cl in PowerSystem.loads if (cl.status == true && typeof(cl) != StaticLoad)]
                

    add_variables(m::JuMP.Model, data)
    power_limits(m::JuMP.Model, data)
    network(m::JuMP.Model, data)

end


