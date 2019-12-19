"""
Tracks the last time status of a device changed in a simulation
"""
struct InitialConditionCache <: CacheType end
struct FeedForwardCache <: CacheType end

mutable struct TimeStatusChange <: AbstractCache
    value::JuMP.Containers.DenseAxisArray{Dict{Symbol, Float64}}
    ref::UpdateRef
end

function TimeStatusChange(parameter::Symbol)
    value_array = JuMP.Containers.DenseAxisArray{Dict{Symbol, Float64}}(undef, 1)
    return TimeStatusChange(value_array, UpdateRef{PJ.ParameterRef}(parameter))
end

function TimeStatusChange(ref::UpdateRef)
    value_array = JuMP.Containers.DenseAxisArray{Dict{Symbol, Float64}}(undef, 1)
    return TimeStatusChange(value_array, ref)
end

mutable struct DeviceCommitment <: AbstractCache
    value::JuMP.Containers.DenseAxisArray{Float64}
    ref::UpdateRef
end

function DeviceCommitment(ref::UpdateRef)
    value_array = JuMP.Containers.DenseAxisArray{Float64}(undef, 1)
    return DeviceCommitment(value_array, ref)
end

mutable struct DeviceLevel <: AbstractCache
    value::JuMP.Containers.DenseAxisArray{Float64}
    ref::UpdateRef
end

function DeviceLevel(ref::UpdateRef)
    value_array = JuMP.Containers.DenseAxisArray{Float64}(undef, 1)
    return DeviceLevel(value_array, ref)
end

CacheKey(cache::TimeStatusChange) = CacheKey(InitialConditionCache, cache.ref)
CacheKey(cache::AbstractCache) = CacheKey(FeedForwardCache, cache.ref)

cache_value(cache::AbstractCache, key...) = cache.value[key...]

function build_cache!(cache::TimeStatusChange, sim::Simulation, stage_name::String)
    build_cache!(cache, get_psi_container(get_stage(sim,stage_name)))
end

function build_cache!(cache::TimeStatusChange, op_problem::OperationsProblem)
    build_cache!(cache, op_problem.psi_container)
end

function build_cache!(cache::TimeStatusChange, psi_container::PSIContainer)
    parameter = get_value(psi_container, cache.ref)
    value_array = JuMP.Containers.DenseAxisArray{Dict{Symbol, Float64}}(undef, parameter.axes[1])

    for name in parameter.axes[1]
        # TODO: This is a potential issue if you want to use a VariableRef
        status = PJ.value(parameter[name, end])
        value_array[name] = Dict(:count => 999.0, :status => status)
    end

    cache.value = value_array

    return
end


function build_cache!(cache::C, sim::Simulation, 
                    stage_name::String) where {C<:AbstractCache}
    build_cache!(cache, get_sequence(sim), get_stage(sim, stage_name))
end

function build_cache!(cache::C, sequence::SimulationSequence, 
                    stage::Stage) where {C<:AbstractCache}
                    
    stage_name = get_name(sequence, stage)
    psi_container = get_psi_container(stage)
    axisarray = get_value(psi_container, cache.ref)
    executions = get_executions(stage) 
    devices = axes(axisarray)[1]
    interval = get_interval(sequence, stage_name)
    time_length = 1:Int(interval/PSY.get_forecasts_resolution(get_sys(stage)))*executions
    value_array = JuMP.Containers.DenseAxisArray{Float64}(undef, devices, time_length)

    for name in devices, t in time_length
        value_array[name, t] = 0.0
    end

    cache.value = value_array
    return
end
################################Cache Update################################################
function update_cache!(cache::TimeStatusChange, stage::Stage,
                        interval::T) where {T <:Dates.TimePeriod}
    parameter = get_value(stage.internal.psi_container, cache.ref)
    for name in parameter.axes[1], time in parameter.axes[2]
        if time <= Int(interval/PSY.get_forecasts_resolution(get_sys(stage)))
            param_status = PJ.value(parameter[name, time])
            if cache.value[name][:status] == param_status
                cache.value[name][:count] += 1.0
            elseif cache.value[name][:status] != param_status
                cache.value[name][:count] = 1.0
                cache.value[name][:status] = param_status
            end
        end
    end

    return
end

function update_cache!(cache::C, stage::Stage, 
                        interval::T) where {T <:Dates.TimePeriod,
                                            C<:AbstractCache}
    execution_count = get_execution_count(stage)
    psi_container = get_psi_container(stage)
    axisarray = get_value(psi_container, cache.ref)
    time_steps = Int(interval / PSY.get_forecasts_resolution(get_sys(stage)))
    for name in axisarray.axes[1], time in axisarray.axes[2]
        if time <= time_steps
            cache.value[name,(execution_count-1)*time_steps+time] = _get_value(axisarray, cache.ref, name, time)
        end
    end
    return
end

function _get_value(array::JuMP.Containers.DenseAxisArray{T},
                    ref::UpdateRef{PJ.ParameterRef},
                    axes...) where T
    return PJ.value(array[axes...])
end

function _get_value(array::JuMP.Containers.DenseAxisArray{T},
                    ref::UpdateRef{JuMP.VariableRef},
                    axes...) where T
    return JuMP.value(array[axes...])
end
