function VarNetInjectIterate!(NetInjectionVar::A, buses::Array{Bus}, variable::PowerVariable, time_periods::Int, device::Array{T}) where {T <: PowerSystems.ThermalGen, A <: PowerExpressionArray}

        for b in buses

            for t = 1:time_periods

                set = [d.name for d in device if d.bus == b]

                isempty(set) ? break : total = sum(variable[i,t] for i in set)

                isassigned(NetInjectionVar, b.number,t) ? append!(NetInjectionVar[b.number,t], total): NetInjectionVar[b.number,t] = total;

            end
        end

    return NetInjectionVar

end

function VarNetInjectIterate!(NetInjectionVar::A, buses::Array{Bus}, variable::PowerVariable, time_periods::Int, device::Array{T}) where {T <: PowerSystems.RenewableGen, A <: PowerExpressionArray}

        for b in buses

            for t = 1:time_periods

                set = [d.name for d in device if d.bus == b && !isa(d, PowerSystems.RenewableFix)]

                isempty(set) ? break : total = sum(variable[i,t] for i in set)

                isassigned(NetInjectionVar, b.number,t) ? append!(NetInjectionVar[b.number,t], total): NetInjectionVar[b.number,t] = total;

            end
        end

    return NetInjectionVar

end

function VarNetInjectIterate!(NetInjectionVar::A, buses::Array{Bus}, variable::PowerVariable, time_periods::Int, device::Array{T}) where {T <: PowerSystems.HydroGen, A <: PowerExpressionArray}

    for b in buses

        for t = 1:time_periods

            set = [d.name for d in device if d.bus == b && !isa(d, PowerSystems.HydroFix)]

            isempty(set) ? break : total = sum(variable[i,t] for i in set)

            isassigned(NetInjectionVar, b.number,t) ? append!(NetInjectionVar[b.number,t], total): NetInjectionVar[b.number,t] = total;

        end
    end

    return NetInjectionVar
end

function VarNetInjectIterate!(NetInjectionVar::A, buses::Array{Bus}, variable::PowerVariable, time_periods::Int, device::Array{T}) where {T <: PowerSystems.ElectricLoad,A <: PowerExpressionArray}

    for b in buses

        for t = 1:time_periods

            set = [d.name for d in device if d.bus == b && !isa(d, PowerSystems.StaticLoad)]

            isempty(set) ? break : total = sum(variable[i,t] for i in set)

            isassigned(NetInjectionVar, b.number,t) ? append!(NetInjectionVar[b.number,t], total): NetInjectionVar[b.number,t] = total;

        end
    end

    return NetInjectionVar

end

function VarNetInjectIterate!(NetInjectionVar::A, buses::Array{Bus}, variable_in::PowerVariable, variable_out::PowerVariable, time_periods::Int, device::Array{T}) where{T <: PowerSystems.Storage, A <: PowerExpressionArray}

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

"""
This function generates an Array of affine expressions where each entry represents the LHS of the nodal balance equations. The corresponding expressions are the sum of the relevant JuMP variables for each node and each time-step
"""
function VarInjectionExpressions(sys::PowerSystems.PowerSystem; var_th=nothing, var_re=nothing, phy=nothing, var_cl=nothing, var_in=nothing, var_out=nothing)

    NetInjectionVar =  Array{JuMP.GenericAffExpr{Float64,JuMP.Variable},2}(length(sys.buses), sys.time_periods)

    # TODO: Iterate over generator types in PowerSystems.Generators to enable any type of possible future generation types

    !isa(sys.generators.thermal,Nothing)? NetInjectionVar = VarNetInjectIterate!(NetInjectionVar, sys.buses, var_th, sys.time_periods, sys.generators.thermal): true

    !isa(sys.generators.renewable,Nothing)? NetInjectionVar = VarNetInjectIterate!(NetInjectionVar, sys.buses, var_re, sys.time_periods, sys.generators.renewable): true

    !isa(sys.generators.hydro,Nothing)? NetInjectionVar = VarNetInjectIterate!(NetInjectionVar, sys.buses, phy, sys.time_periods, sys.generators.hydro): true

    !isa(sys.storage,Nothing)? NetInjectionVar = VarNetInjectIterate!(NetInjectionVar, sys.buses, var_in, var_out, sys.time_periods, sys.storage) : true

    NetInjectionVar = VarNetInjectIterate!(NetInjectionVar, sys.buses, var_cl, sys.time_periods, sys.loads)

    return NetInjectionVar
end


"""
This function generates an Array of floats where each entry represents the RHS of the nodal balance equations. The corresponding values are the net-load values for each node and each time-step
"""
function TsInjectionBalance(sys::PowerSystems.PowerSystem)

    NetInjectionTs =  zeros(Float64, length(sys.buses), sys.time_periods)

    # TODO: Change syntax to for source in sys.generators when implemented in Julia v0.7 with Named Tuples

       for source_name in fieldnames(sys.generators)

            source = getfield(sys.generators,source_name)

            typeof(source) <: Array{<:ThermalGen} ? continue : (isa(source, Nothing) ? continue : true)

            for b in sys.buses

                for t = 1:sys.time_periods

                    fixed_source = [fs.tech.installedcapacity*fs.scalingfactor.values[t] for fs in source if fs.bus == b]

                    isempty(fixed_source)? break : fixed_source = NetInjectionTs[b.number,t] -= sum(fixed_source)

                end

            end

        end

        for b in sys.buses

                for t = 1:sys.time_periods

                staticload = [sl.maxrealpower*sl.scalingfactor.values[t] for sl in sys.loads if sl.bus == b]

                isempty(staticload) ? break : NetInjectionTs[b.number,t] = sum(staticload)

            end
        end


    return  NetInjectionTs
end