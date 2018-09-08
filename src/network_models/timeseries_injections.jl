"""
This function generates an Array of floats where each entry represents the RHS of the nodal balance equations. The corresponding values are the net-load values for each node and each time-step
"""
function timeseries_netinjection(sys::PowerSystems.PowerSystem)

    tsnetinjection =  zeros(Float64, length(sys.buses), sys.time_periods)

    # Note: This function has separate loops for load and resources such that it is possible to break the loops when there is no 
    # fix loads or fix resources in the bus and in that way avoid looping through all the buses*time_steps`

    for source in sys.generators

         typeof(source) <: Array{<:ThermalGen} ? continue : (isa(source, Nothing) ? continue : true)

         for b in sys.buses

             for t in 1:sys.time_periods

                 fixed_source = [fs.tech.installedcapacity*fs.scalingfactor.values[t] for fs in source if (fs.bus == b && isa(fs,fix_resource))]

                 isempty(fixed_source) ? break : fixed_source = tsnetinjection[b.number,t] -= sum(fixed_source)

             end

         end

     end

     for b in sys.buses

             for t in 1:sys.time_periods

             staticload = [sl.maxrealpower*sl.scalingfactor.values[t] for sl in sys.loads if sl.bus == b]

             isempty(staticload) ? break : tsnetinjection[b.number,t] += sum(staticload)

         end
     end


    return  tsnetinjection
end
