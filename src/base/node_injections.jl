function VarNetInjectIterate!(NetInjectionVar::Array{JuMP.AffExpr}, buses::Array{Bus}, variable::PowerVariable, time_periods::Int, device::Array{T}) where T <: PowerSystems.ThermalGen

        for b in buses

            for t = 1:time_periods

                set = [d.name for d in device if d.bus == b]

                isempty(set) ? break : total = sum(variable[i,t] for i in set)

                isassigned(NetInjectionVar, b.number,t) ? append!(NetInjectionVar[b.number,t], total): NetInjectionVar[b.number,t] = total;

            end
        end

    return NetInjectionVar

end

function VarNetInjectIterate!(NetInjectionVar::Array{JuMP.AffExpr}, buses::Array{Bus}, variable::PowerVariable, time_periods::Int, device::Array{T}) where T <: PowerSystems.RenewableGen

        for b in buses

            for t = 1:time_periods

                set = [d.name for d in device if d.bus == b && !isa(d, PowerSystems.RenewableFix)]

                isempty(set) ? break : total = sum(variable[i,t] for i in set)

                isassigned(NetInjectionVar, b.number,t) ? append!(NetInjectionVar[b.number,t], total): NetInjectionVar[b.number,t] = total;

            end
        end

    return NetInjectionVar

end

function VarNetInjectIterate!(NetInjectionVar::Array{JuMP.AffExpr}, buses::Array{Bus}, variable::PowerVariable, time_periods::Int, device::Array{T}) where T <: PowerSystems.HydroGen

    for b in buses

        for t = 1:time_periods

            set = [d.name for d in device if d.bus == b && !isa(d, PowerSystems.HydroFix)]

            isempty(set) ? break : total = sum(variable[i,t] for i in set)

            isassigned(NetInjectionVar, b.number,t) ? append!(NetInjectionVar[b.number,t], total): NetInjectionVar[b.number,t] = total;

        end
    end

    return NetInjectionVar
end

function VarNetInjectIterate!(NetInjectionVar::Array{JuMP.AffExpr}, buses::Array{Bus}, variable::PowerVariable, time_periods::Int, device::Array{T}) where T <: PowerSystems.ElectricLoad

    for b in buses

        for t = 1:time_periods

            set = [d.name for d in device if d.bus == b && !isa(d, PowerSystems.StaticLoad)]

            isempty(set) ? break : total = sum(variable[i,t] for i in set)

            isassigned(NetInjectionVar, b.number,t) ? append!(NetInjectionVar[b.number,t], total): NetInjectionVar[b.number,t] = total;

        end
    end

    return NetInjectionVar

end

function VarNetInjectIterate!(NetInjectionVar::Array{JuMP.AffExpr}, buses::Array{Bus}, variable_in::PowerVariable, variable_out::PowerVariable, time_periods::Int, device::Array{T}) where T <: PowerSystems.Storage

        for b in buses

            for t = 1:time_periods

                set = [d.name for d in device if d.bus == b]

                #Detects if there is a device connected at the node, if not, breaks the time loop and goes to the next bus.
                isempty(set) ? break : total = sum(variable_in[i,t] - variable_out[i,t] for i in set)

                isassigned(NetInjectionVar, b.number,t) ? append!(NetInjectionVar[b.number,t], total): NetInjectionVar[b.number,t] = total;

            end
        end

    return NetInjectionVar

end



function InjectionExpressions(sys::PowerSystems.PowerSystem; var_th=nothing, var_re=nothing, phy=nothing, var_cl=nothing, var_in=nothing, var_out=nothing)

    NetInjectionVar =  Array{JuMP.AffExpr}(length(sys.buses), sys.timesteps)

    # TODO: Iterate over generator types in PowerSystems.Generators to enable any type of possible future generation types

    !isa(sys.generators.thermal,Void)? NetInjectionVar = VarNetInjectIterate!(NetInjectionVar, sys.buses, var_th, sys.timesteps, sys.generators.thermal): true

    !isa(sys.generators.renewable,Void)? NetInjectionVar = VarNetInjectIterate!(NetInjectionVar, sys.buses, var_re, sys.timesteps, sys.generators.renewable): true

    !isa(sys.generators.hydro,Void)? NetInjectionVar = VarNetInjectIterate!(NetInjectionVar, sys.buses, phy, sys.timesteps, sys.generators.hydro): true

    !isa(sys.storage,Void)? NetInjectionVar = VarNetInjectIterate!(NetInjectionVar, sys.buses, var_in, var_out, sys.timesteps, sys.storage) : true

    NetInjectionVar = VarNetInjectIterate!(NetInjectionVar, sys.buses, var_cl, sys.timesteps, sys.loads)

    return NetInjectionVar
end
