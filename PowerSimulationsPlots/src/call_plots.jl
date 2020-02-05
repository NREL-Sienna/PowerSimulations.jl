# Color Definitions
# to define or change the RGB based on a 288 scale, divide by 288 for each rgb and set A = 1
import Plots
NUCLEAR = Colors.RGBA(0.615, 0.108, 0.125, 1)
COAL = Colors.RGBA(0.118, 0.118, 0.118, 1)
HYDRO = Colors.RGBA(0.083, 0.441, 0.514, 1)
GAS_CC = Colors.RGBA(0.285, 0.462, 0.372, 1)
GAS_CT = Colors.RGBA(0.493, 0.406, 0.563, 1)
STORAGE = Colors.RGBA(0.128, 0.528, 0.556, 1)
OIL_ST = Colors.RGBA(0.462, 0.212, 0.351, 1) # petroleum
OIL_CT = Colors.RGBA(0.462, 0.212, 0.351, 1) # petroleum
SYNC_COND = Colors.RGBA(0.462, 0.212, 0.351, 1) # petroleum
WIND = Colors.RGBA(0.000, 0.632, 0.830, 1)
SOLAR = Colors.RGBA(0.885, 0.594, 0.007, 1)
CSP = Colors.RGBA(0.875, 0.410, 0.094, 1)
CURTAILMENT = Colors.RGBA(0.847, 0.219, 0.295, 1)

# Out of a 288 rgba scale
NUCLEAR_288 = "rgba(177, 31, 36, 1)"
COAL_288 = "rgba(34, 34, 34, 1)"
HYDRO_288 = "rgba(24, 127, 148, 1)"
GAS_CC_288 = "rgba(82, 133, 107, 1)"
GAS_CT_288 = "rgba(142, 117, 162, 1)"
STORAGE_288 = "rgba(37, 152, 160, 1)"
OIL_ST_288 = "rgba(133, 61, 101, 1)" # petroleum
OIL_CT_288 = "rgba(133, 61, 101, 1)" # petroleum
SYNC_COND_288 = "rgba(133, 61, 101, 1)" # petroleum
WIND_288 = "rgba(0, 182, 239, 1)"
SOLAR_288 = "rgba(255, 171, 2, 1)"
CSP_288 = "rgba(252, 118, 27, 1)"
CURTAILMENT_288 = "rgba(244, 63, 85, 1)"

GR_DEFAULT = hcat(
    NUCLEAR,
    COAL,
    HYDRO,
    GAS_CC,
    GAS_CT,
    STORAGE,
    OIL_ST,
    OIL_CT,
    SYNC_COND,
    WIND,
    SOLAR,
    CSP,
    CURTAILMENT,
)

FUEL_DEFAULT = vcat(
    NUCLEAR,
    COAL,
    HYDRO,
    GAS_CC,
    GAS_CT,
    STORAGE,
    OIL_ST,
    OIL_CT,
    SYNC_COND,
    WIND,
    SOLAR,
    CSP,
    CURTAILMENT,
)

PLOTLY_DEFAULT = vcat(
    NUCLEAR_288,
    COAL_288,
    HYDRO_288,
    GAS_CC_288,
    GAS_CT_288,
    STORAGE_288,
    OIL_ST_288,
    OIL_CT_288,
    SYNC_COND_288,
    WIND_288,
    SOLAR_288,
    CSP_288,
    CURTAILMENT_288,
)

function match_fuel_colors(
    stack::StackedGeneration,
    bar::BarGeneration,
    backend::Any,
    default::Array,
)
    if backend == Plots.PlotlyJSBackend()
        color_range = PLOTLY_DEFAULT
    else
        color_range = FUEL_DEFAULT
    end
    fuels = [
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
    ]
    color_fuel = DataFrames.DataFrame(fuels = fuels, colors = color_range)
    default =
        [(color_fuel[findall(in(["$(bar.labels[1])"]), color_fuel.fuels), :][:, :colors])[1]]
    for i in 2:length(bar.labels)
        specific_color =
            (color_fuel[findall(in(["$(bar.labels[i])"]), color_fuel.fuels), :][
                :,
                :colors,
            ])[1]
        default = hcat(default, specific_color)
    end
    return default
