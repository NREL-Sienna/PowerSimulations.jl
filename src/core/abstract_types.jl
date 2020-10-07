# All subtypes of AbstractAffectFeedForward must define the field affected_variables.
# TODO: make a unit test that checks for this.
abstract type AbstractAffectFeedForward end

abstract type AbstractCache end
abstract type FeedForwardChronology end

get_trigger(val::FeedForwardChronology) = val.trigger

abstract type AbstractOperationsProblem end
abstract type PowerSimulationsOperationsProblem <: AbstractOperationsProblem end
