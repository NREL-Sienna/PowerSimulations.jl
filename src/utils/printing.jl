function Base.show(io::IO, container::OptimizationContainer)
    show(io, get_jump_model(container))
end

function Base.show(io::IO, ::MIME"text/plain", input::Union{ServiceModel, DeviceModel})
    _show_method(io, input, :auto)
end

function Base.show(io::IO, ::MIME"text/html", input::Union{ServiceModel, DeviceModel})
    _show_method(io, input, :html; standalone=false, tf=PrettyTables.tf_html_simple)
end

function _show_method(
    io::IO,
    model::Union{ServiceModel, DeviceModel},
    backend::Symbol;
    kwargs...,
)
    println(io)
    header = ["Device Type", "Formulation", "Slacks"]

    table = Matrix{String}(undef, 1, length(header))
    table[1, 1] = string(get_component_type(model))
    table[1, 2] = string(get_formulation(model))
    table[1, 3] = string(model.use_slacks)

    PrettyTables.pretty_table(
        io,
        table;
        header=header,
        backend=backend,
        title="Device Model",
        alignment=:l,
        kwargs...,
    )

    if !isempty(model.attributes)
        println(io)
        header = ["Name", "Value"]

        table = Matrix{String}(undef, length(model.attributes), length(header))
        for (ix, (k, v)) in enumerate(model.attributes)
            table[ix, 1] = string(k)
            table[ix, 2] = string(v)
        end

        PrettyTables.pretty_table(
            io,
            table;
            header=header,
            backend=backend,
            title="Attributes",
            alignment=:l,
            kwargs...,
        )
    end

    if !isempty(model.time_series_names)
        println(io)
        header = ["Parameter Name", "Time Series Name"]

        table = Matrix{String}(undef, length(model.time_series_names), length(header))
        for (ix, (k, v)) in enumerate(model.time_series_names)
            table[ix, 1] = string(k)
            table[ix, 2] = string(v)
        end

        PrettyTables.pretty_table(
            io,
            table;
            header=header,
            backend=backend,
            title="Time Series Names",
            alignment=:l,
            kwargs...,
        )
    end

    if !isempty(model.duals)
        println(io)
        table = string.(model.duals)

        PrettyTables.pretty_table(
            io,
            table;
            header=header,
            backend=backend,
            title="Duals",
            alignment=:l,
            kwargs...,
        )
    end

    if !isempty(model.feedforwards)
        println(io)
        table = string.(model.feedforwards)

        PrettyTables.pretty_table(
            io,
            table;
            header=header,
            backend=backend,
            title="Feedforwards",
            alignment=:l,
            kwargs...,
        )
    else
        println(io)
        print(io, "No FeedForwards Assigned")
    end
end

function Base.show(io::IO, ::MIME"text/plain", input::NetworkModel)
    _show_method(io, input, :auto)
end

function Base.show(io::IO, ::MIME"text/html", input::NetworkModel)
    _show_method(io, input, :html; standalone=false, tf=PrettyTables.tf_html_simple)
end

function _show_method(io::IO, network_model::NetworkModel, backend::Symbol; kwargs...)
    table = [
        "Network Model" string(get_network_formulation(network_model))
        "Slacks" get_use_slacks(network_model)
        "PTDF" !isnothing(get_PTDF(network_model))
        "Duals" join(string.(get_duals(network_model)), " ")
    ]

    PrettyTables.pretty_table(
        io,
        table;
        backend=backend,
        header=["Field", "Value"],
        title="Network Model",
        alignment=:l,
        kwargs...,
    )
    return
end

function Base.show(io::IO, ::MIME"text/plain", input::OperationModel)
    _show_method(io, input, :auto)
end

function Base.show(io::IO, ::MIME"text/html", input::OperationModel)
    _show_method(io, input, :html; standalone=false, tf=PrettyTables.tf_html_simple)
end

function _show_method(io::IO, model::OperationModel, backend::Symbol; kwargs...)
    _show_method(io, model.template, backend; kwargs...)
end

function Base.show(io::IO, ::MIME"text/plain", input::ProblemTemplate)
    _show_method(io, input, :auto)
end

function Base.show(io::IO, ::MIME"text/html", input::ProblemTemplate)
    _show_method(io, input, :html; standalone=false, tf=PrettyTables.tf_html_simple)
end

