function _add_to_expression!(
    expression_array::T,
    ix::Int,
    jx::Int,
    var::JV,
    multiplier::Float64,
) where {T, JV <: JuMP.AbstractVariableRef}
    if isassigned(expression_array, ix, jx)
        JuMP.add_to_expression!(expression_array[ix, jx], multiplier, var)
    else
        expression_array[ix, jx] = multiplier * var
    end

    return
end

function _add_to_expression!(
    expression_array::T,
    ix::Int,
    jx::Int,
    var::JV,
    multiplier::Float64,
    constant::Float64,
) where {T, JV <: JuMP.AbstractVariableRef}
    if isassigned(expression_array, ix, jx)
        JuMP.add_to_expression!(expression_array[ix, jx], multiplier, var)
        JuMP.add_to_expression!(expression_array[ix, jx], constant)
    else
        expression_array[ix, jx] = multiplier * var + constant
    end

    return
end

function _add_to_expression!(
    expression_array::T,
    ix::Int,
    jx::Int,
    value::Float64,
) where {T}
    if isassigned(expression_array, ix, jx)
        expression_array[ix, jx].constant += value
    else
        expression_array[ix, jx] = zero(eltype(expression_array)) + value
    end

    return
end

function _add_to_expression!(
    expression_array::T,
    ix::Int,
    jx::Int,
    parameter::PJ.ParameterRef,
) where {T}
    if isassigned(expression_array, ix, jx)
        JuMP.add_to_expression!(expression_array[ix, jx], 1.0, parameter)
    else
        expression_array[ix, jx] = zero(eltype(expression_array)) + parameter
    end

    return
end

"""
Default implementation to add parameters to SystemBalanceExpressions
"""
function add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    devices::IS.FlattenIteratorWrapper{U},
    parameter::ParameterType,
    ::Type{S}
) where {T <: SystemBalanceExpressions, U <: PSY.Device, S <: PM.AbstractActivePowerModel}
    parameter_array = get_parameter_array(container, parameter, U)
    multiplier = get_parameter_multiplier_array(container, parameter, U)
    for d in devices, t in get_time_steps(container)
        bus_number = PSY.get_number(PSY.get_bus(d))
        name = get_name(d)
        _add_to_expression!(
            get_expression(container, T(), S),
            bus_number,
            t,
            parameter_array[name, t],
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
    devices::IS.FlattenIteratorWrapper{U},
    variable::V,
    ::Type{W}
) where {T <: SystemBalanceExpressions, U <: PSY.Device, V <: VariableType, W <: PM.AbstractPowerModel}
    variable = get_variable(container, V(), U)
    for d in devices, t in get_time_steps(container)
        bus_number = PSY.get_number(PSY.get_bus(d))
        _add_to_expression!(
            get_expression(container, T, S),
            bus_number,
            t,
            variable[name, t],
            get_variable_sign(variable, U, formulation),
        )
    end
    return
end
