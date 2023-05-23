function get_default_time_series_names(
    ::Type{PSY.TransmissionInterface},
    ::Type{ConstantMaxInterfaceFlow},
)
    return Dict{Type{<:TimeSeriesParameter}, String}()
end

function get_default_attributes(
    ::Type{<:PSY.TransmissionInterface},
    ::Type{ConstantMaxInterfaceFlow})
    return Dict{String, Any}()
end

function get_initial_conditions_service_model(
    ::OperationModel,
    ::ServiceModel{T, D},
) where {T <: PSY.TransmissionInterface, D <: ConstantMaxInterfaceFlow}
    return ServiceModel(T, D)
end
