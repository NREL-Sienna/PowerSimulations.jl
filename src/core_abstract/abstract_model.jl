export AbstractPowerModel
export SimulationModel
export PowerResults

struct AbstractPowerModel
    cost::Function
    device::Any
    dynamics::Function
    network::Function
    model::Jump.Model
end

struct SimulationModel
    model::AbstractPowerModel
    periods::Int
    resolution::Int
    date_from::Datetime
    date_to::Datetime
    lookahead_periods::Int
    lookahead_resolution::Int
    reserve_products::Any
    dynamic_analysis::Bool
    forecast::Any #Need to define this properly
    #A constructor here has to return the model based on the data, the time is AbstractModel
end

struct PowerResults 
    Dispatch::TimeSeries.TimeArray
    Solveroutput::Any 
end 

