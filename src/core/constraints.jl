# The constants below are strings instead of enums because there is a requirement that users
# should be able to define their own without changing PowerSimulations.

# Constraints
const ACTIVE = "active"
const ACTIVE_RANGE = "activerange"
const ACTIVE_RANGE_LB = "activerange_lb"
const ACTIVE_RANGE_UB = "activerange_ub"
const COMMITMENT = "commitment"
const DURATION = "duration"
const DURATION_DOWN = "duration_dn"
const DURATION_UP = "duration_up"
const ENERGY_CAPACITY = "energy_capacity"
const ENERGY_CAPACITY_UP = "energy_capacity_up"
const ENERGY_CAPACITY_DOWN = "energy_capacity_down"
const ENERGY_LIMIT = "energy_limit"
const ENERGY_TARGET = "energy_target"
const FEEDFORWARD = "FF"
const FEEDFORWARD_UB = "FF_ub"
const FEEDFORWARD_BIN = "FF_bin"
const FEEDFORWARD_INTEGRAL_LIMIT = "FF_integral"
const FEEDFORWARD_POWER_COMMITMENT = "FF_power_commitment"
const FLOW_LIMIT = "FlowLimit"
const FLOW_LIMIT_FROM_TO = "FlowLimitFT"
const FLOW_LIMIT_TO_FROM = "FlowLimitTF"
const FLOW_REACTIVE_POWER_FROM_TO = "FqFT"
const FLOW_REACTIVE_POWER_TO_FROM = "FqTF"
const FLOW_ACTIVE_POWER_FROM_TO = "FpFT"
const FLOW_ACTIVE_POWER_TO_FROM = "FpTF"
const FLOW_ACTIVE_POWER = "Fp"
const FLOW_REACTIVE_POWER = "Fq"
const INPUT_POWER_RANGE = "inputpower_range"
const OUTPUT_POWER_RANGE = "outputpower_range"
const RAMP = "ramp"
const RAMP_DOWN = "ramp_dn"
const RAMP_UP = "ramp_up"
const RATE_LIMIT = "RateLimit"
const RATE_LIMIT_FT = "RateLimitFT"
const RATE_LIMIT_TF = "RateLimitTF"
const REACTIVE = "reactive"
const REACTIVE_RANGE = "reactiverange"
const REQUIREMENT = "requirement"
const RESERVE_POWER = "reserve_power"
const RESERVE_ENERGY = "reserve_energy"
const INFLOW_RANGE = "inflowrange"
const ACTIVE_RANGE_IC = "active_range_ic"
const START_TYPE = "start_type"
const STARTUP_TIMELIMIT = "startup_timelimit"
const STARTUP_TIMELIMIT_WARM = "startup_timelimit_warm"
const STARTUP_TIMELIMIT_HOT = "startup_timelimit_warm"
const STARTUP_INITIAL_CONDITION = "startup_initial_condition"
const STARTUP_INITIAL_CONDITION_UB = "startup_initial_condition_ub"
const STARTUP_INITIAL_CONDITION_LB = "startup_initial_condition_lb"
const MUST_RUN = "must_run"
const MUST_RUN_LB = "must_run_lb"
const NODAL_BALANCE_ACTIVE = "nodal_balance_active"
const NODAL_BALANCE_REACTIVE = "nodal_balance_reactive"
const POWER_BALANCE_INFLOW = "power_balance_inflow"
const POWER_BALANCE_OUTFLOW = "power_balance_outflow"
const INVERTOR_LIMIT = "invertor_limit"
const BATTERY_COUPLING = "battery_coupling"
const NETWORK_FLOW = "network_flow"
const FEEDFORWARD_ENERGY_TARGET = "FF_energy_target"
const ENERGY_CONSTRAINT = "energy_constraint"

abstract type ConstraintType end

abstract type RangeConstraint <: ConstraintType end
abstract type EnergyBalanceConstraint <: ConstraintType end

abstract type ThermalRangeConstraint <: RangeConstraint end
abstract type ElectricLoadRangeConstraint <: RangeConstraint end
abstract type RenewableGenRangeConstraint <: RangeConstraint end
abstract type StorageRangeConstraint <: RangeConstraint end

function make_constraint_name(
    ::Type{T},
    ::Type{U},
    ::Type{V},
) where {T <: ConstraintType, U <: VariableType, V <: PSY.Device}
    return encode_symbol(T, make_variable_name(U, V))
end

make_constraint_name(cons_type, device_type) = encode_symbol(device_type, cons_type)
make_constraint_name(cons_type) = encode_symbol(cons_type)
