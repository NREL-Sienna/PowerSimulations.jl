struct StackedArea
    time_range::Array
    data_matrix::Matrix
    labels::Array
end

struct BarPlot
    time_range::Array
    bar_data::Matrix
    labels::Array
end

struct StackedGeneration
    time_range::Array
    data_matrix::Matrix
    labels::Array
end

struct BarGeneration
    time_range::Array
    bar_data::Matrix
    labels::Array
end

"""

get_stacked_plot_data(res::OperationsProblemResults, variable::String)

This function takes in results of struct OperationsProblemResult. It takes the
dataframe from whichever variable name was given and converts it to type StackedArea.
StackedArea is the type of struct that signals the plot() function to use the
StackedArea plot recipe method.

#Example

```julia
ThermalStandard = get_stacked_plot_data(res, "P_ThermalStandard")
plot(ThermalStandard)
```
"""

function get_stacked_plot_data(res::OperationsProblemResults, variable::String; kwargs...)

    sort = get(kwargs, :sort, nothing)
    time_range = res.time_stamp[!,:Range]
    variable = res.variables[Symbol(variable)]
    alphabetical = sort!(names(variable))

    if isnothing(sort)
        variable = variable[:, alphabetical]
    else
        variable = variable[:,sort]
    end

    data_matrix = convert(Matrix, variable)
    labels = collect(names(variable))
    legend = string.(labels)

    return StackedArea(time_range, data_matrix, legend)

end

function get_bar_plot_data(res::OperationsProblemResults, variable::String; kwargs...)

    sort = get(kwargs, :sort, nothing)
    time_range = res.time_stamp[!,:Range]
    variable = res.variables[Symbol(variable)]
    alphabetical = sort!(names(variable))

    if isnothing(sort)
        variable = variable[:, alphabetical]
    else
        variable = variable[:,sort]
    end

    data = convert(Matrix, variable)
    bar_data = sum(data, dims = 1)
    labels = collect(names(variable))
    legend = string.(labels)

    return BarPlot(time_range, bar_data, legend)

end

function get_stacked_generation_data(res::OperationsProblemResults; kwargs...)

    sort = get(kwargs, :sort, nothing)
    time_range = res.time_stamp[!,:Range]
    key_name = collect(keys(res.variables))
    alphabetical = sort!(key_name)

    if !isnothing(sort)
        labels = sort
    else
        labels = alphabetical
    end

    variable = res.variables[Symbol(labels[1])]
    data_matrix = sum(convert(Matrix, variable), dims = 2)
    legend = string.(labels)

    for i in 1:length(labels)
        if i !== 1
            variable = res.variables[Symbol(labels[i])]
            data_matrix = hcat(data_matrix, sum(convert(Matrix, variable), dims = 2))
        end
    end

    return StackedGeneration(time_range, data_matrix, legend)

end

function get_bar_gen_data(res::OperationsProblemResults)

   time_range = res.time_stamp[!,:Range]
   key_name = collect(keys(res.variables))
   variable = res.variables[Symbol(key_name[1])]
   data_matrix = sum(convert(Matrix, variable), dims = 2)
   legend = string.(key_name)

    for i in 1:length(key_name)
       if i !== 1
           variable = res.variables[Symbol(key_name[i])]
           data_matrix = hcat(data_matrix, sum(convert(Matrix, variable), dims = 2))
       end
   end
   bar_data = sum(data_matrix, dims = 1)
   return BarGeneration(time_range, bar_data, legend)

end

"""
    sort_data(results::OperationsProblemResults)

This function takes in struct OperationsProblemResults,
sorts the generators in each variable, and outputs the sorted
results. The generic function sorts the generators alphabetically.

# Arguments
-`results::OperationsProblemResults`: the results of the simulation

# Accepted Key Words
-`Variables` to choose which variables to be sorted.

#Examples
```julia
new_results = sort_data(results)
```
***Note:*** only the generators included in 'my_order' will be in the
results, and consequently, only these will be plotted. This can be a nice
feature for variables with more than 5 generators.

"""
function sort_data(res::OperationsProblemResults; kwargs...)

    Variables = Dict()
    Variables[:P_ThermalStandard]  = get(kwargs, :P_ThermalStandard, nothing)
    Variables[:P_RenewableDispatch]  = get(kwargs, :P_RenewableDispatch, nothing)
    Variables[:START_ThermalStandard] = get(kwargs, :START_ThermalStandard, nothing)
    Variables[:STOP_ThermalStandard] = get(kwargs, :STOP_ThermalStandard, nothing)
    Variables[:ON_ThermalStandard] = get(kwargs, :ON_ThermalStandard, nothing)
    Variable_dict = get(kwargs, :Variables, nothing)
    key_name = collect(keys(res.variables))
    alphabetical = sort!(key_name)

    if !isnothing(Variable_dict)
        labels = Variable_dict
    else
        labels = alphabetical
    end
    variable_dict = Dict()
    for label in labels
        variable_dict[labels[label]] = res.variables[labels[label]]
    end
    for (k,v) in Variables, k in keys(variable_dict)
        variable = variable_dict[k]
        alphabetical = sort!(names(variable))
        order = Variables[k]
        if isnothing(order)
            variable = variable[:, alphabetical]
        else
            variable = variable[:, order]
        end
        variable_dict[k] = variable
    end
    res = OperationsProblemResults(variable_dict, res.total_cost, res.optimizer_log, res.time_stamp)
    return res
end
