abstract type AbstractOperationsProblem end

struct GenericOpProblem<:AbstractOperationsProblem end

mutable struct OperationsTemplate
    transmission::Type{<:PM.AbstractPowerModel}
    devices::Dict{Symbol, DeviceModel}
    branches::Dict{Symbol, DeviceModel}
    services::Dict{Symbol, ServiceModel}
end

"""
    OperationsTemplate(::Type{T}) where {T<:PM.AbstractPowerFormulation}

Creates a model reference of the Power Formulation, devices, branches, and services.

# Arguments
- `model::Type{T<:PM.AbstractPowerFormulation}`:
- `devices::Dict{Symbol, DeviceModel}`: device dictionary
- `branches::Dict{Symbol, BranchModel}`: branch dictionary
- `services::Dict{Symbol, ServiceModel}`: service dictionary

# Example
```julia
template = OperationsTemplate(CopperPlatePowerModel, devices, branches, services)
```
"""
function OperationsTemplate(::Type{T}) where {T<:PM.AbstractPowerModel}

    return  OperationsTemplate(T,
                           Dict{Symbol, DeviceModel}(),
                           Dict{Symbol, DeviceModel}(),
                           Dict{Symbol, ServiceModel}())

end

mutable struct OperationsProblem{M<:AbstractOperationsProblem}
    template::OperationsTemplate
    sys::PSY.System
    canonical::Canonical
end

"""
    OperationsProblem(::Type{M},
    template::OperationsTemplate,
    sys::PSY.System;
    optimizer::Union{Nothing, JuMP.OptimizerFactory}=nothing,
    kwargs...) where {M<:AbstractOperationsProblem,
                      T<:PM.AbstractPowerFormulation}

This builds the optimization model and populates the operation model

# Arguments
- `::Type{M} where {M<:AbstractOperationsProblem, T<:PM.AbstractPowerFormulation} = TestOpProblem`:
The abstract operation model type
- `template::OperationsTemplate`: The model reference made up of transmission, devices,
                                          branches, and services.
- `sys::PSY.System`: the system created using Power Systems

# Output
- `op_problem::OperationsProblem`: The operation model contains the model type, model, Power
Systems system, and optimization model.

# Example
```julia
template = OperationsTemplate(CopperPlatePowerModel, devices, branches, services)
OpModel = OperationsProblem(TestOpProblem, template, system; optimizer = optimizer)
```

# Accepted Key Words
- `verbose::Bool`: verbose default is true
- `PTDF::PTDF`: Passes the PTDF matrix into the optimization model
- `optimizer::union{Nothing,JuMP.OptimizerFactory} = GLPK_optimizer`: The optimizer gets passed
into the optimization model the default is nothing.
- `initial_conditions::DICKDA`: default of Dict{ICKey, Array{InitialCondition}}
- `parameters::Bool`: enable JuMP parameters
- `use_forecast_data::Bool`: if true, forecast collects the time steps in Power Systems,
if false it runs for one time step
- `initial_time::Dates.DateTime`: initial time of forecast
"""
function OperationsProblem(::Type{M},
                        template::OperationsTemplate,
                        sys::PSY.System;
                        optimizer::Union{Nothing, JuMP.OptimizerFactory}=nothing,
                        kwargs...) where {M<:AbstractOperationsProblem}

    op_problem = OperationsProblem{M}(template,
                          sys,
                          Canonical(template.transmission, sys, optimizer; kwargs...))

    build_op_problem!(op_problem; kwargs...)

    return  op_problem

