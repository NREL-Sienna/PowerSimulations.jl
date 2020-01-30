#=
function Base.show(io::IO, op_problem::OperationsProblem)
    println(io, "Operation Model")
end
=#

function _organize_model(
    val::Dict{Symbol,T},
    field::Symbol,
    io::IO,
) where {T<:Union{DeviceModel,ServiceModel}}
    println(io, "  $(field): ")
    for (i, ix) in val
        println(io, "      $(i):")
        for inner_field in fieldnames(T)
            inner_field == :services && continue
            value = getfield(val[i], Symbol(inner_field))

            if !isnothing(value)
                println(io, "        $(inner_field) = $value")
            end
        end
    end

end

"""
    Base.show(io::IO, ::MIME"text/plain", op_problem::OperationsProblem)

This function goes through the fields in OperationsProblem and then in OperationsProblemTemplate,
if the field contains a Device model dictionary, it calls organize_device_model() &
prints the data by field, key, value. If the field is not a Device model dictionary,
and a value exists for that field it prints the value.


"""
function Base.show(io::IO, m::MIME"text/plain", op_problem::OperationsProblem)
    show(io, m, op_problem.template)
end

function Base.show(io::IO, ::MIME"text/plain", template::OperationsProblemTemplate)
    println(io, "\nOperations Problem Specification")
    println(io, "============================================\n")

    for field in fieldnames(OperationsProblemTemplate)
        val = getfield(template, Symbol(field))
        if typeof(val) <: Dict{Symbol,<:Union{DeviceModel,ServiceModel}}
            println(io, "============================================")
            _organize_model(val, field, io)
        else
            if !isnothing(val)
                println(io, "  $(field):  $(val)")
            else
                println(io, "no data")
            end
        end
    end
    println(io, "============================================")
end

function Base.show(io::IO, op_problem::PSIContainer)
    println(io, "PSIContainer()")
end

function Base.show(io::IO, op_problem::SimulationSequence)
    # Here ASCII Art
    println(io, "SimulationSequence()")
end

function Base.show(io::IO, op_problem::Simulation)
    println(io, "Simulation()")
end
#=
function Base.show(io::IO, results::OperationsProblemResults)
    println(io, "Results Model")
 end

=#

function Base.show(io::IO, ::MIME"text/plain", results::Results)
    println(io, "\nResults")
    println(io, "===============\n")

    for (k, v) in results.variables
        time = DataFrames.DataFrame(Time = results.time_stamp[!, :Range])
        if size(time, 1) == size(v, 1)
            var = hcat(time, v)
        else
            var = v
        end
        println(io, "$(k)")
        println(io, "==================")
        println(io, "$(var)\n")
    end
    println(io, "Optimizer Log")
    println(io, "-------------")
    for (k, v) in results.optimizer_log
        if !isnothing(v)
            println(io, "        $(k) = $(v)")
        end
    end
    println(io, "\n")
    for (k, v) in results.total_cost
        println(io, "Total Cost: $(k) = $(v)")
    end
end

function Base.show(io::IO, ::MIME"text/html", results::PSI.Results)
    println(io, "<h1>Results</h1>")
    for (k, v) in results.variables
        time = DataFrames.DataFrame(Time = results.time_stamp[!, :Range])
        if size(time, 1) == size(v, 1)
            var = hcat(time, v)
        else
            var = v
        end
        println(io, "<b>$(k)</b>")
        show(io, MIME"text/html"(), var)
    end
    println(io, "<p><b>Optimizer Log</b></p>")
    for (k, v) in results.optimizer_log
        if !isnothing(v)
            println(io, "<p>        $(k) = $(v)</p>")
        end
    end
    println(io, "\n")
    for (k, v) in results.total_cost
        println(io, "<p><b>Total Cost: $(v)<b/></p>")
    end
end

function Base.show(io::IO, stage::Stage)
    println(io, "Stage()")
end

function Base.show(io::IO, ::MIME"text/html", services::Dict{Symbol,PSI.ServiceModel})
    println(io, "<h1>Services</h1>")
    for (k, v) in services
        println(io, "<p><b>$(k)</b></p>")
        println(io, "<p>$(v)</p>")
    end
end

function Base.show(io::IO, ::MIME"text/html", sim_results::SimulationResultsReference)
    println(io, "<h1>Simulation Results Reference</h1>")
    println(io, "<p><b>Results Folder:</b> $(sim_results.results_folder)</p>")
    println(io, "<h2>Reference Tables</h2>")
    for (k, v) in sim_results.ref
        println(io, "<p><b>$(k)</b></p>")
        for (i, x) in v
            println(io, "<p>$(i): dataframe size $(size(x))</p>")
        end
    end
    for (k, v) in sim_results.chronologies
        println(io, "<p><b>$(k)</b></p>")
        println(io, "<p>time length: $(v)</p>")
    end
end

function Base.show(io::IO, ::MIME"text/plain", sim_results::SimulationResultsReference)
    println(io, "Simulation Results Reference\n")
    println(io, "Results Folder: $(sim_results.results_folder)\n")
    println(io, "Reference Tables\n")
    for (k, v) in sim_results.ref
        println(io, "$(k)\n")
        for (i, x) in v
            println(io, "$(i): dataframe size $(size(x))\n")
        end
    end
    for (k, v) in sim_results.chronologies
        println(io, "$(k)\n")
        println(io, "time length: $(v)\n")
    end
end
