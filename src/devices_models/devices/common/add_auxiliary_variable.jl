"""
Add variables to the OptimizationContainer for any component.
"""
function add_variables!(
    optimization_container::OptimizationContainer,
    ::Type{T},
    devices::Union{Vector{U}, IS.FlattenIteratorWrapper{U}},
    formulation::Union{AbstractDeviceFormulation, AbstractServiceFormulation},
) where {T <: AuxVariableType, U <: PSY.Component}
    add_variable!(optimization_container, T(), devices, formulation)
end


@doc raw"""
Adds an auxiliary variable to the model. These variables are populated after the model is
solved.
"""
function add_variable!(
    optimization_container::OptimizationContainer,
    variable_type::AuxVariableType,
    devices::U,
    formulation,
) where {U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}}} where {D <: PSY.Component}
    @assert !isempty(devices)
    time_steps = model_time_steps(optimization_container)
    var_name = make_variable_name(typeof(variable_type), D)
    variable = add_aux_var_container!(
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