end
"""
    OperationsProblem(op_problem::Type{M},
                    ::Type{T},
                    sys::PSY.System;
                    kwargs...) where {M<:AbstractOperationsProblem,
                                    T<:PM.AbstractPowerFormulation}

This uses the Abstract Power Formulation to build the model reference and
the optimization model and populates the operation model struct.

# Arguments
- `op_problem::Type{M} = where {M<:AbstractOperationsProblem`: Defines the type of the operation model
- `::Type{T} where T<:PM.AbstractPowerFormulation`: The power formulation used for model ref & optimization model
- `sys::PSY.System`: the system created in Power Systems

# Output
- `op_problem::OperationsProblem`: The operation model contains the model type, model, Power
Systems system, and optimization model.

# Example
```julia
template = OperationsTemplate(CopperPlatePowerModel, devices, branches, services)
OpModel = OperationsProblem(TestOpProblem, template, system; optimizer = optimizer)
```


# Accepted Key Words
- `verbose::Bool`: verbose default is true
- `PTDF::PTDF`: Passes the PTDF matrix into the optimization model
- `optimizer::union{Nothing,JuMP.OptimizerFactory}`: The optimizer gets passed
into the optimization model the default is nothing.
- `initial_conditions::DICKDA`: default of Dict{ICKey, Array{InitialCondition}}
- `parameters::Bool`: enable JuMP parameters
- `use_forecast_data::Bool`: if true, forecast collects the time steps in Power Systems,
if false it runs for one time step
- `initial_time::Dates.DateTime`: initial time of forecast

"""
function OperationsProblem(::Type{M},
                        ::Type{T},
                        sys::PSY.System;
                        kwargs...) where {M<:AbstractOperationsProblem,
                                          T<:PM.AbstractPowerModel}

    optimizer = get(kwargs, :optimizer, nothing)
    return OperationsProblem{M}(OperationsTemplate(T),
                          sys,
                          Canonical(T, sys, optimizer; kwargs...))

end
"""
    OperationsProblem(::Type{T},
                    sys::PSY.System;
                    kwargs...) where {M<:AbstractOperationsProblem,
                                    T<:PM.AbstractPowerFormulation}

This uses the Abstract Power Formulation to build the model reference and
the optimization model and populates the operation model struct.

***Note:*** the abstract operation model is set to the default operation model

# Arguments
- `op_problem::Type{M}`: Defines the type of the operation model
- `::Type{T} where T<:PM.AbstractPowerFormulation`: The power formulation used for model ref & optimization model
- `sys::PSY.System`: the system created in Power Systems

# Output
- `op_problem::OperationsProblem`: The operation model contains the model type, model, Power
Systems system, and optimization model.

# Example
```julia
template = OperationsTemplate(CopperPlatePowerModel, devices, branches, services)
OpModel = OperationsProblem(TestOpProblem, template, system; optimizer = optimizer)
```

# Accepted Key Words
- `verbose::Bool`: verbose default is true
- `PTDF::PTDF`: Passes the PTDF matrix into the optimization model
- `optimizer::union{Nothing,JuMP.OptimizerFactory}`: The optimizer gets passed
into the optimization model the default is nothing.
- `initial_conditions::DICKDA`: default of Dict{ICKey, Array{InitialCondition}}
- `parameters::Bool`: enable JuMP parameters
- `use_forecast_data::Bool`: if true, forecast collects the time steps in Power Systems,
if false it runs for one time step
- `initial_time::Dates.DateTime`: initial time of forecast

"""
function OperationsProblem(::Type{T},
                        sys::PSY.System;
                        kwargs...) where {T<:PM.AbstractPowerModel}

    return OperationsProblem(GenericOpProblem,
                         T,
                         sys; kwargs...)

end

get_transmission_ref(op_problem::OperationsProblem) = op_problem.template.transmission
get_devices_ref(op_problem::OperationsProblem) = op_problem.template.devices
get_branches_ref(op_problem::OperationsProblem) = op_problem.template.branches
get_services_ref(op_problem::OperationsProblem) = op_problem.template.services
get_system(op_problem::OperationsProblem) = op_problem.sys

function set_transmission_model!(op_problem::OperationsProblem{M},
                               transmission::Type{T}; kwargs...) where {T<:PM.AbstractPowerModel,
                                                                        M<:AbstractOperationsProblem}

    # Reset the canonical
    op_problem.template.transmission = transmission
    op_problem.canonical = Canonical(transmission,
                                        op_problem.sys,
                                        op_problem.canonical.optimizer_factory; kwargs...)

    build_op_problem!(op_problem; kwargs...)

    return
end

function set_devices_template!(op_problem::OperationsProblem{M},
                          devices::Dict{Symbol, DeviceModel}; kwargs...) where M<:AbstractOperationsProblem

    # Reset the canonical
    op_problem.template.devices = devices
    op_problem.canonical = Canonical(op_problem.template.transmission,
                                        op_problem.sys,
                                        op_problem.canonical.optimizer_factory; kwargs...)

    build_op_problem!(op_problem; kwargs...)

    return
end

