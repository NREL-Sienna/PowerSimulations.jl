# Internal functions to create the variable DataFrame

function _result_dataframe_variables(variable::JuMP.Containers.DenseAxisArray)

    if length(axes(variable)) == 1
        result = Vector{Float64}(undef, length(first(variable.axes)))

        for t in variable.axes[1]
            result[t] = JuMP.value(variable[t])
        end

        return DataFrames.DataFrame(var = result)

    elseif length(axes(variable)) == 2

        result = Array{Float64, length(variable.axes)}(undef, length(variable.axes[2]), length(variable.axes[1]))
        names = Array{Symbol, 1}(undef, length(variable.axes[1]))

        for t in variable.axes[2], (ix, name) in enumerate(variable.axes[1])
            result[t, ix] = JuMP.value(variable[name, t])
            names[ix] = Symbol(name)
        end

        return DataFrames.DataFrame(result, names)

    elseif length(axes(variable)) == 3
        extra_dims = sum(length(axes(variable)[2:end-1]))
        extra_vars = [Symbol("S$(s)") for s in 1:extra_dims]
        result_df = DataFrames.DataFrame()
        names = vcat(extra_vars, Symbol.(axes(variable)[1]))

        for i in variable.axes[2]
            third_dim = collect(fill(i,size(variable)[end]))
            result = Array{Float64 ,2}(undef, length(last(variable.axes)),
                                              length(first(variable.axes)))
            for t in last(variable.axes), (ix, name) in enumerate(first(variable.axes))
                result[t, ix] = JuMP.value(variable[name, i, t])
            end
            res = DataFrames.DataFrame(hcat(third_dim, result))
            result_df = vcat(result_df, res)
        end

        return DataFrames.names!(result_df, names)

    else
        error("Dimension Number $(length(axes(variable))) not Supported")

    end

end

function _result_dataframe_duals(constraint::JuMP.Containers.DenseAxisArray)

    result = Array{Float64, length(constraint.axes)}(undef, length(constraint.axes[1]))
    names = Array{Symbol, 1}(undef, length(constraint.axes[1]))

    for (ix, name) in enumerate(constraint.axes[1])
        try result[ix] = JuMP.dual(constraint[name])
        catch
            result[ix] = NaN
        end
    end

    return DataFrames.DataFrame(Price = result)

end

# Function to write results dataframes and variables to a dictionary

function get_model_result(op_m::OperationsProblem)

    results_dict = Dict{Symbol, DataFrames.DataFrame}()

    for (k, v) in get_variables(op_m.canonical)
        results_dict[k] = _result_dataframe_variables(v)
    end

    return results_dict

end

function get_model_duals(op_m::OperationsProblem, cons::Vector{Symbol})

    results_dict = Dict{Symbol, DataFrames.DataFrame}()

    for c in cons
        v = get_constraint(op_m.canonical, c)
        results_dict[c] = _result_dataframe_duals(v)
    end

    return results_dict

end

# Function to create a dictionary for the optimizer log of the simulation

function get_optimizer_log(op_m::OperationsProblem)

    canonical = op_m.canonical

    optimizer_log = Dict{Symbol, Any}()

    optimizer_log[:obj_value] = JuMP.objective_value(canonical.JuMPmodel)
    optimizer_log[:termination_status] = JuMP.termination_status(canonical.JuMPmodel)
    optimizer_log[:primal_status] = JuMP.primal_status(canonical.JuMPmodel)
    optimizer_log[:dual_status] = JuMP.dual_status(canonical.JuMPmodel)
    optimizer_log[:solver] =  JuMP.solver_name(canonical.JuMPmodel)
    try
        optimizer_log[:solve_time] = MOI.get(canonical.JuMPmodel, MOI.SolveTime())
    catch
        @warn("SolveTime() property not supported by $(optimizer_log[:solver])")
        optimizer_log[:solve_time] = "Not Supported by $(optimizer_log[:solver])"
    end
    return optimizer_log
end

# Function to create a dictionary for the time series of the simulation

function get_time_stamps(op_problem::OperationsProblem)

    initial_time = PSY.get_forecasts_initial_time(op_problem.sys)
    interval = PSY.get_forecasts_resolution(op_problem.sys)
    horizon = PSY.get_forecasts_horizon(op_problem.sys)
    range = collect(initial_time:interval:initial_time+interval.*horizon)
    time_stamp = DataFrames.DataFrame(Range = range[:,1])

    return time_stamp
end

function get_time_stamps(stage::_Stage, start_time::Dates.DateTime)

    interval = PSY.get_forecasts_resolution(stage.sys)
    horizon = PSY.get_forecasts_horizon(stage.sys)
    range = collect(start_time:interval:start_time+ interval.*horizon)
    time_stamp = DataFrames.DataFrame(Range = range[:,1])

    return time_stamp
end
