
function timeconstraints(ps_m::CanonicalModel, devices::Array{T,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_periods::Int64; kwargs...) where {T <: PSY.ThermalGen, D <: ThermalUnitCommitment , S <: PM.AbstractActivePowerFormulation}

    devices = [d for d in devices if !isa(d.tech.timelimits, Nothing)]

    if !isempty(devices)
        # TODO: Change loop orders, loop over time first and then over the device names

        on_th = m[:on_th]
        start_th = m[:start_th]
        stop_th = m[:stop_th]
        time_index = m[:on_th].axes[2]
        name_index = [d.name for d in devices]

        # set args default values
        if :initialonduration in keys(args)
            initialonduration = args[:initialonduration]
        else
            initialonduration = Dict(zip(name_index,ones(Float64,length(devices))*9999))
        end

        if :initialoffduration in keys(args)
            initialoffduration = args[:initialoffduration]
        else
            initialoffduration = Dict(zip(name_index,ones(Float64,length(devices))*9999))
        end

    
        JuMP.register_object(m, :minup_th, minup_th)
        JuMP.register_object(m, :mindown_th, mindown_th)

    else
        @warn "There are no generators with Min-up -down limits data in the system"

    end

end
