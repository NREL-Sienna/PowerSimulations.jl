function add_to_jump_expression!(
    expression_array::AbstractArray{T},
    ix::Int,
    jx::Int,
    var::JV,
    multiplier::Float64,
) where {T <: JuMP.AbstractJuMPScalar, JV <: JuMP.AbstractVariableRef}
    if isassigned(expression_array, ix, jx)
        JuMP.add_to_expression!(expression_array[ix, jx], multiplier, var)
    else
        expression_array[ix, jx] = multiplier * var
    end

    return
end

function add_to_jump_expression!(
    expression_array::AbstractArray{T},
    ix::Int,
    jx::Int,
    var::JV,
    multiplier::Float64,
    constant::Float64,
) where {T <: JuMP.AbstractJuMPScalar, JV <: JuMP.AbstractVariableRef}
    if isassigned(expression_array, ix, jx)
        JuMP.add_to_expression!(expression_array[ix, jx], multiplier, var)
        JuMP.add_to_expression!(expression_array[ix, jx], constant)
    else
        expression_array[ix, jx] = multiplier * var + constant
    end

    return
end

function add_to_jump_expression!(
    expression_array::AbstractArray{T},
    ix::Int,
    jx::Int,
    value::Float64,
) where {T <: JuMP.AbstractJuMPScalar}
    if isassigned(expression_array, ix, jx)
        JuMP.add_to_expression!(expression_array[ix, jx], value)
    else
        expression_array[ix, jx] = zero(eltype(expression_array)) + value
    end

    return
end

function add_to_jump_expression!(
    expression_array::AbstractArray{T},
    ix::Int,
    jx::Int,
    parameter::PJ.ParameterRef,
    multiplier::Float64,
) where {T <: JuMP.AbstractJuMPScalar}
    if isassigned(expression_array, ix, jx)
        JuMP.add_to_expression!(expression_array[ix, jx], multiplier, parameter)
    else
        expression_array[ix, jx] = zero(eltype(expression_array)) + parameter * multiplier
    end

    return
end

function add_to_jump_expression!(
    expression_array::AbstractArray{T},
    ix::Int,
    jx::Int,
    parameter::Float64,
    multiplier::Float64,
) where {T <: JuMP.AbstractJuMPScalar}
    add_to_jump_expression!(expression_array, ix, jx, parameter * multiplier)
    return
end

"""
Default implementation to add parameters to SystemBalanceExpressions
"""
function add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    ::DeviceModel{V, W},
    ::Type{X},
) where {
    T <: SystemBalanceExpressions,
    U <: TimeSeriesParameter,
    V <: PSY.Device,
    W <: AbstractDeviceFormulation,
    X <: PM.AbstractPowerModel,
}
    parameter = get_parameter_array(container, U(), V)
    multiplier = get_parameter_multiplier_array(container, U(), V)
    for d in devices, t in get_time_steps(container)
        bus_number = X <: CopperPlatePowerModel ? 1 : PSY.get_number(PSY.get_bus(d))
        name = get_name(d)
        add_to_jump_expression!(
            get_expression(container, T(), X),
            bus_number,
            t,
            parameter[name, t],
            multiplier[name, t],
        )
    end
    return
end

"""
Default implementation to add variables to SystemBalanceExpressions
"""
function add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    ::DeviceModel{V, W},
    ::Type{X},
) where {
    T <: SystemBalanceExpressions,
    U <: VariableType,
    V <: PSY.Device,
    W <: AbstractDeviceFormulation,
    X <: PM.AbstractPowerModel,
}
    variable = get_variable(container, U(), V)
     expression = get_expression(container, T(), X)
    for d in devices, t in get_time_steps(container)
        name = PSY.get_name(d)
        bus_number = X <: CopperPlatePowerModel ? 1 : PSY.get_number(PSY.get_bus(d))
        add_to_jump_expression!(
            expression,
            bus_number,
            t,
            variable[name, t],
            get_variable_multiplier(U(), V, W()),
        )
    end
    return
end

"""
Implementation of add_to_expression! for lossless branch/network models
"""
function add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    devices::IS.FlattenIteratorWrapper{V},
    ::DeviceModel{V, W},
    ::Type{X},
) where {
    T <: ActivePowerBalance,
    U <: FlowActivePowerVariable,
    V <: PSY.Branch,
    W <: AbstractDeviceFormulation,
    X <: PM.AbstractActivePowerModel,
}
    @assert !(X <: CopperPlatePowerModel)
    var = get_variable(container, U(), B)
    expression = get_expression(container, T(), X)
    for d in devices
        for t in get_time_steps(container)
            flow_variable = var[PSY.get_name(d), t]
            add_to_jump_expression!(
                expression,
                PSY.get_number(PSY.get_arc(d).from),
                t,
                flow_variable,
                -1.0,
            )
            add_to_jump_expression!(
                expression,
                PSY.get_number(PSY.get_arc(d).to),
                t,
                flow_variable,
                1.0,
            )
        end
    end
end
