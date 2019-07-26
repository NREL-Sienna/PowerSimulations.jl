function write_op_model(op_model::OperationModel, path::String)
    MOF_model = MOPFM
    MOI.copy_to(MOF_model, JuMP.backend(op_model.canonical_model.JuMPmodel))
    MOI.write_to_file(MOF_model, path)
end
