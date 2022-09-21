"""
Return the categories of types available as a JSON string.

# Examples
```julia
julia> JSON3.pretty(list_api_type_categories())
{
    "categories": [
        "DecisionProblems",
        "Devices",
        "DeviceFormulations",
        "InitialConditionChronologies",
        "Optimizers",
        "PowerModels",
        "Services",
        "ServiceFormulations",
        "VariableTypes"
    ]
}
```
"""
list_api_type_categories() = to_json(Dict("categories" => collect(keys(API_TYPES))))

"""
Return the types available for the given category.

# Examples
```julia
julia> JSON3.pretty(list_types("Devices"))
{
    "types": [
        "AggregateDistributedGenerationA",
        "BatteryEMS",
        "DynamicBranch",
        "ExponentialLoad",
        "FixedAdmittance",
        "GenericBattery",
        "GenericDER",
        "HVDCLine",
        "HybridSystem",
        "HydroDispatch",
        "HydroEnergyReservoir",
        "HydroPumpedStorage",
        "InterruptibleLoad",
        "Line",
        "MonitoredLine",
        "PeriodicVariableSource",
        "PhaseShiftingTransformer",
        "PowerLoad",
        "RenewableDispatch",
        "RenewableFix",
        "SimplifiedSingleCageInductionMachine",
        "SingleCageInductionMachine",
        "Source",
        "StandardLoad",
        "TapTransformer",
        "ThermalMultiStart",
        "ThermalStandard",
        "Transformer2W",
        "VSCDCLine"
    ]
}
```
"""
function list_types(category::AbstractString)
    container = get(API_TYPES, category, nothing)
    if isnothing(container)
        throw(InvalidApiKey("category = $category is not stored"))
    end
    return to_json(Dict("types" => list_keys(container[1])))
end

"""
Return the default settings for the given optimizer.

# Examples
```julia
julia> JSON3.pretty(get_default_optimizer_settings("HighsOptimizer"))
{
    "type": "HighsOptimizer",
    "time_limit": 100,
    "log_to_console": false
}
```
"""
function get_default_optimizer_settings(optimizer::AbstractString)
    check_key(OPTIMIZERS, optimizer)
    return to_json(OPTIMIZERS.members[optimizer]())
end

"""
Return the device types in the system.

# Examples
```julia
julia> JSON3.pretty(list_device_types(sys))
{
    "types": [
        "HydroPumpedStorage",
        "Line",
        "HydroDispatch",
        "ThermalStandard",
        "TapTransformer",
        "HydroEnergyReservoir",
        "PowerLoad"
    ]
}
```
"""
function list_device_types(system::PSY.System)
    to_json(
        Dict(
            "types" => [
                string(nameof(x)) for x in PSY.get_existing_device_types(system)
            ]
        )
    )
end

"""
Return the service types in the system.

# Examples
```julia
julia> JSON3.pretty(list_service_types(sys))
{
    "types": [
        "VariableReserve"
    ]
}
```
"""
function list_service_types(system::PSY.System)
    to_json(
        Dict(
            "types" => [
                string(nameof(x)) for x in PSY.get_existing_component_types(system) if x <: PSY.Service
            ]
        )
    )
end

"""
Return the device and service formulations available in the system.

# Examples
```julia
julia> JSON3.pretty(get_available_formulations(sys))
{
    "device_formulations": [
        {
            "device_type": "HydroDispatch",
            "formulation": "FixedOutput"
        },
        {
            "device_type": "HydroDispatch",
            "formulation": "HydroDispatchRunOfRiver"
        },
    "service_formulations": [
    ]
}
```
"""
function get_available_formulations(system::PSY.System)
    to_json(PSI.serialize_formulation_combinations(system))
end

"""
Return the device formulations that can be created with each device type.
Refer to [`get_available_formulations`](@ref) for how to get `formulations`.

# Examples
```julia
julia> JSON3.pretty(list_device_formulations_by_type(f))
{
    "formulations_by_type": [
        {
            "formulations": [
                "BatteryAncillaryServices",
                "BookKeeping",
                "EnergyTarget"
            ],
            "device_type": "GenericBattery"
        },
        {
            "formulations": [
                "FixedOutput",
                "HydroDispatchRunOfRiver",
                "HydroDispatchPumpedStorage",
                "HydroDispatchReservoirBudget",
                "HydroDispatchReservoirStorage",
                "HydroCommitmentReservoirBudget",
                "HydroCommitmentRunOfRiver"
            ],
            "device_type": "HydroDispatch"
        }
    ]
}
```
"""
function list_device_formulations_by_type(formulations::AbstractString)
    _list_formulations_by_type(formulations, "device")
end

"""
Return the service formulations that can be created with each service type.
Refer to [`get_available_formulations`](@ref) for how to get `formulations`.
"""
function list_service_formulations_by_type(formulations::AbstractString)
    _list_formulations_by_type(formulations, "service")
end

function _list_formulations_by_type(formulations::AbstractString, type)
    models = OrderedDict{String, Dict{String, Any}}()
    for item in from_json(Dict, formulations)["$(type)_formulations"]
        if !in(item["$(type)_type"], keys(models))
            models[item["$(type)_type"]] = Dict(
                "$(type)_type" => item["$(type)_type"], "formulations" => [item["formulation"]]
            )
        else
            push!(models[item["$(type)_type"]]["formulations"], item["formulation"])
        end
    end

    return to_json(Dict("formulations_by_type" => collect(values(models))))
end

"""
Construct the correct optimizer based on optimizer type and return the result.

# Examples
```julia
julia> JSON3.pretty(create_optimizer("HighsOptimizer", "{\"log_to_console\":false}"))
{
    "type": "HighsOptimizer",
    "time_limit": 100,
    "log_to_console": false
}
```
"""
function create_optimizer(optimizer_type::AbstractString, optimizer::AbstractString)
    to_json(from_json(get_siip_type("Optimizers", optimizer_type), optimizer))
end

"""
Construct the decision model and return the value as a Dict.
"""
function create_decision_model(decision_model::AbstractString)
    to_json(from_json(DecisionModel, decision_model))
end

"""
Construct the simulation and return the value as a Dict.
"""
function create_simulation(simulation::AbstractString)
    to_json(from_json(Simulation, simulation))
end
