# Color Definitions
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

### Fuel Plots will be added in next PR
#= 
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

function fuel_plot(res::PSI.OperationsProblemResults, generator_dict::Dict; kwargs...)

    color_range = hcat(
        [maroon], [darkgray], [:lightblue], [olivegreen], [:pink], [darkorange],
        [orchid], [darkpink], [lightyellow], [steelblue], [canaryyellow], [khaki], [:red])
    
    fuels = ["Nuclear", "Coal", "Hydro", "Gas_CC",
             "Gas_CT", "Storage", "Oil_ST", "Oil_CT",
             "Sync_Cond", "Wind", "Solar", "CSP", "curtailment"]
  
    color_fuel = DataFrames.DataFrame(fuels = fuels, colors = color_range)
  
    stack = get_stacked_aggregation_data(res, generator_dict)
    bar = get_bar_aggregation_data(res, generator_dict)
    default =  [(color_fuel[findall(in(["$(bar.labels[1])"]),
    color_fuel.fuels), :][:,:colors])[1]]
    for i in 2:length(bar.labels)
      specific_color = (color_fuel[findall(in(["$(bar.labels[i])"]),
                        color_fuel.fuels), :][:,:colors])[1]
      default = [default specific_color]
      
    end
  
    seriescolor = (get(kwargs, :seriescolor, default))
    P1 = RecipesBase.plot(stack; seriescolor = seriescolor)
    P2 = RecipesBase.plot(bar; seriescolor = seriescolor)
 
    display(P1)
    display(P2)
end

function fuel_plot(res::PSI.SimulationResults, generator_dict::Dict; kwargs...)
    results = OperationsProblemResults(res.variables, res.total_cost, 
    res.optimizer_log, res.time_stamp)
    fuel_plot(results, generator_dict; kwargs...)
end

function fuel_plot(res::PSI.DualResults, generator_dict::Dict; kwargs...)
    results = OperationsProblemResults(res.variables, res.total_cost, 
    res.optimizer_log, res.time_stamp)
    fuel_plot(results, generator_dict; kwargs...)
end =#
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

function bar_plot(res::OperationsProblemResults; kwargs...)
    default = hcat([maroon], [darkgray], [:lightblue], [olivegreen], [:pink], [darkorange],
        [orchid], [darkpink], [lightyellow], [steelblue], [canaryyellow], [khaki], [:red])
    seriescolor = get(kwargs, :seriescolor, default)
    for name in string.(keys(res.variables))
        variable_bar = get_bar_plot_data(res, name)
        p = RecipesBase.plot(variable_bar, name; seriescolor = seriescolor)
        display(p)
    end
    bar_gen = get_bar_gen_data(res)
    p2 = RecipesBase.plot(bar_gen; seriescolor = seriescolor)
    display(p2)
end

function bar_plot(res::PSI.DualResults; kwargs...)
    results = OperationsProblemResults(
        res.variables, res.total_cost, res.optimizer_log, res.time_stamp)
    bar_plot(results; kwargs...)
end
function bar_plot(res::PSI.SimulationResults; kwargs...)
    results = OperationsProblemResults(
        res.variables, res.total_cost, res.optimizer_log, res.time_stamp)
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

function stack_plot(res::OperationsProblemResults; kwargs...)
    default = hcat([maroon], [darkgray], [:lightblue], [olivegreen], [:pink], [darkorange],
        [orchid], [darkpink], [lightyellow], [steelblue], [canaryyellow], [khaki], [:red])
    seriescolor = get(kwargs, :seriescolor, default)
    for name in string.(keys(res.variables))
        variable_stack = get_stacked_plot_data(res, name)
        p3 = RecipesBase.plot(variable_stack, name; seriescolor = seriescolor)
        display(p3)
    end
    stacked_gen = get_stacked_generation_data(res)
    p4 = RecipesBase.plot(stacked_gen; seriescolor = seriescolor)
    display(p4)
end

function stack_plot(res::PSI.DualResults; kwargs...)
    results = OperationsProblemResults(
        res.variables, res.total_cost, res.optimizer_log, res.time_stamp)
    stack_plot(results; kwargs...)
end

function stack_plot(res::PSI.SimulationResults; kwargs...)
    results = OperationsProblemResults(
        res.variables, res.total_cost, res.optimizer_log, res.time_stamp)
    stack_plot(results; kwargs...)
end