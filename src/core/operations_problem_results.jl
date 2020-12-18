struct OperationsProblemResults <: PSIResults
    base_power::Float64
    variable_values::Dict{Symbol, DataFrames.DataFrame}
    total_cost::Dict
    optimizer_log::Dict
    time_stamp::DataFrames.DataFrame
    dual_values::Dict{Symbol, DataFrames.DataFrame}
    parameter_values::Dict{Symbol, DataFrames.DataFrame}
end

get_existing_variables(result::OperationsProblemResults) = keys(get_variables(result))
get_model_base_power(result::OperationsProblemResults) = result.base_power
IS.get_variables(result::OperationsProblemResults) = result.variable_values
IS.get_total_cost(result::OperationsProblemResults) = result.total_cost
IS.get_optimizer_log(results::OperationsProblemResults) = results.optimizer_log
IS.get_timestamp(result::OperationsProblemResults) = result.time_stamp
get_duals(result::OperationsProblemResults) = result.dual_values
IS.get_parameters(result::OperationsProblemResults) = result.parameter_values

function get_variable_value(res_model::OperationsProblemResults, key::Symbol)
    var_result = get(res_model.variable_values, key, nothing)
    if isnothing(var_result)
        throw(IS.ConflictingInputsError("No variable with key $(key) has been found."))
    end
    return var_result
end

function _find_duals(variables::Array)
    duals = []
    for i in 1:length(variables)
        if occursin("dual", String.(variables[i]))
            duals = vcat(duals, variables[i])
        end
    end
    return duals
end

function _find_params(variables::Array)
    params = []
    for i in 1:length(variables)
        if occursin("parameter", String.(variables[i]))
            params = vcat(params, variables[i])
        end
    end
    return params
end

function write_to_CSV(results::OperationsProblemResults, save_path::String; kwargs...)
    if !isdir(save_path)
        throw(IS.ConflictingInputsError("Specified path is not valid. Run write_results to save results."))
    end
    folder_path = mkdir(joinpath(
        save_path,
        replace_chars("$(round(Dates.now(), Dates.Minute))", ":", "-"),
    ))
    export_variables = Dict()
    for (k, v) in IS.get_variables(results)
        start = decode_symbol(k)[1]
        if start !== "ON" || start !== "START" || start != "STOP"
            export_variables[k] = get_model_base_power(results) .* v
        else
            export_variables[k] = v
        end
    end
    write_data(export_variables, folder_path; file_type = CSV, kwargs...)
    if !isempty(get_duals(results))
        write_data(
            get_duals(results),
            folder_path;
            duals = true,
            file_type = CSV,
            kwargs...,
        )
    end
    export_parameters = Dict()
    if !isempty(IS.get_parameters(results))
        for (p, v) in IS.get_parameters(results)
            export_parameters[p] = get_model_base_power(results) .* v
        end
        write_data(
            export_parameters,
            folder_path;
            params = true,
            file_type = CSV,
            kwargs...,
        )
    end
    write_optimizer_log(results.optimizer_log, folder_path)
    write_data(
        IS.get_timestamp(results),
        folder_path,
        "time_stamp";
        file_type = CSV,
        kwargs...,
    )
    files = readdir(folder_path)
    compute_file_hash(folder_path, files)
    @info("Files written to $folder_path folder.")
    return
end