function _show_method(io::IO, template::ProblemTemplate, backend::Symbol; kwargs...)
    table = [
        "Network Model" string(get_network_formulation(template.network_model))
        "Slacks" get_use_slacks(template.network_model)
        "PTDF" !isnothing(get_PTDF(template.network_model))
        "Duals" join(string.(get_duals(template.network_model)), " ")
    ]

    PrettyTables.pretty_table(
        io,
        table;
        backend=backend,
        noheader=true,
        title="Network Model",
        alignment=:l,
        kwargs...,
    )

    println(io)
    header = ["Device Type", "Formulation", "Slacks"]

    table = Matrix{String}(undef, length(template.devices), length(header))
    for (ix, model) in enumerate(values(template.devices))
        table[ix, 1] = string(get_component_type(model))
        table[ix, 2] = string(get_formulation(model))
        table[ix, 3] = string(model.use_slacks)
    end

    PrettyTables.pretty_table(io, table; header=header, title="Device Models", alignment=:l)

    if !isempty(template.branches)
        println(io)
        header = ["Branch Type", "Formulation", "Slacks"]

        table = Matrix{String}(undef, length(template.branches), length(header))
        for (ix, model) in enumerate(values(template.branches))
            table[ix, 1] = string(get_component_type(model))
            table[ix, 2] = string(get_formulation(model))
            table[ix, 3] = string(model.use_slacks)
        end

        PrettyTables.pretty_table(
            io,
            table;
            header=header,
            backend=backend,
            title="Branch Models",
            alignment=:l,
            kwargs...,
        )
    end

    if !isempty(template.services)
        println(io)
        if isempty(first(keys(template.services))[1])
            header = ["Service Type", "Formulation", "Slacks", "Aggregated Model"]
        else
            header = ["Name", "Service Type", "Formulation", "Slacks", "Aggregated Model"]
        end

        table = Matrix{String}(undef, length(template.services), length(header))
        for (ix, (key, model)) in enumerate(template.services)
            if isempty(key[1])
                table[ix, 1] = string(get_component_type(model))
                table[ix, 2] = string(get_formulation(model))
                table[ix, 3] = string(model.use_slacks)
                table[ix, 4] = string(model.attributes["aggregated_service_model"])
            else
                table[ix, 1] = key[1]
                table[ix, 2] = string(get_component_type(model))
                table[ix, 3] = string(get_formulation(model))
                table[ix, 4] = string(model.use_slacks)
                table[ix, 5] = string(model.attributes["aggregated_service_model"])
            end
        end

        PrettyTables.pretty_table(
            io,
            table;
            header=header,
            backend=backend,
            title="Service Models",
            alignment=:l,
            kwargs...,
        )
    end
    return
end

function Base.show(io::IO, ::MIME"text/plain", input::SimulationModels)
    _show_method(io, input, :auto)
end

function Base.show(io::IO, ::MIME"text/html", input::SimulationModels)
    _show_method(io, input, :html; standalone=false, tf=PrettyTables.tf_html_simple)
end

_get_model_type(::DecisionModel{T}) where {T <: DecisionProblem} = T
_get_model_type(::EmulationModel{T}) where {T <: DecisionProblem} = T

function _show_method(io::IO, sim_models::SimulationModels, backend::Symbol; kwargs...)
    println(io)
    header = ["Model Name", "Model Type", "Status", "Output Directory"]

    table = Matrix{Any}(undef, length(sim_models.decision_models), length(header))
    for (ix, model) in enumerate(sim_models.decision_models)
        table[ix, 1] = string(get_name(model))
        table[ix, 2] = string(_get_model_type(model))
        table[ix, 3] = string(get_status(model))
        table[ix, 4] = get_output_dir(model)
    end

    PrettyTables.pretty_table(
        io,
        table;
        header=header,
        backend=backend,
        title="Decision Models",
        alignment=:l,
        kwargs...,
    )

    if !isnothing(sim_models.emulation_model)
        println(io)
        table = Matrix{Any}(undef, 1, length(header))
        table[1, 1] = string(get_name(sim_models.emulation_model))
        table[1, 2] = string(_get_model_type(sim_models.emulation_model))
        table[1, 3] = string(get_status(sim_models.emulation_model))
        table[1, 4] = get_output_dir(sim_models.emulation_model)

        PrettyTables.pretty_table(
            io,
            table;
            header=header,
            backend=backend,
            title="Emulator Models",
            alignment=:l,
            kwargs...,
        )
    else
        println(io)
        println(io, "No Emulator Model Specified")
    end
end

function Base.show(io::IO, ::MIME"text/plain", input::SimulationSequence)
    _show_method(io, input, :auto)
end

function Base.show(io::IO, ::MIME"text/html", input::SimulationSequence)
    _show_method(io, input, :html; standalone=false, tf=PrettyTables.tf_html_simple)
end

