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
        for b in branches
            canonical_model.constraints[:network_flow][PSY.get_name(b), t] = JuMP.@constraint(canonical_model.JuMPmodel, canonical_model.variables[var_dict[typeof(b)]][PSY.get_name(b), t] == PTDF[PSY.get_name(b), :]'*canonical_model.expressions[expression].data[:, t])
        end

        for b in branches
            _add_to_expression!(canonical_model.expressions[expression], (PSY.get_arc(b)).from |> PSY.get_number, t, canonical_model.variables[var_dict[typeof(b)]][PSY.get_name(b), t], -1.0)
            _add_to_expression!(canonical_model.expressions[expression], (PSY.get_arc(b)).to |> PSY.get_number, t, canonical_model.variables[var_dict[typeof(b)]][PSY.get_name(b), t], 1.0)
        end

        for b in buses
            canonical_model.constraints[:nodal_balance][PSY.get_number(b), t] = JuMP.@constraint(canonical_model.JuMPmodel, canonical_model.expressions[expression][PSY.get_number(b), t] == 0)
        end
    end

    return

end

#=
The previous implementation of the PTDF constraints showed to be faster in the 5 bus system. I have added
another implementatio for further testing with larger systems

 ─────────────────────────────────────────────────────────────────────────────

The first implementation, above was tested this way with the respective results

to = TimerOutput()

@timeit to "canonical_model"   ps_m = CanonicalModel(Model(ipopt_optimizer),
                              Dict{String, JuMP.Containers.DenseAxisArray{JuMP.VariableRef}}(),
                              Dict{String, JuMP.Containers.DenseAxisArray}(),
                              nothing,
                              Dict{Symbol, JuMPAffineExpressionArray}(:nodal_balance_active => JuMPAffineExpressionArray(undef, 5, 24),
                                                                         :nodal_balance_reactive => JuMPAffineExpressionArray(undef, 5, 24)),
                              nothing);
@timeit to "build_thermal"    construct_device!(canonical_model, PSY.ThermalGen, ThermalDispatch, PM.StandardACPModel, sys5b);
@timeit to "build_load"    construct_device!(canonical_model, PSY.PowerLoad, StaticPowerLoad, PM.StandardACPModel, sys5b);
@timeit to "add_flow"      flow_variables(canonical_model, PM.DCPPowerModel, branches5, 1:24)
@timeit to "PTDF cons" begin
    @timeit to "allocate_space" canonical_model.constraints["Flow_con1"] = JuMPConstraintArray(undef, [b.name for b in branches5], 1:24)
    @timeit to "make constraints" for t in 1:24
                                    for b in branches5
                                        canonical_model.constraints["Flow_con1"][b.name, t] = JuMP.@constraint(canonical_model.JuMPmodel, canonical_model.variables[key][b.name, t] == PTDF[b.name, :].data'*canonical_model.expressions[:nodal_balance_active][:, t])
                                    end
                                end
                            end

 ─────────────────────────────────────────────────────────────────────────────
                                      Time                   Allocations
                              ──────────────────────   ───────────────────────
       Tot / % measured:           305ms / 12.3%           4.78MiB / 91.0%

 Section              ncalls     time   %tot     avg     alloc   %tot      avg
 ─────────────────────────────────────────────────────────────────────────────
 PTDF cons                 1   35.7ms  95.2%  35.7ms   3.30MiB  75.8%  3.30MiB
   allocate_space          1   33.3ms  88.6%  33.3ms   2.82MiB  64.8%  2.82MiB
   make constraints        1   2.43ms  6.47%  2.43ms    488KiB  11.0%   488KiB
 build_thermal             1   1.39ms  3.71%  1.39ms    904KiB  20.3%   904KiB
 add_flow                  1    221μs  0.59%   221μs   64.8KiB  1.45%  64.8KiB
 canonical_model           1    133μs  0.36%   133μs   46.3KiB  1.04%  46.3KiB
 build_load                1   62.3μs  0.17%  62.3μs   63.8KiB  1.43%  63.8KiB
 ─────────────────────────────────────────────────────────────────────────────

 ─────────────────────────────────────────────────────────────────────────────


 The second implementation and the results are as follows:

 to = TimerOutput()

@timeit to "canonical_model"   ps_m = CanonicalModel(Model(ipopt_optimizer),
                              Dict{String, JuMP.Containers.DenseAxisArray{JuMP.VariableRef}}(),
                              Dict{String, JuMP.Containers.DenseAxisArray}(),
                              nothing,
                              Dict{Symbol, JuMPAffineExpressionArray}(:nodal_balance_active => JuMPAffineExpressionArray(undef, 5, 24),
                                                                         :nodal_balance_reactive => JuMPAffineExpressionArray(undef, 5, 24)),
                              nothing);
@timeit to "build_thermal"    construct_device!(canonical_model, PSY.ThermalGen, ThermalDispatch, PM.StandardACPModel, sys5b);
@timeit to "build_load"    construct_device!(canonical_model, PSY.PowerLoad, StaticPowerLoad, PM.StandardACPModel, sys5b);
@timeit to "add_flow"      flow_variables(canonical_model, PM.DCPPowerModel, branches5, 1:24)
@timeit to "PTDF cons" begin
    @timeit to "allocate_space" canonical_model.constraints["Flow_con2"] = JuMPConstraintArray(undef, [b.name for b in branches5], 1:24)
    @timeit to "make constraints" begin for t in 1:24
            for b in branches5
                expr = JuMP.AffExpr(0.0, canonical_model.variables[key][b.name, t] => 1.0)
                    for n in nodes5
                        JuMP.add_to_expression!(expr, -1*PTDF[b.name, :].data[n.number]*canonical_model.expressions[:nodal_balance_active][n.number, t])
                    end
                canonical_model.constraints["Flow_con2"][b.name, t] = JuMP.@constraint(canonical_model.JuMPmodel, expr == 0.0)
        end
    end
    end
end

 ─────────────────────────────────────────────────────────────────────────────
                                      Time                   Allocations
                              ──────────────────────   ───────────────────────
       Tot / % measured:           1.25s / 2.48%           5.10MiB / 90.9%

 Section              ncalls     time   %tot     avg     alloc   %tot      avg
 ─────────────────────────────────────────────────────────────────────────────
 PTDF cons                 1   29.0ms  93.9%  29.0ms   3.58MiB  77.3%  3.58MiB
   allocate_space          1   24.8ms  80.2%  24.8ms   2.82MiB  60.8%  2.82MiB
   make constraints        1   4.19ms  13.5%  4.19ms    781KiB  16.4%   781KiB
 build_thermal             1   1.40ms  4.54%  1.40ms    904KiB  19.0%   904KiB
 add_flow                  1    267μs  0.86%   267μs   64.8KiB  1.36%  64.8KiB
 canonical_model           1    136μs  0.44%   136μs   46.3KiB  0.98%  46.3KiB
 build_load                1   94.2μs  0.30%  94.2μs   63.8KiB  1.34%  63.8KiB
 ─────────────────────────────────────────────────────────────────────────────

 =#
