function _display_model(
    val::Dict{String, T},
    field::Symbol,
    io::IO,
) where {T <: ServiceModel}
    field = titlecase(string(field))
    println(io, "$(field) Models:\n")
    if isempty(val)
        println("\t No Models Specified\n")
        return
    end
    for (i, ix) in val
        println(io, "\tLabel: $(i)\n \tType: $(ix.component_type)\n \tFormulation: $(ix.formulation)\n")
        if ix.use_service_name
            println(io, "\tName specific Model\n")
        end
    end
end

function _display_model(
    val::Dict{String, T},
    field::Symbol,
    io::IO,
) where {T <: DeviceModel}
    field = titlecase(string(field))
    println(io, "$(field) Models: \n")
    if isempty(val)
        println("\t No Models Specified\n")
        return
    end
    for (i, ix) in val
        println(io, "\tLabel: $(i)\n \tType: $(ix.component_type)\n \tFormulation: $(ix.formulation)\n")
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
    println(io, "============================================")

    for field in fieldnames(OperationsProblemTemplate)
        val = getfield(template, Symbol(field))
        if typeof(val) <: Dict{String, <:Union{DeviceModel, ServiceModel}}
            println(io, "============================================")
            _display_model(val, field, io)
        else
            if !(val === nothing)
                field = titlecase(string(field))
                println(io, "$(field):\n\t$(val) \n")
            else
                println(io, "no data")
            end
        end
    end
    println(io, "============================================")
end

function Base.show(io::IO, optimization_container::OptimizationContainer)
    println(io, "OptimizationContainer()")
end

function Base.show(io::IO, sim::Simulation)
    println(io, "Simulation()")
end

function Base.show(io::IO, ::MIME"text/plain", results::SimulationResults)
    for res in values(results.stage_results)
        show(io, MIME"text/plain"(), res)
    end
end

function Base.show(io::IO, ::MIME"text/plain", results::StageResults)
    title = results.stage * " Results"
    println(io, "\n$title")
    bars = join(("=" for _ in 1:length(title)))
    println(io, "$bars\n")
    timestamps = get_existing_timestamps(results)
    println(io, "Start: $(timestamps.start)")
    println(io, "End: $(timestamps.stop)")
    println(io, "Resolution: $(timestamps.step)")
    println(io, "\n")
    println(io, "Variables")
    println(io, "=========\n")
    for v in get_existing_variables(results)
        println(io, "$(v)")
    end
    println(io, "\n")
    parameters = get_existing_parameters(results)
    duals = get_existing_duals(results)
    for val in [("Parameters", parameters), ("Duals", duals)]
        if !isempty(val[2])
            println(io, "$(val[1])")
            println(io, "==========\n")
            for v in val[2]
                println(io, "$(v)")
            end
            println(io, "\n")
        end
    end
end
function Base.show(io::IO, ::MIME"text/html", results::PSIResults)
    println(io, "<h1>Results</h1>")
    timestamps = get_existing_timestamps(results)
    println(io, "<p> Start: $(timestamps.start)</p>")
    println(io, "<p> End: $(timestamps.stop)</p>")
    println(io, "<p> Resolution: $(timestamps.step)</p>")
    println(io, "<h2>Variables</h2>")
    times = IS.get_timestamp(results)
    variables = IS.get_variables(results)
    if (length(keys(variables)) > 5)
        for (k, v) in variables
            println(io, "<p>$k: $(size(v))</p>")
        end
    else
        for (k, v) in IS.get_variables(results)
            if size(times, 1) == size(v, 1)
                var = hcat(times, v)
            else
                var = v
            end
            (l, w) = size(var)
            if w < 6
                println(io, "<b>$(k)</b>")
                println(io, "<p>$("-" ^ length("$k"))</p>")
                show(io, MIME"text/html"(), var)
            else
                println(io, "<p>$(k)  size ($l, $w)</p>")
            end
        end
    end
    parameters = IS.get_parameters(results)
    if !isempty(parameters)
        println(io, "<h2>Parameters</h2>")
        for (k, v) in parameters
            if size(times, 1) == size(v, 1)
                var = hcat(times, v)
            else
                var = v
            end
            (l, w) = size(var)
            if w < 6
                println(io, "<b>$(k)</b>")
                println(io, "<p>$("-" ^ length("$k"))</p>")
                show(io, MIME"text/html"(), var)
            else
                println(io, "<p>$(k)  size ($l, $w)</p>")
            end
        end
    end
    println(io, "<p><b>Optimizer Log</b></p>")
    for (k, v) in results.optimizer_log
        if !(v === nothing)
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

function _count_stages(sequence::Array)
    stages = Dict{Int, Int}()
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
            println(io, "$line1\n$spaces|\n$spaces$line5\n")
        else
            if times == 2
                line3 = string("┌", string(dashes, "┤"))
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
            println(io, "$line1\n$line2\n$line3\n$line4\n$line4\n$line5\n")
        end
    end
end
function _print_inter_stages(io::IO, stages::Dict{Int, Int})
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

function _print_intra_stages(io::IO, stages::Dict{Int, Int})
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
            from = String.(v.binary_source_stage)
        elseif isa(v, RangeFF)
            from = String.([v.variable_source_stage_ub, v.variable_source_stage_lb])
        else
            from = String.(v.variable_source_stage)
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
