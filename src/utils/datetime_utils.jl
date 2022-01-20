"""
calculates the index in the time series corresponding to the data. Assumes that the dates vector is sorted.
"""
function find_timestamp_index(
    dates::Union{Vector{Dates.DateTime}, StepRange{Dates.DateTime, Dates.Millisecond}},
    date::Dates.DateTime,
)
    if date == first(dates)
        index = 1
    elseif date == last(dates)
        index = length(dates)
    else
        dates_resolution = dates[2] - dates[1]
        index = 1 + ((date - first(dates)) ÷ dates_resolution)
    end
    # Uncomment for debugging. The method below is fool proof but slower
    # s_index = findlast(dates .<= date)
    # IS.@assert_op index == s_index
    if index < 1 || index > length(dates)
        error("Requested timestamp $date not in the provided dates $dates")
    end
    return index
end
