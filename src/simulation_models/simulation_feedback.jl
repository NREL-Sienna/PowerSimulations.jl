function update_stage!(stage::Stage, sim::Simulation)

    for (k, v) in stage.model.canonical.parameters
        parameter_update!(k, v, stage.key, sim)
    end

    return

end
