function ptdf_networkflow(canonical_model::CanonicalModel,
                          branches::IS.FlattenIteratorWrapper{B},
                          buses::IS.FlattenIteratorWrapper{PSY.Bus},
                          expression::Symbol,
                          PTDF::PSY.PTDF) where {B<:PSY.Branch}

    time_steps = model_time_steps(canonical_model)
    canonical_model.constraints[:network_flow] = JuMPConstraintArray(undef, PTDF.axes[1], time_steps)
    canonical_model.constraints[:nodal_balance] = JuMPConstraintArray(undef, PTDF.axes[2], time_steps)
    branch_types = typeof.(branches)

    _remove_undef!(canonical_model.expressions[expression])

    var_dict = Dict{Type,Symbol}()
    for btype in Set(branch_types)
        var_dict[btype] = Symbol("Fp_$(btype)")
        typed_branches = IS.FlattenIteratorWrapper(btype, Vector([[b for b in branches if typeof(b) == btype]]))
        flow_variables(canonical_model, StandardPTDFModel, typed_branches)
    end

    for t in time_steps
        for br in branches
            flow_expression = sum(PTDF[PSY.get_name(br), PSY.get_number(b)]*canonical_model.expressions[expression].data[PSY.get_number(b), t] for b in buses)
            canonical_model.constraints[:network_flow][PSY.get_name(br), t] = JuMP.@constraint(canonical_model.JuMPmodel, canonical_model.variables[var_dict[typeof(br)]][PSY.get_name(br), t] == flow_expression)
        end

        for br in branches
            _add_to_expression!(canonical_model.expressions[expression], (PSY.get_arc(br)).from |> PSY.get_number, t, canonical_model.variables[var_dict[typeof(br)]][PSY.get_name(br), t], -1.0)
            _add_to_expression!(canonical_model.expressions[expression], (PSY.get_arc(br)).to |> PSY.get_number, t, canonical_model.variables[var_dict[typeof(br)]][PSY.get_name(br), t], 1.0)
        end

        for b in buses
            canonical_model.constraints[:nodal_balance][PSY.get_number(b), t] = JuMP.@constraint(canonical_model.JuMPmodel, canonical_model.expressions[expression][PSY.get_number(b), t] == 0)
        end
    end

    return

end
