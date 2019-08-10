function Base.show(io::IO, op_model::OperationModel)
    println(io, "Operation Model")
end

function Base.show(io::IO, op_model::CanonicalModel)
    println(io, "Canonical Model")
end

function Base.show(io::IO, op_model::Simulation)
    println(io, "Simulation Model")
end

 function Base.show(io::IO, res_model::OperationModelResults)
    println(io, "Results Model")
 end
