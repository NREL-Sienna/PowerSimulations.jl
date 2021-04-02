"""
Add variables to the OptimizationContainer for any component.
"""
function add_variables!(
    optimization_container::OptimizationContainer,
    ::Type{T},
    devices::Union{Vector{U}, IS.FlattenIteratorWrapper{U}},
    formulation::Union{AbstractDeviceFormulation, AbstractServiceFormulation},
) where {T <: VariableType, U <: PSY.Component}
    add_variable!(optimization_container, T(), devices, formulation)
end

"""
Add variables to the OptimizationContainer for a service.
"""
function add_variables!(
    optimization_container::OptimizationContainer,
    ::Type{T},
    service::U,
    devices::Vector{V},
    formulation::AbstractReservesFormulation,
) where {T <: VariableType, U <: PSY.Reserve, V <: PSY.Device}
    add_variable!(optimization_container, T(), devices, service, formulation)
end

@doc raw"""
Adds a variable to the optimization model and to the affine expressions contained
in the optimization_container model according to the specified sign. Based on the inputs, the variable can
be specified as binary.

# Bounds

``` lb_value_function <= varstart[name, t] <= ub_value_function ```

If binary = true:

``` varstart[name, t] in {0,1} ```

# LaTeX

``  lb \ge x^{device}_t \le ub \forall t ``

``  x^{device}_t \in {0,1} \forall t iff \text{binary = true}``

# Arguments
* optimization_container::OptimizationContainer : the optimization_container model built in PowerSimulations
* devices : Vector or Iterator with the devices
* var_name::Symbol : Base Name for the variable
* binary::Bool : Select if the variable is binary
* expression_name::Symbol : Expression_name name stored in optimization_container.expressions to add the variable
* sign::Float64 : sign of the addition of the variable to the expression_name. Default Value is 1.0

# Accepted Keyword Arguments
* ub_value : Provides the function over device to obtain the value for a upper_bound
* lb_value : Provides the function over device to obtain the value for a lower_bound. If the variable is meant to be positive define lb = x -> 0.0
* initial_value : Provides the function over device to obtain the warm start value

"""
function add_variable!(
    optimization_container::OptimizationContainer,
    variable_type::VariableType,
    devices::U,
    formulation,
) where {U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}}} where {D <: PSY.Component}
    @assert !isempty(devices)
    time_steps = model_time_steps(optimization_container)
    settings = get_settings(optimization_container)
    var_name = make_variable_name(typeof(variable_type), D)
    binary = get_variable_binary(variable_type, D, formulation)
    expression_name = get_variable_expression_name(variable_type, D)
    sign = get_variable_sign(variable_type, D, formulation)

    variable = add_var_container!(
        optimization_container,
        var_name,
        [PSY.get_name(d) for d in devices],
        time_steps,
    )

    for t in time_steps, d in devices
        name = PSY.get_name(d)
        variable[name, t] = JuMP.@variable(
            optimization_container.JuMPmodel,
            base_name = "$(var_name)_{$(name), $(t)}",
            binary = binary
        )

        ub = get_variable_upper_bound(variable_type, d, formulation)
        !(ub === nothing) && JuMP.set_upper_bound(variable[name, t], ub)

        lb = get_variable_lower_bound(variable_type, d, formulation)
        !(lb === nothing) && !binary && JuMP.set_lower_bound(variable[name, t], lb)

        if get_warm_start(settings)
            init = get_variable_initial_value(variable_type, d, formulation)
            !(init === nothing) && JuMP.set_start_value(variable[name, t], init)
        end

        if !((expression_name === nothing))
            bus_number = PSY.get_number(PSY.get_bus(d))
            add_to_expression!(
                get_expression(optimization_container, expression_name),
                bus_number,
                t,
                variable[name, t],
                get_variable_sign(variable_type, eltype(devices), formulation),
            )
        end
    end

    return
end

