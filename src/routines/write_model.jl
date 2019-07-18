function write_op_model(op_model::OperationModel, path::String)
    mopf_model= MOI.copy_to(MOPFM, JuMP.backend(op_model.canonical_model.JuMPmodel))
    MOI.write_to_file(mopf_model, joinpath(path,"$(op_model).json"))
end