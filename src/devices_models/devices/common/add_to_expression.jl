function add_to_jump_expression!(
    expression_array::AbstractArray{T},
    var::JV,
    multiplier::Float64,
    ixs::Vararg{Any, N},
) where {T <: JuMP.AbstractJuMPScalar, JV <: JuMP.AbstractVariableRef, N}
    if isassigned(expression_array, ixs...)
        JuMP.add_to_expression!(expression_array[CartesianIndex(ixs)], multiplier, var)
    else
        expression_array[CartesianIndex(ixs)] = multiplier * var
    end

    return
end

function add_to_jump_expression!(
    expression_array::AbstractArray{T},
    var::JV,
    multiplier::Float64,
    constant::Float64,
    ixs::Vararg{Any, N},
) where {T <: JuMP.AbstractJuMPScalar, JV <: JuMP.VariableRef, N}
    if isassigned(expression_array, ixs...)
        JuMP.add_to_expression!(expression_array[CartesianIndex(ixs)], multiplier, var)
        JuMP.add_to_expression!(expression_array[CartesianIndex(ixs)], constant)
    else
        expression_array[CartesianIndex(ixs)] = multiplier * var + constant
    end

    return
end

function add_to_jump_expression!(
    expression_array::AbstractArray{T},
    value::Float64,
    ixs::Vararg{Any, N},
) where {T <: JuMP.AbstractJuMPScalar, N}
    if isassigned(expression_array, ixs...)
        JuMP.add_to_expression!(expression_array[CartesianIndex(ixs)], value)
    else
        expression_array[CartesianIndex(ixs)] = zero(eltype(expression_array)) + value
    end

    return
end

function add_to_jump_expression!(
    expression_array::AbstractArray{T},
    parameter::PJ.ParameterRef,
    multiplier::Float64,
    ixs::Vararg{Any, N},
) where {T <: JuMP.AbstractJuMPScalar, N}
    if isassigned(expression_array, ixs...)
        JuMP.add_to_expression!(expression_array[CartesianIndex(ixs)], multiplier, parameter)
    else
        expression_array[CartesianIndex(ixs)] = zero(eltype(expression_array)) + parameter * multiplier
    end

    return
end

function add_to_jump_expression!(
    expression_array::AbstractArray{T},
    parameter::Float64,
    multiplier::Float64,
    ixs::Vararg{Any, N},
) where {T <: JuMP.AbstractJuMPScalar, N}
    add_to_jump_expression!(expression_array, parameter * multiplier, ixs)
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
        bus_number = PSY.get_number(PSY.get_bus(d))
        name = get_name(d)
        add_to_jump_expression!(
            get_expression(container, T(), X),
            parameter[name, t],
            multiplier[name, t],
            bus_number,
            t,
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
        bus_number = PSY.get_number(PSY.get_bus(d))
        add_to_jump_expression!(
            expression,
            variable[name, t],
            get_variable_multiplier(U(), V, W()),
            bus_number,
            t,
        )
    end
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
    V <: PSY.StaticInjection,
    W <: AbstractDeviceFormulation,
    X <: CopperPlatePowerModel,
}
    parameter = get_parameter_array(container, U(), V)
    multiplier = get_parameter_multiplier_array(container, U(), V)
    for d in devices, t in get_time_steps(container)
        name = get_name(d)
        add_to_jump_expression!(
            get_expression(container, T(), X),
            parameter[name, t],
            multiplier[name, t],
            t,
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
    T <: ActivePowerBalance,
    U <: VariableType,
    V <: PSY.StaticInjection,
    W <: AbstractDeviceFormulation,
    X <: CopperPlatePowerModel,
}
    variable = get_variable(container, U(), V)
    expression = get_expression(container, T(), X)
    for d in devices, t in get_time_steps(container)
        name = PSY.get_name(d)
        add_to_jump_expression!(
            expression,
            variable[name, t],
            get_variable_multiplier(U(), V, W()),
            t,
        )
    end
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
    V <: PSY.StaticInjection,
    W <: AbstractDeviceFormulation,
    X <: Union{PTDFPowerModel, StandardPTDFModel},
}
    parameter = get_parameter_array(container, U(), V)
    multiplier = get_parameter_multiplier_array(container, U(), V)
    for d in devices, t in get_time_steps(container)
        name = get_name(d)
        add_to_jump_expression!(
            get_expression(container, T(), PSY.System),
            parameter[name, t],
            multiplier[name, t],
            t,
        )
        add_to_jump_expression!(
            get_expression(container, T(), PSY.Bus),
            parameter[name, t],
            multiplier[name, t],
            PSY.get_number(PSY.get_bus(d)),
            t,
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
    T <: ActivePowerBalance,
    U <: VariableType,
    V <: PSY.StaticInjection,
    W <: AbstractDeviceFormulation,
    X <: Union{PTDFPowerModel, StandardPTDFModel},
}
    variable = get_variable(container, U(), V)
    for d in devices, t in get_time_steps(container)
        name = PSY.get_name(d)
        add_to_jump_expression!(
            get_expression(container, T(), PSY.System),
            variable[name, t],
            get_variable_multiplier(U(), V, W()),
            t,
        )
        add_to_jump_expression!(
            get_expression(container, T(), PSY.Bus),
            variable[name, t],
            get_variable_multiplier(U(), V, W()),
            PSY.get_number(PSY.get_bus(d)),
            t,
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
    W <: AbstractBranchFormulation,
    X <: PM.AbstractActivePowerModel,
}
    var = get_variable(container, U(), V)
    expression = get_expression(container, T(), X)
    for d in devices
        for t in get_time_steps(container)
            flow_variable = var[PSY.get_name(d), t]
            add_to_jump_expression!(
                expression,
                flow_variable,
                -1.0,
                PSY.get_number(PSY.get_arc(d).from),
                t,
            )
            add_to_jump_expression!(
                expression,
                flow_variable,
                1.0,
                PSY.get_number(PSY.get_arc(d).to),
                t,
            )
        end
    end
end
