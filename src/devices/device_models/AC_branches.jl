#Generic Branch Models
abstract type AbstractBranchFormulation <: AbstractDeviceFormulation end

#Abstract Line Models

abstract type AbstractLineForm <: AbstractBranchFormulation end

struct StaticLine <: AbstractLineForm end

#Abstract Transformer Models

abstract type AbstractTransformerForm <: AbstractBranchFormulation end

struct StaticTransformer <: AbstractTransformerForm end

# Not implemented yet
struct TapControl <: AbstractTransformerForm end
struct PhaseControl <: AbstractTransformerForm end

#################################### Branch Variables ##################################################
# Because of the way we integrate with PowerModels, most of the time PowerSimulations will create variables
# for the branch flows either in AC or DC. 
function flow_variables(ps_m::CanonicalModel,
                        system_formulation::Type{S},
                        devices::PSY.FlattenedVectorsIterator{B}) where {B <: PSY.ACBranch,
                                                             S <: PM.AbstractPowerFormulation}
                                                   
    return

end

function flow_variables(ps_m::CanonicalModel,
                        system_formulation::Type{S},
                        devices::PSY.FlattenedVectorsIterator{B}) where {B <: PSY.ACBranch,
                                                             S <: StandardPTDFForm}

    time_steps = model_time_steps(ps_m)                                                             
    var_name = Symbol("Fbr_$(B)")
    ps_m.variables[var_name] = PSI._container_spec(ps_m.JuMPmodel,
                                                    (d.name for d in devices),
                                                     time_steps)

    for d in devices
        bus_fr = d.connectionpoints.from.number
        bus_to = d.connectionpoints.to.number
        for t in time_steps
            ps_m.variables[var_name][d.name,t] = JuMP.@variable(ps_m.JuMPmodel,
                                                                base_name="$(bus_fr),$(bus_to)_{$(d.name),$(t)}",
                                                                upper_bound = d.rate,
                                                                lower_bound = -d.rate,
                                                                start = 0.0)
        end
    end
    
    return

end

#################################### Flow Limits Variables ##################################################

function branch_rate_constraint(ps_m::CanonicalModel,
                                devices::PSY.FlattenedVectorsIterator{B},
                                device_formulation::Type{D},
                                system_formulation::Type{StandardPTDFForm}) where {B <: PSY.ACBranch,
                                                                                   D <: AbstractBranchFormulation}

    range_data = [(h.name, (min = -1*h.rate, max = h.rate)) for h in devices]

    device_range(ps_m, 
                range_data, 
                Symbol("rate_limit_$(B)"), 
                Symbol("Fbr_$(B)"))

    return

end
