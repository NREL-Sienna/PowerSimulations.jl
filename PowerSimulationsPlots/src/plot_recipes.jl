### PlotlyJS set up
import PlotlyJS
function plotly_stack_gen(stacked_gen::StackedGeneration, seriescolor::Array; kwargs...)
    set_display = get(kwargs, :display, true)
    save_fig = get(kwargs, :save, nothing)
    traces = PlotlyJS.GenericTrace{Dict{Symbol,Any}}[]
    gens = stacked_gen.labels
    for gen = 1:length(gens)
        push!(
            traces,
            PlotlyJS.scatter(;
                name = gens[gen],
                x = stacked_gen.time_range,
                y = stacked_gen.data_matrix[:, gen],
                stackgroup = "one",
                mode = "lines",
                fill = "tonexty",
                line_color = seriescolor[gen],
                fillcolor = seriescolor[gen],
            ),
        )
    end
    p = PlotlyJS.plot(
        traces,
        PlotlyJS.Layout(title = "Variables", yaxis_title = "Generation (MW)"),
    )
    set_display && display(p)
    !isnothing(save_fig) && Plots.savefig(p, joinpath(save_fig, "Stack_Generation.png"))
end

function plotly_stack_plots(res::PSI.Results, seriescolor::Array; kwargs...)
    set_display = get(kwargs, :display, true)
    save_fig = get(kwargs, :save, nothing)
    for (key, var) in res.variables
        traces = PlotlyJS.GenericTrace{Dict{Symbol,Any}}[]
        gens = collect(names(var))
        for gen = 1:length(gens)
            push!(
                traces,
                PlotlyJS.scatter(;
                    name = gens[gen],
                    x = res.time_stamp[:, 1],
                    y = convert(Matrix, var)[:, gen],
                    stackgroup = "one",
                    mode = "lines",
                    fill = "tonexty",
                    line_color = seriescolor[gen],
                    fillcolor = seriescolor[gen],
                ),
            )
        end
        p = PlotlyJS.plot(
            traces,
            PlotlyJS.Layout(title = "$key", yaxis_title = "Generation (MW)"),
        )
        set_display && display(p)
        !isnothing(save_fig) && Plots.savefig(p, joinpath(save_fig, "$(key)_Stack.png"))
    end
end

function plotly_bar_gen(bar_gen::BarGeneration, seriescolor::Array; kwargs...)
    time_range = bar_gen.time_range
    set_display = get(kwargs, :display, true)
    save_fig = get(kwargs, :save, nothing)
    time_span = convert(Dates.Hour, (time_range[2]) - (time_range[1])) * length(time_range)
    traces = PlotlyJS.GenericTrace{Dict{Symbol,Any}}[]
    gens = bar_gen.labels
    for gen = 1:length(gens)
        push!(
            traces,
            PlotlyJS.scatter(;
                name = gens[gen],
                x = ["$time_span, $(time_range[1])"],
                y = bar_gen.bar_data[:, gen],
                type = "bar",
                marker_color = seriescolor[gen],
            ),
        )
    end
    p = PlotlyJS.plot(
        traces,
        PlotlyJS.Layout(
            title = "Variables",
            yaxis_title = "Generation (MW)",
            color = seriescolor,
            barmode = "stack",
        ),
    )
    set_display && display(p)
    !isnothing(save_fig) && PlotlyJS.savefig(p, joinpath(save_fig, "Bar_Generation.svg"))
end

function plotly_bar_plots(res::PSI.Results, seriescolor::Array; kwargs...)
    set_display = get(kwargs, :display, true)
    save_fig = get(kwargs, :save, nothing)
    time_range = res.time_stamp
    time_span =
        convert(Dates.Hour, (time_range[2, 1]) - (time_range[1, 1])) *
        length(time_range[!, 1])
    for (key, var) in res.variables
        traces = PlotlyJS.GenericTrace{Dict{Symbol,Any}}[]
        gens = collect(names(var))
        for gen = 1:length(gens)
            push!(
                traces,
                PlotlyJS.scatter(;
                    name = gens[gen],
                    x = ["$time_span, $(time_range[1, 1])"],
                    y = sum(convert(Matrix, var)[:, gen], dims = 1),
                    type = "bar",
                    marker_color = seriescolor[gen],
                ),
            )
        end
        p = PlotlyJS.plot(
            traces,
            PlotlyJS.Layout(
                title = "$key",
                yaxis_title = "Generation (MW)",
                barmode = "stack",
            ),
        )
        set_display && display(p)
        !isnothing(save_fig) && PlotlyJS.savefig(p, joinpath(save_fig, "$(key)_Bar.svg"))
    end
end


RecipesBase.@recipe function StackedPlot(results::StackedArea, variable::String)
    time = convert.(Dates.DateTime, results.time_range)
    n = length(time)
    data = results.data_matrix
    z = cumsum(data, dims = 2)
    # Plot attributes
    grid := false
    title := variable
    if size(results.labels, 2) == 1 # work-around for a weird glitch in recipes
        label := results.labels[1]
    else
        label := results.labels
    end
    legend := :outerright
    interval = time[2] - time[1]
    time_interval = convert(Dates.Hour, interval * n)
    xlabel := "$time_interval"
    ylabel := "Generation (MW)"
    xtick := [time[1], time[n]]
    # create filled polygon
    sy = vcat(z[:, 1], zeros(n))
    sx = [time[1:n]; reverse(time[1:n])]
    for c = 1:size(z, 2)
        if c !== 1
            sy = hcat(sy, vcat(z[:, c], reverse(z[:, c-1])))
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
    if size(res.labels, 2) == 1 # work-around for a weird glitch in recipes
        label := res.labels[1]
    else
        label := res.labels
    end
    legend := :outerright
    interval = time[2] - time[1]
    time_interval = convert(Dates.Hour, interval * n)
    xlabel := "$time_interval"
    ylabel := "Generation (MW)"
    xtick := [time[1], time[n]]
    # Create filled polygon
    sy = vcat(z[:, 1], zeros(n))
    sx = [time[1:n]; reverse(time[1:n])]
    for c = 2:size(z, 2)
        if c !== 1
            sy = hcat(sy, vcat(z[:, c], reverse(z[:, c-1])))
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
    if size(res.labels, 2) == 1 # work-around for a weird glitch in recipes
        label := res.labels[1]
    else
        label := res.labels
    end

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
        sx = [[4, 5]; [5, 4]]
        sy = vcat(z[:, c], c == 1 ? zeros(n) : reverse(z[:, c-1]))
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
    if size(res.labels, 2) == 1 # work-around for a weird glitch in recipes
        label := res.labels[1]
    else
        label := res.labels
    end
    legend := :outerright
    xlims := (1, 8)
    xticks := false
    for c = 1:size(z, 2)
        sx = [[4, 5]; [5, 4]]
        sy = vcat(z[:, c], c == 1 ? zeros(n) : reverse(z[:, c-1]))
        RecipesBase.@series sx, sy
    end
end
