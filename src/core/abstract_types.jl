# All subtypes of AbstractAffectFeedForward must define the field affected_variables.
# TODO: make a unit test that checks for this.
abstract type AbstractAffectFeedForward end

abstract type AbstractCache end
abstract type FeedForwardChronology end
abstract type IniCondChronology end
abstract type InitialConditionType end
abstract type Results end
abstract type AbstractOperationsProblem end
