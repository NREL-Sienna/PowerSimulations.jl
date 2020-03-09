# Declaring functions for IS.Results interface
function get_variables(result::T) where {T <: IS.Results}
    return IS.get_variables(result)
end

function get_total_cost(result::T) where {T <: IS.Results}
    return IS.get_total_cost(result)
end

function get_optimizer_log(result::T) where {T <: IS.Results}
    return IS.get_optimizer_log(result)
end

function get_time_stamp(result::T) where {T <: IS.Results}
    return IS.get_time_stamp(result)
end

function write_results(results::T, save_path::String; kwargs...) where {T <: IS.Results}
    return IS.write_results(results, save_path; kwargs...)
end