function _show_method(io::IO, sequence::SimulationSequence, backend::Symbol; kwargs...)
    println(io)
    table = [
        "Simulation Step Interval" Dates.Hour(get_step_resolution(sequence))
        "Number of Problems" length(sequence.executions_by_model)
    ]

    PrettyTables.pretty_table(
        io,
        table;
        backend=backend,
        noheader=true,
        title="Simulation Sequence",
        alignment=:l,
        kwargs...,
    )

    println(io)
    header = ["Model Name", "Horizon", "Interval", "Executions Per Step"]

    table = Matrix{Any}(undef, length(sequence.executions_by_model), length(header))
    for (ix, (model, executions)) in enumerate(sequence.executions_by_model)
        table[ix, 1] = string(model)
        table[ix, 2] = sequence.horizons[model]
        table[ix, 3] = Dates.Minute(sequence.intervals[model])
        table[ix, 4] = executions
    end

    PrettyTables.pretty_table(
        io,
        table;
        header=header,
        backend=backend,
        title="Simulation Problems",
        alignment=:l,
    )

    if !isempty(sequence.feedforwards)
        println(io)
        header = ["Model Name", "Feed Forward Type"]
        table = Matrix{Any}(undef, length(sequence.feedforwards), length(header))
        for (ix, (k, ff)) in enumerate(sequence.feedforwards)
            table[ix, 1] = k
            table[ix, 2] = join(string.(typeof.(ff)), " ")
        end
        PrettyTables.pretty_table(
            io,
            table;
            header=header,
            backend=backend,
            title="Feedforwards",
            alignment=:l,
            kwargs...,
        )
    end
end

function Base.show(io::IO, sim::Simulation)
    println(io, "Simulation()")
end

function Base.show(io::IO, ::MIME"text/plain", results::SimulationResults)
    println(io, "Decision Problem Results:")
    for res in values(results.decision_problem_results)
        show(io, MIME"text/plain"(), res)
    end
    println(io, "\nEmulation Problem Results:")
    show(io, MIME"text/plain"(), results.emulation_problem_results)
end

function Base.show(io::IO, ::MIME"text/plain", results::SimulationProblemResults)
    title = results.problem * " Results"
    println(io, "\n$title")
    bars = join(("=" for _ in 1:length(title)))
    println(io, "$bars\n")
    timestamps = get_timestamps(results)
    println(io, "Start: $(timestamps.start)")
    println(io, "End: $(timestamps.stop)")
    println(io, "Resolution: $(timestamps.step)")
    println(io, "\n")
    println(io, "Variables")
    println(io, "=========\n")
    for v in list_variable_names(results)
        println(io, "$(v)")
    end
    println(io, "\n")
    parameters = list_parameter_names(results)
    duals = list_dual_names(results)
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

PSIResults = Union{ProblemResults, SimulationProblemResults, SimulationResults}

function Base.show(io::IO, ::MIME"text/html", results::PSIResults)
    println(io, "<h1>Results</h1>")
    timestamps = get_timestamps(results)
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
    for (k, v) in results.optimizer_stats
        if v !== nothing
            println(io, "<p>        $(k) = $(v)</p>")
        end
    end
    println(io, "\n")
    for (k, v) in results.total_cost
        println(io, "<p><b>Total Cost: $(v)<b/></p>")
    end
end

function Base.show(io::IO, stage::DecisionModel)
    println(io, "DecisionModel()")
end

function Base.show(io::IO, ::MIME"text/plain", results::ProblemResults)
    println(io, "ProblemResults:")
    println(io, "  Base power: $(results.base_power)")
    vars = join(keys(results.variable_values), " ")
    println(io, "  Variables: $vars")
    duals = join(keys(results.dual_values), " ")
    println(io, "  Duals: $duals")
    params = join(keys(results.parameter_values), " ")
    println(io, "  Parameters: $params")
end

function Base.show(io::IO, ::MIME"text/plain", bounds::ConstraintBounds)
    println(io, "ConstraintBounds:")
    println(io, "Constraint Coefficient")
    show(io, MIME"text/plain"(), bounds.coefficient)
    println(io, "Constraint RHS")
    show(io, MIME"text/plain"(), bounds.rhs)
end

function Base.show(io::IO, ::MIME"text/plain", bounds::VariableBounds)
    println(io, "VariableBounds:")
    show(io, MIME"text/plain"(), bounds.bounds)
end

function Base.show(io::IO, ::MIME"text/plain", bounds::NumericalBounds)
    spacing = 1
    println(io, rpad("  Minimum", 20), "Maximum")
    println(io, rpad("  $(bounds.min)", 20), "$(bounds.max)")
end
