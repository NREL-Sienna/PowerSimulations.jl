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