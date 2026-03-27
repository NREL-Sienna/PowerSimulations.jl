function process_duals(container::OptimizationContainer, lp_optimizer)
    var_container = get_variables(container)
    for (k, v) in var_container
        if isa(v, JuMP.Containers.SparseAxisArray)
            container.primal_values_cache.variables_cache[k] = jump_value.(v)
            for idx in eachindex(v)
                container.primal_values_cache.variables_cache[k][idx] = jump_value(v[idx])
            end
        else
            container.primal_values_cache.variables_cache[k] = jump_value.(v)
        end
    end

    for (k, v) in get_expressions(container)
        container.primal_values_cache.expressions_cache[k] = jump_value.(v)
    end
    var_cache = container.primal_values_cache.variables_cache
    cache = sizehint!(Dict{VariableKey, Dict}(), length(var_container))
    for (key, variable) in get_variables(container)
        is_integer_flag = false
        is_binary_flag = false
        if isa(variable, JuMP.Containers.SparseAxisArray)
            continue
        else
            if JuMP.is_binary(first(variable))
                JuMP.unset_binary.(variable)
                is_binary_flag = true
            elseif JuMP.is_integer(first(variable))
                JuMP.unset_integer.(variable)
                is_integer_flag = true
            else
                continue
            end
            cache[key] = Dict{Symbol, Any}()
            if JuMP.has_lower_bound(first(variable))
                cache[key][:lb] = JuMP.lower_bound.(variable)
            end
            if JuMP.has_upper_bound(first(variable))
                cache[key][:ub] = JuMP.upper_bound.(variable)
            end
            if JuMP.is_fixed(first(variable)) && is_integer_flag
                cache[key][:fixed_int_value] = jump_value.(v)
            end
            cache[key][:integer] = is_integer_flag
            JuMP.fix.(variable, var_cache[key]; force = true)
        end
    end
    @assert !isempty(cache)
    jump_model = get_jump_model(container)

    if JuMP.mode(jump_model) != JuMP.DIRECT
        JuMP.set_optimizer(jump_model, lp_optimizer)
    else
        @debug("JuMP model set in direct mode during dual calculation")
    end

    JuMP.optimize!(jump_model)

    model_status = JuMP.primal_status(jump_model)
    if model_status ∉ [
        MOI.FEASIBLE_POINT::MOI.ResultStatusCode,
        MOI.NEARLY_FEASIBLE_POINT::MOI.ResultStatusCode,
    ]
        @error "Optimizer returned $model_status during dual calculation"
        return RunStatus.FAILED
    end

    if JuMP.has_duals(jump_model)
        for (key, dual) in get_duals(container)
            constraint = get_constraint(container, key)
            dual.data .= jump_value.(constraint).data
        end
    end

    for (key, variable) in get_variables(container)
        if !haskey(cache, key)
            continue
        end
        if isa(variable, JuMP.Containers.SparseAxisArray)
            continue
        else
            JuMP.unfix.(variable)
            JuMP.set_binary.(variable)
            if haskey(cache[key], :fixed_int_value)
                JuMP.fix.(variable, cache[key][:fixed_int_value])
            end
            #= Needed if a model has integer variables
            if haskey(cache[key], :lb) && JuMP.has_lower_bound(first(variable))
                JuMP.set_lower_bound.(variable, cache[key][:lb])
            end

            if haskey(cache[key], :ub) && JuMP.has_upper_bound(first(variable))
                JuMP.set_upper_bound.(variable, cache[key][:ub])
            end

            if cache[key][:integer]
                JuMP.set_integer.(variable)
            else
                JuMP.set_binary.(variable)
            end
            =#
        end
    end
    return RunStatus.SUCCESSFULLY_FINALIZED
end
