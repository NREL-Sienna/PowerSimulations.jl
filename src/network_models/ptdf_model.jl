function ptdf_networkflow(canonical_model::CanonicalModel,
                          branches::IS.FlattenIteratorWrapper{B},
                          buses::IS.FlattenIteratorWrapper{PSY.Bus},
                          expression::Symbol,
                          PTDF::PSY.PTDF) where {B<:PSY.Branch}

    time_steps = model_time_steps(canonical_model)
    _add_cons_container!(canonical_model, :network_flow, PTDF.axes[1], time_steps)
    _add_cons_container!(canonical_model, :nodal_balance, PTDF.axes[2], time_steps)
    network_flow = con(canonical_model, :network_flow)
    nodal_balance = con(canonical_model, :nodal_balance)
    nodal_balance_expressions = canonical_model.expressions[expression]

    branch_types = typeof.(branches)

    _remove_undef!(nodal_balance_expressions)

    var_dict = Dict{Type, Symbol}()
    for btype in Set(branch_types)
        var_dict[btype] = Symbol("Fp_$(btype)")
        typed_branches = IS.FlattenIteratorWrapper(btype,
                                           Vector([[b for b in branches if isa(b, btype)]]))
        flow_variables!(canonical_model, StandardPTDFModel, typed_branches)
    end

    for t in time_steps
        for br in branches
            flow_variable = canonical_model.variables[var_dict[typeof(br)]]
            name = PSY.get_name(br)
            flow_expression =
                sum(PTDF[name, PSY.get_number(b)]*nodal_balance_expressions[PSY.get_number(b), t] for b in buses)
            network_flow[name, t] = JuMP.@constraint(canonical_model.JuMPmodel,
                                                  flow_variable[name, t] == flow_expression)
        end

# The process is done in two separate loops to avoid modifying the nodal_balance_expressions
# before making the flow constraints. If this two operations are done in the same loop
# then the PTDF will multiply an expression that contains the flow variable.
        for br in branches
            name = PSY.get_name(br)
            from_number = PSY.get_number(PSY.get_arc(br).from)
            to_number = PSY.get_number(PSY.get_arc(br).to)
            flow_variable = canonical_model.variables[var_dict[typeof(br)]]
            _add_to_expression!(nodal_balance_expressions,
                                from_number, t, flow_variable[name, t], -1.0)
            _add_to_expression!(nodal_balance_expressions,
                                to_number, t, flow_variable[name, t], 1.0)

        end

        for b in buses
            number = PSY.get_number(b)
            nodal_balance[number, t] = JuMP.@constraint(canonical_model.JuMPmodel,
                                       nodal_balance_expressions[number, t] == 0)
        end
    end

    return

end
