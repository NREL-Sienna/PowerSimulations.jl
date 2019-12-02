abstract type AbstractDCLineFormulation <: AbstractBranchFormulation end
struct HVDCLossless <: AbstractDCLineFormulation end
struct HVDCDispatch <: AbstractDCLineFormulation end
struct VoltageSourceDC <: AbstractDCLineFormulation end

#################################### Branch Variables ##################################################
flow_variables!(psi_container::PSIContainer,
                system_formulation::Type{<:PM.AbstractPowerModel},
                devices::IS.FlattenIteratorWrapper{<:PSY.DCBranch}) = nothing

function flow_variables!(psi_container::PSIContainer,
                        system_formulation::Type{StandardPTDFModel},
                        devices::IS.FlattenIteratorWrapper{B}) where B<:PSY.DCBranch
    time_steps = model_time_steps(psi_container)
    var_name = Symbol("Fp_$(B)")
    psi_container.variables[var_name] = _container_spec(psi_container.JuMPmodel,
                                                  (PSY.get_name(d) for d in devices),
                                                   time_steps)
    for d in devices
        bus_fr = PSY.get_number(PSY.get_arc(d).from)
        bus_to = PSY.get_number(PSY.get_arc(d).to)
        for t in time_steps
            psi_container.variables[var_name][PSY.get_name(d), t] = JuMP.@variable(psi_container.JuMPmodel,
                                                                base_name="$(bus_fr), $(bus_to)_{$(PSY.get_name(d)), $(t)}")
            _add_to_expression!(psi_container.expressions[:nodal_balance_active],
                                PSY.get_number(PSY.get_arc(d).from),
                                t,
                                psi_container.variables[var_name][PSY.get_name(d), t],
                                -1.0)
            _add_to_expression!(psi_container.expressions[:nodal_balance_active],
                                PSY.get_number(PSY.get_arc(d).to),
                                t,
                                psi_container.variables[var_name][PSY.get_name(d), t],
                                1.0)
        end
    end
    return
end

#################################### Flow Variable Bounds ##################################################
#################################### Rate Limits Constraints ##################################################
function branch_rate_constraint!(psi_container::PSIContainer,
                                devices::IS.FlattenIteratorWrapper{B},
                                device_formulation::Type{<:AbstractDCLineFormulation},
                                system_formulation::Type{<:PM.AbstractDCPModel},
                                feed_forward::Union{Nothing, AbstractAffectFeedForward}) where B<:PSY.DCBranch
    var_name = Symbol("Fp_$(B)")
    con_name = Symbol("RateLimit_$(B)")
    time_steps = model_time_steps(psi_container)
    psi_container.constraints[con_name] = JuMPConstraintArray(undef, (PSY.get_name(d) for d in devices), time_steps)

    for t in time_steps, d in devices
        min_rate = max(PSY.get_activepowerlimits_from(d).min, PSY.get_activepowerlimits_to(d).min)
        max_rate = min(PSY.get_activepowerlimits_from(d).max, PSY.get_activepowerlimits_to(d).max)
        psi_container.constraints[con_name][PSY.get_name(d), t] = JuMP.@constraint(psi_container.JuMPmodel, min_rate <= psi_container.variables[var_name][PSY.get_name(d), t] <= max_rate)
    end
    return
end

function branch_rate_constraint!(psi_container::PSIContainer,
                                devices::IS.FlattenIteratorWrapper{B},
                                device_formulation::Type{HVDCLossless},
                                system_formulation::Type{<:PM.AbstractActivePowerModel},
                                feed_forward::Union{Nothing, AbstractAffectFeedForward}) where B<:PSY.DCBranch
    for dir in ("FT", "TF")
        var_name = Symbol("Fp$(dir)_$(B)")
        con_name = Symbol("RateLimit_$(dir)_$(B)")
        time_steps = model_time_steps(psi_container)
        psi_container.constraints[con_name] = JuMPConstraintArray(undef, (PSY.get_name(d) for d in devices), time_steps)

        for t in time_steps, d in devices
            min_rate = max(PSY.get_activepowerlimits_from(d).min, PSY.get_activepowerlimits_to(d).min)
            max_rate = min(PSY.get_activepowerlimits_from(d).max, PSY.get_activepowerlimits_to(d).max)
            name = PSY.get_name(d)
            psi_container.constraints[con_name][name, t] = JuMP.@constraint(psi_container.JuMPmodel, min_rate <= psi_container.variables[var_name][name, t] <= max_rate)
        end
    end
    return
