const _SERIALIZED_MODEL_FILENAME = "model.bin"
const _SERIALIZED_OPTIMIZER_ATTRS =
    (MOI.Silent(), MOI.NumberOfThreads(), MOI.TimeLimitSec())

struct OptimizerAttributes
    name::String
    attrs::Dict
end

function OptimizerAttributes(model::OperationModel)
    name = JuMP.solver_name(get_jump_model(model))
    return OptimizerAttributes(name, _get_optimizer_attributes(model))
end

function _get_optimizer_attributes(model::OperationModel)
    jump_model = get_jump_model(model)
    attributes = Dict()
    for attr in _SERIALIZED_OPTIMIZER_ATTRS
        try
            attributes[string(attr)] = JuMP.get_optimizer_attribute(jump_model, attr)
        catch e
            # Not all solvers support all attributes.
            @debug "Failed to get $attr: $e"
        end
    end

    return attributes
end

struct ProblemSerializationWrapper
    template::ProblemTemplate
    sys::Union{Nothing, String}
    settings::Settings
    model_type::DataType
    name::String
    optimizer::OptimizerAttributes
end

function serialize_problem(model::OperationModel)
    # A PowerSystem cannot be serialized in this format because of how it stores
    # time series data. Use its specialized serialization method instead.
    sys_to_file = get_system_to_file(get_settings(model))
    if sys_to_file
        sys = get_system(model)
        sys_filename = joinpath(get_output_dir(model), make_system_filename(sys))
        # Skip serialization if the system is already in the folder
        !ispath(sys_filename) && PSY.to_json(sys, sys_filename)
    else
        sys_filename = nothing
    end
    container = get_optimization_container(model)
    obj = ProblemSerializationWrapper(
        model.template,
        sys_filename,
        container.settings_copy,
        typeof(model),
        string(get_name(model)),
        OptimizerAttributes(model),
    )
    bin_file_name = joinpath(get_output_dir(model), _SERIALIZED_MODEL_FILENAME)
    Serialization.serialize(bin_file_name, obj)
    @info "Serialized DecisionModel to" bin_file_name
end

function deserialize_problem(
    ::Type{T},
    directory::AbstractString;
    kwargs...,
) where {T <: OperationModel}
    filename = joinpath(directory, _SERIALIZED_MODEL_FILENAME)
    if !isfile(filename)
        error("$directory does not contain a serialized model")
    end
    obj = Serialization.deserialize(filename)
    if !(obj isa ProblemSerializationWrapper)
        throw(IS.DataFormatError("deserialized object has incorrect type $(typeof(obj))"))
    end
    sys = get(kwargs, :system, nothing)
    settings = restore_from_copy(obj.settings; optimizer = kwargs[:optimizer])
    if sys === nothing
        if obj.sys === nothing && !settings[:sys_to_file]
            throw(
                IS.DataFormatError(
                    "Operations Problem System was not serialized and a System has not been specified.",
                ),
            )
        elseif !ispath(obj.sys)
            throw(IS.DataFormatError("PowerSystems.System file $(obj.sys) does not exist"))
        end
        sys = PSY.System(obj.sys)
    end

    model =
        obj.model_type(obj.template, sys, kwargs[:jump_model]; name = obj.name, settings...)
    jump_model = get_jump_model(model)
    if obj.optimizer.name == JuMP.solver_name(jump_model)
        new_attrs = _get_optimizer_attributes(model)
        for attr in _SERIALIZED_OPTIMIZER_ATTRS
            attr_name = string(attr)
            new = get(new_attrs, attr_name, nothing)
            old = get(obj.optimizer.attrs, attr_name, nothing)
            if new != old
                @warn "Original solver used attribute $attr = $old. New solver uses $new."
            end
        end
    else
        @warn "Original solver was $(obj.optimizer.name), new solver is $(JuMP.solver_name(jump_model))"
    end

    return model
end
