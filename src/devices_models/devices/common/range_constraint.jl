""" Data Container to construct range constraints"""
struct DeviceRange
    names::Vector{String}
    values::Vector{MinMax}
    additional_terms_ub::Vector{Vector{Symbol}}
    additional_terms_lb::Vector{Vector{Symbol}}
end

function DeviceRange(count::Int64)
    names = Vector{String}(undef, count)
    limit_values = Vector{MinMax}(undef, count)
    additional_terms_ub = fill(Vector{Symbol}(), count)
    additional_terms_lb = fill(Vector{Symbol}(), count)
    return DeviceRange(names, limit_values, additional_terms_ub, additional_terms_lb)
end

@doc raw"""
    device_range(psi_container::PSIContainer,
                 range_data::DeviceRange,
                 cons_name::Symbol,
                 var_name::Symbol)

Constructs min/max range constraint from device variable.

# Constraints
If min and max within an epsilon width:

``` variable[name, t] == limits.max ```

Otherwise:

``` limits.min <= variable[name, t] <= limits.max ```

where limits in range_data.

# LaTeX

`` x = limits^{max}, \text{ for } |limits^{max} - limits^{min}| < \varepsilon ``

`` limits^{min} \leq x \leq limits^{max}, \text{ otherwise } ``

# Arguments
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* range_data::DeviceRange : contains names and vector of min/max
* cons_name::Symbol : name of the constraint
* var_name::Symbol : the name of the continuous variable
"""
function device_range(psi_container::PSIContainer,
                      range_data::DeviceRange,
                      cons_name::Symbol,
                      var_name::Symbol)
    @show range_data
    time_steps = model_time_steps(psi_container)
    variable = get_variable(psi_container, var_name)
    ub_name = _middle_rename(cons_name, "_", "ub")
    lb_name = _middle_rename(cons_name, "_", "lb")
    con_ub = add_cons_container!(psi_container, ub_name, range_data.names, time_steps)
    con_lb = add_cons_container!(psi_container, lb_name, range_data.names, time_steps)

    for (ix, name) in enumerate(range_data.names)
        limits = range_data.values[ix]
        for t in time_steps
            expression_ub = JuMP.AffExpr(0.0, variable[name, t] => 1.0)
            for val in range_data.additional_terms_ub[ix]
                JuMP.add_to_expression!(expression_ub, get_variable(psi_container, val)[name, t])
            end
            expression_lb = JuMP.AffExpr(0.0, variable[name, t] => 1.0)
            for val in range_data.additional_terms_lb[ix]
                JuMP.add_to_expression!(expression_lb, get_variable(psi_container, val)[name, t])
            end
            con_ub[name, t] = JuMP.@constraint(psi_container.JuMPmodel, expression_ub <= limits.max)
            con_lb[name, t] = JuMP.@constraint(psi_container.JuMPmodel, expression_lb >= limits.min)
        end
    end

    return
end

@doc raw"""
    device_semicontinuousrange(psi_container::PSIContainer,
                                    sc_range_data::DeviceRange,
                                    cons_name::Symbol,
                                    var_name::Symbol,
                                    binvar_name::Symbol)

Constructs min/max range constraint from device variable and on/off decision variable.

# Constraints
If device min = 0:

``` varcts[name, t] <= limits.max*varbin[name, t]) ```

``` varcts[name, t] >= 0.0 ```

Otherwise:

``` varcts[name, t] <= limits.max*varbin[name, t] ```

``` varcts[name, t] >= limits.min*varbin[name, t] ```

where limits in sc_range_data.

# LaTeX

`` 0 \leq x^{cts} \leq limits^{max} x^{bin}, \text{ for } limits^{min} = 0 ``

`` limits^{min} x^{bin} \leq x^{cts} \leq limits^{max} x^{bin}, \text{ otherwise } ``

# Arguments
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* sc_range_data::DeviceRange : contains names and vector of min/max
* cons_name::Symbol : name of the constraint
* var_name::Symbol : the name of the continuous variable
* binvar_name::Symbol : the name of the binary variable
"""
function device_semicontinuousrange(psi_container::PSIContainer,
                                    sc_range_data::DeviceRange,
                                    cons_name::Symbol,
                                    var_name::Symbol,
                                    binvar_name::Symbol)
    time_steps = model_time_steps(psi_container)
    varcts = get_variable(psi_container, var_name)
    varbin = get_variable(psi_container, binvar_name)
    ub_name = _middle_rename(cons_name, "_", "ub")
    lb_name = _middle_rename(cons_name, "_", "lb")
    #MOI has a semicontinous set, but after some tests is not clear most MILP solvers support it.
    #In the future this can be updated
    con_ub = add_cons_container!(psi_container, ub_name, sc_range_data.names, time_steps)
    con_lb = add_cons_container!(psi_container, lb_name, sc_range_data.names, time_steps)

    for (ix, name) in enumerate(sc_range_data.names)
        limits = sc_range_data.values[ix]
        for t in time_steps
            if JuMP.has_lower_bound(varcts[name, t])
                JuMP.set_lower_bound(varcts[name, t], 0.0)
            end
            expression_ub = JuMP.AffExpr(0.0, varcts[name, t] => 1.0)
            for val in range_data.additional_terms_ub[ix]
                JuMP.add_to_expression!(expression_ub, get_variable(psi_container, val)[name, t])
            end
            expression_lb = JuMP.AffExpr(0.0, varcts[name, t] => 1.0)
            for val in range_data.additional_terms_lb[ix]
                JuMP.add_to_expression!(expression_lb, get_variable(psi_container, val)[name, t])
            end
            con_ub[name, t] = JuMP.@constraint(psi_container.JuMPmodel, expression_ub <= limits.max*varbin[name, t])
            con_lb[name, t] = JuMP.@constraint(psi_container.JuMPmodel, expression_lb >= limits.min*varbin[name, t])
        end
    end

    return
