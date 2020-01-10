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

    time = convert.(Dates.DateTime, results.time_range)
    n = length(time)
    data = results.data_matrix
    z = cumsum(data, dims = 2)
    # Plot attributes
    grid := false
    title := variable
    label := results.labels
    legend := :outerright
    interval = time[2] - time[1]
    time_interval = convert(Dates.Hour, interval * n)
    xlabel := "$time_interval"
    ylabel := "Generation (MW)"
    xtick := [time[1], time[n]]
    # create filled polygon
    sy = vcat(z[:,1], zeros(n))
    sx = [time[1:n]; reverse(time[1:n])]
    for c = 1:size(z, 2)
        if c !== 1
            sy = hcat(sy, vcat(z[:,c], reverse(z[:,c - 1])))
        end
    end

    RecipesBase.@series begin
        seriestype := :shape
        sx, sy
    end

end

RecipesBase.@recipe function StackedGeneration(res::StackedGeneration)

    time = convert.(Dates.DateTime, res.time_range)
    n = length(time)
    data = res.data_matrix
    z = cumsum(data, dims = 2)
    # Plot Attributes
    grid := false
    title := "Generator"
    label := res.labels
    legend := :outerright
    interval = time[2] - time[1]
    time_interval = convert(Dates.Hour, interval * n)
    xlabel := "$time_interval"
    ylabel := "Generation (MW)"
    xtick := [time[1], time[n]]
    # Create filled polygon
    sy = vcat(z[:,1], zeros(n))
    sx = [time[1:n]; reverse(time[1:n])]
    for c = 1:size(z, 2)
        if c !== 1
            sy = hcat(sy, vcat(z[:,c], reverse(z[:,c - 1])))
        end
    end

    RecipesBase.@series begin
        seriestype := :shape
        sx, sy
    end

end


RecipesBase.@recipe function BarPlot(res::BarPlot, variable::String)

    time = convert.(Dates.DateTime, res.time_range)
    n = length(time)
    data_point = res.bar_data
    data = [data_point; data_point]
    z = cumsum(data, dims = 2)
  # Plot Attributes
    grid := false
    title := variable
    seriestype := :shape
    label := res.labels
    legend := :outerright
    interval = time[2] - time[1]
    time_interval = convert(Dates.Hour, interval * n)
    xlabel := "$time_interval, $(time[1])"
    ylabel := "Generation(MW)"
    xlims := (1, 8)
    xticks := false
    n = 2
    # Create filled polygon
    for c = 1:size(z, 2)
        sx = [[4,5]; [5,4]]
        sy = vcat(z[:,c], c == 1 ? zeros(n) : reverse(z[:,c - 1]))
        RecipesBase.@series sx, sy
    end

end

RecipesBase.@recipe function BarGen(res::BarGeneration)

    time = convert.(Dates.DateTime, res.time_range)
    n = 2
    data_point = res.bar_data
    data = [data_point; data_point]
    z = cumsum(data, dims = 2)
    # Plot Attributes
    grid := false
    title := "Generator"
    start_time = time[1]
    interval = time[2] - time[1]
    time_interval = convert(Dates.Hour, interval * length(time))
    xlabel := "$time_interval, $(time[1])"
    ylabel := "Generation(MW)"
    seriestype := :shape
    label := res.labels
    legend := :outerright
    xticks := false
    xlims := (1, 8)
    for c = 1:size(z, 2)
        sx = [[4,5]; [5,4]]
        sy = vcat(z[:,c], c == 1 ? zeros(n) : reverse(z[:,c - 1]))
        RecipesBase.@series sx, sy
    end
end
