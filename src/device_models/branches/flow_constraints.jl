function thermalflowlimits(m::JuMP.AbstractModel, system_formulation::Type{S}, devices::Array{B,1}, time_periods::Int64) where {B <: PowerSystems.Branch, S <: PM.AbstractDCPForm}

    fbr = m[:fbr]
    name_index = m[:fbr].axes[1]
    time_index = m[:fbr].axes[2]

    device_index = Dict(value => key for (key, value) in Dict(collect(enumerate([d.name for d in devices]))))

    Flow_max_tf = JuMP.JuMPArray(Array{ConstraintRef}(undef,length(name_index), time_periods), name_index, time_index)
    Flow_max_ft = JuMP.JuMPArray(Array{ConstraintRef}(undef,length(name_index), time_periods), name_index, time_index)

    for t in time_index, (ix, name) in enumerate(name_index)
        if name in keys(device_index)
            if name == devices[device_index[name]].name
                Flow_max_tf[name, t] = @constraint(m, fbr[name, t] <= devices[device_index[name]].rate)
                Flow_max_ft[name, t] = @constraint(m, fbr[name, t] >= -1*devices[device_index[name]].rate)
            else
                @error "Branch name in Array and variable do not match"
            end
        else
            @warn "No flow limit constraint populated for $(name)"
        end
    end

    JuMP.register_object(m, :Flow_max_ToFrom, Flow_max_tf)
    JuMP.register_object(m, :Flow_max_FromTo, Flow_max_ft)

    return m
end

function thermalflowlimits(m::JuMP.AbstractModel, system_formulation::Type{S}, devices::Array{B,1}, time_periods::Int64) where {B <: PowerSystems.Branch, S <: PM.AbstractDCPLLForm}

    fbr_fr = m[:fbr_fr]
    fbr_to = m[:fbr_to]
    name_index = m[:fbr_fr].axes[1]
    time_index = m[:fbr_to].axes[2]

    device_index = Dict(value => key for (key, value) in Dict(collect(enumerate([d.name for d in devices]))))

    Flow_max_tf = JuMP.JuMPArray(Array{ConstraintRef}(undef,length(name_index), time_periods), name_index, time_index)
    Flow_max_ft = JuMP.JuMPArray(Array{ConstraintRef}(undef,length(name_index), time_periods), name_index, time_index)

    for t in time_index, (ix, name) in enumerate(name_index)
        if name in keys(device_index)
            if name == devices[device_index[name]].name
                Flow_max_tf[name, t] = @constraint(m, fbr_fr[name, t] <= devices[device_index[name]].rate)
                Flow_max_ft[name, t] = @constraint(m, fbr_to[name, t] >= -1*devices[device_index[name]].rate)
            else
                @error "Branch name in Array and variable do not match"
            end
        else
            @warn "No flow limit constraint populated for $(name)"
        end
    end

    JuMP.register_object(m, :Flow_max_ToFrom, Flow_max_tf)
    JuMP.register_object(m, :Flow_max_FromTo, Flow_max_ft)

    return m
end

#TODO: Implement Limits in AC. Use Norm from JuMP Implemented norms. 