########################### Interfaces ########################################################
get_variable_key(variabletype, d) = error("Not Implemented")

get_variable_binary(pv, t::Type{<:PSY.Component}, _) =
    error("`get_variable_binary` must be implemented for $pv and $t")

get_variable_warm_start_value(_, ::PSY.Component, __) = nothing

get_variable_lower_bound(_, ::PSY.Component, __) = nothing

get_variable_upper_bound(_, ::PSY.Component, __) = nothing

get_multiplier_value(::StartupCostParameter, d::PSY.Device, ::AbstractDeviceFormulation) =
    1.0
get_multiplier_value(::ShutdownCostParameter, d::PSY.Device, ::AbstractDeviceFormulation) =
    1.0
get_multiplier_value(::CostAtMinParameter, d::PSY.Device, ::AbstractDeviceFormulation) =
    1.0

get_multiplier_value(x, y::PSY.Component, z) =
    error("Unable to get parameter $x for device $(IS.summary(y)) for formulation $z")

get_expression_type_for_reserve(_, y::Type{<:PSY.Component}, z) =
    error("`get_expression_type_for_reserve` must be implemented for $y and $z")

get_initial_conditions_device_model(
    ::OperationModel,
    ::DeviceModel{T, D},
) where {T <: PSY.Device, D <: AbstractDeviceFormulation} =
    error("`get_initial_conditions_device_model` must be implemented for $T and $D")

requires_initialization(::AbstractDeviceFormulation) = false

does_subcomponent_exist(T::PSY.Component, S::Type{<:PSY.Component}) =
    error("`does_subcomponent_exist` must be implemented for $T and subcomponent type $S")

_get_initial_condition_type(
    X::Type{<:ConstraintType},
    Y::Type{<:PSY.Component},
    Z::Type{<:AbstractDeviceFormulation},
) = error("`_get_initial_condition_type` must be implemented for $X , $Y and $Z")

get_initial_conditions_device_model(
    ::OperationModel,
    model::DeviceModel{T, FixedOutput},
) where {T <: PSY.Device} = model

get_default_on_variable(component::T) where {T <: PSY.Component} = OnVariable()
get_default_on_parameter(component::T) where {T <: PSY.Component} = OnStatusParameter()