function set_branches_template!(op_problem::OperationsProblem{M},
                           branches::Dict{Symbol, DeviceModel}; kwargs...) where M<:AbstractOperationsProblem

    # Reset the canonical
    op_problem.template.branches = branches
    op_problem.canonical = Canonical(op_problem.template.transmission,
                                        op_problem.sys,
                                        op_problem.canonical.optimizer_factory; kwargs...)

    build_op_problem!(op_problem; kwargs...)

    return
end

function set_services_template!(op_problem::OperationsProblem{M},
                           services::Dict{Symbol, DeviceModel}; kwargs...) where M<:AbstractOperationsProblem

    # Reset the canonical
    op_problem.template.services = services
    op_problem.canonical = Canonical(op_problem.template.transmission,
                                        op_problem.sys,
                                        op_problem.canonical.optimizer_factory; kwargs...)

    build_op_problem!(op_problem; kwargs...)

    return
end

function set_device_model!(op_problem::OperationsProblem{M},
                           name::Symbol,
                           device::DeviceModel{D, B}; kwargs...) where {D<:PSY.Injection,
                                                                        B<:AbstractDeviceFormulation,
                                                                        M<:AbstractOperationsProblem}

    if haskey(op_problem.template.devices, name)
        op_problem.template.devices[name] = device
        op_problem.canonical = Canonical(op_problem.template.transmission,
                                            op_problem.sys,
                                            op_problem.canonical.optimizer_factory; kwargs...)
        build_op_problem!(op_problem; kwargs...)
    else
        error("Device Model with name $(name) doesn't exist in the model")
    end

    return

end

function set_branch_model!(op_problem::OperationsProblem{M},
                           name::Symbol,
                           branch::DeviceModel{D, B}; kwargs...) where {D<:PSY.Branch,
                                                                        B<:AbstractDeviceFormulation,
                                                                        M<:AbstractOperationsProblem}

    if haskey(op_problem.template.branches, name)
        op_problem.template.branches[name] = branch
        op_problem.canonical = Canonical(op_problem.template.transmission,
                                            op_problem.sys,
                                            op_problem.canonical.optimizer_factory; kwargs...)
        build_op_problem!(op_problem; kwargs...)
    else
        error("Branch Model with name $(name) doesn't exist in the model")
    end

    return

end

function set_services_model!(op_problem::OperationsProblem{M},
                             name::Symbol,
                             service::DeviceModel; kwargs...) where M<:AbstractOperationsProblem

    if haskey(op_problem.template.devices, name)
        op_problem.template.services[name] = service
        op_problem.canonical = Canonical(op_problem.template.transmission,
                                            op_problem.sys,
                                            op_problem.canonical.optimizer_factory; kwargs...)
        build_op_problem!(op_problem; kwargs...)
    else
        error("Branch Model with name $(name) doesn't exist in the model")
    end

    return

end

function construct_device!(op_problem::OperationsProblem,
                           name::Symbol,
                           device_model::DeviceModel;
                           kwargs...)

    if haskey(op_problem.template.devices, name)
        error("Device with model name $(name) already exists in the Opertaion Model")
    end

    devices_ref = get_devices_ref(op_problem)
    devices_ref[name] = device_model

    construct_device!(op_problem.canonical,
                      get_system(op_problem),
                      device_model,
                      get_transmission_ref(op_problem);
                      kwargs...)

    JuMP.@objective(op_problem.canonical.JuMPmodel,
                    MOI.MIN_SENSE,
                    op_problem.canonical.cost_function)

    return

end

function construct_network!(op_problem::OperationsProblem; kwargs...)

    construct_network!(op_problem, op_problem.template.transmission; kwargs...)

    return
end


function construct_network!(op_problem::OperationsProblem,
                            system_formulation::Type{T};
                            kwargs...) where {T<:PM.AbstractPowerModel}

    construct_network!(op_problem.canonical, get_system(op_problem), T; kwargs...)

    return
end


function get_initial_conditions(op_problem::OperationsProblem)
    return op_problem.canonical.initial_conditions
end

function get_initial_conditions(op_problem::OperationsProblem,
                                ic::InitialConditionQuantity,
                                device::PSY.Device)

    canonical = op_problem.canonical
    key = ICKey(ic, device)

    return get_initial_conditions(canonical, key)

end
