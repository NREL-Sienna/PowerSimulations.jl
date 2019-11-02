abstract type AbstractDCLineFormulation <: AbstractBranchFormulation end

struct HVDCLossless <: AbstractDCLineFormulation end

struct HVDCDispatch <: AbstractDCLineFormulation end

struct VoltageSourceDC <: AbstractDCLineFormulation end

#################################### Branch Variables ##################################################

function flow_variables!(canonical::Canonical,
                        system_formulation::Type{S},
                        devices::IS.FlattenIteratorWrapper{B}) where {B<:PSY.DCBranch,
                                                                        S<:PM.AbstractPowerModel}

    return

end

function flow_variables!(canonical::Canonical,
                        system_formulation::Type{StandardPTDFModel},
                        devices::IS.FlattenIteratorWrapper{B}) where {B<:PSY.DCBranch}

    time_steps = model_time_steps(canonical)
    var_name = Symbol("Fp_$(B)")
    canonical.variables[var_name] = PSI._container_spec(canonical.JuMPmodel,
                                                  (PSY.get_name(d) for d in devices),
                                                   time_steps)

    for d in devices
        bus_fr = PSY.get_number(PSY.get_arc(d).from)
        bus_to = PSY.get_number(PSY.get_arc(d).to)
        for t in time_steps
            canonical.variables[var_name][PSY.get_name(d), t] = JuMP.@variable(canonical.JuMPmodel,
                                                                base_name="$(bus_fr), $(bus_to)_{$(PSY.get_name(d)), $(t)}")
            _add_to_expression!(canonical.expressions[:nodal_balance_active],
                                PSY.get_number(PSY.get_arc(d).from),
                                t,
                                canonical.variables[var_name][PSY.get_name(d), t],
                                -1.0)
            _add_to_expression!(canonical.expressions[:nodal_balance_active],
                                PSY.get_number(PSY.get_arc(d).to),
                                t,
                                canonical.variables[var_name][PSY.get_name(d), t],
                                1.0)
        end
    end

    return

end

#################################### Flow Variable Bounds ##################################################


#################################### Rate Limits Constraints ##################################################

function branch_rate_constraint!(canonical::Canonical,
                                devices::IS.FlattenIteratorWrapper{B},
                                device_formulation::Type{D},
                                system_formulation::Type{S}) where {B<:PSY.DCBranch,
                                                                    D<:AbstractDCLineFormulation,
                                                                    S<:PM.AbstractDCPModel}

    var_name = Symbol("Fp_$(B)")
    con_name = Symbol("RateLimit_$(B)")
    time_steps = model_time_steps(canonical)
    canonical.constraints[con_name] = JuMPConstraintArray(undef, (PSY.get_name(d) for d in devices), time_steps)

    for t in time_steps, d in devices
        min_rate = max(PSY.get_activepowerlimits_from(d).min, PSY.get_activepowerlimits_to(d).min)
        max_rate = min(PSY.get_activepowerlimits_from(d).max, PSY.get_activepowerlimits_to(d).max)
        canonical.constraints[con_name][PSY.get_name(d), t] = JuMP.@constraint(canonical.JuMPmodel, min_rate <= canonical.variables[var_name][PSY.get_name(d), t] <= max_rate)
    end

    return

end

function branch_rate_constraint!(canonical::Canonical,
                                devices::IS.FlattenIteratorWrapper{B},
                                device_formulation::Type{HVDCLossless},
                                system_formulation::Type{S}) where {B<:PSY.DCBranch,
                                                                    S<:PM.AbstractActivePowerModel}

    for dir in ("FT", "TF")
        var_name = Symbol("Fp$(dir)_$(B)")
        con_name = Symbol("RateLimit_$(dir)_$(B)")
        time_steps = model_time_steps(canonical)
        canonical.constraints[con_name] = JuMPConstraintArray(undef, (PSY.get_name(d) for d in devices), time_steps)

        for t in time_steps, d in devices
            min_rate = max(PSY.get_activepowerlimits_from(d).min, PSY.get_activepowerlimits_to(d).min)
            max_rate = min(PSY.get_activepowerlimits_from(d).max, PSY.get_activepowerlimits_to(d).max)
            name = PSY.get_name(d)
            canonical.constraints[con_name][name, t] = JuMP.@constraint(canonical.JuMPmodel, min_rate <= canonical.variables[var_name][name, t] <= max_rate)
        end
    end

    return

