function solve_op_model!(op_model::PSI.PowerOperationModel; kwargs...) 

    if op_model.canonical_model.JuMPmodel.moi_backend.state == MOIU.NO_OPTIMIZER
        
        if !(:optimizer in keys(kwargs))
        
            @error("No Optimizer has been defined, can't solve the operational problem")
            
        else
                
            JuMP.optimize!(op_model.canonical_model.JuMPmodel, kwargs[:optimizer])
                
        end
    
    else
        
        JuMP.optimize!(op_model.canonical_model.JuMPmodel)
    
    end
            

end