"""Only used when building the model"""
function _retrieve_forecasts(sys::PSY.System, ::Type{C}) where {C <: PSY.Component}

    first_step = PSY.get_forecasts_initial_time(sys)
    forecasts = PSY.get_component_forecasts(C, sys, first_step)
    isempty(forecasts) && throw(IS.DataFormatError("System has no forecasts for device $(C)"))

    return collect(forecasts)
    #TODO: Remove this collect
end
