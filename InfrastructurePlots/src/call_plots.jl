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

gr_default = hcat(
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
    KHAKI,
    KHAKI,
)

fuel_default = vcat(
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

plotly_default = vcat(
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
        color_range = plotly_default
    else
        color_range = fuel_default
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
    fuel_plot(res, generator_dict)

This function makes a stack plot of the results by fuel type
and assigns each fuel type a specific color.

# Arguments

`res::OperationsProblemResults= results`: results to be plotted
`generator_dict::Dict = generator_dict`: the dictionary of fuel type and an array
 of the generators per fuel type

# Example

```julia
res = solve_op_problem!(OpProblem)
generator_dict = make_fuel_dictionary(sys, res)
fuel_plot(res, generator_dict)
```

# Accepted Key Words
plot attributes, such as seriescolor = [:red :blue :orange]
will override the default series color
"""
function fuel_plot(res::PSI.Results, sys::PSY.System; kwargs...)
    ref = make_fuel_dictionary(sys, res)
    fuel_plot(res, ref; kwargs...)
end

function fuel_plot(res::PSI.Results, generator_dict::Dict; kwargs...)
    set_display = get(kwargs, :display, true)
    stack = get_stacked_aggregation_data(res, generator_dict)
    bar = get_bar_aggregation_data(res, generator_dict)
    backend = Plots.backend()
    default_colors = match_fuel_colors(stack, bar, backend, fuel_default)
    seriescolor = get(kwargs, :seriescolor, default_colors)
    if isnothing(backend)
        @info "No backend detected. Setting GR() by default"
        Plots.gr()
    end
    _fuel_plot_internal(stack, bar, seriescolor, backend; kwargs...)
end

function _fuel_plot_internal(
    stack::StackedGeneration,
    bar::BarGeneration,
    seriescolor::Array,
    backend::Plots.PlotlyJSBackend;
    kwargs...,
)
    plotly_stack_gen(stack, seriescolor; kwargs...)
    plotly_bar_gen(bar, seriescolor; kwargs...)
end

function _fuel_plot_internal(
    stack::StackedGeneration,
    bar::BarGeneration,
    seriescolor::Array,
    backend::Module;
    kwargs...,
)
    p1 = RecipesBase.plot(stack; seriescolor = seriescolor)
    p2 = RecipesBase.plot(bar; seriescolor = seriescolor)
    set_display && display(p1)
    set_display && display(p2)
end

"""
   bar_plot(OperationsProblemResults)
  
This function plots a bar plot for the generators in each variable within
the results variables dictionary, and makes a bar plot for all of the variables.

# Arguments
- `res::OperationsProblemResults= results`: results to be plotted

# Example

```julia
results = solve_op_problem!(OpProblem)
bar_plot(results)
```

# Accepted Key Words
plot attributes, such as seriescolor = [:red :blue :orange]
will override the default series color
"""

function bar_plot(res::PSI.OperationsProblemResults; kwargs...)
    backend = Plots.backend()
    set_display = get(kwargs, :display, true)
    bar_gen = get_bar_gen_data(res)
    backend
    if isnothing(backend)
        @info("No backend detected. Setting GR() by default.")
        Plots.gr()
    end
    if backend == Plots.PlotlyJSBackend()
        seriescolor = get(kwargs, :seriescolor, plotly_default)
        plotly_bar_plots(res, seriescolor; kwargs...)
        plotly_bar_gen(bar_gen, seriescolor; kwargs...)
    else
        seriescolor = get(kwargs, :seriescolor, gr_default)
        for name in string.(keys(res.variables))
            variable_bar = get_bar_plot_data(res, name)
            p = RecipesBase.plot(variable_bar, name; seriescolor = seriescolor, kwargs...)
            set_display && display(p)
        end
        p2 = RecipesBase.plot(bar_gen; seriescolor = seriescolor, kwargs...)
        set_display && display(p2)
    end
end

function bar_plot(res::PSI.DualResults; kwargs...)
    results = PSI.OperationsProblemResults(
        res.variables,
        res.total_cost,
        res.optimizer_log,
        res.time_stamp,
    )
    bar_plot(results; kwargs...)
end
function bar_plot(res::PSI.SimulationResults; kwargs...)
    results = PSI.OperationsProblemResults(
        res.variables,
        res.total_cost,
        res.optimizer_log,
        res.time_stamp,
    )
    bar_plot(results; kwargs...)
end

function bar_plot(res::PSI.SimulationResults, variables::Array; kwargs...)
    res_var = Dict()
    for variable in variables
        res_var[variable] = res.variables[variable]
    end
    results = PSI.OperationsProblemResults(
        res_var,
        res.total_cost,
        res.optimizer_log,
        res.time_stamp,
    )
    bar_plot(results; kwargs...)
end

function bar_plot(res::PSI.OperationsProblemResults, variables::Array; kwargs...)
    res_var = Dict()
    for variable in variables
        res_var[variable] = res.variables[variable]
    end
    results = PSI.OperationsProblemResults(
        res_var,
        res.total_cost,
        res.optimizer_log,
        res.time_stamp,
    )
    bar_plot(results; kwargs...)
end

"""
     stack_plot(OperationsProblemResults)

This function plots a stack plot for the generators in each variable within
the results variables dictionary, and makes a stack plot for all of the variables.

# Examples

```julia
results = solve_op_problem!(OpProblem)
stack_plot(results)
```

# Accepted Key Words
plot attributes, such as seriescolor = [:red :blue :orange]
will override the default series color
"""

function stack_plot(res::PSI.OperationsProblemResults; kwargs...)
    set_display = get(kwargs, :display, true)
    backend = Plots.backend()
    stacked_gen = get_stacked_generation_data(res)
    if isnothing(backend)
        @info("no backend detected. Setting GR() as default.")
        Plots.gr()
    end
    if backend == Plots.PlotlyJSBackend()
        seriescolor = get(kwargs, :seriescolor, plotly_default)
        plotly_stack_plots(res, seriescolor; kwargs...)
        plotly_stack_gen(stacked_gen, seriescolor; kwargs...)
    else
        seriescolor = get(kwargs, :seriescolor, gr_default)
        for name in string.(keys(res.variables))
            variable_stack = get_stacked_plot_data(res, name)
            p = RecipesBase.plot(variable_stack, name; seriescolor = seriescolor, kwargs...)
            set_display && display(p)
        end
        p = RecipesBase.plot(stacked_gen; seriescolor = seriescolor, kwargs...)
        set_display && display(p)
    end
end

function stack_plot(res::PSI.DualResults; kwargs...)
    results = PSI.OperationsProblemResults(
        res.variables,
        res.total_cost,
        res.optimizer_log,
        res.time_stamp,
    )
    stack_plot(results; kwargs...)
end

function stack_plot(res::PSI.SimulationResults; kwargs...)
    results = PSI.OperationsProblemResults(
        res.variables,
        res.total_cost,
        res.optimizer_log,
        res.time_stamp,
    )
    stack_plot(results; kwargs...)
end

function stack_plot(res::PSI.SimulationResults, variables::Array; kwargs...)
    res_var = Dict()
    for variable in variables
        res_var[variable] = res.variables[variable]
    end
    results = PSI.OperationsProblemResults(
        res_var,
        res.total_cost,
        res.optimizer_log,
        res.time_stamp,
    )
    stack_plot(results; kwargs...)
end

function stack_plot(res::PSI.OperationsProblemResults, variables::Array; kwargs...)
    res_var = Dict()
    for variable in variables
        res_var[variable] = res.variables[variable]
    end
    results = PSI.OperationsProblemResults(
        res_var,
        res.total_cost,
        res.optimizer_log,
        res.time_stamp,
    )
    stack_plot(results; kwargs...)
end
