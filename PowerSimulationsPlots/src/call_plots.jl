# Color Definitions
import Plots
maroon = Colors.RGBA(0.7, 0.1, 0.1, 0.95)
darkgray = Colors.RGBA(0, 0, 0, 0.8)
olivegreen = Colors.RGBA(0.33, 0.42, 0.18, 0.9)
darkorange = Colors.RGBA(0.93, 0.46, 0, 1) 
orchid = Colors.RGBA(0.56, 0.28, 0.54, 1)
darkpink = Colors.RGBA(0.9, 0.5, 0.6, 0.80)
lightyellow = Colors.RGBA(1, 1, 0.5, 0.6)
steelblue = Colors.RGBA(0.27, 0.5, 0.7, 0.9)
canaryyellow = Colors.RGBA(1, 0.757, 0.15, 01)
khaki = Colors.RGBA(0.8, 0.6, 0.3, 1)

gr_default = hcat(maroon, darkgray, :lightblue, olivegreen, :pink,
    darkorange, orchid, darkpink, lightyellow, steelblue, 
    canaryyellow, khaki, :red, khaki, khaki)

fuel_default = vcat(maroon, darkgray, :lightblue, olivegreen, :pink, darkorange,
        orchid, darkpink, lightyellow, steelblue, canaryyellow, khaki, :red)

plotly_default = vcat(:firebrick, :slategrey, :lightblue, :darkolivegreen, :lightpink, 
:darkorange, :purple, :pink, :lightgoldenrodyellow, :steelblue, 
:goldenrod, :tan, :red) # tan is the problem

function match_fuel_colors(stack::StackedGeneration, bar::BarGeneration, backend::Any, default::Array)
    if backend == Plots.PlotlyJSBackend()
        color_range = plotly_default
    else
        color_range = fuel_default
    end
    fuels = ["Nuclear", "Coal", "Hydro", "Gas_CC",
             "Gas_CT", "Storage", "Oil_ST", "Oil_CT",
             "Sync_Cond", "Wind", "Solar", "CSP", "curtailment"]
    color_fuel = DataFrames.DataFrame(fuels = fuels, colors = color_range)
    default = [(color_fuel[findall(in(["$(bar.labels[1])"]), color_fuel.fuels), :][:,:colors])[1]]
    for i in 2:length(bar.labels)
        specific_color = (color_fuel[findall(in(["$(bar.labels[i])"]),
            color_fuel.fuels), :][:,:colors])[1]
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

*OR*

- `res::Results = results`: results to be plotted
- `generators::Dict`: the dictionary of fuel type and an array
 of the generators per fuel type, or some other specified category order

# Example

```julia
res = solve_op_problem!(OpProblem)
fuel_plot(res, sys)
```
*OR*
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
function fuel_plot(res::PSI.Results, sys::PSY.System; kwargs...)
    ref = make_fuel_dictionary(sys, res)
    fuel_plot(res, ref; kwargs...)
end

function fuel_plot(res::PSI.Results, generator_dict::Dict; kwargs...)
    set_display = get(kwargs, :display, true)
    save_fig = get(kwargs, :save, nothing)
    stack = get_stacked_aggregation_data(res, generator_dict)
    bar = get_bar_aggregation_data(res, generator_dict)
    backend = Plots.backend()
    default_colors = match_fuel_colors(stack, bar, backend, fuel_default)
    seriescolor = get(kwargs, :seriescolor, default_colors)
    if isnothing(backend)
        @info("No backend detected. Setting GR() by default")
        Plots.gr()
    end
    if backend == Plots.PlotlyJSBackend()
        plotly_stack_gen(stack, seriescolor; kwargs...)
        plotly_bar_gen(bar, seriescolor; kwargs...)
    else
        P1 = RecipesBase.plot(stack; seriescolor = seriescolor)
        set_display && display(P1)
        !isnothing(save_fig) && Plots.savefig(P1, joinpath(save_fig, "Fuel_Stack.png"))
        P2 = RecipesBase.plot(bar; seriescolor = seriescolor)
        set_display && display(P2)
        !isnothing(save_fig) && Plots.savefig(P2, joinpath(save_fig, "Fuel_Bar.png"))
    end
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
            p = RecipesBase.plot(variable_bar, name; seriescolor = seriescolor)
            set_display && display(p)
            !isnothing(save_fig) && Plots.savefig(p, joinpath(save_fig, "$(name)_Bar.png"))
        end
        p2 = RecipesBase.plot(bar_gen; seriescolor = seriescolor)
        set_display && display(p2)
        !isnothing(save_fig) && Plots.savefig(p2, joinpath(save_fig, "Bar_Generation.png"))
    end
end

function bar_plot(res::PSI.Results, variables::Array; kwargs...)
    res_var = Dict()
    for variable in variables
        res_var[variable] = res.variables[variable]
    end
    results = PSI.OperationsProblemResults(res_var, res.total_cost, res.optimizer_log, res.time_stamp)
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

function stack_plot(res::PSI.Results; kwargs...)
    set_display = get(kwargs, :set_display, true)
    backend = Plots.backend()
    save_fig = get(kwargs, :save, nothing)
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
            p = RecipesBase.plot(variable_stack, name; seriescolor = seriescolor)
            set_display && display(p)
            @show save_fig
            !isnothing(save_fig) && Plots.savefig(p, joinpath(save_fig, "$(name)_Stack.png"))
        end
        p = RecipesBase.plot(stacked_gen; seriescolor = seriescolor)
        set_display && display(p)
        !isnothing(save_fig) && Plots.savefig(p, joinpath(save_fig, "Stack_Generation.png"))

    end
end

function stack_plot(res::PSI.SimulationResults, variables::Array; kwargs...)
    res_var = Dict()
    for variable in variables
        res_var[variable] = res.variables[variable]
    end
    results = PSI.OperationsProblemResults(res_var, res.total_cost, res.optimizer_log, res.time_stamp)
    stack_plot(results; kwargs...)
end

function stack_plot(res::PSI.Results, variables::Array; kwargs...)
    res_var = Dict()
    for variable in variables
        res_var[variable] = res.variables[variable]
    end
    results = PSI.OperationsProblemResults(res_var, res.total_cost, res.optimizer_log, res.time_stamp)
    stack_plot(results; kwargs...)
end
