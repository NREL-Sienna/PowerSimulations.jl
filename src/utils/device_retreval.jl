function all_devices(sys, filter::Array)
    dev = Array{PowerSystems.PowerSystemDevice}([])

    for source in sys.generators
        if typeof(source) <: Array{<:PowerSystems.Generator}
            for d in source
                d.name in filter ? push!(dev,d) : continue
            end
        end
    end

    for d in sys.loads
        d.name in filter ? push!(dev,d) : continue
    end

    return dev
end

function all_devices(sys)
    dev = Array{PowerSystems.PowerSystemDevice}([])

    for source in sys.generators
        if typeof(source) <: Array{<:PowerSystems.Generator}
            for d in source
                push!(dev,d)
            end
        end
    end

    for d in sys.loads
        push!(dev,d)
    end

    return dev
end


#TODO: Make additional methods to handle other device types
function get_pg(m::JuMP.Model, gen::G, t::Int64) where G <: PowerSystems.ThermalGen
    return m.obj_dict[:p_th][gen.name,t]
end

function get_pg(m::JuMP.Model, gen::G, t::Int64) where G <: PowerSystems.RenewableCurtailment
    return m.obj_dict[:p_re][gen.name,t]
end


function get_Fmax(branch::PowerSystems.Line)
    return (from_to = branch.rate.from_to, to_from = branch.rate.to_from)
end

function get_Fmax(branch::B) where B <: PowerSystems.Branch
    return (from_to = branch.rate, to_from = branch.rate)
end


# Methods for accessing jump, moi, and optimizer variables
function get_all_vars(obj_dict)
    # get all variables in a jump model
    var_arays = [v.data for (k,v) in obj_dict if isa(v,JuMP.JuMPArray{JuMP.VariableRef}) ];
    vars = [i for arr in var_arays for i in arr]
end

function map_moi_opt_variables(model::JuMP.Model)
    # maps moi variablerefs (keys) to optimizer variable refs (values)
    vmap = model.moi_backend.model.optimizer.variable_mapping
    moi_optimizer_vmap = Dict()
    for v in vmap
        moi_optimizer_vmap[model.moi_backend.model.optimizer_to_model_map.varmap[v[1]]]=v[2]
    end
    return moi_optimizer_vmap
end

function map_jump_vars(model::JuMP.Model)
    # maps jump variablerefs (keys) to optimizer variable refs (values)
    vars = get_all_vars(model.obj_dict)
    moi_optimizer_vmap = map_moi_opt_variables(model)
    moivariables = [moi_optimizer_vmap[v.index] for v in vars]
    moivars = [moi_optimizer_vmap[v.index] for v in vars]
    return Dict(zip(vars,moivars))
end
    

function map_optimizer_vars(model::JuMP.Model)
    # maps optimizer variablerefs (keys) to jump variable refs (values)
    vars = get_all_vars(model.obj_dict)
    moi_optimizer_vmap = map_moi_opt_variables(model)
    moivariables = [moi_optimizer_vmap[v.index] for v in vars]
    moivars = [moi_optimizer_vmap[v.index] for v in vars]
    return Dict(zip(moivars,vars))
end

# Methods for accessing jump, moi, and optimizer constraintrefs
function get_all_constraints(obj_dict)
    # get all constraints in a jump model
    constraint_arrays = [v.data for (k,v) in obj_dict if isa(v,JuMP.JuMPArray{JuMP.ConstraintRef}) ];
    constraints = [i for arr in constraint_arrays for i in arr]
end

function map_moi_opt_constraints(model::JuMP.Model)
    # maps moi constraintrefs (keys) to optimizer constraint refs (values)
    cmap = model.moi_backend.model.optimizer.constraint_mapping
    moi_optimizer_map = Dict()
    for f in fieldnames(typeof(cmap))
        ctype = getfield(cmap,f)
        for c in ctype
            moi_optimizer_map[model.moi_backend.model.optimizer_to_model_map.conmap[c[1]]]=c[2]
        end
    end
    return moi_optimizer_map
end

function map_jump_constraints(model::JuMP.Model)
    # maps jump constraints (keys) to optimizer constraint refs (values)
    constraints = get_all_constraints(model.obj_dict)
    moi_optimizer_map = map_moi_opt_constraints(model)
    moiconstraints = [moi_optimizer_map[c.index] for c in constraints]
    return Dict(zip(constraints,moiconstraints))
end

function map_optimizer_constraints(model::JuMP.Model)
    # maps optimizer constraint refs (keys) to jump constraints (values)
    constraints = get_all_constraints(model.obj_dict)
    moi_optimizer_map = map_moi_opt_constraints(model)
    moiconstraints = [moi_optimizer_map[c.index] for c in constraints]
    return Dict(zip(moiconstraints,constraints))
end
