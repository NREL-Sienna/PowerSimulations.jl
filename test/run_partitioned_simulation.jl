using PowerSimulations
using PowerSystems
using PowerSystemCaseBuilder
using InfrastructureSystems
import PowerSystemCaseBuilder: PSITestSystems
using Logging
using Test

using PowerModels
using DataFrames
using Dates
using JuMP
using TimeSeries
using ParameterJuMP
using CSV
using DataFrames
using DataStructures
import UUIDs
using Random
import Serialization

const PM = PowerModels
const PSY = PowerSystems
const PSI = PowerSimulations
const PSB = PowerSystemCaseBuilder

const PJ = ParameterJuMP
const IS = InfrastructureSystems
const BASE_DIR = string(dirname(dirname(pathof(PowerSimulations))))
const DATA_DIR = joinpath(BASE_DIR, "test/test_data")

include(joinpath(BASE_DIR, "test/test_utils/common_operation_model.jl"))
include(joinpath(BASE_DIR, "test/test_utils/model_checks.jl"))
include(joinpath(BASE_DIR, "test/test_utils/mock_operation_models.jl"))
include(joinpath(BASE_DIR, "test/test_utils/solver_definitions.jl"))
include(joinpath(BASE_DIR, "test/test_utils/operations_problem_templates.jl"))

function build_simulation(
    output_dir::AbstractString,
    simulation_name::AbstractString,
    partitions::Union{Nothing, SimulationPartitions}=nothing,
    index::Union{Nothing, Integer}=nothing;
    initial_time=nothing,
    num_steps=nothing,
)
    if isnothing(partitions) && isnothing(num_steps)
        error("num_steps must be set if partitions is nothing")
    end
    if !isnothing(partitions) && !isnothing(num_steps)
        error("num_steps and partitions cannot both be set")
    end
    c_sys5_pjm_da = PSB.build_system(PSITestSystems, "c_sys5_pjm")
    PSY.transform_single_time_series!(c_sys5_pjm_da, 48, Hour(24))
    c_sys5_pjm_rt = PSB.build_system(PSITestSystems, "c_sys5_pjm_rt")
    PSY.transform_single_time_series!(c_sys5_pjm_rt, 12, Hour(1))

    for sys in [c_sys5_pjm_da, c_sys5_pjm_rt]
        th = get_component(ThermalStandard, sys, "Park City")
        set_active_power_limits!(th, (min=0.1, max=1.7))
        set_status!(th, false)
        set_active_power!(th, 0.0)
        c = get_operation_cost(th)
        c.start_up = 1500
        c.shut_down = 75
        set_time_at_status!(th, 1)

        th = get_component(ThermalStandard, sys, "Alta")
        set_time_limits!(th, (up=5, down=1))
        set_active_power_limits!(th, (min=0.05, max=0.4))
        set_active_power!(th, 0.05)
        c = get_operation_cost(th)
        c.start_up = 400
        c.shut_down = 200
        set_time_at_status!(th, 2)

        th = get_component(ThermalStandard, sys, "Brighton")
        set_active_power_limits!(th, (min=2.0, max=6.0))
        c = get_operation_cost(th)
        set_active_power!(th, 4.88041)
        c.start_up = 5000
        c.shut_down = 3000

        th = get_component(ThermalStandard, sys, "Sundance")
        set_active_power_limits!(th, (min=1.0, max=2.0))
        set_time_limits!(th, (up=5, down=1))
        set_active_power!(th, 2.0)
        c = get_operation_cost(th)
        c.start_up = 4000
        c.shut_down = 2000
        set_time_at_status!(th, 1)

        th = get_component(ThermalStandard, sys, "Solitude")
        set_active_power_limits!(th, (min=1.0, max=5.2))
        set_ramp_limits!(th, (up=0.0052, down=0.0052))
        set_active_power!(th, 2.0)
        c = get_operation_cost(th)
        c.start_up = 3000
        c.shut_down = 1500
    end

    to_json(c_sys5_pjm_da, "PSI-5-BUS-UC-ED/c_sys5_pjm_da.json"; force=true)
    to_json(c_sys5_pjm_rt, "PSI-5-BUS-UC-ED/c_sys5_pjm_rt.json"; force=true)

    HiGHSoptimizer = optimizer_with_attributes(HiGHS.Optimizer)

    template_uc = template_unit_commitment()
    set_network_model!(
        template_uc,
        NetworkModel(
            StandardPTDFModel;
            PTDF=PTDF(c_sys5_pjm_da),
            # duals = [CopperPlateBalanceConstraint]
        ),
    )

    set_device_model!(template_uc, ThermalStandard, ThermalStandardUnitCommitment)
    template_ed = deepcopy(template_uc)
    set_device_model!(template_ed, ThermalStandard, ThermalStandardDispatch)

    models = SimulationModels(
        decision_models=[
            DecisionModel(
                template_uc,
                c_sys5_pjm_da,
                optimizer=HiGHSoptimizer,
                name="UC",
                initialize_model=false,
            ),
            DecisionModel(
                template_ed,
                c_sys5_pjm_rt,
                optimizer=HiGHSoptimizer,
                name="ED",
                calculate_conflict=false,
            ),
        ],
    )
    sequence = SimulationSequence(
        models=models,
        feedforwards=Dict(
            "ED" => [
                SemiContinuousFeedforward(
                    component_type=ThermalStandard,
                    source=OnVariable,
                    affected_values=[ActivePowerVariable],
                ),
            ],
        ),
        ini_cond_chronology=InterProblemChronology(),
    )

    sim = Simulation(
        name=simulation_name,
        steps=isnothing(partitions) ? num_steps : partitions.num_steps,
        models=models,
        sequence=sequence,
        simulation_folder=output_dir,
        initial_time=initial_time,
    )

    status = build!(sim; partitions=partitions, index=index, serialize=isnothing(index))
    if status != PSI.BuildStatus.BUILT
        error("Failed to build simulation: status=$status")
    end

    return sim
end

function execute_simulation(sim, args...; kwargs...)
    return execute!(sim)
end
