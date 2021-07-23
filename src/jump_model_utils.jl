# The Numerical stability checks code in this file is based on the code from the SDDP.jl package, 
 # from the below mentioned commit and file.
 # commit :8cd305188caffc50a1734913053fc81bba613778 
 # link to file :https://github.com/odow/SDDP.jl/blob/d353fe5a2903421e7fed6d609eb9377c35d715a1/src/print.jl#L190
 
########### JuMP model utils #########

mutable struct NumericalBounds
    min::Float64
    max::Float64
    min_index::Any
    max_index::Any
end

NumericalBounds() = NumericalBounds(Inf, -Inf, nothing, nothing)

set_min!(v::NumericalBounds, value::Real) = v.min = value
set_max!(v::NumericalBounds, value::Real) = v.max = value
set_min_index!(v::NumericalBounds, idx) = v.min_index = idx
set_max_index!(v::NumericalBounds, idx) = v.max_index = idx

mutable struct ConstraintBounds
    coefficient::NumericalBounds
    rhs::NumericalBounds
    function ConstraintBounds()
        return new(NumericalBounds(), NumericalBounds())
    end
end

function _update_coefficient_bounds(
    v::ConstraintBounds,
    constraint::JuMP.ScalarConstraint,
    idx,
)
    _update_numerical_bounds(v.coefficient, constraint.func, idx)
    return
end

function _update_rhs_bounds(v::ConstraintBounds, constraint::JuMP.ScalarConstraint, idx)
    _update_numerical_bounds(v.rhs, constraint.set, idx)
end

mutable struct VariableBounds
    bounds::NumericalBounds
    function VariableBounds()
        return new(NumericalBounds())
    end
end

function _update_variable_bounds(v::VariableBounds, variable::JuMP.VariableRef, idx)
    if JuMP.is_binary(variable)
        set_min!(v.bounds, 0.0)
        _update_numerical_bounds(v.bounds, 1.0, idx)
    else
        if JuMP.has_lower_bound(variable)
            _update_numerical_bounds(v.bounds, JuMP.lower_bound(variable), idx)
        end
        if JuMP.has_upper_bound(variable)
            _update_numerical_bounds(v.bounds, JuMP.upper_bound(variable), idx)
        end
    end
    return
end

function _update_numerical_bounds(v::NumericalBounds, value::Real, idx)
    if !isapprox(value, 0.0)
        if v.min > abs(value)
            set_min!(v, value)
            set_min_index!(v, idx)
        elseif v.max < abs(value)
            set_max!(v, value)
            set_max_index!(v, idx)
        end
    end
    return
end

function _update_numerical_bounds(bonuds::NumericalBounds, func::JuMP.GenericAffExpr, idx)
    for coefficient in values(func.terms)
        _update_numerical_bounds(bonuds, coefficient, idx)
    end
    return
end

function _update_numerical_bounds(bonuds::NumericalBounds, func::MOI.LessThan, idx)
    return _update_numerical_bounds(bonuds, func.upper, idx)
end

function _update_numerical_bounds(bonuds::NumericalBounds, func::MOI.GreaterThan, idx)
    return _update_numerical_bounds(bonuds, func.lower, idx)
end

function _update_numerical_bounds(bonuds::NumericalBounds, func::MOI.EqualTo, idx)
    return _update_numerical_bounds(bonuds, func.value, idx)
end

function _update_numerical_bounds(bonuds::NumericalBounds, func::MOI.Interval, idx)
    _update_numerical_bounds(bonuds, func.upper, idx)
    return _update_numerical_bounds(bonuds, func.lower, idx)
end

# Default fallback for unsupported constraints.
_update_numerical_bounds(range::NumericalBounds, func, idx) = nothing

function get_constraint_numerical_bounds(model::OperationsProblem; verbose = false)
    if verbose
        constraint_bounds = Dict()
        for (const_key, constriant_array) in
            get_constraints(get_optimization_container(model))
            bounds = ConstraintBounds()
            for idx in Iterators.product(constriant_array.axes...)
                con_obj = JuMP.constraint_object(constriant_array[idx...])
                _update_coefficient_bounds(bounds, con_obj, idx)
                _update_rhs_bounds(bounds, con_obj, idx)
            end
            constraint_bounds[const_key] = bounds
        end
        return constraint_bounds
    else
        bounds = ConstraintBounds()
        for (const_key, constriant_array) in
            get_constraints(get_optimization_container(model))
            for idx in Iterators.product(constriant_array.axes...)
                con_obj = JuMP.constraint_object(constriant_array[idx...])
                _update_coefficient_bounds(bounds, con_obj, (const_key, idx))
                _update_rhs_bounds(bounds, con_obj, (const_key, idx))
            end
        end
        return bounds
    end
end

function get_variable_numerical_bounds(model::OperationsProblem; verbose = false)
    if verbose
        variable_bounds = Dict()
        for (variable_key, variable_array) in
            get_variables(get_optimization_container(model))
            bounds = VariableBounds()
            for idx in Iterators.product(variable_array.axes...)
                var = variable_array[idx...]
                _update_variable_bounds(bounds, var, idx)
            end
            variable_bounds[variable_key] = bounds
        end
        return variable_bounds
    else
        bounds = VariableBounds()
        for (variable_key, variable_array) in
            get_variables(get_optimization_container(model))
            for idx in Iterators.product(variable_array.axes...)
                var = variable_array[idx...]
                _update_variable_bounds(bounds, var, (variable_key, idx))
            end
        end
        return bounds
    end
end
