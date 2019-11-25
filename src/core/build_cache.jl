function build_cache!(cache::TimeStatusChange, op_problem::OperationsProblem)
    build_cache!(cache, op_problem.psi_container)
end

function build_cache!(cache::TimeStatusChange, psi_container::PSIContainer)
    parameter = get_value(psi_container, cache.ref)
    value_array = JuMP.Containers.DenseAxisArray{Dict{Symbol, Float64}}(undef, axes(parameter)...)

    for name in parameter.axes[1]
        status = PJ.value(parameter[name])
        value_array[name] = Dict(:count => 999.0, :status => status)
    end

    cache.value = value_array

    return

end
