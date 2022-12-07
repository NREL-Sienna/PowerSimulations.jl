# Definitions

## D

* *Decision Problem*: A decision problem calculates the desired system operation based on forecasts of uncertain inputs and information about the state of the system. The output of a decision problem represents the policies used to drive the set-points of the system's devices, like generators or switches, and depends on the purpose of the problem.

## E

* *Emulation Problem*: An emulation problem is used to mimic the system's behavior subject to an incoming decision and the realization of a forecasted inputs. The solution of the emulator produces outputs representative of the system performance when operating subject the policies resulting from the decision models.

## H

* *Horizon*: The number of steps in the look-ahead of a decision problem. For instance, a Day-ahead problem usually has a 48 step horizon.

## I

* *Interval*:

## R

* *Resolution*: The amount of time between timesteps in a simulation. For instance 1-hour or 5-minutes. In Julia these are defined using the syntax `Hour(1)` and `Minute(5)`
