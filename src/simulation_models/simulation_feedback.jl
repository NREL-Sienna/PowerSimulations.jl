@enum FeedbackModel begin
    SYNCHRONIZE = 1
    RECEDINGHORIZON = 2
end

function update_stage!(stage::_Stage, sim::Simulation)

    for (k, v) in stage.model.canonical.parameters
        parameter_update!(k, v, stage.key, sim)
    end

    return

end
