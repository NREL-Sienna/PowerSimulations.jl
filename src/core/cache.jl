"""
Tracks the last time status of a device changed in a simulation
"""
mutable struct TimeStatusChange <: AbstractCache
    value::JuMP.Containers.DenseAxisArray{Dict{Symbol,Float64}}
    ref::UpdateRef
end

function TimeStatusChange(::Type{T}, name::AbstractString) where T <: PSY.Device
    value_array = JuMP.Containers.DenseAxisArray{Dict{Symbol, Float64}}(undef, 1)
    return TimeStatusChange(value_array, UpdateRef{PJ.ParameterRef}(T, name))
end

cache_value(cache::AbstractCache, key) = cache.value[key]

function build_cache!(cache::TimeStatusChange, op_problem::OperationsProblem)
    build_cache!(cache, op_problem.psi_container)
end

function build_cache!(cache::TimeStatusChange, psi_container::PSIContainer)
    # TODO: This currently only supports parameters; we may need to support variables and
    # constraints in the future. A get function would need to be parametrized on cache.ref.
    parameter = get_parameter_array(psi_container, cache.ref)
    value_array = JuMP.Containers.DenseAxisArray{Dict{Symbol, Float64}}(undef, axes(parameter)...)

    for name in parameter.axes[1]
        status = PJ.value(parameter[name])
        value_array[name] = Dict(:count => 999.0, :status => status)
    end

    cache.value = value_array

    return
end

################################Cache Update################################################
function update_cache!(c::TimeStatusChange, stage::Stage)
    parameter = get_parameter_array(stage.internal.psi_container, c.ref)
    for name in parameter.axes[1]
        param_status = PJ.value(parameter[name])
        if c.value[name][:status] == param_status
            c.value[name][:count] += 1.0
        elseif c.value[name][:status] != param_status
            c.value[name][:count] = 1.0
            c.value[name][:status] = param_status
        end
    end

    return
end
