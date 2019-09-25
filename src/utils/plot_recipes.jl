"""
  bar_plot(OperationModelResults)

This function plots a bar plot for the generators in each variable within
the results variables dictionary, and makes a bar plot for all of the variables.

#Examples

results = solve_op_model!(OpModel)
bar_plot(results)

generates a bar plot for each variable,
and one bar plot of all the variables

kwargs: plot attributes, such as seriescolor = [:red :blue :orange]
will override the default series color
"""

function bar_plot(res::OperationModelResults; kwargs...)

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

  stack_plot(OperationModelResults)

This function plots a stack plot for the generators in each variable within
the results variables dictionary, and makes a stack plot for all of the variables.

#Examples

results = solve_op_model!(OpModel)
stack_plot(results)

generates a stack plot for each variable,
and one stack plot of all the variables

kwargs: plot attributes, such as seriescolor = [:red :blue :orange]
will override the default series color

"""

function stack_plot(res::OperationModelResults; kwargs...)

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
"""
    Recipe StackedPlot(results::StackedArea, variable::String)

This is a Plots series recipe expecting to use Plots and the gr() backend.
RecipesBase.@Recipe function StackedPlot(res::StackedArea)

This recipe is called when plot() takes in data of struct StackedArea.
It creates a stacked area plot. To overlay a scatter plot or line, add
another series:

  Recipesbase.@series begin		
    seriestype := (plot type, such as :scatter) 		
    x, y		
  end		

  plot attributes can be changed and spacing for the x-tick can be changed.		
  For example, if a plot is a 7 day period, xtick can be changed to 		
  xtick := time[1]:Dates.Day(1):time[n-1]


"""

RecipesBase.@recipe function StackedPlot(results::StackedArea, variable::String)

  time = convert.(Dates.DateTime,results.time_range)
  n = length(time)		
  data = results.data_matrix		
  z = cumsum(data, dims = 2)		
  # Plot attributes		
  grid := false		
  title := variable		
  label := results.labels		
  legend := :topleft				
  time_interval = Dates.Hour(convert(Dates.DateTime,time[n])-convert(Dates.DateTime,time[1]))		
  xlabel := "$time_interval"		
  ylabel := "Generation (MW)"		
  xtick := time[1]:Dates.Hour(12):time[n-1]

    #create filled polygon
    sy = vcat(z[:,1],zeros(n))		
    sx = [time[1:n]; reverse(time[1:n])]		

     for c=1:size(z,2)		
      if c !== 1		
        sy = hcat(sy,vcat(z[:,c],reverse(z[:,c-1])))		
      end		
    end

  RecipesBase.@series begin

    seriestype := :shape
    sx, sy

  end

end

RecipesBase.@recipe function StackedGeneration(res::StackedGeneration)		  

  time = convert.(Dates.DateTime,res.time_range)		
  n = length(time)		
  data = res.data_matrix		
  z = cumsum(data, dims = 2)		
  # Plot Attributes		
  grid := false		
  title := "Generation Type"				
  label := res.labels		
  legend := :bottomright		
  time_interval = Dates.Hour(convert(Dates.DateTime,time[n])-convert(Dates.DateTime,time[1]))		
  xlabel := "$time_interval"		
  ylabel := "Generation (MW)"		
  xtick := time[1]:Dates.Hour(12):time[n]		

  # Create filled polygon		
 sy = vcat(z[:,1],zeros(n))		
 sx = [time[1:n]; reverse(time[1:n])]		

for c=1:size(z,2)		
   if c !== 1		
     sy = hcat(sy,vcat(z[:,c],reverse(z[:,c-1])))		
   end		
end		

  RecipesBase.@series begin		

  seriestype := :shape		
   sx, sy		

  end		

end		


RecipesBase.@recipe function BarPlot(res::BarPlot, variable::String)		

  time = convert.(Dates.DateTime,res.time_range)		
 n = length(time)		
 data_point = res.bar_data		
 data = [data_point; data_point]		
 z = cumsum(data, dims = 2)		
 # Plot Attributes		
 grid := false		
 title := variable		
 seriestype := :shape		  
 label := res.labels		
 start_time = time[1]		
 time_interval = Dates.Hour(convert(Dates.DateTime,time[n])-convert(Dates.DateTime,time[1]))		
 xlabel := "$time_interval, $start_time"		
 ylabel := "Generation(MW)"			  
 xlims := (1, 8)
 xticks := false		
 n = 2		

    # Create filled polygon		

  for c=1:size(z,2)		
   sx = [[4,5]; [5,4]]		
   sy = vcat(z[:,c], c==1 ? zeros(n) : reverse(z[:,c-1]))		
   RecipesBase.@series sx, sy		
 end		

end

RecipesBase.@recipe function BarGen(res::BarGeneration)

  time = convert.(Dates.DateTime,res.time_range)
  n = 2
  data_point = res.bar_data	
  data = [data_point; data_point]
  z = cumsum(data, dims = 2)
   # Plot Attributes
   grid := false		 
   title := "Generation Type"	
   seriestype := :shape		 
   label := res.labels	
   start_time = time[1]
   xticks := false 
   xlims := (1, 8)

   for c=1:size(z,2)		
    sx = [[4,5]; [5,4]]		
    sy = vcat(z[:,c], c==1 ? zeros(n) : reverse(z[:,c-1]))		
    RecipesBase.@series sx, sy		
  end		
end