struct CheckResults <: Results
    variables::Dict{Symbol, DataFrames.DataFrame}
    total_cost::Dict
    optimizer_log::Dict
    time_stamp::DataFrames.DataFrame
    check_sum::Array
end
"""This function creates the correct results struct for the context"""
function _make_results(variables::Dict,
                      total_cost::Dict,
                      optimizer_log::Dict,
                      time_stamp::DataFrames.DataFrame, 
                      check_sum::Array)
    return CheckResults(variables, total_cost, optimizer_log, time_stamp, check_sum)
end
# sums the power generation across all variables into one number to verify that results 
# have not been tampered with in writing and reading back
function _sum_variable_results(results::Results)
    variable_sums = []
    for (k,v) in results.variables
        variable_sums = vcat(variable_sums,sum([sum(v[!,i]) for i in 1 : size(v,2)]))
    end
    return total_sum = [sum(variable_sums)]
end

function _sum_variable_results(variables::Dict)
    variable_sums = []
    for (k,v) in variables
        variable_sums = vcat(variable_sums,sum([sum(v[!,i]) for i in 1 : size(v,2)]))
    end
    return total_sum = [sum(variable_sums)]
end