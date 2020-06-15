abstract type InitialConditionChronology end
abstract type InitialConditionType end

"""
    InterStageChronology()

    Type struct to select an information sharing model between stages that uses results from the most recent stage executed to calculate the initial conditions. This model takes into account solutions from stages defined finer resolutions
"""

struct InterStageChronology <: InitialConditionChronology end

"""
    InterStageChronology()

    Type struct to select an information sharing model between stages that uses results from the same recent stage to calculate the initial conditions. This model ignores solutions from stages defined finer resolutions.
"""
struct IntraStageChronology <: InitialConditionChronology end

#########################Initial Conditions Definitions#####################################
struct DevicePower <: InitialConditionType end
struct DeviceStatus <: InitialConditionType end
struct TimeDurationON <: InitialConditionType end
struct TimeDurationOFF <: InitialConditionType end
struct EnergyLevel <: InitialConditionType end
struct AreaControlError <: InitialConditionType end
