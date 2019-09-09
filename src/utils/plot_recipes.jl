"""
  bar_plot(OperationModelResults)

This function plots a bar plot for the generators in each variable within
the results variables dictionary, and makes a bar plot for all of the variables.

#Examples

for a results with 6 variables, each with 10 generators:

bar_plot(results)

generates a bar plot for each variable, with 10 generators,
and one bar plot of the 6 variables (7 plots)

"""

function bar_plot(res::OperationModelResults)

  key_name = string.(collect(keys(res.variables)))

  for i in 1:length(key_name)

    variable_bar = get_bar_plot_data(res, key_name[i])
    p = RecipesBase.plot(variable_bar, key_name[i])
    display(p)
    
  end

  bar_gen = get_bar_gen_data(res)
  p2 = RecipesBase.plot(bar_gen)
  display(p2)

end

""" 

  stack_plot(OperationModelResults)

This function plots a stack plot for the generators in each variable within
the results variables dictionary, and makes a stack plot for all of the variables.

#Examples

for a results with 6 variables, each with 10 generators:

stack_plot(results)

generates a stack plot for each variable, with 10 generators,
and one stack plot of the 6 variables (7 plots)

"""

function stack_plot(res::OperationModelResults)
    
  key_name = string.(collect(keys(res.variables)))

  for i in 1:length(key_name)

    variable_stack = get_stacked_plot_data(res, key_name[i])
    p3 = RecipesBase.plot(variable_stack, key_name[i])
    display(p3)

  end

  stacked_gen = get_stacked_generation_data(res)
  p4 = RecipesBase.plot(stacked_gen)
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
  alpha := 0.6		
  seriescolor := [:lightblue :darkorange :lightgreen :red :turquoise :blue :orange]		
  time_interval = Dates.Hour(convert(Dates.DateTime,time[n])-convert(Dates.DateTime,time[1]))		
  xlabel := "$time_interval"		
  ylabel := "Generation (MW)"		
  xtick := time[1]:Dates.Hour(12):time[n-1]

    #create filled polygon
    sy = vcat(z[:,1],zeros(n-1))		
    sx = [time[1:n-1]; reverse(time[1:n-1])]		

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
  alpha := 0.6		
  seriescolor := [:lightblue :orange :lightgreen :red :turquoise]  		
  label := res.labels		
  legend := :bottomright		
  time_interval = Dates.Hour(convert(Dates.DateTime,time[n])-convert(Dates.DateTime,time[1]))		
  xlabel := "$time_interval"		
  ylabel := "Generation (MW)"		
  xtick := time[1]:Dates.Hour(12):time[n-1]		

  # Create filled polygon		
 sy = vcat(z[:,1],zeros(n-1))		
 sx = [time[1:n-1]; reverse(time[1:n-1])]		

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
 alpha := 0.6		 
 seriescolor := [:lightblue :orange :lightgreen :red :turquoise :blue]   
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
   alpha := 0.6		 
   seriescolor := [:lightblue :orange :lightgreen :red :turquoise :blue] 
   xlims := (1, 8)

   for c=1:size(z,2)		
    sx = [[4,5]; [5,4]]		
    sy = vcat(z[:,c], c==1 ? zeros(n) : reverse(z[:,c-1]))		
    RecipesBase.@series sx, sy		
  end		
end