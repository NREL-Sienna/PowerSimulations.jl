# TODO: More refactoring to resemble Simulation Results and match interfaces
struct OperationsProblemResults <: PSIResults
    base_power::Float64
    variable_values::Dict{Symbol, DataFrames.DataFrame}
    total_cost::Dict
    optimizer_log::Dict
    time_stamp::DataFrames.DataFrame
    dual_values::Dict{Symbol, DataFrames.DataFrame}
    parameter_values::Dict{Symbol, DataFrames.DataFrame}
end

get_existing_variables(res::OperationsProblemResults) = keys(get_variables(res))
get_existing_parameters(res::OperationsProblemResults) = keys(IS.get_parameters(res))
get_existing_duals(res::OperationsProblemResults) = keys(get_duals(res))
get_model_base_power(res::OperationsProblemResults) = res.base_power
IS.get_variables(res::OperationsProblemResults) = res.variable_values
IS.get_total_cost(res::OperationsProblemResults) = res.total_cost
IS.get_optimizer_log(res::OperationsProblemResults) = res.optimizer_log
IS.get_timestamp(res::OperationsProblemResults) = res.time_stamp
get_duals(res::OperationsProblemResults) = res.dual_values
IS.get_parameters(res::OperationsProblemResults) = res.parameter_values

# TODO:
# - Handle PER-UNIT conversion of variables according to type
# - Enconde Variable/Parameter/Dual from other inputs to avoid passing Symbol

function get_variable_value(res::OperationsProblemResults, key::Symbol)
    var_result = get(res.variable_values, key, nothing)
    if var_result === nothing
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

function write_to_CSV(res::OperationsProblemResults, save_path::String)
    if !isdir(save_path)
        throw(IS.ConflictingInputsError("Specified path is not valid."))
    end
    folder_path = mkdir(joinpath(
        save_path,
        replace_chars("$(round(Dates.now(), Dates.Minute))", ":", "-"),
    ))
    export_variables = Dict()
    for (k, v) in IS.get_variables(res)
        export_variables[k] = v
    end
    write_data(export_variables, folder_path)
    if !isempty(get_duals(res))
        write_data(get_duals(res), folder_path; duals = true)
    end
    export_parameters = Dict()
    if !isempty(IS.get_parameters(res))
        for (p, v) in IS.get_parameters(res)
            export_parameters[p] = get_model_base_power(res) .* v
        end
        write_data(export_parameters, folder_path; params = true)
    end
    write_optimizer_log(res.optimizer_log, folder_path)
    write_data(IS.get_timestamp(res), folder_path, "time_stamp")
    files = readdir(folder_path)
    compute_file_hash(folder_path, files)
    @info("Files written to $folder_path folder.")
    return
end
