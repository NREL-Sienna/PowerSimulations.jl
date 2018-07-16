function varnetinjectiterate!(DevicesNetInjection::A, buses::Array{PowerSystems.Bus}, variable::PowerVariable, time_periods::Int, device::Array{T}) where {T <: PowerSystems.ThermalGen, A <: PowerExpressionArray}

    for b in buses

        set = [d.name for d in device if d.bus == b]

        for t in 1:time_periods

            isempty(set) ? break : total = sum(variable[i,t] for i in set)

            isassigned(DevicesNetInjection, b.number,t) ? append!(DevicesNetInjection[b.number,t], total): DevicesNetInjection[b.number,t] = total;

        end
    end

    return DevicesNetInjection

end

function varnetinjectiterate!(DevicesNetInjection::A, buses::Array{PowerSystems.Bus}, variable::PowerVariable, time_periods::Int, device::Array{T}) where {T <: PowerSystems.RenewableGen, A <: PowerExpressionArray}

    for b in buses

        set = [d.name for d in device if d.bus == b && !isa(d, PowerSystems.RenewableFix)]

        for t in 1:time_periods

            isempty(set) ? break : total = sum(variable[i,t] for i in set)

            isassigned(DevicesNetInjection, b.number,t) ? append!(DevicesNetInjection[b.number,t], total): DevicesNetInjection[b.number,t] = total;

        end
    end

    return DevicesNetInjection

end

function varnetinjectiterate!(DevicesNetInjection::A, buses::Array{PowerSystems.Bus}, variable::PowerVariable, time_periods::Int, device::Array{T}) where {T <: PowerSystems.HydroGen, A <: PowerExpressionArray}

    for b in buses

        set = [d.name for d in device if d.bus == b && !isa(d, PowerSystems.HydroFix)]

        for t in 1:time_periods

            isempty(set) ? break : total = sum(variable[i,t] for i in set)

            isassigned(DevicesNetInjection, b.number,t) ? append!(DevicesNetInjection[b.number,t], total): DevicesNetInjection[b.number,t] = total;

        end
    end

    return DevicesNetInjection
end

function varnetinjectiterate!(DevicesNetInjection::A, buses::Array{PowerSystems.Bus}, variable::PowerVariable, time_periods::Int, device::Array{T}) where {T <: PowerSystems.ElectricLoad,A <: PowerExpressionArray}

    for b in buses

        set = [d.name for d in device if d.bus == b && !isa(d, PowerSystems.StaticLoad)]

        for t in 1:time_periods

            isempty(set) ? break : total = sum(variable[i,t] for i in set)

            isassigned(DevicesNetInjection, b.number,t) ? append!(DevicesNetInjection[b.number,t], total): DevicesNetInjection[b.number,t] = total;

        end
    end

    return DevicesNetInjection

end

function varnetinjectiterate!(DevicesNetInjection::A, buses::Array{PowerSystems.Bus}, variable_in::PowerVariable, variable_out::PowerVariable, time_periods::Int, device::Array{T}) where{T <: PowerSystems.Storage, A <: PowerExpressionArray}

        for b in buses

            set = [d.name for d in device if d.bus == b]

            for t in 1:time_periods

                #Detects if there is a device connected at the node, if not, breaks the time loop and goes to the next bus.
                isempty(set) ? break : total = sum(variable_in[i,t] - variable_out[i,t] for i in set)

                isassigned(DevicesNetInjection, b.number,t) ? append!(DevicesNetInjection[b.number,t], total): DevicesNetInjection[b.number,t] = total;

            end
        end

    return DevicesNetInjection

end

"""
This function generates an Array of affine expressions where each entry represents the LHS of the nodal balance equations. The corresponding expressions are the sum of the relevant JuMP variables for each node and each time-step
"""
function deviceinjectionexpressions(sys::PowerSystems.PowerSystem; var_th=nothing, var_re=nothing, phy=nothing, var_cl=nothing, var_in=nothing, var_out=nothing)

    # TODO: @constraintref dissapears in JuMP 0.19. A new syntax goes here.
    DevicesNetInjection =  Array{JuMP.GenericAffExpr{Float64,JuMP.Variable},2}(length(sys.buses), sys.time_periods)

    # TODO: Iterate over generator types in PowerSystems.Generators to enable any type of possible future generation types

    !isa(sys.generators.thermal,Nothing)? DevicesNetInjection = varnetinjectiterate!(DevicesNetInjection, sys.buses, var_th, sys.time_periods, sys.generators.thermal): true

    !isa(sys.generators.renewable,Nothing)? DevicesNetInjection = varnetinjectiterate!(DevicesNetInjection, sys.buses, var_re, sys.time_periods, sys.generators.renewable): true

    !isa(sys.generators.hydro,Nothing)? DevicesNetInjection = varnetinjectiterate!(DevicesNetInjection, sys.buses, phy, sys.time_periods, sys.generators.hydro): true

    !isa(sys.storage,Nothing)? DevicesNetInjection = varnetinjectiterate!(DevicesNetInjection, sys.buses, var_in, var_out, sys.time_periods, sys.storage) : true

    DevicesNetInjection = varnetinjectiterate!(DevicesNetInjection, sys.buses, var_cl, sys.time_periods, sys.loads)

    DevicesNetInjection = remove_undef!(DevicesNetInjection)

    return DevicesNetInjection
end
