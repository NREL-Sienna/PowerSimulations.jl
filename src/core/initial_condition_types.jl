abstract type InitialConditionChronology end
abstract type InitialConditionType end

"""
    InterProblemChronology()

    Type struct to select an information sharing model between stages that uses results from the most recent stage executed to calculate the initial conditions. This model takes into account solutions from stages defined finer resolutions
"""

struct InterProblemChronology <: InitialConditionChronology end

"""
    InterProblemChronology()

    Type struct to select an information sharing model between stages that uses results from the same recent stage to calculate the initial conditions. This model ignores solutions from stages defined finer resolutions.
"""
struct IntraProblemChronology <: InitialConditionChronology end

######################### Initial Conditions Definitions#####################################
struct DevicePower <: InitialConditionType end
struct DeviceStatus <: InitialConditionType end
struct InitialInitialTimeDurationON <: InitialConditionType end
struct InitialInitialTimeDurationOFF <: InitialConditionType end
struct InitialInitialEnergyLevel <: InitialConditionType end
struct InitialInitialEnergyLevelUP <: InitialConditionType end
struct InitialInitialEnergyLevelDOWN <: InitialConditionType end
struct AreaControlError <: InitialConditionType end
