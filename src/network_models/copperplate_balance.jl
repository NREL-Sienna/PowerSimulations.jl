function copperplatebalance(m::JuMP.Model, DeviceNetInjection::A, TsInjectionBalance:: Array{Float64}, time_periods::Int64) where A <: PowerExpressionArray

    TsInjectionBalance = sum(TsInjectionBalance, 1)

    @constraintref cpn[1:time_periods]

    for t in 1:time_periods
        # TODO: Check is sum() is the best way to do this. Update in JuMP 0.19 to append!()
        cpn[t] = @constraint(m, sum(DeviceNetInjection[:,t]) == TsInjectionBalance[t])
    end

    JuMP.registercon(m, :CopperPlateBalance, cpn)

    return m
end