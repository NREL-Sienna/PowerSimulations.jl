#! format: off

abstract type AbstractHybridFormulation <: AbstractDeviceFormulation end
struct Case4 <: AbstractHybridFormulation end
struct Case3 <: AbstractHybridFormulation end
struct Case2 <: AbstractHybridFormulation end
struct Case1 <: AbstractHybridFormulation end

########################### ActivePowerInVariable, HybridSystem #################################

get_variable_binary(::ActivePowerInVariable, ::Type{<:PSY.HybridSystem}) = false
get_variable_expression_name(::ActivePowerInVariable, ::Type{<:PSY.HybridSystem}) = :nodal_balance_active

get_variable_initial_value(pv::ActivePowerInVariable, d::PSY.HybridSystem, settings) = nothing

get_variable_lower_bound(::ActivePowerInVariable, d::PSY.HybridSystem, _) = PSY.get_input_active_power_limits(d).min
get_variable_upper_bound(::ActivePowerInVariable, d::PSY.HybridSystem, _) = PSY.get_input_active_power_limits(d).max

########################### ActivePowerOutVariable, HybridSystem #################################

get_variable_binary(::ActivePowerOutVariable, ::Type{<:PSY.HybridSystem}) = false
get_variable_expression_name(::ActivePowerOutVariable, ::Type{<:PSY.HybridSystem}) = :nodal_balance_active

get_variable_initial_value(pv::ActivePowerOutVariable, d::PSY.HybridSystem, settings) = nothing

get_variable_lower_bound(::ActivePowerOutVariable, d::PSY.HybridSystem, _) = PSY.get_output_active_power_limits(d).min
get_variable_upper_bound(::ActivePowerOutVariable, d::PSY.HybridSystem, _) = PSY.get_output_active_power_limits(d).max

############## ActivePowerVariableThermal, HybridSystem ####################

get_variable_binary(::ActivePowerVariableThermal, ::Type{<:PSY.HybridSystem}) = false
# get_variable_expression_name(::ActivePowerVariableThermal, ::Type{<:PSY.HybridSystem}) = :nodal_balance_active

get_variable_initial_value(pv::ActivePowerVariableThermal, d::PSY.HybridSystem, settings) = nothing

get_variable_lower_bound(::ActivePowerVariableThermal, d::PSY.HybridSystem, _) = isnothing(PSY.get_thermal_unit(d)) ? nothing : PSY.get_active_power_limits(PSY.get_thermal_unit(d)).min
get_variable_upper_bound(::ActivePowerVariableThermal, d::PSY.HybridSystem, _) = isnothing(PSY.get_thermal_unit(d)) ? nothing : PSY.get_active_power_limits(PSY.get_thermal_unit(d)).max

############## ActivePowerVariableLoad, HybridSystem ####################

get_variable_binary(::ActivePowerVariableLoad, ::Type{<:PSY.HybridSystem}) = false
# get_variable_expression_name(::ActivePowerVariableLoad, ::Type{<:PSY.HybridSystem}) = :nodal_balance_active

get_variable_initial_value(pv::ActivePowerVariableLoad, d::PSY.HybridSystem, settings) = nothing

get_variable_lower_bound(::ActivePowerVariableLoad, d::PSY.HybridSystem, _) = isnothing(PSY.get_electric_load(d)) ? nothing : PSY.get_max_active_power(PSY.get_electric_load(d))
get_variable_upper_bound(::ActivePowerVariableLoad, d::PSY.HybridSystem, _) =  nothing

############## ActivePowerInVariableStorage, HybridSystem ####################

get_variable_binary(::ActivePowerInVariableStorage, ::Type{<:PSY.HybridSystem}) = false
# get_variable_expression_name(::ActivePowerInVariableStorage, ::Type{<:PSY.HybridSystem}) = :nodal_balance_active

get_variable_initial_value(pv::ActivePowerInVariableStorage, d::PSY.HybridSystem, settings) = nothing

get_variable_lower_bound(::ActivePowerInVariableStorage, d::PSY.HybridSystem, _) = isnothing(PSY.get_storage(d)) ? nothing : PSY.get_input_active_power_limits(PSY.get_storage(d)).min
get_variable_upper_bound(::ActivePowerInVariableStorage, d::PSY.HybridSystem, _) = isnothing(PSY.get_storage(d)) ? nothing : PSY.get_input_active_power_limits(PSY.get_storage(d)).max

############## ActivePowerOutVariableStorage, HybridSystem ####################

get_variable_binary(::ActivePowerOutVariableStorage, ::Type{<:PSY.HybridSystem}) = false
# get_variable_expression_name(::ActivePowerOutVariableStorage, ::Type{<:PSY.HybridSystem}) = :nodal_balance_active

get_variable_initial_value(pv::ActivePowerOutVariableStorage, d::PSY.HybridSystem, settings) = nothing

get_variable_lower_bound(::ActivePowerOutVariableStorage, d::PSY.HybridSystem, _) = isnothing(PSY.get_storage(d)) ? nothing : PSY.get_output_active_power_limits(PSY.get_storage(d)).min
get_variable_upper_bound(::ActivePowerOutVariableStorage, d::PSY.HybridSystem, _) = isnothing(PSY.get_storage(d)) ? nothing : PSY.get_output_active_power_limits(PSY.get_storage(d)).max

############## ActivePowerVariableRenewable, HybridSystem ####################

get_variable_binary(::ActivePowerVariableRenewable, ::Type{<:PSY.HybridSystem}) = false
# get_variable_expression_name(::ActivePowerVariableRenewable, ::Type{<:PSY.HybridSystem}) = :nodal_balance_active

get_variable_initial_value(pv::ActivePowerVariableRenewable, d::PSY.HybridSystem, settings) = nothing

get_variable_lower_bound(::ActivePowerVariableRenewable, d::PSY.HybridSystem, _) = isnothing(PSY.get_renewable_unit(d)) ? nothing : PSY.get_output_active_power_limits(PSY.get_renewable_unit(d)).min
get_variable_upper_bound(::ActivePowerVariableRenewable, d::PSY.HybridSystem, _) = isnothing(PSY.get_renewable_unit(d)) ? nothing : PSY.get_output_active_power_limits(PSY.get_renewable_unit(d)).max


"""
Add variables to the PSIContainer for any component.
"""
function add_variables!(
    psi_container::PSIContainer,
    ::Type{T},
    devices::Union{Vector{U}, IS.FlattenIteratorWrapper{U}},
) where {T <: VariableType, U <: PSY.Component}
    thermal_devices = PSY.get_thermal_unit.(devices)
    add_variable!(psi_container, T(), thermal_devices)

    load_devices = PSY.get_electric_load.(devices)
    add_variable!(psi_container, T(), load_devices)

    storage_devices = PSY.get_storage.(devices)
    add_variable!(psi_container, T(), storage_devices)

    renewable_devices = PSY.get_renewable_unit.(devices)
    add_variable!(psi_container, T(), renewable_devices)
end
