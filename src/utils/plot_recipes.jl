
#;@userplot StackedArea
using RecipesBase
@recipe function AreaPlot(res::OperationModelResults, variable::String) # variable::DataFrames.DataFrame)
  
  plot_res = plot_results(res, variable)
  labels = plot_res.labels
  legend = [string(labels[1]), string(labels[2]), string(labels[3]), string(labels[4]), string(labels[5])]
  time = plot_res.time_range
  interval = Dates.Hour(convert(Dates.DateTime,time[24])- convert(Dates.DateTime, time[1]))
  data = plot_res.data_matrix
  n = length(time)
  x = 1:n
  y = data
  z = cumsum(y, dims = 2) 
  time = Dates.plot_res.time_range
  grid := false
  title := variable
  seriestype := :shape
  label := legend
  xlabel := "$interval"
  ylabel := "Power (MW)"
  
    #create filled polygon
    
    for c=1:size(z,2)
        sx = [x; reverse(x)]
        sy = vcat(z[:,c], c==1 ? zeros(24) : reverse(z[:,c-1]))
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




