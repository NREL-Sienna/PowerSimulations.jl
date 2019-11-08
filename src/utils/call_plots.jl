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

    color_range = [Colors.RGBA(0.7,0.1,0.1,0.95), # maroon
    Colors.RGBA(0,0,0,0.8), :lightblue, # Dark gray
    Colors.RGBA(0.33,0.42,0.18,0.9), :pink, # olive green
    Colors.RGBA(0.93,0.46,0,1), Colors.RGBA(0.56,0.28,0.54,1), # orange, orchid
    Colors.RGBA(0.9,0.5,0.6,0.80),  # dark pink
    Colors.RGBA(1, 1, 0.5, 0.6), # light yellow
    Colors.RGBA(0.27, 0.5, 0.7, 0.9), # steel blue
    Colors.RGBA(1, 0.757, 0.15, 01), # canary yellow
    Colors.RGBA(0.8, 0.6, 0.3, 1), :red] # khaki
    
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
  
  
"""
   bar_plot(OperationsProblemResults)
  
This function plots a bar plot for the generators in each variable within
the results variables dictionary, and makes a bar plot for all of the variables.

# Arguments
-`res::OperationsProblemResults= results`: results to be plotted

# Example

```julia
results = solve_op_problem!(OpProblem)
bar_plot(results)
```

# Accepted Key Words
plot attributes, such as seriescolor = [:red :blue :orange]
will override the default series color
"""
function bar_plot(res::AggregatedResults; kwargs...)
  results = OperationsProblemResults(res.variables, res.total_cost, 
  res.optimizer_log, res.time_stamp)
  bar_plot(res; kwargs...)
end

function bar_plot(res::OperationsProblemResults; kwargs...)

  default = hcat([Colors.RGBA(0.7,0.1,0.1,0.95)], # maroon
            [Colors.RGBA(0,0,0,0.8)], [:lightblue], # Dark gray
            [Colors.RGBA(0.33,0.42,0.18,0.9)], [:pink], # olive green
            [Colors.RGBA(0.93,0.46,0,1)], [Colors.RGBA(0.56,0.28,0.54,1)], # orange, orchid
            [Colors.RGBA(0.9,0.5,0.6,0.80)],  # dark pink
            [Colors.RGBA(1, 1, 0.5, 0.6)], # light yellow
            [Colors.RGBA(0.27, 0.5, 0.7, 0.9)], # steel blue
            [Colors.RGBA(1, 0.757, 0.15, 01)], # canary yellow
            [Colors.RGBA(0.8, 0.6, 0.3, 1)], [:red]) # khaki

  seriescolor = get(kwargs, :seriescolor, default)
  key_name = string.(collect(keys(res.variables)))

  for i in 1:length(key_name)

    variable_bar = get_bar_plot_data(res, key_name[i])
    p = RecipesBase.plot(variable_bar, key_name[i]; seriescolor = seriescolor)
    display(p)

  end

  bar_gen = get_bar_gen_data(res)
  p2 = RecipesBase.plot(bar_gen; seriescolor = seriescolor)
  display(p2)

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
function stack_plot(res::AggregatedResults; kwargs...)
  results = OperationsProblemResults(res.variables, res.total_cost, 
  res.optimizer_log, res.time_stamp)
  stack_plot(res; kwargs...)
end

function stack_plot(res::OperationsProblemResults; kwargs...)
  
  default = hcat([Colors.RGBA(0.7,0.1,0.1,0.95)], # maroon
  [Colors.RGBA(0,0,0,0.8)], [:lightblue], # Dark gray
  [Colors.RGBA(0.33,0.42,0.18,0.9)], [:pink], # olive green
  [Colors.RGBA(0.93,0.46,0,1)], [Colors.RGBA(0.56,0.28,0.54,1)], # orange, orchid
  [Colors.RGBA(0.9,0.5,0.6,0.80)],  # dark pink
  [Colors.RGBA(1, 1, 0.5, 0.6)], # light yellow
  [Colors.RGBA(0.27, 0.5, 0.7, 0.9)], # steel blue
  [Colors.RGBA(1, 0.757, 0.15, 01)], # canary yellow
  [Colors.RGBA(0.8, 0.6, 0.3, 1)], [:red]) # khaki
  seriescolor = get(kwargs, :seriescolor, default)  
  key_name = string.(collect(keys(res.variables)))

  for i in 1:length(key_name)

    variable_stack = get_stacked_plot_data(res, key_name[i])
    p3 = RecipesBase.plot(variable_stack, key_name[i]; seriescolor = seriescolor)
    display(p3)

  end

  stacked_gen = get_stacked_generation_data(res)
  p4 = RecipesBase.plot(stacked_gen; seriescolor = seriescolor)
  display(p4)

end