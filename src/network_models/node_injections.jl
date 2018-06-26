function NetInjectIterate!(NetInjection::Array{JuMP.AffExpr}, buses::Array{Bus}, variable::PowerVariable, tp::Int, device::Array{T}) where T <: PowerSystems.ThermalGen

        for b in buses

            for t = 1:tp

                set = [d.name for d in device if d.bus == b]

                isempty(set) ? break : total = sum(variable[i,t] for i in set)

                isassigned(NetInjection, b.number,t) ? append!(NetInjection[b.number,t], total): NetInjection[b.number,t] = total;

            end
        end

    return NetInjection

end

function NetInjectIterate!(NetInjection::Array{JuMP.AffExpr}, buses::Array{Bus}, variable::PowerVariable, tp::Int, device::Array{T}) where T <: PowerSystems.RenewableGen

        for b in buses

            for t = 1:tp

                devices = [d for d in device if d.bus == b]

                if isempty(devices)
                    break
                else
                    set = [d.name for d in devices if d.bus == b && !isa(d, PowerSystems.RenewableFix)]
                    isempty(set)? total = 0.0 : total = sum(variable[i,t] for i in set)
                    total = total + sum([d.tech.installedcapacity*d.scalingfactor.values[t] for d in devices])

                end

                isassigned(NetInjection, b.number,t) ? append!(NetInjection[b.number,t], total): NetInjection[b.number,t] = total;

            end
        end

    return NetInjection

end

function NetInjectIterate!(NetInjection::Array{JuMP.AffExpr}, buses::Array{Bus}, variable::PowerVariable, tp::Int, device::Array{T}) where T <: PowerSystems.HydroGen

        for b in buses

            for t = 1:tp

                devices = [d for d in device if d.bus == b]

                if isempty(devices)
                    break
                else
                    set = [d.name for d in devices if d.bus == b && !isa(d, PowerSystems.HydroFix)]
                    isempty(set)? total = 0.0 : total = sum(variable[i,t] for i in set)
                    total = total + sum([d.tech.installedcapacity*d.scalingfactor.values[t] for d in devices])

                end

                isassigned(NetInjection, b.number,t) ? append!(NetInjection[b.number,t], total): NetInjection[b.number,t] = total;

            end
        end

    return NetInjection
end

function NetInjectIterate!(NetInjection::Array{JuMP.AffExpr}, buses::Array{Bus}, variable::PowerVariable, tp::Int, device::Array{T}) where T <: PowerSystems.ElectricLoad

    for  b in buses

        for t = 1:tp

            devices = [d for d in device if d.bus == b]

            if isempty(devices)
                break
            else
                set = [d.name for d in devices if d.bus == b && !isa(d, PowerSystems.StaticLoad)]
                isempty(set)? total = 0.0 : total = sum(variable[i,t] for i in set)
                total = total + sum([d.maxrealpower*d.scalingfactor.values[t] for d in devices])

            end

            isassigned(NetInjection, b.number,t) ? append!(NetInjection[b.number,t], total): NetInjection[b.number,t] = total;

        end
    end

    return NetInjection

end

function NetInjectIterate!(NetInjection::Array{JuMP.AffExpr}, buses::Array{Bus}, variable_in::PowerVariable, variable_out::PowerVariable, tp::Int, device::Array{T}) where T <: PowerSystems.Storage

        for b in buses

            for t = 1:tp

                set = [d.name for d in device if d.bus == b]

                #Detects if there is a device connected at the node, if not, breaks the time loop and goes to the next bus.
                isempty(set) ? break : total = sum(variable_in[i,t] - variable_out[i,t] for i in set)

                isassigned(NetInjection, b.number,t) ? append!(NetInjection[b.number,t], total): NetInjection[b.number,t] = total;

            end
        end

    return NetInjection

end



function InjectionExpressions(m::JuMP.Model, sys::PowerSystems.PowerSystem; var_th=nothing, var_re=nothing, phy=nothing, var_cl=nothing, var_in=nothing, var_out=nothing)

    NetInjection =  Array{JuMP.AffExpr}(length(sys.buses), sys.timesteps)

    # TODO: Iterate over generator types in PowerSystems.Generators to enable any type of possivle future generation types

    !isa(sys.generators.thermal,Void)? NetInjection = NetInjectIterate!(NetInjection, sys.buses, var_th, sys.timesteps, sys.generators.thermal): true

    !isa(sys.generators.renewable,Void)? NetInjection = NetInjectIterate!(NetInjection, sys.buses, var_re, sys.timesteps, sys.generators.renewable): true

    !isa(sys.generators.hydro,Void)? NetInjection= NetInjectIterate!(NetInjection, sys.buses, phy, sys.timesteps, sys.generators.hydro): true

    !isa(sys.storage,Void)? NetInjection = NetInjectIterate!(NetInjection, sys.buses, var_in, var_out, sys.timesteps, sys.storage) : true

    NetInjection = NetInjectIterate!(NetInjection, sys.buses, var_cl, sys.timesteps, sys.loads)

    return NetInjection
end
