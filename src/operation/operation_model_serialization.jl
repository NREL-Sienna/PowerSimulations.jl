const _SERIALIZED_MODEL_FILENAME = "model.bin"

struct OptimizerAttributes
    name::String
    version::String
    attributes::Any
end

function OptimizerAttributes(model::OperationModel, optimizer::MOI.OptimizerWithAttributes)
    jump_model = get_jump_model(model)
    name = JuMP.solver_name(jump_model)
    # Note that this uses private field access to MOI.OptimizerWithAttributes because there
    # is no public method available.
    # This could break if MOI changes their implementation.
    try
        version = MOI.get(JuMP.backend(jump_model), MOI.SolverVersion())
        return OptimizerAttributes(name, version, optimizer.params)
    catch
        @debug "Solver Version not supported by the solver"
        version = "MOI.SolverVersion not supported"
        return OptimizerAttributes(name, version, optimizer.params)
    end
end

function _get_optimizer_attributes(model::OperationModel)
    return get_optimizer(get_settings(model)).params
end

struct ProblemSerializationWrapper
    template::ProblemTemplate
    sys::Union{Nothing, String}
    settings::Settings
    model_type::DataType
    name::String
    optimizer::OptimizerAttributes
end

function serialize_problem(model::OperationModel; optimizer = nothing)
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

    if optimizer === nothing
        optimizer = get_optimizer(get_settings(model))
        @assert optimizer !== nothing "optimizer must be passed if it wasn't saved in Settings"
    end

    obj = ProblemSerializationWrapper(
        model.template,
        sys_filename,
        container.settings_copy,
        typeof(model),
        string(get_name(model)),
        OptimizerAttributes(model, optimizer),
    )
    bin_file_name = joinpath(get_output_dir(model), _SERIALIZED_MODEL_FILENAME)
    Serialization.serialize(bin_file_name, obj)
    @info "Serialized OperationModel to" bin_file_name
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
    settings =
        Settings(sys; restore_from_copy(obj.settings; optimizer = kwargs[:optimizer])...)
    model =
        obj.model_type(obj.template, sys, settings, kwargs[:jump_model]; name = obj.name)
    jump_model = get_jump_model(model)
    if obj.optimizer.name == JuMP.solver_name(jump_model)
        orig_attrs = obj.optimizer.attributes
        new_attrs = _get_optimizer_attributes(model)
        if length(orig_attrs) != length(new_attrs)
            @warn "Different optimizer attributes are set. Original: $orig_attrs New: $new_attrs"
        else
            for attrs in (orig_attrs, new_attrs)
                sort!(attrs; by = x -> x.first.name)
            end
            for i in 1:length(orig_attrs)
                name = orig_attrs[i].first.name
                orig = orig_attrs[i].second
                new = new_attrs[i].second
                if new != orig
                    @warn "Original solver used $name = $orig. New solver uses $new."
                end
            end
        end
    else
        @warn "Original solver was $(obj.optimizer.name), new solver is $(JuMP.solver_name(jump_model))"
    end

    return model
end
