order = ([
    "Nuclear",
    "Coal",
    "Hydro",
    "Gas_CC",
    "Gas_CT",
    "Storage",
    "Oil_ST",
    "Oil_CT",
    "Sync_Cond",
    "Wind",
    "Solar",
    "CSP",
    "curtailment",
])
function _get_iterator(sys::PSY.System, res::PSI.Results)
    iterators = []
    for (k, v) in res.variables
        if "$k"[1:2] == "P_"
            datatype = (split("$k", "P_")[2])
            if datatype == "ThermalStandard"
                iterators =
                    vcat(iterators, collect(PSY.get_components(PSY.ThermalStandard, sys)))
            elseif datatype == "RenewableDispatch"
                iterators =
                    vcat(iterators, collect(PSY.get_components(PSY.RenewableDispatch, sys)))
            end
        end
    end
    iterators_sorted = Dict{Any,Any}()
    for iterator in iterators
        name = iterator.name
        iterators_sorted[name] = []
        if isdefined(iterator.tech, :fuel)
            iterators_sorted[name] = vcat(
                iterators_sorted[name],
                (
                    NamedTuple{(:primemover, :fuel)},
                    ((iterator.tech.primemover), (iterator.tech.fuel)),
                ),
            )
        else
            iterators_sorted[name] = vcat(
                iterators_sorted[name],
                (NamedTuple{(:primemover, :fuel)}, (iterator.tech.primemover, nothing)),
            )
        end
    end
    return iterators_sorted
end

"""
    generators = make_fuel_dictionary(system::PSY.System, results::PSI.Results)

This function makes a dictionary of fuel type and the generators associated.

# Arguments
- `c_sys5_re::PSY.System`: the system that is used to create the results
- `results::PSI.Results`: simulation or operations results

# Key Words
- `categories::Dict{String, NamedTuple}`: if stacking by a different category is desired

# Example
results = solve_op_model!(OpModel)
generators = make_fuel_dictionary(c_sys5_re, results)

"""
function make_fuel_dictionary(sys::PSY.System, res::PSI.Results; kwargs...)

    categories = Dict()
    categories["Solar"] = NamedTuple{(:primemover, :fuel)}, (PSY.PVe, nothing)
    categories["Wind"] = NamedTuple{(:primemover, :fuel)}, (PSY.WT, nothing)
    categories["Oil_CT"] =
        NamedTuple{(:primemover, :fuel)}, (PSY.CT, PSY.DISTILLATE_FUEL_OIL)
    categories["Oil_ST"] =
        NamedTuple{(:primemover, :fuel)}, (PSY.ST, PSY.DISTILLATE_FUEL_OIL)
    categories["Storage"] = NamedTuple{(:primemover, :fuel)}, (PSY.BA, nothing)
    categories["Gas_CT"] = NamedTuple{(:primemover, :fuel)}, (PSY.CT, PSY.NATURAL_GAS)
    categories["Gas_CC"] = NamedTuple{(:primemover, :fuel)}, (PSY.CC, PSY.NATURAL_GAS)
    categories["Hydro"] = NamedTuple{(:primemover, :fuel)}, (PSY.HY, nothing)
    categories["Coal"] = NamedTuple{(:primemover, :fuel)}, (PSY.ST, PSY.COAL)
    categories["Nuclear"] = NamedTuple{(:primemover, :fuel)}, (PSY.ST, PSY.NUCLEAR)
    categories = get(kwargs, :categories, categories)
    iterators = _get_iterator(sys, res)
    generators = Dict()

    for (category, fuel_type) in categories
        generators["$category"] = []
        for (name, fuels) in iterators
            for fuel in fuels
                if fuel == fuel_type
                    generators["$category"] = vcat(generators["$category"], name)
                end
            end
        end
        if isempty(generators["$category"])
            delete!(generators, "$category")
        end
    end
    return generators
end

function _aggregate_data(res::PSI.Results, generators::Dict)
    All_var = DataFrames.DataFrame()
    var_names = collect(keys(res.variables))
    for i in 1:length(var_names)
        All_var = hcat(All_var, res.variables[var_names[i]], makeunique = true)
    end
    fuel_dataframes = Dict()

    for (k, v) in generators
        generator_df = DataFrames.DataFrame()
        for l in v
            generator_df = hcat(generator_df, All_var[:, Symbol("$(l)")], makeunique = true)
        end
        fuel_dataframes[k] = generator_df
    end

    return fuel_dataframes
end

"""
    stack = get_stacked_aggregation_data(res, generators::Dict)

This function aggregates the data into a struct type StackedGeneration
so that the results can be plotted using the StackedGeneration recipe.

# Example
```julia
using Plots
gr()
generators = make_fuel_dictionary(res, system)
stack = get_stacked_aggregation_data(res, generators)
plot(stack)
```
*OR*
```julia
using Plots
gr()
fuel_plot(res, system)
```
"""
function get_stacked_aggregation_data(res::PSI.Results, generators::Dict)
    # order at the top
    category_aggs = _aggregate_data(res, generators)
    time_range = res.time_stamp[!, :Range]
    labels = collect(keys(category_aggs))
    new_labels = []

    for fuel in order
        for label in labels
            if label == fuel
                new_labels = vcat(new_labels, label)
            end
        end
    end
    variable = category_aggs[(new_labels[1])]
    data_matrix = sum(Matrix(variable), dims = 2)
    legend = [string.(new_labels)[1]]
    for i in 2:length(new_labels)
        variable = category_aggs[(new_labels[i])]
        legend = hcat(legend, string.(new_labels)[i])
        data_matrix = hcat(data_matrix, sum(Matrix(variable), dims = 2))
    end
    return StackedGeneration(time_range, data_matrix, legend)
end
"""
    bar = get_bar_aggregation_data(results::PSI.Results, generators::Dict)

This function aggregates the data into a struct type StackedGeneration
so that the results can be plotted using the StackedGeneration recipe.

# Example
```julia
using Plots
gr()
generators = make_fuel_dictionary(res, system)
bar = get_bar_aggregation_data(res, generators)
plot(bar)
```
*OR*
```julia
using Plots
gr()
fuel_plot(res, system)
```
"""
function get_bar_aggregation_data(res::PSI.Results, generators::Dict)
    category_aggs = _aggregate_data(res, generators)
    time_range = res.time_stamp[!, :Range]
    labels = collect(keys(category_aggs))
    new_labels = []
    for fuel in order
        for label in labels
            if label == fuel
                new_labels = vcat(new_labels, label)
            end
        end
    end
    variable = category_aggs[(new_labels[1])]
    data_matrix = sum(Matrix(variable), dims = 2)
    legend = [string.(new_labels)[1]]
    for i in 2:length(new_labels)
        variable = category_aggs[(new_labels[i])]
        data_matrix = hcat(data_matrix, sum(Matrix(variable), dims = 2))
        legend = hcat(legend, string.(new_labels)[i])
    end
    bar_data = sum(data_matrix, dims = 1)
    return BarGeneration(time_range, bar_data, legend)
end