end
"""
    fuel_plot(results, system)

This function makes a stack plot of the results by fuel type
and assigns each fuel type a specific color.

# Arguments

- `res::Results = results`: results to be plotted
- `system::PSY.System`: The power systems system

# Example

```julia
res = solve_op_problem!(OpProblem)
fuel_plot(res, sys)
```

# Accepted Key Words
- `display::Bool`: set to false to prevent the plots from displaying
- `save::String = "file_path"`: set a file path to save the plots
- `seriescolor::Array`: Set different colors for the plots
"""
function fuel_plot(res::PSI.Results, sys::PSY.System; kwargs...)
    ref = make_fuel_dictionary(sys, res)
    fuel_plot(res, ref; kwargs...)
end

"""
    fuel_plot(results::PSI.Results, generators)

This function makes a stack plot of the results by fuel type
and assigns each fuel type a specific color.

# Arguments

- `res::PSI.Results = results`: results to be plotted
- `generators::Dict`: the dictionary of fuel type and an array
 of the generators per fuel type, or some other specified category order

# Example

```julia
res = solve_op_problem!(OpProblem)
generator_dict = make_fuel_dictionary(sys, res)
fuel_plot(res, generator_dict)
```

# Accepted Key Words
- `display::Bool`: set to false to prevent the plots from displaying
- `save::String = "file_path"`: set a file path to save the plots
- `seriescolor::Array`: Set different colors for the plots
"""

function fuel_plot(res::PSI.Results, generator_dict::Dict; kwargs...)
    set_display = get(kwargs, :display, true)
    save_fig = get(kwargs, :save, nothing)
    stack = get_stacked_aggregation_data(res, generator_dict)
    bar = get_bar_aggregation_data(res, generator_dict)
    backend = Plots.backend()
    default_colors = match_fuel_colors(stack, bar, backend, FUEL_DEFAULT)
    seriescolor = get(kwargs, :seriescolor, default_colors)
    if isnothing(backend)
        throw(IS.ConflictingInputsError("No backend detected. Type gr() to set a backend."))
    end
    _fuel_plot_internal(stack, bar, seriescolor, backend, save_fig, set_display; kwargs...)
end

function _fuel_plot_internal(
    stack::StackedGeneration,
    bar::BarGeneration,
    seriescolor::Array,
    backend::Plots.PlotlyJSBackend,
    save_fig::Any,
    set_display::Bool;
    kwargs...,
)
    plotly_stack_gen(stack, seriescolor; kwargs...)
    plotly_bar_gen(bar, seriescolor; kwargs...)
end

function _fuel_plot_internal(
    stack::StackedGeneration,
    bar::BarGeneration,
    seriescolor::Array,
    backend::Any,
    save_fig::Any,
    set_display::Bool;
    kwargs...,
)
    p1 = RecipesBase.plot(stack; seriescolor = seriescolor)
    p2 = RecipesBase.plot(bar; seriescolor = seriescolor)
    set_display && display(p1)
    set_display && display(p2)
    if !isnothing(save_fig)
        Plots.savefig(p1, joinpath(save_fig, "Fuel_Stack.png"))
        Plots.savefig(p2, joinpath(save_fig, "Fuel_Bar.png"))
    end
end

"""
   bar_plot(results::PSI.Results)
  
This function plots a bar plot for the generators in each variable within
the results variables dictionary, and makes a bar plot for all of the variables.

# Arguments
- `res::PSI.Results = results`: results to be plotted

# Example

```julia
results = solve_op_problem!(OpProblem)
bar_plot(results)
```

# Accepted Key Words
- `display::Bool`: set to false to prevent the plots from displaying
- `save::String = "file_path"`: set a file path to save the plots
- `seriescolor::Array`: Set different colors for the plots
"""

function bar_plot(res::PSI.Results; kwargs...)
    backend = Plots.backend()
    set_display = get(kwargs, :display, true)
    save_fig = get(kwargs, :save, nothing)
    bar_gen = get_bar_gen_data(res)
    if isnothing(backend)
        throw(IS.ConflictingInputsError("No backend detected. Type gr() to set a backend."))
    end
    _bar_plot_internal(res, bar_gen, backend, save_fig, set_display; kwargs...)
end

