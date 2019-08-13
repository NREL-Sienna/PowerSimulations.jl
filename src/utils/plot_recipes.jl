
#;@userplot StackedArea
using RecipesBase
@recipe function StackedPlot(res::StackedArea, variable::String) # variable::DataFrames.DataFrame)
  
  legend = res.labels
  time = res.time_range
  n = length(time)
  interval = Dates.Hour(convert(Dates.DateTime,time[n])-convert(Dates.DateTime,time[1]))
  data = res.data_matrix
  z = cumsum(data, dims = 2) 

  grid := false
  title := variable
  seriestype := :shape
  label := legend
  xlabel := "$interval"
  ylabel := "Generation (MW)"
  xticks := time[1]:Dates.Hour(n-2):time[n-1]
  
    #create filled polygon
    
    for c=1:size(z,2)
        sx = [time[1:n-1]; reverse(time[1:n-1])]
        sy = vcat(z[:,c], c==1 ? zeros(n-1) : reverse(z[:,c-1]))
        @series (sx, sy)
    end
  
end

@recipe function StackedPlot(res::BarPlot, variable::String) # variable::DataFrames.DataFrame)
  
  legend = res.labels
  time = res.time_range
  n = length(time)
  interval = Dates.Hour(convert(Dates.DateTime,time[n])-convert(Dates.DateTime,time[1]))
  data = res.bar_data
  z = cumsum(data, dims = 2) 

  grid := false
  title := variable
  seriestype := :shape
  label := legend
  xlabel := "$interval"
  ylabel := "Generation (MW)"
  xticks := time[1]
  
    #create filled polygon
    
    for c=1:size(z,2)
        sx = [1; reverse(1)]
        sy = vcat(z[:,c], c==1 ? zeros(n-1) : reverse(z[:,c-1]))
        @series (sx, sy)
    end
  
end

# function create_plot_data(results::OperationModelResults)

#=

    time_range = res.times[!,:Range]
    variable = res.variables[:P_ThermalStandard]
    s_names = names(res.variables[:P_ThermalStandard])
    a = variable[!, s_names[1]]
    b = variable[!, s_names[2]]
    c = variable[!, s_names[3]]
    d = variable[!, s_names[4]]
    e = variable[!, s_names[5]]


end 

@recipe function plot(::T, n = 1; customcolor = :green)
    markershape --> :auto        # if markershape is unset, make it :auto
    markercolor :=  customcolor  # force markercolor to be customcolor
    xrotation   --> 45           # if xrotation is unset, make it 45
    zrotation   --> 90           # if zrotation is unset, make it 90
    rand(10,n)                   # return the arguments (input data) for the next recipe
  end

=#




