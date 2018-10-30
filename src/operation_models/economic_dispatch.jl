"""
This function populates a particular AbstractPowerSimulationModel and populates the fields according to the
    data in the system and stablishes the device models included which effectively are calls to the construction
    functions.
"""

function economic_dispatch(sys,tp)
    m = JuMP.Model()
    #Variable Creation
    p_th = activepowervariables(m, sys.generators["Thermal"], tp);
    # on_th, start_th, stop_th = PowerSimulations.CommitmentVariables(m, system.generators["Thermal"], tp)

    fl = BranchFlowVariables(m, sys.network.branches, tp);
    pcl = PowerSimulations.LoadVariables(m, sys.loads, tp);

    powerconstraints(m, p_th, sys.generators["Thermal"], tp);
    powerconstraints(m, pcl, [sys.loads[4]], tp);


    KCLBalance(m, sys, fl, p_th, pcl, tp);

    CopperPlateNetwork(m, sys, fl, tp);
    objective = PowerSimulations.VariableCostGen(p_th, sys.generators["Thermal"]);

    device = sys.loads[4]
    for i in [device.name]
        for t in 1:time_periods
            objective = objective + 5000*(pcl[i, t] - device.maxactivepower * values(device.scalingfactor)[t])
        end
    end

    @objective(m, :Min, objective);

    return m

end
