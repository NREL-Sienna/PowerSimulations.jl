abstract type AbstractOperationsProblem end

struct DefaultOpModel<:AbstractOperationsProblem end

mutable struct FormulationTemplate
    transmission::Type{<:PM.AbstractPowerModel}
    devices::Dict{Symbol, DeviceModel}
    branches::Dict{Symbol, DeviceModel}
    services::Dict{Symbol, ServiceModel}
end

"""
    FormulationTemplate(::Type{T}) where {T<:PM.AbstractPowerFormulation}

Creates a model reference of the Power Formulation, devices, branches, and services.

# Arguments
-`model::Type{T<:PM.AbstractPowerFormulation}`:
-`devices::Dict{Symbol, DeviceModel}`: device dictionary
-`branches::Dict{Symbol, BranchModel}`: branch dictionary
-`services::Dict{Symbol, ServiceModel}`: service dictionary

# Example
```julia
model_ref= FormulationTemplate(CopperPlatePowerModel, devices, branches, services)
```
"""
function FormulationTemplate(::Type{T}) where {T<:PM.AbstractPowerModel}

    return  FormulationTemplate(T,
                           Dict{Symbol, DeviceModel}(),
                           Dict{Symbol, DeviceModel}(),
                           Dict{Symbol, ServiceModel}())

end

mutable struct OperationsProblem{M<:AbstractOperationsProblem}
    model_ref::FormulationTemplate
    sys::PSY.System
    canonical::Canonical
end

"""
    OperationsProblem(::Type{M},
    model_ref::FormulationTemplate,
    sys::PSY.System;
    optimizer::Union{Nothing, JuMP.OptimizerFactory}=nothing,
    kwargs...) where {M<:AbstractOperationsProblem,
                      T<:PM.AbstractPowerFormulation}

This builds the optimization model and populates the operation model

# Arguments
-`::Type{M} where {M<:AbstractOperationsProblem, T<:PM.AbstractPowerFormulation} = TestOptModel`:
The abstract operation model type
-`model_ref::FormulationTemplate`: The model reference made up of transmission, devices,
                                          branches, and services.
-`sys::PSY.System`: the system created using Power Systems

# Output
-`op_model::OperationsProblem`: The operation model contains the model type, model, Power
Systems system, and optimization model.

# Example
```julia
model_ref= FormulationTemplate(CopperPlatePowerModel, devices, branches, services)
OpModel = OperationsProblem(TestOptModel, model_ref, c_sys5_re; PTDF = PTDF5, optimizer = GLPK_optimizer)
```

# Accepted Key Words
-`verbose::Bool = true`: verbose default is true
-`PTDF::PTDF = PTDF`: Passes the PTDF matrix into the optimization model
-`optimizer::union{Nothing,JuMP.OptimizerFactory} = GLPK_optimizer`: The optimizer gets passed
into the optimization model the default is nothing.
-`initial_conditions::DICKDA = DICKDA()`: default of Dict{ICKey, Array{InitialCondition}}
-`parameters::Bool = false`: enable JuMP parameters
-`use_forecast_data::Bool = true`: if true, forecast collects the time steps in Power Systems,
if false it runs for one time step
-`initial_time::Dates.DateTime = PSY.get_forecasts_initial_time(sys)`: initial time of forecast
"""
function OperationsProblem(::Type{M},
                        model_ref::FormulationTemplate,
                        sys::PSY.System;
                        optimizer::Union{Nothing, JuMP.OptimizerFactory}=nothing,
                        kwargs...) where {M<:AbstractOperationsProblem}

    op_model = OperationsProblem{M}(model_ref,
                          sys,
                          Canonical(model_ref.transmission, sys, optimizer; kwargs...))

    build_op_model!(op_model; kwargs...)

    return  op_model

