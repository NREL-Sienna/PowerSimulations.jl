# Solvers
using Ipopt
using GLPK
using SCS
using HiGHS
using Cbc

ipopt_optimizer =
    JuMP.optimizer_with_attributes(Ipopt.Optimizer, "tol" => 1e-6, "print_level" => 0)
fast_ipopt_optimizer = JuMP.optimizer_with_attributes(
    Ipopt.Optimizer,
    "print_level" => 0,
    "max_cpu_time" => 5.0,
)
# use default print_level = 5 # set to 0 to disable
GLPK_optimizer =
    JuMP.optimizer_with_attributes(GLPK.Optimizer, "msg_lev" => GLPK.GLP_MSG_OFF)
scs_solver = JuMP.optimizer_with_attributes(
    SCS.Optimizer,
    "max_iters" => 100000,
    "eps_rel" => 1e-4,
    "verbose" => 0,
)

HiGHS_optimizer = JuMP.optimizer_with_attributes(
    HiGHS.Optimizer,
    "time_limit" => 100.0,
    "log_to_console" => false,
)

cbc_optimizer = JuMP.optimizer_with_attributes(Cbc.Optimizer)