# TODO: refactor this function when ServiceModel is updated to include service name
function add_variable!(
    optimization_container::OptimizationContainer,
    variable_type::VariableType,
    devices::U,
    service::T,
    formulation::AbstractReservesFormulation,
) where {
    T <: PSY.Service,
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
} where {D <: PSY.Component}
    @assert !isempty(devices)
    time_steps = model_time_steps(optimization_container)

    var_name = make_variable_name(PSY.get_name(service), T)
    binary = get_variable_binary(variable_type, T, formulation)
    expression_name = get_variable_expression_name(variable_type, T)
    sign = get_variable_sign(variable_type, T, formulation)

    variable = add_var_container!(
        optimization_container,
        var_name,
        [PSY.get_name(d) for d in devices],
        time_steps,
    )

    for t in time_steps, d in devices
        name = PSY.get_name(d)
        variable[name, t] = JuMP.@variable(
            optimization_container.JuMPmodel,
            base_name = "$(var_name)_{$(name), $(t)}",
            binary = binary
        )

        ub = get_variable_upper_bound(
            variable_type,
            service,
            d,
            optimization_container.settings,
        )
        !(ub === nothing) && JuMP.set_upper_bound(variable[name, t], ub)

        lb = get_variable_lower_bound(
            variable_type,
            service,
            d,
            optimization_container.settings,
        )
        !(lb === nothing) && !binary && JuMP.set_lower_bound(variable[name, t], lb)

        init = get_variable_initial_value(variable_type, d, optimization_container.settings)
        !(init === nothing) && JuMP.set_start_value(variable[name, t], init)

        if !((expression_name === nothing))
            bus_number = PSY.get_number(PSY.get_bus(d))
            add_to_expression!(
                get_expression(optimization_container, expression_name),
                bus_number,
                t,
                variable[name, t],
                get_variable_sign(variable_type, eltype(devices), formulation),
            )
        end
    end

    return
end

@doc raw"""
Adds a bounds to a variable in the optimization model.

# Bounds

``` bounds.min <= varstart[name, t] <= bounds.max  ```


# LaTeX

``  x^{device}_t >= bound^{min;} \forall t ``

``  x^{device}_t <= bound^{max} \forall t ``

# Arguments
* optimization_container::OptimizationContainer : the optimization_container model built in PowerSimulations
* bounds::DeviceRangeConstraintInfo : contains names and vector of min / max
* var_type::AbstractString : type of the variable
* T: type of the device

"""
function set_variable_bounds!(
    optimization_container::OptimizationContainer,
    bounds::Vector{DeviceRangeConstraintInfo},
    var_type::AbstractString,
    ::Type{T},
) where {T <: PSY.Component}
    var = get_variable(optimization_container, var_type, T)
    for t in model_time_steps(optimization_container), bound in bounds
        _var = var[get_component_name(bound), t]
        JuMP.set_upper_bound(_var, bound.limits.max)
        JuMP.set_lower_bound(_var, bound.limits.min)
    end
end

function commitment_variables!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
) where {T <: PSY.ThermalGen}
    time_steps = model_time_steps(optimization_container)
    if get_warm_start(optimization_container.settings)
        initial_value = d -> (PSY.get_active_power(d) > 0 ? 1.0 : 0.0)
    else
        initial_value = nothing
    end

    add_variable!(optimization_container, OnVariable(), devices)
    var_status = get_variable(optimization_container, OnVariable, T)
    for t in time_steps, d in devices
        name = PSY.get_name(d)
        bus_number = PSY.get_number(PSY.get_bus(d))
        add_to_expression!(
            get_expression(optimization_container, :nodal_balance_active),
            bus_number,
            t,
            var_status[name, t],
            PSY.get_active_power_limits(d).min,
        )
    end

    variable_types = [StartVariable(), StopVariable()]
    for variable_type in variable_types
        add_variable!(optimization_container, variable_type, devices)
    end

    return
end

