function all_devices(sys, filter::Array)
    dev = Array{PSY.PowerSystemDevice}([])

    for source in sys.generators
        if typeof(source) <: Array{<:PSY.Generator}
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
    dev = Array{PSY.PowerSystemDevice}([])

    for source in sys.generators
        if typeof(source) <: Array{<:PSY.Generator}
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
function get_pg(m::JuMP.AbstractModel, gen::G, t::Int64) where G <: PSY.ThermalGen
    return m.obj_dict[:p_th][gen.name,t]
end

function get_pg(m::JuMP.AbstractModel, gen::G, t::Int64) where G <: PSY.RenewableCurtailment
    return m.obj_dict[:p_re][gen.name,t]
end

# Methods for accessing jump, moi, and optimizer variables
function get_all_vars(obj_dict)
    # get all variables in a jump model
    var_arays = [v.data for (k,v) in obj_dict if isa(v,JuMP.Containers.DenseAxisArray{JuMP.JuMP.VariableRef}) ];
    vars = [i for arr in var_arays for i in arr]
end

function map_moi_opt_variables(model::JuMP.AbstractModel)
    # maps moi variablerefs (keys) to optimizer variable refs (values)
    vmap = model.moi_backend.model.optimizer.variable_mapping
    moi_optimizer_vmap = Dict()
    for v in vmap
        moi_optimizer_vmap[model.moi_backend.model.optimizer_to_model_map.varmap[v[1]]]=v[2]
    end
    return moi_optimizer_vmap
end

function map_jump_vars(model::JuMP.AbstractModel)
    # maps jump variablerefs (keys) to optimizer variable refs (values)
    vars = get_all_vars(model.obj_dict)
    moi_optimizer_vmap = map_moi_opt_variables(model)
    moivariables = [moi_optimizer_vmap[v.index] for v in vars]
    moivars = [moi_optimizer_vmap[v.index] for v in vars]
    return Dict(zip(vars,moivars))
end


function map_optimizer_vars(model::JuMP.AbstractModel)
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
    constraint_arrays = [v.data for (k,v) in obj_dict if isa(v,JuMP.Containers.DenseAxisArray{JuMP.ConstraintRef}) ];
    constraints = [i for arr in constraint_arrays for i in arr]
end

function map_moi_opt_constraints(model::JuMP.AbstractModel)
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

function map_jump_constraints(model::JuMP.AbstractModel)
    # maps jump constraints (keys) to optimizer constraint refs (values)
    constraints = get_all_constraints(model.obj_dict)
    moi_optimizer_map = map_moi_opt_constraints(model)
    moiconstraints = [moi_optimizer_map[c.index] for c in constraints]
    return Dict(zip(constraints,moiconstraints))
end

function map_optimizer_constraints(model::JuMP.AbstractModel)
    # maps optimizer constraint refs (keys) to jump constraints (values)
    constraints = get_all_constraints(model.obj_dict)
    moi_optimizer_map = map_moi_opt_constraints(model)
    moiconstraints = [moi_optimizer_map[c.index] for c in constraints]
    return Dict(zip(moiconstraints,constraints))
end


function create_result_dict(jump_array, ::Type{Int64})

    d = Dict{String, Array{Int64}}()

    for var in jump_array.axes[1]
        arr = Int64[]

        for t in jump_array.axes[2]
            push!(arr, Int64(round(JuMP.result_value(jump_array[var, t]))))
        end

        d[var] = arr
    end

    return d

end


function create_result_dict(jump_array, ::Type{Float64})

    d = Dict{String, Array{Float64}}()

    for var in jump_array.axes[1]
        arr = Float64[]

        for t in jump_array.axes[2]
            push!(arr, Float64(JuMP.result_value(jump_array[var, t])))
        end

        d[var] = arr
    end

    return d

end


function create_result_dict(jump_array, k)

    if k in [:on_th, :start_th, :stop_th]
        return create_result_dict(jump_array, Int64)
    elseif k in [:p_th, :fbr, :p_re, :p_cl, :p_rsv, :q_th, :q_cl, :q_re]
        return create_result_dict(jump_array, Float64)
    end


end


function get_model_result(pspom::PSI.PowerOperationModel)

    d = Dict{Symbol, DataFrames.DataFrame}()
    for (k, v) in pspom.model.obj_dict
        if typeof(v) <: Containers.DenseAxisArray{JuMP.VariableRef}
            d[k] = create_result_dict(v, k)
        end
    end

    return d

end

function get_previous_value_df(res::DataFrames.DataFrame)
    res[:period] = 1:size(res, 1)
    var_res = melt(res[end,:], :period, variable_name = :Device)
    return var_res
end

function get_previous_value(res::DataFrames.DataFrame)
    var_res = get_previous_value_df(res)
    prev_val = Dict(zip(map(String,var_res[:Device]),var_res[:value]))
    return prev_val
end

function commitment_duration(res::Dict, initial,  transition::Symbol, minutes_per_step = 60)
    # res is the results df from the previous solution
    # initial is the dict that defines the initial status (e.g. initialonduration)
    # transition is the variable of commitment transition {:start_th or :stop_th}

    last_period = size(res[:on_th],1)

    on_devices = get_previous_value_df(res[:on_th])
    if transition == :start_th
        status = 1
    elseif transition == :stop_th
        status = 0
    end
    off_devices = copy(on_devices)
    off_devices = off_devices[off_devices.value.!=status,[:Device]]
    off_devices.value = 0.0
    on_devices = on_devices[on_devices.value.==status,[:Device]]

    initial = melt(DataFrames.DataFrame(initial), variable_name = :Device)
    initial.value = initial.value .+ (last_period * minutes_per_step/60)

    # for devices that have changed status in the last step, calculate how long they have been at their current status
    res_df = copy(res[transition])
    res_df[:period] = 1:size(res_df, 1)

    res_df = melt(res_df, :period, variable_name = :Device)

    res_df = join(res_df,on_devices, on = :Device)
    res_df = by(res_df[res_df[:value] .== 1 ,[:Device,:period]], :Device, df -> DataFrames.DataFrames.tail(df[[:period]],1))

    if size(res_df,1) > 0
        res_df.value  = ((last_period + 1) .- res_df.period) .* minutes_per_step/60
        res_df = join(on_devices,res_df[[:Device,:value]], on = :Device, kind = :outer)
        res_df[findall(ismissing,res_df.value),:] = join(initial, res_df[findall(ismissing,res_df.value),[:Device]], on=:Device)
    else
        # for everything else, add the current step periods to initial status
        res_df = copy(on_devices)
        res_df = join(initial,res_df,on=:Device)
    end
    res_df = vcat(res_df,off_devices)


    return Dict(zip(map(String,res_df.Device),res_df.value))
end


function collect_results(simulation_results)
    dfs = []
    vars = []

    for (d,step) in simulation_results
        for (v,df) in step
            df.Date = d
            df.period = 1:size(df,1)
            df.DateTime = [(DateTime(df.Date[ix])+Hour(df.period[ix]-1)) for ix in df.period]
            push!(dfs,df)
            push!(vars,v)
        end
    end

    sim_res = Dict()
    for var in unique(vars)
        ids = findall(vars -> vars == var,vars)
        sim_res[var] = copy(dfs[ids[1]])
        for id in ids[2:end]
            sim_res[var] = vcat(sim_res[var],dfs[id])
        end
    end
    return(sim_res)
end