end

function branch_rate_constraint!(psi_container::PSIContainer,
                                devices::IS.FlattenIteratorWrapper{B},
                                device_formulation::Type{HVDCLossless},
                                system_formulation::Type{<:PM.AbstractPowerModel},
                                feed_forward::Union{Nothing, AbstractAffectFeedForward}) where B<:PSY.DCBranch
    for dir in ("FT", "TF")
        var_name = Symbol("Fp$(dir)_$(B)")
        con_name = Symbol("RateLimit_$(dir)_$(B)")
        time_steps = model_time_steps(psi_container)
        psi_container.constraints[con_name] = JuMPConstraintArray(undef, (PSY.get_name(d) for d in devices), time_steps)

        for t in time_steps, d in devices
            min_rate = max(PSY.get_activepowerlimits_from(d).min, PSY.get_activepowerlimits_to(d).min)
            max_rate = min(PSY.get_activepowerlimits_from(d).max, PSY.get_activepowerlimits_to(d).max)
            name = PSY.get_name(d)
            psi_container.constraints[con_name][name, t] = JuMP.@constraint(psi_container.JuMPmodel, min_rate <= psi_container.variables[var_name][name, t] <= max_rate)
        end
    end
    return
end

function branch_rate_constraint!(psi_container::PSIContainer,
                                devices::IS.FlattenIteratorWrapper{B},
                                device_formulation::Type{<:AbstractDCLineFormulation},
                                system_formulation::Type{<:PM.AbstractActivePowerModel},
                                feed_forward::Union{Nothing, AbstractAffectFeedForward}) where B<:PSY.DCBranch
    time_steps = model_time_steps(psi_container)
    for dir in ("FT", "TF")
        var_name = Symbol("Fp$(dir)_$(B)")
        con_name = Symbol("RateLimit$(dir)_$(B)")
        psi_container.constraints[con_name] = JuMPConstraintArray(undef, (PSY.get_name(d) for d in devices), time_steps)

        for t in time_steps, d in devices
            min_rate = max(PSY.get_activepowerlimits_from(d).min, PSY.get_activepowerlimits_to(d).min)
            max_rate = min(PSY.get_activepowerlimits_from(d).max, PSY.get_activepowerlimits_to(d).max)
            psi_container.constraints[con_name][PSY.get_name(d), t] = JuMP.@constraint(psi_container.JuMPmodel, min_rate <= psi_container.variables[var_name][PSY.get_name(d), t] <= max_rate)
            _add_to_expression!(psi_container.expressions[:nodal_balance_active],
                                PSY.get_number(PSY.get_arc(d).to),
                                t,
                                psi_container.variables[var_name][PSY.get_name(d), t],
                                -PSY.get_loss(d).l1,
                                -PSY.get_loss(d).l0)
        end
    end
    return
end

function branch_rate_constraint!(psi_container::PSIContainer,
                                devices::IS.FlattenIteratorWrapper{B},
                                device_formulation::Type{<:AbstractDCLineFormulation},
                                system_formulation::Type{<:PM.AbstractPowerModel},
                                feed_forward::Union{Nothing, AbstractAffectFeedForward}) where B<:PSY.DCBranch
    time_steps = model_time_steps(psi_container)
    for dir in ("FT", "TF")
        var_name = Symbol("Fp$(dir)_$(B)")
        con_name = Symbol("RateLimit$(dir)_$(B)")
        psi_container.constraints[con_name] = JuMPConstraintArray(undef, (PSY.get_name(d) for d in devices), time_steps)

        for t in time_steps, d in devices
            min_rate = max(PSY.get_activepowerlimits_from(d).min, PSY.get_activepowerlimits_to(d).min)
            max_rate = min(PSY.get_activepowerlimits_from(d).max, PSY.get_activepowerlimits_to(d).max)
            psi_container.constraints[con_name][PSY.get_name(d), t] = JuMP.@constraint(psi_container.JuMPmodel, min_rate <= psi_container.variables[var_name][PSY.get_name(d), t] <= max_rate)
            _add_to_expression!(psi_container.expressions[:nodal_balance_active],
                                PSY.get_number(PSY.get_arc(d).to),
                                t,
                                psi_container.variables[var_name][PSY.get_name(d), t],
                                -PSY.get_loss(d).l1,
                                -PSY.get_loss(d).l0)
        end
    end
    return
end
