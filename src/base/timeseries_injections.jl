"""
This function generates an Array of floats where each entry represents the RHS of the nodal balance equations. The corresponding values are the net-load values for each node and each time-step
"""
function timeseries_netinjection(sys::PowerSystems.PowerSystem)

    tsnetinjection =  zeros(Float64, length(sys.buses), sys.time_periods)

    # TODO: Change syntax to for source in sys.generators when implemented in Julia v0.7 with Named Tuples

    for source_name in fieldnames(sys.generators)

         source = getfield(sys.generators,source_name)

         typeof(source) <: Array{<:ThermalGen} ? continue : (isa(source, Nothing) ? continue : true)

         for b in sys.buses

             for t in 1:sys.time_periods

                 fixed_source = [fs.tech.installedcapacity*fs.scalingfactor.values[t] for fs in source if fs.bus == b]

                 isempty(fixed_source)? break : fixed_source = tsnetinjection[b.number,t] -= sum(fixed_source)

             end

         end

     end

     for b in sys.buses

             for t in 1:sys.time_periods

             staticload = [sl.maxrealpower*sl.scalingfactor.values[t] for sl in sys.loads if sl.bus == b]

             isempty(staticload) ? break : tsnetinjection[b.number,t] = sum(staticload)

         end
     end


    return  tsnetinjection
end
