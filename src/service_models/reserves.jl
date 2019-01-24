
function reservevariables(m::JuMP.AbstractModel, devices::Array{NamedTuple{(:device, :formulation), Tuple{R,DataType}}}, time_periods::Int64) where {R <: PSY.PowerSystemDevice}

    on_set = [d.device.name for d in devices]

    t = 1:time_periods

    p_rsv = JuMP.@variable(m, p_rsv[on_set,t] >= 0)

    return p_rsv

end

# headroom constraints
function make_pmax_rsv_constraint(m::JuMP.AbstractModel,t::Int64, device::G, formulation::Type{D}) where {G<:PSY.ThermalGen, D <: AbstractThermalDispatchForm}
    return JuMP.@constraint(m, m[:p_th][device.name,t] + m[:p_rsv][device.name,t]  <= device.tech.activepowerlimits.max)
end

function make_pmax_rsv_constraint(m::JuMP.AbstractModel,t::Int64, device::G, formulation::Type{D}) where {G<:PSY.ThermalGen, D <: AbstractThermalFormulation}
    return JuMP.@constraint(m, m[:p_th][device.name,t] + m[:p_rsv][device.name,t] <= device.tech.activepowerlimits.max * m[:on_th][device.name,t])
end

function make_pmax_rsv_constraint(m::JuMP.AbstractModel,t::Int64, device::G, formulation::Type{D}) where {G<:PSY.RenewableGen, D <: AbstractRenewableDispatchForm}
    return JuMP.@constraint(m, m[:p_re][device.name,t] + m[:p_rsv][device.name,t] <= device.tech.installedcapacity * values(device.scalingfactor)[t])
end

function make_pmax_rsv_constraint(m::JuMP.AbstractModel,t::Int64, device::G, formulation::Type{D}) where {G<:PSY.InterruptibleLoad, D <: FullControllablePowerLoad}
    return JuMP.@constraint(m, m[:p_cl][device.name,t] + m[:p_rsv][device.name,t] <= device.maxactivepower * values(device.scalingfactor)[t])
end

# ramp constraints
function make_pramp_rsv_constraint(m::JuMP.AbstractModel,t::Int64, device::G, formulation::Type{D}, timeframe) where {G<:PSY.ThermalGen, D <: AbstractThermalFormulation}
    rmax = device.tech.ramplimits != nothing  ? device.tech.ramplimits.up : device.tech.activepowerlimits.max
    return JuMP.@constraint(m, m[:p_rsv][device.name,t] <= rmax/60 * timeframe)
end

function make_pramp_rsv_constraint(m::JuMP.AbstractModel,t::Int64, device::G, formulation::Type{D}, timeframe) where {G<:PSY.RenewableGen, D <: AbstractRenewableDispatchForm}
    return
end
function make_pramp_rsv_constraint(m::JuMP.AbstractModel,t::Int64, device::G, formulation::Type{D}, timeframe) where {G<:PSY.InterruptibleLoad, D <: FullControllablePowerLoad}
    #rmax =  device.maxactivepower * values(device.scalingfactor)[t] #nominally setting load ramp limit to full range within 1 min
    #return JuMP.@constraint(m, m[:p_rsv][device.name,t] <= rmax/60 * timeframe)
    return
end


function reserves(m::JuMP.AbstractModel, devices::Array{NamedTuple{(:device, :formulation), Tuple{R,DataType}}}, service::PSY.StaticReserve, time_periods::Int64) where {R <: PSY.PowerSystemDevice}

    p_rsv = m[:p_rsv]
    time_index = m[:p_rsv].axes[2]
    name_index = m[:p_rsv].axes[1]

    (length(time_index) != time_periods) ? @error("Length of time dimension inconsistent") : true

    pmin_rsv = JuMP.Containers.DenseAxisArray(Array{JuMP.ConstraintRef}(undef,length(time_index)), time_index) #minimum system reserve provision
    pmax_rsv = JuMP.Containers.DenseAxisArray(Array{JuMP.ConstraintRef}(undef, length.(JuMP.axes(p_rsv))), name_index, time_index) #maximum generator reserve provision


    for t in time_index
        pmin_rsv[t] = JuMP.@constraint(m, sum([p_rsv[name,t] for name in name_index]) >= service.requirement)

        for (ix, name) in enumerate(name_index)
            if name == devices[ix].device.name
                pmax_rsv[name,t] = make_pmax_rsv_constraint(m, t, devices[ix].device,devices[ix].formulation)
            else
                @error "Gen name in Array and variable do not match"
            end
        end

    end

    rmp_devices = [d for d in devices if d.formulation<:PowerSimulations.ThermalDispatch]
    rmp_name_index = [d.device.name for d in rmp_devices]

    pramp_rsv = JuMP.Containers.DenseAxisArray(Array{JuMP.ConstraintRef}(undef, (length(rmp_name_index),length(time_index))), rmp_name_index, time_index) #maximum generator reserve provision

    for t in time_index
        # TODO: check the units of ramplimits
        for (ix, name) in enumerate(rmp_name_index)
            if name == rmp_devices[ix].device.name
                pramp_rsv[name,t] = make_pramp_rsv_constraint(m, t, rmp_devices[ix].device, rmp_devices[ix].formulation, service.timeframe)
            else
                @error "Gen name in Array and variable do not match"
            end
        end

    end

    JuMP.register_object(m, :RsvProvisionMin, pmin_rsv)
    JuMP.register_object(m, :RsvProvisionMax, pmax_rsv)
    JuMP.register_object(m, :RsvProvisionRamp, pramp_rsv)

    return m

end