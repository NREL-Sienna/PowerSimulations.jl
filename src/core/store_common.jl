# Aliases used for clarity in the method dispatches so it is possible to know if writing to
# DecisionModel data or EmulationModel data
const DecisionModelIndexType = Dates.DateTime
const EmulationModelIndexType = Int

function write_results!(
    store,
    model::OperationModel,
    index::Union{DecisionModelIndexType, EmulationModelIndexType},
    update_timestamp::Dates.DateTime;
    exports = nothing,
)
    if exports !== nothing
        export_params = Dict{Symbol, Any}(
            :exports => exports,
            :exports_path => joinpath(exports.path, string(get_name(model))),
            :file_type => get_export_file_type(exports),
            :resolution => get_resolution(model),
            :horizon_count => get_horizon(get_settings(model)) ÷ get_resolution(model),
        )
    else
        export_params = nothing
    end

    write_model_dual_results!(store, model, index, update_timestamp, export_params)
    write_model_parameter_results!(store, model, index, update_timestamp, export_params)
    write_model_variable_results!(store, model, index, update_timestamp, export_params)
    write_model_aux_variable_results!(store, model, index, update_timestamp, export_params)
    write_model_expression_results!(store, model, index, update_timestamp, export_params)
    return
end

function write_model_dual_results!(
    store,
    model::T,
    index::Union{DecisionModelIndexType, EmulationModelIndexType},
    update_timestamp::Dates.DateTime,
    export_params::Union{Dict{Symbol, Any}, Nothing},
) where {T <: OperationModel}
    container = get_optimization_container(model)
    model_name = get_name(model)
    if export_params !== nothing
        exports_path = joinpath(export_params[:exports_path], "duals")
        mkpath(exports_path)
    end

    for (key, constraint) in get_duals(container)
        !should_write_resulting_value(key) && continue
        data = jump_value.(constraint)
        write_result!(store, model_name, key, index, update_timestamp, data)

        if export_params !== nothing &&
           should_export_dual(export_params[:exports], index, model_name, key)
            horizon_count = export_params[:horizon_count]
            resolution = export_params[:resolution]
            file_type = export_params[:file_type]
            df = to_dataframe(jump_value.(constraint), key)
            time_col = range(index; length = horizon_count, step = resolution)
            DataFrames.insertcols!(df, 1, :DateTime => time_col)
            IS.Optimization.export_result(file_type, exports_path, key, index, df)
        end
    end
    return
end

function write_model_parameter_results!(
    store,
    model::T,
    index::Union{DecisionModelIndexType, EmulationModelIndexType},
    update_timestamp::Dates.DateTime,
    export_params::Union{Dict{Symbol, Any}, Nothing},
) where {T <: OperationModel}
    container = get_optimization_container(model)
    model_name = get_name(model)
    if export_params !== nothing
        exports_path = joinpath(export_params[:exports_path], "parameters")
        mkpath(exports_path)
    end


    horizon = get_horizon(get_settings(model))
    resolution = get_resolution(get_settings(model))
    horizon_count = horizon ÷ resolution

    parameters = get_parameters(container)
    for (key, container) in parameters
        !should_write_resulting_value(key) && continue
        data = calculate_parameter_values(container)
        write_result!(store, model_name, key, index, update_timestamp, data)

        if export_params !== nothing &&
           should_export_parameter(export_params[:exports], index, model_name, key)
            resolution = export_params[:resolution]
            file_type = export_params[:file_type]
            df = to_dataframe(data, key)
            time_col = range(index; length = horizon_count, step = resolution)
            DataFrames.insertcols!(df, 1, :DateTime => time_col)
            IS.Optimization.export_result(file_type, exports_path, key, index, df)
        end
    end
    return
end

function write_model_variable_results!(
    store,
    model::T,
    index::Union{DecisionModelIndexType, EmulationModelIndexType},
    update_timestamp::Dates.DateTime,
    export_params::Union{Dict{Symbol, Any}, Nothing},
) where {T <: OperationModel}
    container = get_optimization_container(model)
    model_name = get_name(model)
    if export_params !== nothing
        exports_path = joinpath(export_params[:exports_path], "variables")
        mkpath(exports_path)
    end

    if !isempty(container.primal_values_cache)
        variables = container.primal_values_cache.variables_cache
    else
        variables = get_variables(container)
    end

    for (key, variable) in variables
        !should_write_resulting_value(key) && continue
        data = jump_value.(variable)
        write_result!(store, model_name, key, index, update_timestamp, data)

        if export_params !== nothing &&
           should_export_variable(export_params[:exports], index, model_name, key)
            horizon_count = export_params[:horizon_count]
            resolution = export_params[:resolution]
            file_type = export_params[:file_type]
            df = to_dataframe(data, key)
            time_col = range(index; length = horizon_count, step = resolution)
            DataFrames.insertcols!(df, 1, :DateTime => time_col)
            IS.Optimization.export_result(file_type, exports_path, key, index, df)
        end
    end
    return
end

function write_model_aux_variable_results!(
    store,
    model::T,
    index::Union{DecisionModelIndexType, EmulationModelIndexType},
    update_timestamp::Dates.DateTime,
    export_params::Union{Dict{Symbol, Any}, Nothing},
) where {T <: OperationModel}
    container = get_optimization_container(model)
    model_name = get_name(model)
    if export_params !== nothing
        exports_path = joinpath(export_params[:exports_path], "aux_variables")
        mkpath(exports_path)
    end

    for (key, variable) in get_aux_variables(container)
        !should_write_resulting_value(key) && continue
        data = jump_value.(variable)
        write_result!(store, model_name, key, index, update_timestamp, data)

        if export_params !== nothing &&
           should_export_aux_variable(export_params[:exports], index, model_name, key)
            horizon_count = export_params[:horizon_count]
            resolution = export_params[:resolution]
            file_type = export_params[:file_type]
            df = to_dataframe(data, key)
            time_col = range(index; length = horizon_count, step = resolution)
            DataFrames.insertcols!(df, 1, :DateTime => time_col)
            IS.Optimization.export_result(file_type, exports_path, key, index, df)
        end
    end
    return
end

function write_model_expression_results!(
    store,
    model::T,
    index::Union{DecisionModelIndexType, EmulationModelIndexType},
    update_timestamp::Dates.DateTime,
    export_params::Union{Dict{Symbol, Any}, Nothing},
) where {T <: OperationModel}
    container = get_optimization_container(model)
    model_name = get_name(model)
    if export_params !== nothing
        exports_path = joinpath(export_params[:exports_path], "expressions")
        mkpath(exports_path)
    end

    if !isempty(container.primal_values_cache)
        expressions = container.primal_values_cache.expressions_cache
    else
        expressions = get_expressions(container)
    end

    for (key, expression) in expressions
        !should_write_resulting_value(key) && continue
        data = jump_value.(expression)
        write_result!(store, model_name, key, index, update_timestamp, data)

        if export_params !== nothing &&
           should_export_expression(export_params[:exports], index, model_name, key)
            horizon_count = export_params[:horizon_count]
            resolution = export_params[:resolution]
            file_type = export_params[:file_type]
            df = to_dataframe(data, key)
            time_col = range(index; length = horizon_count, step = resolution)
            DataFrames.insertcols!(df, 1, :DateTime => time_col)
            IS.Optimization.export_result(file_type, exports_path, key, index, df)
        end
    end
    return
end
