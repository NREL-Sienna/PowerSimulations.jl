function build_cache!(cache::TimeStatusChange, op_model::OperationModel)
    build_cache!(cache, op_model.canonical)
end

function build_cache!(cache::TimeStatusChange, canonical::CanonicalModel)
    parameter = get_value(canonical, cache.ref)
    value_array = JuMP.Containers.DenseAxisArray{Dict{Symbol, Float64}}(undef, axes(parameter)...)

    for name in parameter.axes[1]
        status = PJ.value(parameter[name])
        value_array[name] = Dict(:count => 999.0, :status => status)
    end

    cache.value = value_array

    return

end
