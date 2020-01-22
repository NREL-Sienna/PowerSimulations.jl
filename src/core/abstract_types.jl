# All subtypes of AbstractAffectFeedForward must define the field affected_variables.
# TODO: make a unit test that checks for this.
abstract type AbstractAffectFeedForward end

abstract type AbstractCache end
abstract type AbstractChronology end
abstract type InitialConditionQuantity end
abstract type Results end
abstract type AbstractOperationsProblem end
