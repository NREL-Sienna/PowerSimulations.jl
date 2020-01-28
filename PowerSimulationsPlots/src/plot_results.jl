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
    variable = get_stacked_plot_data(res::PSI.Results, variable::String)

This function takes in results and uses a dataframe from whichever variable name was given and converts it to type StackedArea.
StackedArea is the type of struct that signals the plot() function to use the StackedArea plot recipe method.

# Arguments
- `res::PSI.Results`: simulation or operations results
- `variable::String`: the variable to be plotted

#Example
```julia
ThermalStandard = get_stacked_plot_data(res, "P_ThermalStandard")
plot(ThermalStandard)
```

# Accepted Key Words
- `sort::Array`: the array of generators to be plotted, in the order to be plotted
"""

function get_stacked_plot_data(res::PSI.Results, variable::String; kwargs...)

    sort = get(kwargs, :sort, nothing)
    time_range = res.time_stamp[!, :Range]
    variable = res.variables[Symbol(variable)]
    alphabetical = sort!(names(variable))

    if isnothing(sort)
        variable = variable[:, alphabetical]
    else
        variable = variable[:, sort]
    end

    data_matrix = convert(Matrix, variable)
    labels = collect(names(variable))
    legend = [names(variable)[1]]
    for name = 2:length(labels)
        legend = hcat(legend, string.(labels[name]))
    end

    return StackedArea(time_range, data_matrix, legend)

end

"""
    variable = get_bar_plot_data(res::PSI.Results, variable::String)

This function takes in results and uses a dataframe from whichever variable name was given and converts it to type BarPlot.
StackedGeneration is the type of struct that signals the plot() function to use the StackedGeneration plot recipe method.

# Arguments
- `res::PSI.Results`: simulation or operations results
- `variable::String`: the variable to be plotted

#Example
```julia
ThermalStandard = get_bar_plot_data(res, "P_ThermalStandard")
plot(ThermalStandard)
```

# Accepted Key Words
- `sort::Array`: the array of generators to be plotted, in the order to be plotted
"""

function get_bar_plot_data(res::PSI.Results, variable::String; kwargs...)

    sort = get(kwargs, :sort, nothing)
    time_range = res.time_stamp[!, :Range]
    variable = res.variables[Symbol(variable)]
    alphabetical = sort!(names(variable))

    if isnothing(sort)
        variable = variable[:, alphabetical]
    else
        variable = variable[:, sort]
    end

    data = convert(Matrix, variable)
    bar_data = sum(data, dims = 1)
    labels = collect(names(variable))
    legend = [names(variable)[1]]
    for name = 2:length(labels)
        legend = hcat(legend, string.(labels[name]))
    end

    return BarPlot(time_range, bar_data, legend)
end

"""
    variable = get_stacked_gen_data(res::PSI.Results)

This function takes in results and stacks the variables given.
StackedGeneration is the type of struct that signals the plot() function to use the StackedGeneration plot recipe method.

# Arguments
- `res::PSI.Results`: simulation or operations results

#Example
```julia
stack = get_stacked_gen_data(res)
plot(stack)
```

# Accepted Key Words
- `sort::Array`: the array of generators to be plotted, in the order to be plotted
"""

function get_stacked_generation_data(res::PSI.Results; kwargs...)

    sort = get(kwargs, :sort, nothing)
    time_range = res.time_stamp[!, :Range]
    key_name = collect(keys(res.variables))
    alphabetical = sort!(key_name)

    if !isnothing(sort)
        labels = sort
    else
        labels = alphabetical
    end

    variable = res.variables[Symbol(labels[1])]
    data_matrix = sum(convert(Matrix, variable), dims = 2)
    legend = [key_name[1]]

    for i = 1:length(labels)
        if i !== 1
            variable = res.variables[Symbol(labels[i])]
            legend = hcat(legend, string.(key_name[i]))
            data_matrix = hcat(data_matrix, sum(convert(Matrix, variable), dims = 2))
        end
    end

    return StackedGeneration(time_range, data_matrix, legend)

end

"""
    variable = get_bar_gen_data(res::PSI.Results)

This function takes in results and stacks the variables given.
StackedGeneration is the type of struct that signals the plot() function to use the StackedGeneration plot recipe method.

# Arguments
- `res::PSI.Results`: simulation or operations results

#Example
```julia
stack = get_stacked_gen_data(res)
plot(stack)
```

# Accepted Key Words
- `sort::Array`: the array of generators to be plotted, in the order to be plotted
"""

function get_bar_gen_data(res::PSI.Results)

    time_range = res.time_stamp[!, :Range]
    key_name = collect(keys(res.variables))
    variable = res.variables[Symbol(key_name[1])]
    data_matrix = sum(convert(Matrix, variable), dims = 2)
    legend = [key_name[1]]
    for i = 1:length(key_name)
        if i !== 1
            variable = res.variables[Symbol(key_name[i])]
            legend = hcat(legend, string.(key_name[i]))
            data_matrix = hcat(data_matrix, sum(convert(Matrix, variable), dims = 2))
        end
    end
    bar_data = sum(data_matrix, dims = 1)
    return BarGeneration(time_range, bar_data, legend)

end

"""
    sort_data(results::PSI.Results)

This function takes in struct Results, sorts the generators in each variable, and outputs the sorted
results. The generic function sorts the generators alphabetically.

# Arguments
- `results::Results`: the results of the simulation

# Key Words
- `Variables::Dict{Symbol, Array{Symbol}`: the desired variables and their generator order

#Examples
```julia
Variables = Dict(:ON_ThermalStandard => [:Brighton, :Solitude])
sorted_results = sort_data(res_UC; Variables = Variables)
```
***Note:*** only the generators included in key word 'Variables' will be in the
results, and consequently, only these will be plotted. 
"""
function sort_data(res::PSI.Results; kwargs...)
    order = get(kwargs, :Variables, Dict())
    if !isempty(order)
        labels = collect(keys(order))
    else
        labels = sort!(collect(keys(res.variables)))
    end
    sorted_variables = Dict()
    for label in labels
        sorted_variables[label] = res.variables[label]
    end
    for (k, variable) in sorted_variables
        if !isempty(order)
            variable = variable[:, order[k]]
        else
            alphabetical = sort!(names(variable))
            variable = variable[:, alphabetical]
        end
        sorted_variables[k] = variable
    end
    return PSI.OperationsProblemResults(
        sorted_variables,
        res.total_cost,
        res.optimizer_log,
        res.time_stamp,
    )
end