end
"""
    OperationsProblem(op_model::Type{M},
                    ::Type{T},
                    sys::PSY.System;
                    kwargs...) where {M<:AbstractOperationsProblem,
                                    T<:PM.AbstractPowerFormulation}

This uses the Abstract Power Formulation to build the model reference and
the optimization model and populates the operation model struct.

# Arguments
-`op_model::Type{M} = where {M<:AbstractOperationsProblem`: Defines the type of the operation model
-`::Type{T} where T<:PM.AbstractPowerFormulation`: The power formulation used for model ref & optimization model
-`sys::PSY.System = c_sys5`: the system created in Power Systems

# Output
-`op_model::OperationsProblem`: The operation model contains the model type, model, Power
Systems system, and optimization model.

# Example
```julia
model_ref= FormulationTemplate(CopperPlatePowerModel, devices, branches, services)
OpModel = OperationsProblem(TestOptModel, model_ref, c_sys5_re; PTDF = PTDF5, optimizer = GLPK_optimizer)
```


# Accepted Key Words
-`verbose::Bool = true`: verbose default is true
-`PTDF::PTDF = PTDF`: Passes the PTDF matrix into the optimization model
-`optimizer::union{Nothing,JuMP.OptimizerFactory}`: The optimizer gets passed
into the optimization model the default is nothing.
-`initial_conditions::DICKDA = DICKDA()`: default of Dict{ICKey, Array{InitialCondition}}
-`parameters::Bool = false`: enable JuMP parameters
-`use_forecast_data::Bool = true`: if true, forecast collects the time steps in Power Systems,
if false it runs for one time step
-`initial_time::Dates.DateTime = PSY.get_forecasts_initial_time(sys)`: initial time of forecast

"""
function OperationsProblem(::Type{M},
                        ::Type{T},
                        sys::PSY.System;
                        kwargs...) where {M<:AbstractOperationsProblem,
                                          T<:PM.AbstractPowerModel}

    optimizer = get(kwargs, :optimizer, nothing)
    return OperationsProblem{M}(FormulationTemplate(T),
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
-`op_model::Type{M}`: Defines the type of the operation model
-`::Type{T} where T<:PM.AbstractPowerFormulation`: The power formulation used for model ref & optimization model
-`sys::PSY.System`: the system created in Power Systems

# Output
-`op_model::OperationsProblem`: The operation model contains the model type, model, Power
Systems system, and optimization model.

# Example
```julia
model_ref= FormulationTemplate(CopperPlatePowerModel, devices, branches, services)
OpModel = OperationsProblem(TestOptModel, model_ref, c_sys5_re; PTDF = PTDF5, optimizer = GLPK_optimizer)
```

# Accepted Key Words
-`verbose::Bool = true`: verbose default is true
-`PTDF::PTDF = PTDF`: Passes the PTDF matrix into the optimization model
-`optimizer::union{Nothing,JuMP.OptimizerFactory}`: The optimizer gets passed
into the optimization model the default is nothing.
-`initial_conditions::DICKDA = DICKDA()`: default of Dict{ICKey, Array{InitialCondition}}
-`parameters::Bool = false`: enable JuMP parameters
-`use_forecast_data::Bool = true`: if true, forecast collects the time steps in Power Systems,
if false it runs for one time step
-`initial_time::Dates.DateTime`: initial time of forecast

"""
function OperationsProblem(::Type{T},
                        sys::PSY.System;
                        kwargs...) where {T<:PM.AbstractPowerModel}

    return OperationsProblem(DefaultOpModel,
                         T,
                         sys; kwargs...)

end

get_transmission_ref(op_model::OperationsProblem) = op_model.model_ref.transmission
get_devices_ref(op_model::OperationsProblem) = op_model.model_ref.devices
get_branches_ref(op_model::OperationsProblem) = op_model.model_ref.branches
get_services_ref(op_model::OperationsProblem) = op_model.model_ref.services
get_system(op_model::OperationsProblem) = op_model.sys

function set_transmission_ref!(op_model::OperationsProblem{M},
                               transmission::Type{T}; kwargs...) where {T<:PM.AbstractPowerModel,
                                                                        M<:AbstractOperationsProblem}

    # Reset the canonical
    op_model.model_ref.transmission = transmission
    op_model.canonical = Canonical(transmission,
                                        op_model.sys,
                                        op_model.canonical.optimizer_factory; kwargs...)

    build_op_model!(op_model; kwargs...)

    return
end

function set_devices_ref!(op_model::OperationsProblem{M},
                          devices::Dict{Symbol, DeviceModel}; kwargs...) where M<:AbstractOperationsProblem

    # Reset the canonical
    op_model.model_ref.devices = devices
    op_model.canonical = Canonical(op_model.model_ref.transmission,
                                        op_model.sys,
                                        op_model.canonical.optimizer_factory; kwargs...)

    build_op_model!(op_model; kwargs...)

    return
end

function set_branches_ref!(op_model::OperationsProblem{M},
                           branches::Dict{Symbol, DeviceModel}; kwargs...) where M<:AbstractOperationsProblem

    # Reset the canonical
    op_model.model_ref.branches = branches
    op_model.canonical = Canonical(op_model.model_ref.transmission,
                                        op_model.sys,
                                        op_model.canonical.optimizer_factory; kwargs...)

    build_op_model!(op_model; kwargs...)

    return
end

function set_services_ref!(op_model::OperationsProblem{M},
                           services::Dict{Symbol, DeviceModel}; kwargs...) where M<:AbstractOperationsProblem

    # Reset the canonical
    op_model.model_ref.services = services
    op_model.canonical = Canonical(op_model.model_ref.transmission,
                                        op_model.sys,
                                        op_model.canonical.optimizer_factory; kwargs...)

    build_op_model!(op_model; kwargs...)

    return
end

function set_device_model!(op_model::OperationsProblem{M},
                           name::Symbol,
                           device::DeviceModel{D, B}; kwargs...) where {D<:PSY.Injection,
                                                                        B<:AbstractDeviceFormulation,
                                                                        M<:AbstractOperationsProblem}

    if haskey(op_model.model_ref.devices, name)
        op_model.model_ref.devices[name] = device
        op_model.canonical = Canonical(op_model.model_ref.transmission,
                                            op_model.sys,
                                            op_model.canonical.optimizer_factory; kwargs...)
        build_op_model!(op_model; kwargs...)
    else
        error("Device Model with name $(name) doesn't exist in the model")
    end

    return

end

function set_branch_model!(op_model::OperationsProblem{M},
                           name::Symbol,
                           branch::DeviceModel{D, B}; kwargs...) where {D<:PSY.Branch,
                                                                        B<:AbstractDeviceFormulation,
                                                                        M<:AbstractOperationsProblem}

    if haskey(op_model.model_ref.branches, name)
        op_model.model_ref.branches[name] = branch
        op_model.canonical = Canonical(op_model.model_ref.transmission,
                                            op_model.sys,
                                            op_model.canonical.optimizer_factory; kwargs...)
        build_op_model!(op_model; kwargs...)
    else
        error("Branch Model with name $(name) doesn't exist in the model")
    end

    return

end

function set_services_model!(op_model::OperationsProblem{M},
                             name::Symbol,
                             service::DeviceModel; kwargs...) where M<:AbstractOperationsProblem

    if haskey(op_model.model_ref.devices, name)
        op_model.model_ref.services[name] = service
        op_model.canonical = Canonical(op_model.model_ref.transmission,
                                            op_model.sys,
                                            op_model.canonical.optimizer_factory; kwargs...)
        build_op_model!(op_model; kwargs...)
    else
        error("Branch Model with name $(name) doesn't exist in the model")
    end

    return

end

function construct_device!(op_model::OperationsProblem,
                           name::Symbol,
                           device_model::DeviceModel;
                           kwargs...)

    if haskey(op_model.model_ref.devices, name)
        error("Device with model name $(name) already exists in the Opertaion Model")
    end

    devices_ref = get_devices_ref(op_model)
    devices_ref[name] = device_model

    construct_device!(op_model.canonical,
                      get_system(op_model),
                      device_model,
                      get_transmission_ref(op_model);
                      kwargs...)

    JuMP.@objective(op_model.canonical.JuMPmodel,
                    MOI.MIN_SENSE,
                    op_model.canonical.cost_function)

    return

end

function construct_network!(op_model::OperationsProblem; kwargs...)

    construct_network!(op_model, op_model.model_ref.transmission; kwargs...)

    return
end


function construct_network!(op_model::OperationsProblem,
                            system_formulation::Type{T};
                            kwargs...) where {T<:PM.AbstractPowerModel}

    construct_network!(op_model.canonical, get_system(op_model), T; kwargs...)

    return
end


function get_initial_conditions(op_model::OperationsProblem)
    return op_model.canonical.initial_conditions
end

function get_initial_conditions(op_model::OperationsProblem,
                                ic::InitialConditionQuantity,
                                device::PSY.Device)

    canonical = op_model.canonical
    key = ICKey(ic, device)

    return get_initial_conditions(canonical, key)

end
