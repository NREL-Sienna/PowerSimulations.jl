function _get_iterator(sys::PSY.System, res::OperationModelResults)

    iterator = []
    for (k,v) in res.variables
        if "$k"[1:2] == "P_"
            datatype = (split("$k", "P_")[2])
            if datatype == "ThermalStandard"
            iterator = vcat(iterator,collect(PSY.get_components(PSY.ThermalStandard,sys)))
            elseif datatype == "RenewableDispatch"
                iterator = vcat(iterator,collect(PSY.get_components(PSY.RenewableDispatch,sys)))  
            end 
        end
    end
    iterator_dict = Dict{Any,Any}()
    for i in 1: length(iterator)
        name = iterator[i].name
        if isdefined(iterator[i].tech, :fuel)  
            iterator_dict[name] = NamedTuple{(:primemover, :fuel)},
                              ((iterator[i].tech.primemover),(iterator[i].tech.fuel))
        else
            iterator_dict[name] = NamedTuple{(:primemover, :fuel)},
                              (iterator[i].tech.primemover, nothing)
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
function make_fuel_dictionary(sys::PSY.System, res::OperationModelResults; kwargs...)

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
            if fuel == fuel_type
                generator_dict["$category"] = vcat(generator_dict["$category"], name)
            end
        end
    end

    return generator_dict
end

function _aggregate_data(res::OperationModelResults, generator_dict::Dict)

   
    All_var = DataFrames.DataFrame()
    var_names = collect(keys(res.variables))

    for i in 1:length(var_names)
        All_var = hcat(All_var, res.variables[var_names[i]])
    end

    fuel_dataframe_dict = Dict()
    
    for (k,v) in generator_dict
        if !isempty(v)
            generator_df = DataFrames.DataFrame()
            for l in 1:length(v)
                generator_df = hcat(generator_df, All_var[:,Symbol("$(v[l])")],
                                    makeunique = true)
            end
            fuel_dataframe_dict[k] = generator_df
        end
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
function get_stacked_aggregation_data(res::OperationModelResults, generator_dict::Dict)

    category_agg_dict = _aggregate_data(res, generator_dict)
    time_range = res.time_stamp[!,:Range]
    n = size(time_range,1)
    time_range = time_range[1:n-1,:]
    labels = collect(keys(category_agg_dict))
    variable = category_agg_dict[(labels[1])]
    data_matrix = sum(Matrix(variable), dims = 2)
    legend = string.(labels)

    for i in 2:length(labels)
        variable = category_agg_dict[(labels[i])]
        data_matrix = hcat(data_matrix, sum(Matrix(variable), dims = 2))
    end
    
    return PowerSimulations.StackedGeneration(time_range, data_matrix, legend)
end