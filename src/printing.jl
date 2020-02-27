#=
function Base.show(io::IO, op_problem::OperationsProblem)
    println(io, "Operation Model")
end
=#

function _organize_model(
    val::Dict{Symbol, T},
    field::Symbol,
    io::IO,
) where {T <: Union{DeviceModel, ServiceModel}}
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
        if typeof(val) <: Dict{Symbol, <:Union{DeviceModel, ServiceModel}}
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
#=
function Base.show(io::IO, op_problem::SimulationSequence)
    # Here ASCII Art
    println(io, "SimulationSequence()")
end
=#
function Base.show(io::IO, op_problem::Simulation)
    println(io, "Simulation()")
end
#=
function Base.show(io::IO, results::OperationsProblemResults)
    println(io, "Results Model")
 end

=#

function Base.show(io::IO, ::MIME"text/plain", results::IS.Results)
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

function Base.show(io::IO, ::MIME"text/html", results::IS.Results)
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

function Base.show(io::IO, ::MIME"text/html", services::Dict{Symbol, PSI.ServiceModel})
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

function _count_stages(sequence::Array)
    stages = Dict()
    stage = 1
    count = 0
    for i in 1:length(sequence)
        if sequence[i] == stage
            count += 1
            if i == length(sequence)
                stages[stage] = count
            end
        else
            stages[stage] = count
            stage += 1
            count = 1
        end
    end
    return stages
end

function _print_feedforward(io::IO, feed_forward::Dict, to::Array, from::Any)
    for (keys, sync) in feed_forward
        period = sync.periods
        stage1 = keys[1]
        stage2 = keys[2]
        spaces = " "^(length(stage2) + 2)
        dashes = "-"^(length(stage2) + 2)
        if period <= 12
            times = period
            line5 = string("└─$stage2 "^times, "($period) to : $to")
        else
            times = 12
            line5 = string("└─$stage2 "^times, "... (x$period) to : $to")
        end
        if times == 1
            line1 = "$stage1--┐ from : $from"
            println("$line1\n$spaces|\n$spaces$line5\n")
        else
            if times == 2
                line3 = string("┌", string(dashes,"┤"))
                spacing = 0
            elseif times == 3
                line3 = string("┌", string(dashes, "┼"), string(dashes, "┐"))  
                spacing = 0
            elseif iseven(times)
                spacing = (Int(times / 2) - 2)
                line3 = string(
                    "┌",
                    string(dashes, "┬")^spacing,
                    "----",
                    "┼",
                    string(dashes, "┬")^(spacing + 1),
                    "----┐",
                )
            else
                spacing = Int((times / 2) - 1.5)
                line3 = string(
                    "┌",
                    string(dashes, "┬")^spacing,
                    "----",
                    "┼",
                    string(dashes, "┬")^(spacing),
                    "----┐",
                    )
            end
                line1 = string("     "^(spacing), " $stage1--┐ from : $from")
                line2 = string("     "^(spacing), " "^length(stage1), "   |")
                line4 = string("|", string(spaces, "|")^(times - 2), "    |")
                println("$line1\n$line2\n$line3\n$line4\n$line4\n$line5\n")
        end
    end
end
function _print_inter_stages(io::IO, stages::Dict)
    list = sort!(collect(keys(stages)))
    for i in list
        num = stages[i]
        total = length(list)
        if total > 5
            println(io, "Too many stages to print.")
        else
            if length("$num") == 1
                num = " (x0$num)"
            elseif length("$num") == 3
                num = " ($num)"
            elseif length("$num") == 4
                num = "($num)"
            else
                num = " (x$num)"
            end
            if i == 1
                if total == 2
                    println(io, "$i")
                else
                    println(io, "$i\n|")
                end
            else
                N = 2^(i - 2)
                space_count = 10 * (2^(total - i))
                if i == total
                    print1 = "|             ┌----/"^(N - 1)
                    print2 = "|             |     "^(N - 1)
                    print3 = "$i --> $i ...$num   "^N
                    println(io, "$print1|\n$print2|\n$print3")
                else
                    spaces = " "^(space_count - 11)
                    up = Int(space_count / 2)
                    print = string("$i ", " "^(space_count - 4), "  $i ...$num", spaces)^N
                    println(io, "$print")
                    if i !== total - 1
                        indent1 = string(
                            string("|", " "^(up + 7), "┌", "-"^(up - 10), "/")^(2 * N - 1),
                            "|",
                        )
                        indent2 = string("|", " "^(up + 7), "|", " "^(up - 9))^(2 * N - 1)
                        println(io, "$indent1\n$indent2|")
                    end
                end
            end
        end
    end
end

function _print_intra_stages(io::IO, stages::Dict)
    list = sort!(collect(keys(stages)))
    for i in list
        num = stages[i]
        total = length(list)
        if total > 5
            println(io, "Too many stages to print.")
        else
            if length("$num") == 1
                num = " (x0$num)"
            elseif length("$num") == 3
                num = " ($num)"
            elseif length("$num") == 4
                num = "($num)"
            else
                num = " (x$num)"
            end
            if i == 1
                println(io, "$i\n")
            else
                N = 2^(i - 2)
                space_count = 10 * (2^(total - i))
                if i == total
                    print = "$i --> $i ...$num   "^N
                    println(io, "$print\n\n")
                else
                    spaces = " "^(space_count - 11)
                    print = string("$i ", "-"^(space_count - 4), "> $i ...$num", spaces)^N
                    indent = string(" "^(space_count))^(N * 2)
                    println(io, "$print\n$indent")
                end
            end
        end
    end
end

function Base.show(io::IO, sequence::SimulationSequence)
    stages = _count_stages(sequence.execution_order)
    println(io, "Feed Forward Chronology")
    println(io, "-----------------------\n")
    to = []
    from = String("")
    for (k, v) in sequence.feedforward
        println(io, "$(k[1]): $(typeof(v)) -> $(k[3])\n")
        to = String.(v.affected_variables)
        if isa(v, SemiContinuousFF)
            from = String.(v.binary_from_stage)
        elseif isa(v, RangeFF)
            from = String.([v.variable_from_stage_ub, v.variable_from_stage_lb])
        else
            from = String.(v.variable_from_stage)
        end
        _print_feedforward(io, sequence.feedforward_chronologies, to, from)
    end
    println(io, "Initial Condition Chronology")
    println(io, "----------------------------\n")
    if sequence.ini_cond_chronology == IntraStageChronology()
        _print_intra_stages(io, stages)
    elseif sequence.ini_cond_chronology == InterStageChronology()
        _print_inter_stages(io, stages)
    end
end
