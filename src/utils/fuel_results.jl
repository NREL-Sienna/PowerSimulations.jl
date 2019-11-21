function _get_iterator(sys::PSY.System, res::OperationsProblemResults)

    iterators = []
    for (k,v) in res.variables
        if "$k"[1:2] == "P_"
            datatype = (split("$k", "P_")[2])
            if datatype == "ThermalStandard"
            iterators = vcat(iterators,collect(PSY.get_components(PSY.ThermalStandard,sys)))
            elseif datatype == "RenewableDispatch"
                iterators = vcat(iterators,collect(PSY.get_components(PSY.RenewableDispatch,sys)))  
            end 
        end
    end
    iterator_dict = Dict{Any,Any}()
    for iterator in iterators
        name = iterator.name
        iterator_dict[name] = []
        if isdefined(iterator[i].tech, :fuel)  
            iterator_dict[name] = vcat(iterator_dict[name], (NamedTuple{(:primemover, :fuel)},
                              ((iterator[i].tech.primemover),(iterator[i].tech.fuel))))
        else
            iterator_dict[name] = vcat(iterator_dict[name], (NamedTuple{(:primemover, :fuel)},
                              (iterator[i].tech.primemover, nothing)))
        end
    end
    return iterator_dict
end

"""

    generator_dict = make_fuel_dictionary(c_sys5_re, results)

This function makes a dictionary of fuel type and the generators associated.
# Example
results = solve_op_model!(OpModel)
generator_dict = make_fuel_dictionary(c_sys5_re, results)

kwargs: :category_dict = dictionary{String, NamedTuple} if a different 
type of stacking is desired.

"""
function make_fuel_dictionary(sys::PSY.System, res::OperationsProblemResults; kwargs...)

    category_dict = Dict()
    category_dict["Solar"] = NamedTuple{(:primemover, :fuel)},(PSY.PVe, nothing)
    category_dict["Wind"] = NamedTuple{(:primemover, :fuel)},(PSY.WT, nothing)
    category_dict["Oil_CT"] = NamedTuple{(:primemover, :fuel)},(PSY.CT, PSY.DISTILLATE_FUEL_OIL)
    category_dict["Oil_ST"] = NamedTuple{(:primemover, :fuel)},(PSY.ST, PSY.DISTILLATE_FUEL_OIL)
    category_dict["Storage"] = NamedTuple{(:primemover, :fuel)},(PSY.BA, nothing)
    category_dict["Gas_CT"] = NamedTuple{(:primemover, :fuel)},(PSY.CT, PSY.NATURAL_GAS)
    category_dict["Gas_CC"] = NamedTuple{(:primemover, :fuel)},(PSY.CC, PSY.NATURAL_GAS)
    category_dict["Hydro"] = NamedTuple{(:primemover, :fuel)},(PSY.HY, nothing)
    category_dict["Coal"] = NamedTuple{(:primemover, :fuel)},(PSY.ST, PSY.COAL)
    category_dict["Nuclear"] = NamedTuple{(:primemover, :fuel)},(PSY.ST, PSY.NUCLEAR)

    category_dict = get(kwargs, :category_dict, category_dict)
    iterator_dict = _get_iterator(sys, res)
    generator_dict = Dict()
    
    for (category, fuel_type) in category_dict
        generator_dict["$category"] = []
        
        for (name, fuel) in iterator_dict
            for i in 1:length(fuel)
                if fuel[i] == fuel_type    
                    generator_dict["$category"] = vcat(generator_dict["$category"], name)
                end
            end
        end
        if isempty(generator_dict["$category"] )
            delete!(generator_dict, "$category")
        end
    end
    return generator_dict
end
function make_fuel_dictionary(system::PSY.System, res::PSI.CheckResults; kwargs...)
    results = OperationsProblemResults(res.variables, res.total_cost, 
    res.optimizer_log, res.time_stamp)
    make_fuel_dictionary(system, results; kwargs...)
end
function make_fuel_dictionary(system::PSY.System, res::PSI.AggregatedResults; kwargs...)
    results = OperationsProblemResults(res.variables, res.total_cost, 
    res.optimizer_log, res.time_stamp)
    make_fuel_dictionary(system, results; kwargs...)
end

function _aggregate_data(res::PSI.OperationsProblemResults, generator_dict::Dict)

   
    All_var = DataFrames.DataFrame()
    var_names = collect(keys(res.variables))

    for i in 1:length(var_names)
        All_var = hcat(All_var, res.variables[var_names[i]], makeunique = true)
    end

    fuel_dataframe_dict = Dict()
    
    for (k,v) in generator_dict
            generator_df = DataFrames.DataFrame()
            for l in 1:length(v)
                generator_df = hcat(generator_df, All_var[:,Symbol("$(v[l])")],
                                    makeunique = true)
            end
            fuel_dataframe_dict[k] = generator_df
        end
  
    return fuel_dataframe_dict
end

"""
    stack = stacked_aggregation_data(res, generator_dict)

This function aggregates the data into a struct type StackedGeneration
so that the results can be plotted using the StackedGeneration recipe.

# Example
generator_dict = make_fuel_dictionary(res, c_sys5_re)
stack = stacked_aggregation_data(res, generator_dict)
plot(stack)

OR 
generator_dict = make_fuel_dictionary(res, c_sys5_re)
fuel_plot(res, generator_dict)

"""
function get_stacked_aggregation_data(res::OperationsProblemResults, generator_dict::Dict)
    
    order = (["Nuclear", "Coal", "Hydro", "Gas_CC",
    "Gas_CT", "Storage", "Oil_ST", "Oil_CT",
    "Sync_Cond", "Wind", "Solar", "CSP", "curtailment"])

    category_agg_dict = _aggregate_data(res, generator_dict)
    time_range = res.time_stamp[!,:Range]
    labels = collect(keys(category_agg_dict))
    new_labels = []
    
        for fuel in 1:length(order)
            for n in 1:length(labels)
            if labels[n] == order[fuel]
                new_labels = vcat(new_labels, labels[n])
            end
        end
    end

    variable = category_agg_dict[(new_labels[1])]
    data_matrix = sum(Matrix(variable), dims = 2)
    
    legend = string.(new_labels)

    for i in 2:length(new_labels)
        variable = category_agg_dict[(new_labels[i])]
        data_matrix = hcat(data_matrix, sum(Matrix(variable), dims = 2))
    end
    
    return PowerSimulations.StackedGeneration(time_range, data_matrix, legend)
end
function get_bar_aggregation_data(res::PSI.OperationsProblemResults, generator_dict::Dict)

    order = (["Nuclear", "Coal", "Hydro", "Gas_CC",
    "Gas_CT", "Storage", "Oil_ST", "Oil_CT",
    "Sync_Cond", "Wind", "Solar", "CSP", "curtailment"])

    category_agg_dict = _aggregate_data(res, generator_dict)
    time_range = res.time_stamp[!,:Range]
    labels = collect(keys(category_agg_dict))
    new_labels = []
    
        for fuel in 1:length(order)
            for n in 1:length(labels)
            if labels[n] == order[fuel]
                new_labels = vcat(new_labels, labels[n])
            end
        end
    end

    variable = category_agg_dict[(new_labels[1])]
    data_matrix = sum(Matrix(variable), dims = 2)
    legend = string.(new_labels)

    for i in 2:length(new_labels)
        variable = category_agg_dict[(new_labels[i])]
        data_matrix = hcat(data_matrix, sum(Matrix(variable), dims = 2))
    end
    bar_data = sum(data_matrix, dims = 1)
    
    return PowerSimulations.BarGeneration(time_range, bar_data, legend)
end