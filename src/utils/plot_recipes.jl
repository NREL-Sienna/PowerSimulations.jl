
RecipesBase.@recipe function StackedPlot(results::StackedArea, variable::String) 
  
  time = results.time_range
  n = length(time)
  data = results.data_matrix
  z = cumsum(data, dims = 2) 

  grid := false
  title := variable
  label := results.labels
  legend := :topleft
  alpha := 0.6
  seriescolor := [:lightblue :darkorange :lightgreen :red :turquoise :blue :orange]
  time_interval = Dates.Hour(convert(Dates.DateTime,time[n])-convert(Dates.DateTime,time[1]))
  xlabel := "$time_interval"
  ylabel := "Generation (MW)"
  #xtick := time[1]:Dates.Hour(6):time[n-1]
  
  #create filled polygon
  sy = vcat(z[:,1],zeros(n-1))
  sx = [1:n-1; reverse(1:n-1)]
  #sx = [time[1:n-1]; reverse(time[1:n-1])]

  for c=1:size(z,2)

    if c !== 1

      sy = hcat(sy,vcat(z[:,c],reverse(z[:,c-1])))

    end

  end

  RecipesBase.@series begin
      
    seriestype := :path
    w := 0.5
    fill := true
    sx, sy

  end

end

RecipesBase.@recipe function StackedGeneration(res::StackedGeneration) 
  
  time =25
  time = res.time_range
  n = length(time)
  data = res.data_matrix
  z = cumsum(data, dims = 2) 

  grid := false
  title := "Generation Type"
  seriestype := :shape
  label := res.labels
  legend := :bottomright
  time_interval = Dates.Hour(convert(Dates.DateTime,time[n])-convert(Dates.DateTime,time[1]))
  xlabel := "$time_interval"
  ylabel := "Generation (MW)"
 
  #xtick := time[1]:Dates.Hour(6):time[n-1]
  
    #create filled polygon
  sy = vcat(z[:,1],zeros(n-1)) 
  #sx = [time[1:n-1]; reverse(time[1:n-1])]
  sx = [1:n-1; reverse(1:n-1)]
  for c=1:size(z,2)

    if c !== 1

      sy = hcat(sy,vcat(z[:,c],reverse(z[:,c-1])))

    end

  end
  
  RecipesBase.@series begin

    seriestype := :shape
    alpha := 0.6
    seriescolor := [:lightblue :orange :lightgreen :red :turquoise]  
    sx, sy

  end
  
end

RecipesBase.@recipe function BarPlot(res::BarPlot, variable::String)
  
  
  time = res.time_range
  n = length(time)
  data_point = res.bar_data
  data = [data_point; data_point]
  z = cumsum(data, dims = 2) 

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
  
    #create filled polygon
    
    for c=1:size(z,2)
        sx = [[4,5]; [5,4]]
        sy = vcat(z[:,c], c==1 ? zeros(n) : reverse(z[:,c-1]))
        RecipesBase.@series sx, sy
    end
  
end
