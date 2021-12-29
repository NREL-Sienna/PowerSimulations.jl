# Keep these in sync with the Symbols in src/core/definitions.
get_store_container_type(::AuxVarKey) = STORE_CONTAINER_AUX_VARIABLES
get_store_container_type(::ConstraintKey) = STORE_CONTAINER_DUALS
get_store_container_type(::ExpressionKey) = STORE_CONTAINER_EXPRESSIONS
get_store_container_type(::ParameterKey) = STORE_CONTAINER_PARAMETERS
get_store_container_type(::VariableKey) = STORE_CONTAINER_VARIABLES

function write_model_dual_results!(
    store::SimulationStore,
    model::DecisionModel,
    timestamp::Dates.DateTime,
    exports,
)
    container = get_optimization_container(model)
    model_name = get_name(model)
    if exports !== nothing
        exports_path = joinpath(exports[:exports_path], "duals")
        mkpath(exports_path)
    end

    for (key, constraint) in get_duals(container)
        write_result!(store, model_name, key, timestamp, constraint)

        if exports !== nothing &&
           should_export_dual(exports[:exports], timestamp, model_name, key)
            horizon = exports[:horizon]
            resolution = exports[:resolution]
            file_type = exports[:file_type]
            df = axis_array_to_dataframe(constraint, key)
            time_col = range(timestamp, length = horizon, step = resolution)
            DataFrames.insertcols!(df, 1, :DateTime => time_col)
            export_result(file_type, exports_path, key, timestamp, df)
        end
    end
end

function write_model_parameter_results!(
    store::SimulationStore,
    model::DecisionModel,
    timestamp::Dates.DateTime,
    exports,
)
    container = get_optimization_container(model)
    model_name = get_name(model)
    if exports !== nothing
        exports_path = joinpath(exports[:exports_path], "parameters")
        mkpath(exports_path)
    end

    horizon = get_horizon(get_settings(model))

    parameters = get_parameters(container)
    for (key, container) in parameters
        param_array = get_parameter_array(container)
        multiplier_array = get_multiplier_array(container)
        @assert_op length(axes(param_array)) == 2
        num_columns = size(param_array)[1]
        data = jump_value.(param_array) .* multiplier_array
        write_result!(store, model_name, key, timestamp, data)

        if exports !== nothing &&
           should_export_parameter(exports[:exports], timestamp, model_name, key)
            resolution = exports[:resolution]
            file_type = exports[:file_type]
            df = axis_array_to_dataframe(data, key)
            time_col = range(timestamp, length = horizon, step = resolution)
            DataFrames.insertcols!(df, 1, :DateTime => time_col)
            export_result(file_type, exports_path, key, timestamp, df)
        end
    end
end

function write_model_variable_results!(
    store::SimulationStore,
    model::DecisionModel,
    timestamp::Dates.DateTime,
    exports,
)
    container = get_optimization_container(model)
    model_name = get_name(model)
    if exports !== nothing
        exports_path = joinpath(exports[:exports_path], "variables")
        mkpath(exports_path)
    end

    if !isempty(container.primal_values_cache)
        variables = container.primal_values_cache.variables_cache
    else
        variables = get_variables(container)
    end

    for (key, variable) in variables
        write_result!(store, model_name, key, timestamp, variable)

        if exports !== nothing &&
           should_export_variable(exports[:exports], timestamp, model_name, key)
            horizon = exports[:horizon]
            resolution = exports[:resolution]
            file_type = exports[:file_type]
            df = axis_array_to_dataframe(variable, key)
            time_col = range(timestamp, length = horizon, step = resolution)
            DataFrames.insertcols!(df, 1, :DateTime => time_col)
            export_result(file_type, exports_path, key, timestamp, df)
        end
    end
end

function write_model_aux_variable_results!(
    store::SimulationStore,
    model::DecisionModel,
    timestamp::Dates.DateTime,
    exports,
)
    container = get_optimization_container(model)
    model_name = get_name(model)
    if exports !== nothing
        exports_path = joinpath(exports[:exports_path], "aux_variables")
        mkpath(exports_path)
    end

    for (key, variable) in get_aux_variables(container)
        write_result!(store, model_name, key, timestamp, variable)

        if exports !== nothing &&
           should_export_aux_variable(exports[:exports], timestamp, model_name, key)
            horizon = exports[:horizon]
            resolution = exports[:resolution]
            file_type = exports[:file_type]
            df = axis_array_to_dataframe(variable, key)
            time_col = range(timestamp, length = horizon, step = resolution)
            DataFrames.insertcols!(df, 1, :DateTime => time_col)
            export_result(file_type, exports_path, key, timestamp, df)
        end
    end
end

function write_model_expression_results!(
    store::SimulationStore,
    model::DecisionModel,
    timestamp::Dates.DateTime,
    exports,
)
    container = get_optimization_container(model)
    model_name = get_name(model)
    if exports !== nothing
        exports_path = joinpath(exports[:exports_path], "expressions")
        mkpath(exports_path)
    end

    if !isempty(container.primal_values_cache)
        expressions = container.primal_values_cache.expressions_cache
    else
        expressions = get_expressions(container)
    end

    for (key, expression) in expressions
        write_result!(store, model_name, key, timestamp, expression)

        if exports !== nothing &&
           should_export_expression(exports[:exports], timestamp, model_name, key)
            horizon = exports[:horizon]
            resolution = exports[:resolution]
            file_type = exports[:file_type]
            df = axis_array_to_dataframe(expression, key)
            time_col = range(timestamp, length = horizon, step = resolution)
            DataFrames.insertcols!(df, 1, :DateTime => time_col)
            export_result(file_type, exports_path, key, timestamp, df)
        end
    end
end

function write_optimizer_stats!(store::SimulationStore, model::DecisionModel)
    stats = get_optimizer_stats(model)
    write_optimizer_stats!(store, get_name(model), stats, get_current_time(model))
    return
end

function write_optimizer_stats!(store::SimulationStore, model::EmulationModel)
    stats = get_optimizer_stats(model)
    write_optimizer_stats!(store, stats, get_execution_count(model))
    return
end
