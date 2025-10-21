function get_outage_total_power_by_step_dict(
    sys::PSY.System,
    variables::Dict{String, DataFrame}, 
    var_name::String, 
    associated_outages::Vector{PSY.UnplannedOutage};
    col_name:: String = "name"
    )
    required_variables = variables[var_name]
    total_variable_dict = Dict{String, Vector{Float64}}()
    for outage in associated_outages
        outage_name = string(IS.get_uuid(outage))
        outage_power_v = Vector{Float64}()
        devices = PSY.get_associated_components(
                            sys,
                            outage;
                            component_type = PSY.Generator,
                        )
        for (i, device) in enumerate(devices)
            device_name = PSY.get_name(device)
            current_v = filter( x -> x[col_name] == device_name, required_variables)[!,"value"]
            if i == 1
                outage_power_v = current_v
            else
                outage_power_v .+= current_v
            end
            
        end
        total_variable_dict[outage_name] = outage_power_v
    end
    return total_variable_dict
end
   

function get_reserve_total_power_by_step_dict(
    variables::Dict{String, DataFrame}, 
    var_name::String, 
    associated_outages::Vector{PSY.UnplannedOutage},
    contributing_devices::Union{IS.FlattenIteratorWrapper{<:PSY.Generator}, Vector{<:PSY.Generator}};
    col_name:: String = "name2"
    )
    required_variables = variables[var_name]
    total_variable_dict = Dict{String, Vector{Float64}}()
    for outage in associated_outages
        outage_name = string(IS.get_uuid(outage))
        outage_power_v = Vector{Float64}()
        
        for (i, device) in enumerate(contributing_devices)
            device_name = PSY.get_name(device)
            current_v = filter( x -> x[col_name] == device_name, required_variables)[!,"value"]
            if i == 1
                outage_power_v = current_v
            else
                outage_power_v .+= current_v
            end
            
        end
        total_variable_dict[outage_name] = outage_power_v
    end
    return total_variable_dict
end

function test_reserves_deployment(
    power_outage::Float64,
    reserve_deployment::Float64;
    tol::Float64 = 1e-3
)
    @test isapprox(power_outage, reserve_deployment, atol = tol)
end

function compare_outage_power_and_deployed_reserves(
    sys::PSY.System,
    res::OptimizationProblemResults,
    service::PSY.VariableReserve;
    tolerance::Float64 = 1e-3
    )
    variablesdict = read_variables(res)
    
    associated_outages = PSY.get_supplemental_attributes(PSY.UnplannedOutage, service)
    outage_dict = get_outage_total_power_by_step_dict(
        sys,
        variablesdict, 
        "ActivePowerVariable__ThermalStandard", 
        associated_outages;
        col_name = "name"
    )

    contributing_devices = PSY.get_contributing_devices(
        sys,
        service
    )
    service_name = PSY.get_name(service)
    reserve_dict = get_reserve_total_power_by_step_dict(
        variablesdict, 
        "PostContingencyActivePowerReserveDeploymentVariable__VariableReserve__ReserveUp__" * service_name, 
        associated_outages, 
        contributing_devices;
        col_name = "name2"
    )
    for outage in associated_outages
        outage_name = string(IS.get_uuid(outage))
        for i in 1:length(outage_dict[outage_name])
            test_reserves_deployment(
                outage_dict[outage_name][i],
                reserve_dict[outage_name][i],
            )
        end
    end
    
end