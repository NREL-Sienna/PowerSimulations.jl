abstract type AbstractDCLineForm <: AbstractBranchFormulation end

struct HVDCLossless <: AbstractDCLineForm end

struct HVDCDispatch <: AbstractDCLineForm end

struct VoltageSourceDC <: AbstractDCLineForm end


function flow_variables(ps_m::CanonicalModel,
                        system_formulation::Type{S},
                        devices::PSY.FlattenedVectorsIterator{B}) where {B <: PSY.DCBranch,
                                                                        S <: PM.AbstractPowerFormulation}
                                                     
    return                                                             

end

function flow_variables(ps_m::CanonicalModel,
                        system_formulation::Type{StandardPTDFForm},
                        devices::PSY.FlattenedVectorsIterator{B}) where {B <: PSY.DCBranch}

    time_steps = model_time_steps(ps_m)                          
    var_name = Symbol("Fp_$(B)")
    ps_m.variables[var_name] = PSI._container_spec(ps_m.JuMPmodel,
                                                  (d.name for d in devices),
                                                   time_steps)

    for d in devices
        bus_fr = d.connectionpoints.from.number
        bus_to = d.connectionpoints.to.number
        for t in time_steps
            ps_m.variables[var_name][d.name,t] = JuMP.@variable(ps_m.JuMPmodel,
                                                                base_name="$(bus_fr),$(bus_to)_{$(d.name),$(t)}")
            _add_to_expression!(ps_m.expressions[:nodal_balance_active], 
                                d.connectionpoints.from.number, 
                                t, 
                                ps_m.variables[var_name][d.name,t], 
                                -1.0)
            _add_to_expression!(ps_m.expressions[:nodal_balance_active], 
                                d.connectionpoints.to.number, 
                                t, 
                                ps_m.variables[var_name][d.name,t], 
                                1.0)
        end
    end

    return                                                             

end

function branch_rate_constraint(ps_m::CanonicalModel,
                                devices::PSY.FlattenedVectorsIterator{B},
                                device_formulation::Type{HVDCLossless},
                                system_formulation::Type{StandardPTDFForm}) where {B <: PSY.DCBranch}

    var_name = Symbol("Fp_$(B)")
    con_name = Symbol("rate_limit_$(B)")                                                                
    time_steps = model_time_steps(ps_m)                        
    ps_m.constraints[con_name] = JuMPConstraintArray(undef, (d.name for d in devices), time_steps)

    for t in time_steps, d in devices
        min_rate = max(d.activepowerlimits_from.min, d.activepowerlimits_to.min)
        max_rate = min(d.activepowerlimits_from.max, d.activepowerlimits_to.max)
        ps_m.constraints[con_name][d.name, t] = JuMP.@constraint(ps_m.JuMPmodel, min_rate <= ps_m.variables[var_name][d.name, t] <= max_rate)
    end

    return

end


function branch_rate_constraint(ps_m::CanonicalModel,
                                devices::PSY.FlattenedVectorsIterator{B},
                                device_formulation::Type{HVDCDispatch},
                                system_formulation::Type{StandardPTDFForm}) where {B <: PSY.DCBranch}

    var_name = Symbol("Fp_$(B)")
    con_name = Symbol("rate_limit_$(B)")                                                                
    time_steps = model_time_steps(ps_m)                        
    ps_m.constraints[con_name] = JuMPConstraintArray(undef, (d.name for d in devices), time_steps)

    for t in time_steps, d in devices
        min_rate = max(d.activepowerlimits_from.min, d.activepowerlimits_to.min)
        max_rate = min(d.activepowerlimits_from.max, d.activepowerlimits_to.max)
        ps_m.constraints[con_name][d.name, t] = JuMP.@constraint(ps_m.JuMPmodel, min_rate <= ps_m.variables[var_name][d.name, t] <= max_rate)
        _add_to_expression!(ps_m.expressions[:nodal_balance_active], 
                            d.connectionpoints.to.number, 
                            t, 
                            ps_m.variables[var_name][d.name,t], 
                            -d.loss.l1,
                            -d.loss.l0)
    end

    return

end
