# Internal functions to create the variable DataFrame

function _result_dataframe(variable::JuMP.Containers.DenseAxisArray)

    result = Array{Float64, length(variable.axes)}(undef, length(variable.axes[2]), length(variable.axes[1]))
    names = Array{Symbol, 1}(undef, length(variable.axes[1]))

    for t in variable.axes[2], (ix, name) in enumerate(variable.axes[1])

        result[t, ix] = JuMP.value(variable[name, t])

        names[ix] = Symbol(name)

    end

    return DataFrames.DataFrame(result, names)

end

function _result_dataframe_d(constraint::JuMP.Containers.DenseAxisArray)

    result = Array{Float64, length(constraint.axes)}(undef, length(constraint.axes[1]))
    names = Array{Symbol, 1}(undef, length(constraint.axes[1]))

    for (ix, name) in enumerate(constraint.axes[1])
        try result[ix] = JuMP.dual(constraint[name])
        catch
            result[ix] = NAN
        end
    end

    return DataFrames.DataFrame(Price = result)

end

# Function to write results dataframes and variables to a dictionary

function get_model_result(op_m::OperationModel)

    results_dict = Dict{Symbol, DataFrames.DataFrame}()

    for (k, v) in vars(op_m.canonical)

        results_dict[k] = _result_dataframe(v)

    end

    return results_dict

end

function get_model_duals(op_m::OperationModel, cons::Vector{Symbol})

    results_dict = Dict{Symbol, DataFrames.DataFrame}()

    for c in cons

        v = con(op_m.canonical, c)
        results_dict[c] = _result_dataframe_d(v)

    end

    return results_dict

end

# Function to create a dictionary for the optimizer log of the simulation

function get_optimizer_log(op_m::OperationModel)

    ps_m = op_m.canonical

    optimizer_log = Dict{Symbol, Any}()

    optimizer_log[:obj_value] = JuMP.objective_value(ps_m.JuMPmodel)
    optimizer_log[:termination_status] = JuMP.termination_status(ps_m.JuMPmodel)
    optimizer_log[:primal_status] = JuMP.primal_status(ps_m.JuMPmodel)
    optimizer_log[:dual_status] = JuMP.dual_status(ps_m.JuMPmodel)
    optimizer_log[:solver] =  JuMP.solver_name(ps_m.JuMPmodel)
    try
        optimizer_log[:solve_time] = MOI.get(ps_m.JuMPmodel, MOI.SolveTime())
    catch
        @warn("SolveTime() property not supported by $(optimizer_log[:solver])")
        optimizer_log[:solve_time] = "Not Supported by $(optimizer_log[:solver])"
    end
    return optimizer_log
end

# Function to create a dictionary for the time series of the simulation

function get_time_stamp(op_model::OperationModel)

    initial_time = PSY.get_forecast_initial_times(op_model.sys)[1]
    interval = PSY.get_forecasts_resolution(op_model.sys)
    horizon = PSY.get_forecasts_horizon(op_model.sys)
    range = collect(initial_time:interval:initial_time+ interval.*horizon)
    time_stamp = DataFrames.DataFrame(Range = range[:,1])
  
    return time_stamp
end

