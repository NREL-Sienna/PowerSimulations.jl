struct StackedArea
    time_range::Array
    data_matrix::Matrix
    labels::Array

end

struct BarPlot
    time_range::Array
    bar_data::Matrix
    labels::Array

end

struct StackedGeneration
    time_range::Array
    data_matrix::Matrix
    labels::Array

end

function get_stacked_plot_data(res::OperationModelResults, variable::String; kwargs...)

    sort = get(kwargs, :sort, nothing)
    time_range = res.times[!,:Range]
    variable = res.variables[Symbol(variable)]
    Alphabetical = sort!(names(variable))

    if isnothing(sort)
        variable = variable[:, Alphabetical]
    else
        variable = variable[:,sort]
    end

    data_matrix = convert(Matrix, variable)
    labels = collect(names(variable))
    legend = string.(labels)
  
    return StackedArea(time_range, data_matrix, legend)
   
end

function get_bar_plot_data(res::OperationModelResults, variable::String; kwargs...)

    sort = get(kwargs, :sort, nothing)
    time_range = res.times[!,:Range]
    variable = res.variables[Symbol(variable)]
    Alphabetical = sort!(names(variable))

    if isnothing(sort)
        variable = variable[:, Alphabetical]
    else
        variable = variable[:,sort]
    end

    data = convert(Matrix, variable)
    bar_data = sum(data, dims = 1)
    labels = collect(names(variable))
    legend = string.(labels)
  
    return BarPlot(time_range, bar_data, legend)
   
end

function get_stacked_generation_data(res::OperationModelResults; kwargs...)

    sort = get(kwargs, :sort, nothing)
    time_range = res.times[!,:Range]
    key_name = collect(keys(res.variables))
    Alphabetical = sort!(key_name)

    if !isnothing(sort)
        labels = sort
    else
        labels = Alphabetical
    end

    variable = res.variables[Symbol(labels[1])]
    data_matrix = sum(convert(Matrix, variable), dims = 2)
    legend = string.(labels)

    for i in 1:length(labels)
        if i !== 1
            variable = res.variables[Symbol(labels[i])]
            data_matrix = hcat(data_matrix, sum(convert(Matrix, variable), dims = 2))
        end
    end
 
    return StackedGeneration(time_range, data_matrix, legend)
   
end