"""
Add variables to the OptimizationContainer for any component.
"""
function add_variables!(
    optimization_container::OptimizationContainer,
    ::Type{T},
    devices::Union{Vector{U}, IS.FlattenIteratorWrapper{U}},
    formulation::AbstractDeviceFormulation,
) where {T <: SubComponentVariableType, U <: PSY.Component}
    add_subcomponent_variables!(optimization_container, T(), devices, formulation)
end

function add_subcomponent_variables!(
    optimization_container::OptimizationContainer,
    variable_type::T,
    devices::U,
    formulation::AbstractDeviceFormulation,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    T <: SubComponentVariableType,
} where {D <: PSY.HybridSystem}
    @assert !isempty(devices)
    time_steps = model_time_steps(optimization_container)
    var_name = make_variable_name(typeof(variable_type), eltype(devices))
    binary = get_variable_binary(variable_type, D, formulation)
    expression_name = get_variable_expression_name(variable_type, eltype(devices))
    sign = get_variable_sign(variable_type, D, formulation)
    subcomp_types = get_subcomponent_var_types(variable_type)
    variable = add_var_container!(
        optimization_container,
        var_name,
        [PSY.get_name(d) for d in devices],
        subcomp_types,
        time_steps;
        sparse = true,
    )

    for t in time_steps, d in devices, subcomp in subcomp_types
        name = PSY.get_name(d)

        if !check_subcomponent_exist(d, subcomp)
            continue
        end

        variable[name, subcomp, t] = JuMP.@variable(
            optimization_container.JuMPmodel,
            base_name = "$(var_name)_{$(name), $(subcomp), $(t)}",
            binary = binary
        )

        ub = get_variable_upper_bound(variable_type, d, optimization_container.settings)
        !(ub === nothing) && JuMP.set_upper_bound(variable[name, subcomp, t], ub)

        lb = get_variable_lower_bound(variable_type, d, optimization_container.settings)
        !(lb === nothing) && !binary && JuMP.set_lower_bound(variable[name, subcomp, t], lb)

        init = get_variable_initial_value(variable_type, d, optimization_container.settings)
        !(init === nothing) && JuMP.set_start_value(variable[name, subcomp, t], init)

        if !((expression_name === nothing))
            bus_number = PSY.get_number(PSY.get_bus(d))
            add_to_expression!(
                get_expression(optimization_container, expression_name),
                bus_number,
                t,
                variable[name, subcomp, t],
                get_variable_sign(variable_type, eltype(devices), formulation),
            )
        end
    end

    return
end

get_subcomponent_var_types(::SubComponentActivePowerInVariable) = [PSY.Storage]
get_subcomponent_var_types(::SubComponentActivePowerOutVariable) = [PSY.Storage]
get_subcomponent_var_types(::SubComponentActivePowerVariable) =
    [PSY.ThermalGen, PSY.RenewableGen, PSY.ElectricLoad]
get_subcomponent_var_types(::SubComponentReactivePowerVariable) =
    [PSY.ThermalGen, PSY.RenewableGen, PSY.ElectricLoad, PSY.Storage]
get_subcomponent_var_types(::SubComponentEnergyVariable) = [PSY.Storage]

check_subcomponent_exist(v::PSY.HybridSystem, ::Type{PSY.ThermalGen}) =
    isnothing(PSY.get_thermal_unit(v)) ? false : true
check_subcomponent_exist(v::PSY.HybridSystem, ::Type{PSY.RenewableGen}) =
    isnothing(PSY.get_renewable_unit(v)) ? false : true
check_subcomponent_exist(v::PSY.HybridSystem, ::Type{PSY.ElectricLoad}) =
    isnothing(PSY.get_electric_load(v)) ? false : true
check_subcomponent_exist(v::PSY.HybridSystem, ::Type{PSY.Storage}) =
    isnothing(PSY.get_storage(v)) ? false : true

get_index(name, t, ::Nothing) = JuMP.Containers.DenseAxisArrayKey((name, t))
get_index(name, t, type::Type{<:PSY.Component}) = (name, type, t)
