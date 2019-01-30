function device_constantinjection(ps_m::CanonicalModel, expr_name::String, devices::Array{R,1}, time_range::UnitRange{Int64})

    ax = axes(X)

    for i in ax[1]

        for j in ax[2]
       
            ps_m.expressions["$(expr_name)"][i,j] += values[i,j]
       
        end

    end

end



function timeseries_netinjection(ps_m::CanonicalModel, device::PSY.

    tsnetinjection =  zeros(Float64, length(sys.buses), sys.time_periods)

    # Note: This function has separate loops for load and resources such that it is possible to break the loops when there is no
    # fix loads or fix resources in the bus and in that way avoid looping through all the buses*time_steps`

    for source in sys.generators

         typeof(source) <: Array{<:PSY.ThermalGen} ? continue : (isa(source, Nothing) ? continue : true)

         for b in sys.buses

             for t in 1:sys.time_periods

                 fixed_source = [fs.tech.installedcapacity * values(fs.scalingfactor)[t] for fs in source if (fs.bus == b && isa(fs,fix_resource) && fs.available)]

                 isempty(fixed_source) ? break : fixed_source = tsnetinjection[b.number,t] -= sum(fixed_source)

             end

         end

     end

     for b in sys.buses

             for t in 1:sys.time_periods

             staticload = [sl.maxactivepower * values(sl.scalingfactor)[t] for sl in sys.loads if sl.bus == b]

             isempty(staticload) ? break : tsnetinjection[b.number,t] += sum(staticload)

         end
     end


    return  tsnetinjection
end
