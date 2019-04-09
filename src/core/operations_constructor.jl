function _pass_abstract_jump(optimizer::Union{Nothing,JuMP.OptimizerFactory}; kwargs...)

    if isa(optimizer,Nothing)
        @info("The optimization model has no optimizer attached")
    end

    if :parameters in keys(kwargs)
        parameters = kwargs[:parameters]
    else
        parameters = true
    end

    if :JuMPmodel in keys(kwargs) && parameters

        if !haskey(m.ext, :params)
            @info("Model doesn't have Parameters enabled. Parameters will be enabled")
        end

        PJ.enable_parameters(kwargs[:JuMPmodel])

        return kwargs[:JuMPmodel]

    end

    JuMPmodel = JuMP.Model(optimizer)
    if parameters
        PJ.enable_parameters(JuMPmodel)
    end

    return JuMPmodel

end

function build_op_model!(op_model::PowerOperationModel; optimizer::Union{Nothing,JuMP.OptimizerFactory}=nothing, kwargs...)
        op_model.canonical_model = build_canonical_model(op_model.transmission,
                                                        op_model.devices,
                                                        op_model.branches,
                                                        op_model.services,
                                                        op_model.system,
                                                        optimizer;
                                                        kwargs...)
        return nothing
end