end

function branch_rate_constraint!(canonical::Canonical,
                                devices::IS.FlattenIteratorWrapper{B},
                                device_formulation::Type{HVDCLossless},
                                system_formulation::Type{S}) where {B<:PSY.DCBranch,
                                                                    S<:PM.AbstractPowerModel}

    for dir in ("FT", "TF")
        var_name = Symbol("Fp$(dir)_$(B)")
        con_name = Symbol("RateLimit_$(dir)_$(B)")
        time_steps = model_time_steps(canonical)
        canonical.constraints[con_name] = JuMPConstraintArray(undef, (PSY.get_name(d) for d in devices), time_steps)

        for t in time_steps, d in devices
            min_rate = max(PSY.get_activepowerlimits_from(d).min, PSY.get_activepowerlimits_to(d).min)
            max_rate = min(PSY.get_activepowerlimits_from(d).max, PSY.get_activepowerlimits_to(d).max)
            name = PSY.get_name(d)
            canonical.constraints[con_name][name, t] = JuMP.@constraint(canonical.JuMPmodel, min_rate <= canonical.variables[var_name][name, t] <= max_rate)
        end
    end

    return

end

function branch_rate_constraint!(canonical::Canonical,
                                devices::IS.FlattenIteratorWrapper{B},
                                device_formulation::Type{D},
                                system_formulation::Type{S}) where {B<:PSY.DCBranch,
                                                                    D<:AbstractDCLineFormulation,
                                                                    S<:PM.AbstractActivePowerModel}

    time_steps = model_time_steps(canonical)

    for dir in ("FT", "TF")
        var_name = Symbol("Fp$(dir)_$(B)")
        con_name = Symbol("RateLimit$(dir)_$(B)")
        canonical.constraints[con_name] = JuMPConstraintArray(undef, (PSY.get_name(d) for d in devices), time_steps)

        for t in time_steps, d in devices
            min_rate = max(PSY.get_activepowerlimits_from(d).min, PSY.get_activepowerlimits_to(d).min)
            max_rate = min(PSY.get_activepowerlimits_from(d).max, PSY.get_activepowerlimits_to(d).max)
            canonical.constraints[con_name][PSY.get_name(d), t] = JuMP.@constraint(canonical.JuMPmodel, min_rate <= canonical.variables[var_name][PSY.get_name(d), t] <= max_rate)
            _add_to_expression!(canonical.expressions[:nodal_balance_active],
                                PSY.get_number(PSY.get_arc(d).to),
                                t,
                                canonical.variables[var_name][PSY.get_name(d), t],
                                -PSY.get_loss(d).l1,
                                -PSY.get_loss(d).l0)
        end
    end

    return

end

function branch_rate_constraint!(canonical::Canonical,
                                devices::IS.FlattenIteratorWrapper{B},
                                device_formulation::Type{D},
                                system_formulation::Type{S}) where {B<:PSY.DCBranch,
                                                                    D<:AbstractDCLineFormulation,
                                                                    S<:PM.AbstractPowerModel}

    time_steps = model_time_steps(canonical)

    for dir in ("FT", "TF")
        var_name = Symbol("Fp$(dir)_$(B)")
        con_name = Symbol("RateLimit$(dir)_$(B)")
        canonical.constraints[con_name] = JuMPConstraintArray(undef, (PSY.get_name(d) for d in devices), time_steps)

        for t in time_steps, d in devices
            min_rate = max(PSY.get_activepowerlimits_from(d).min, PSY.get_activepowerlimits_to(d).min)
            max_rate = min(PSY.get_activepowerlimits_from(d).max, PSY.get_activepowerlimits_to(d).max)
            canonical.constraints[con_name][PSY.get_name(d), t] = JuMP.@constraint(canonical.JuMPmodel, min_rate <= canonical.variables[var_name][PSY.get_name(d), t] <= max_rate)
            _add_to_expression!(canonical.expressions[:nodal_balance_active],
                                PSY.get_number(PSY.get_arc(d).to),
                                t,
                                canonical.variables[var_name][PSY.get_name(d), t],
                                -PSY.get_loss(d).l1,
                                -PSY.get_loss(d).l0)
        end
    end

    return

end
