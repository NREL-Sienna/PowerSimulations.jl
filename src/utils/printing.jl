#=
function Base.show(io::IO, op_model::OperationModel)
    println(io, "Operation Model")
end
=#

function _organize_device_model(val::Dict{Symbol,DeviceModel}, field::Symbol, io::IO)
   
    println(io, "  $(field): ")
    for (i, ix) in val

        println(io, "      $(i):")
        for inner_field in fieldnames(DeviceModel)

            value = getfield(val[i], Symbol(inner_field)) 

            if !isnothing(value)
                println(io, "        $(inner_field) = $value")
            end
        end
    end

end

"""
    Base.show(io::IO, ::MIME"text/plain", op_model::OperationModel)

This function goes through the fields in OperationModel and then in ModelReference,
if the field contains a Device model dictionary, it calls organize_device_model() & 
prints the data by field, key, value. If the field is not a Device model dictionary,
and a value exists for that field it prints the value.


"""
function Base.show(io::IO, ::MIME"text/plain", op_model::OperationModel)

    println(io, "\nOperation Model")
    println(io, "===============\n")

    for field in fieldnames(ModelReference)
    
        val = getfield(op_model.model_ref, Symbol(field))

        if typeof(val) == Dict{Symbol,DeviceModel}

            _organize_device_model(val, field, io)
            println(io, "\n")

        else
            if !isnothing(val)
                println(io, "  $(field):  $(val)\n")
            else
                println(io, "no data")
            end  
        end       
    end
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

 function Base.show(io::IO, stage::Stage)
    println(io, "Simulation Stage")
 end