end

@doc raw"""
    reserve_device_semicontinuousrange(psi_container::PSIContainer,
                                    sc_range_data::DeviceRange,
                                    cons_name::Symbol,
                                    var_name::Symbol,
                                    binvar_name::Symbol)

Constructs min/max range constraint from device variable and on/off decision variable.

# Constraints
If device min = 0:

``` varcts[name, t] <= limits.max*(1-varbin[name, t]) ```

``` varcts[name, t] >= 0.0 ```

Otherwise:

``` varcts[name, t] <= limits.max*(1-varbin[name, t]) ```

``` varcts[name, t] >= limits.min*(1-varbin[name, t]) ```

where limits in range_data.

# LaTeX

`` 0 \leq x^{cts} \leq limits^{max} (1 - x^{bin} ), \text{ for } limits^{min} = 0 ``

`` limits^{min} (1 - x^{bin} ) \leq x^{cts} \leq limits^{max} (1 - x^{bin} ), \text{ otherwise } ``

# Arguments
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* sc_range_data::DeviceRange : contains names and vector of min/max
* cons_name::Symbol : name of the constraint
* var_name::Symbol : the name of the continuous variable
* binvar_name::Symbol : the name of the binary variable
"""
#This function looks suspicious and repetittive. Needs verification
function reserve_device_semicontinuousrange(psi_container::PSIContainer,
                                            sc_range_data::DeviceRange,
                                            cons_name::Symbol,
                                            var_name::Symbol,
                                            binvar_name::Symbol)

    time_steps = model_time_steps(psi_container)
    varcts = get_variable(psi_container, var_name)
    varbin = get_variable(psi_container, binvar_name)

    ub_name = _middle_rename(cons_name, "_", "ub")
    lb_name = _middle_rename(cons_name, "_", "lb")
    #MOI has a semicontinous set, but after some tests is not clear most MILP solvers support it.
    #In the future this can be updated
    con_ub = add_cons_container!(psi_container, ub_name, sc_range_data.names, time_steps)
    con_lb = add_cons_container!(psi_container, lb_name, sc_range_data.names, time_steps)

    for (ix, name) in enumerate(sc_range_data.names)
        limits = sc_range_data.values[ix]
        for t in time_steps
            if JuMP.has_lower_bound(varcts[name, t])
                JuMP.set_lower_bound(varcts[name, t], 0.0)
            end
            expression_ub = JuMP.AffExpr(0.0, varcts[name, t] => 1.0)
            for val in range_data.additional_terms_ub[ix]
                JuMP.add_to_expression!(expression_ub, get_variable(psi_container, val)[name, t])
            end
            expression_lb = JuMP.AffExpr(0.0, varcts[name, t] => 1.0)
            for val in range_data.additional_terms_lb[ix]
                JuMP.add_to_expression!(expression_lb, get_variable(psi_container, val)[name, t])
            end
            con_ub[name, t] = JuMP.@constraint(psi_container.JuMPmodel, expression_ub <= limits.max*(1-varbin[name, t]))
            con_lb[name, t] = JuMP.@constraint(psi_container.JuMPmodel, expression_lb >= limits.min*(1-varbin[name, t]))
        end
    end
    return
 end
