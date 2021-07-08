struct ICKey{T <: PSI.InitialConditionType, U <: PSY.Component} <:
       PSI.OptimizationContainerKey
    meta::String
end

function ICKey(
    ::Type{T},
    ::Type{U},
    meta = CONTAINER_KEY_EMPTY_META,
) where {T <: InitialConditionType, U <: PSY.Component}
    return ICKey{T, U}(meta)
end

get_entry_type(::ICKey{T, U}) where {T <: InitialConditionType, U <: PSY.Component} = T
get_component_type(::ICKey{T, U}) where {T <: InitialConditionType, U <: PSY.Component} = U

######################### Initial Conditions Definitions#####################################
struct DevicePower <: InitialConditionType end
struct DeviceStatus <: InitialConditionType end
struct InitialTimeDurationOn <: InitialConditionType end
struct InitialTimeDurationOff <: InitialConditionType end
struct InitialEnergyLevel <: InitialConditionType end
struct InitialEnergyLevelUp <: InitialConditionType end
struct InitialEnergyLevelDown <: InitialConditionType end
struct AreaControlError <: InitialConditionType end
