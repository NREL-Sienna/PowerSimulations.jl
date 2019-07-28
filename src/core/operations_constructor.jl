function build_op_model!(op_model::OperationModel;
                         optimizer::Union{Nothing, JuMP.OptimizerFactory}=nothing,
                         kwargs...)

    op_model.canonical_model = build_canonical_model(op_model.transmission,
                                                        op_model.devices,
                                                        op_model.branches,
                                                        op_model.services,
                                                        op_model.system,
                                                        optimizer;
                                                        kwargs...)

    return

end
