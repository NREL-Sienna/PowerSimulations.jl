# The Numerical stability checks code in this file is based on the code from the SDDP.jl package,
# from the below mentioned commit and file.
# commit :8cd305188caffc50a1734913053fc81bba613778
# link to file :https://github.com/odow/SDDP.jl/blob/d353fe5a2903421e7fed6d609eb9377c35d715a1/src/print.jl#L190

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

function update_coefficient_bounds(
    v::ConstraintBounds,
    constraint::JuMP.ScalarConstraint,
    idx,
)
    update_numerical_bounds(v.coefficient, constraint.func, idx)
    return
end

function update_rhs_bounds(v::ConstraintBounds, constraint::JuMP.ScalarConstraint, idx)
    update_numerical_bounds(v.rhs, constraint.set, idx)
    return
end

mutable struct VariableBounds
    bounds::NumericalBounds
    function VariableBounds()
        return new(NumericalBounds())
    end
end

function update_variable_bounds(v::VariableBounds, variable::JuMP.VariableRef, idx)
    if JuMP.is_binary(variable)
        set_min!(v.bounds, 0.0)
        update_numerical_bounds(v.bounds, 1.0, idx)
    else
        if JuMP.has_lower_bound(variable)
            update_numerical_bounds(v.bounds, JuMP.lower_bound(variable), idx)
        end
        if JuMP.has_upper_bound(variable)
            update_numerical_bounds(v.bounds, JuMP.upper_bound(variable), idx)
        end
    end
    return
end

function update_numerical_bounds(v::NumericalBounds, value::Real, idx)
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

function update_numerical_bounds(bonuds::NumericalBounds, func::JuMP.GenericAffExpr, idx)
    for coefficient in values(func.terms)
        update_numerical_bounds(bonuds, coefficient, idx)
    end
    return
end

function update_numerical_bounds(bonuds::NumericalBounds, func::MOI.LessThan, idx)
    return update_numerical_bounds(bonuds, func.upper, idx)
end

function update_numerical_bounds(bonuds::NumericalBounds, func::MOI.GreaterThan, idx)
    return update_numerical_bounds(bonuds, func.lower, idx)
end

function update_numerical_bounds(bonuds::NumericalBounds, func::MOI.EqualTo, idx)
    return update_numerical_bounds(bonuds, func.value, idx)
end

function update_numerical_bounds(bonuds::NumericalBounds, func::MOI.Interval, idx)
    update_numerical_bounds(bonuds, func.upper, idx)
    return update_numerical_bounds(bonuds, func.lower, idx)
end

# Default fallback for unsupported constraints.
update_numerical_bounds(::NumericalBounds, func, idx) = nothing

function get_constraint_numerical_bounds(model::OperationModel)
    if !is_built(model)
        error("Model not built, can't calculate constraint numerical bounds")
    end
    bounds = ConstraintBounds()
    for (const_key, constraint_array) in get_constraints(get_optimization_container(model))
        # TODO: handle this at compile and not at run time
        if isa(constraint_array, SparseAxisArray)
            for idx in eachindex(constraint_array)
                constraint_array[idx] == 0.0 && continue
                con_obj = JuMP.constraint_object(constraint_array[idx])
                update_coefficient_bounds(bounds, con_obj, (const_key, idx))
                update_rhs_bounds(bounds, con_obj, (const_key, idx))
            end
        else
            for idx in Iterators.product(constraint_array.axes...)
                !isassigned(constraint_array, idx...) && continue
                con_obj = JuMP.constraint_object(constraint_array[idx...])
                update_coefficient_bounds(bounds, con_obj, (const_key, idx))
                update_rhs_bounds(bounds, con_obj, (const_key, idx))
            end
        end
    end
    return bounds
end

function get_variable_numerical_bounds(model::OperationModel)
    if !is_built(model)
        error("Model not built, can't calculate variable numerical bounds")
    end
    bounds = VariableBounds()
    for (variable_key, variable_array) in get_variables(get_optimization_container(model))
        if isa(variable_array, SparseAxisArray)
            for idx in eachindex(variable_array)
                var = variable_array[idx]
                var == 0.0 && continue
                update_variable_bounds(bounds, var, (variable_key, idx))
            end
        else
            for idx in Iterators.product(variable_array.axes...)
                var = variable_array[idx...]
                update_variable_bounds(bounds, var, (variable_key, idx))
            end
        end
    end
    return bounds
end