function bar_plot(res::PSI.Results, variables::Array; kwargs...)
    res_var = Dict()
    for variable in variables
        res_var[variable] = res.variables[variable]
    end
    results =
        PSI.OperationsProblemResults(res_var, res.total_cost, res.optimizer_log, res.time_stamp)
    bar_plot(results; kwargs...)
end

function _bar_plot_internal(
    res::PSI.Results,
    bar_gen::BarGeneration,
    backend::Plots.PlotlyJSBackend,
    save_fig::Any,
    set_display::Bool;
    kwargs...,
)
    seriescolor = get(kwargs, :seriescolor, PLOTLY_DEFAULT)
    plotly_bar_plots(res, seriescolor; kwargs...)
    plotly_bar_gen(bar_gen, seriescolor; kwargs...)
end

function _bar_plot_internal(
    res::PSI.Results,
    bar_gen::BarGeneration,
    backend::Any,
    save_fig::Any,
    set_display::Bool;
    kwargs...,
)
    seriescolor = get(kwargs, :seriescolor, GR_DEFAULT)
    for name in string.(keys(res.variables))
        variable_bar = get_bar_plot_data(res, name)
        p = RecipesBase.plot(variable_bar, name; seriescolor = seriescolor)
        set_display && display(p)
        if !isnothing(save_fig)
            Plots.savefig(p, joinpath(save_fig, "$(name)_Bar.png"))
        end
    end
    p2 = RecipesBase.plot(bar_gen; seriescolor = seriescolor)
    set_display && display(p2)
    if !isnothing(save_fig)
        Plots.savefig(p2, joinpath(save_fig, "Bar_Generation.png"))
    end
end

"""
     stack_plot(results::PSI.Results)

This function plots a stack plot for the generators in each variable within
the results variables dictionary, and makes a stack plot for all of the variables.

# Arguments
- `res::PSI.Results = results`: results to be plotted

# Examples

```julia
results = solve_op_problem!(OpProblem)
stack_plot(results)
```

# Accepted Key Words
plot attributes, such as seriescolor = [:red :blue :orange]
will override the default series color
"""

function stack_plot(res::PSI.Results; kwargs...)
    set_display = get(kwargs, :set_display, true)
    backend = Plots.backend()
    save_fig = get(kwargs, :save, nothing)
    stacked_gen = get_stacked_generation_data(res)
    if isnothing(backend)
        throw(IS.ConflictingInputsError("No backend detected. Type gr() to set a backend."))
    end
    _stack_plot_internal(res, stacked_gen, backend, save_fig, set_display; kwargs...)
end

function stack_plot(res::PSI.Results, variables::Array; kwargs...)
    res_var = Dict()
    for variable in variables
        res_var[variable] = res.variables[variable]
    end
    results =
        PSI.OperationsProblemResults(res_var, res.total_cost, res.optimizer_log, res.time_stamp)
    stack_plot(results; kwargs...)
end

function _stack_plot_internal(
    res::PSI.Results,
    stack::StackedGeneration,
    backend::Plots.PlotlyJSBackend,
    save_fig::Any,
    set_display::Bool;
    kwargs...,
)
    seriescolor = get(kwargs, :seriescolor, PLOTLY_DEFAULT)
    plotly_stack_plots(res, seriescolor; kwargs...)
    plotly_stack_gen(stack, seriescolor; kwargs...)
end

function _stack_plot_internal(
    res::PSI.Results,
    stack::StackedGeneration,
    backend::Any,
    save_fig::Any,
    set_display::Bool;
    kwargs...,
)
    seriescolor = get(kwargs, :seriescolor, GR_DEFAULT)
    for name in string.(keys(res.variables))
        variable_stack = get_stacked_plot_data(res, name)
        p = RecipesBase.plot(variable_stack, name; seriescolor = seriescolor)
        set_display && display(p)
        if !isnothing(save_fig)
            Plots.savefig(p, joinpath(save_fig, "$(name)_Stack.png"))
        end
    end
    p2 = RecipesBase.plot(stack; seriescolor = seriescolor)
    set_display && display(p2)
    if !isnothing(save_fig)
        Plots.savefig(p2, joinpath(save_fig, "Stack_Generation.png"))
    end
end
