const POWER_MODELS = ApiType("PowerModels", "Power Models")
const DEVICE_FORMULATIONS =
    ApiType("DeviceFormulations", "PowerSimulations Device Formulations")
const SERVICE_FORMULATIONS =
    ApiType("ServiceFormulations", "PowerSimulations Service Formulations")
const DECISION_PROBLEMS =
    ApiType("DecisionProblems", "PowerSimulations Decision Problem Types")
const INITIAL_CONDITION_CHRONOLOGIES = ApiType(
    "InitialConditionChronologies",
    "PowerSimulations Initial Condition Chronology Types",
)
const VARIABLE_TYPES =
    ApiType("VariableTypes", "PowerSimulations Variable Types")
const DEVICES = ApiType("Devices", "PowerSystems Device Types")
const SERVICES = ApiType("Services", "PowerSystems Service Types")
const OPTIMIZERS =
    ApiType("Optimizers", "PowerSimulations-Supported Optimizers")
const DECISION_PROBLEM_TYPES =
    ApiType("DecisionProblems", "PowerSimulations Decision Problem Types")

const API_TYPES = OrderedDict(
    DECISION_PROBLEMS.name => (DECISION_PROBLEMS, PSI.DecisionProblem),
    DEVICES.name => (DEVICES, PSY.Device),
    DEVICE_FORMULATIONS.name => (DEVICE_FORMULATIONS, PSI.AbstractDeviceFormulation),
    INITIAL_CONDITION_CHRONOLOGIES.name => (INITIAL_CONDITION_CHRONOLOGIES, PSI.InitialConditionChronology),
    OPTIMIZERS.name => (OPTIMIZERS, AbstractOptimizer),
    POWER_MODELS.name => (POWER_MODELS, PM.AbstractPowerModel),
    SERVICES.name => (SERVICES, PSY.Service),
    SERVICE_FORMULATIONS.name => (SERVICE_FORMULATIONS, PSI.AbstractServiceFormulation),
    VARIABLE_TYPES.name => (VARIABLE_TYPES, PSI.VariableType),
    DECISION_PROBLEM_TYPES.name => (DECISION_PROBLEM_TYPES, PSI.DecisionProblem)
)

function get_siip_type(category::AbstractString, name::AbstractString)
    return check_key(API_TYPES[category][1], name)
end

function initialize_api_types()
    for (api_type, siip_type) in values(API_TYPES)
        # We could consider generating enums instead of strings.
        # That would make it easier for Julia users to consume this API.
        empty!(api_type.members)
        types = [(string(nameof(x)), x) for x in IS.get_all_concrete_subtypes(siip_type)]
        sort!(types, by=x -> x[1])
        for (name, type) in types
            api_type.members[name] = type
        end
    end

    @debug "Initialized API types"
end
