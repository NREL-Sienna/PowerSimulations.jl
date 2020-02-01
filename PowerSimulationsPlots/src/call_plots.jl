# Color Definitions
import Plots
MAROON = Colors.RGBA(0.7, 0.1, 0.1, 0.95)
DARKGRAY = Colors.RGBA(0, 0, 0, 0.8)
OLIVEGREEN = Colors.RGBA(0.33, 0.42, 0.18, 0.9)
DARKORANGE = Colors.RGBA(0.93, 0.46, 0, 1)
ORCHID = Colors.RGBA(0.56, 0.28, 0.54, 1)
DARKPINK = Colors.RGBA(0.9, 0.5, 0.6, 0.80)
LIGHTYELLOW = Colors.RGBA(1, 1, 0.5, 0.6)
STEELBLUE = Colors.RGBA(0.27, 0.5, 0.7, 0.9)
CANARYYELLOW = Colors.RGBA(1, 0.757, 0.15, 01)
KHAKI = Colors.RGBA(0.8, 0.6, 0.3, 1)

GR_DEFAULT = hcat(
    MAROON,
    DARKGRAY,
    :lightblue,
    OLIVEGREEN,
    :pink,
    DARKORANGE,
    ORCHID,
    DARKPINK,
    LIGHTYELLOW,
    STEELBLUE,
    CANARYYELLOW,
    KHAKI,
    :red,
)

FUEL_DEFAULT = vcat(
    MAROON,
    DARKGRAY,
    :lightblue,
    OLIVEGREEN,
    :pink,
    DARKORANGE,
    ORCHID,
    DARKPINK,
    LIGHTYELLOW,
    STEELBLUE,
    CANARYYELLOW,
    KHAKI,
    :red,
)

PLOTLY_DEFAULT = vcat(
    :firebrick,
    :slategrey,
    :lightblue,
    :darkOLIVEGREEN,
    :lightpink,
    :DARKORANGE,
    :purple,
    :pink,
    :lightgoldenrodyellow,
    :STEELBLUE,
    :goldenrod,
    :tan,
    :red,
) # tan is the problem

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
    for i = 2:length(bar.labels)
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
        OperationsProblemResults(res_var, res.total_cost, res.optimizer_log, res.time_stamp)
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
        OperationsProblemResults(res_var, res.total_cost, res.optimizer_log, res.time_stamp)
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
        variable_stack = get_stack_plot_data(res, name)
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
