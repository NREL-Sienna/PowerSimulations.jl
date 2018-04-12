export EconomicDispatch 

"""
This function populates a particular AbstractPowerModel and populates the fields according to the 
    data in the system and stablishes the device models included which effectively are calls to the construction
    functions. 
"""

function EconomicDispatch(data)

    return AbstractPowerModel( 
        cost
        devices,
        dynamics,
        network,
        Model()
    )

end