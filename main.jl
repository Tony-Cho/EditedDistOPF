# main.jl

using PowerModelsDistribution
using Ipopt
using JSON

include("src/parse_case.jl")
include("src/modify_case.jl")
include("src/run_pf.jl")
include("src/run_opf.jl")
include("src/postprocess.jl")

dss_path = "data/opendss_case33/Master.dss"

println("Loading case...")
eng = load_case(dss_path)

# println("Setting voltage limits...")
# eng = set_voltage_limits!(eng; vmin=0.95, vmax=1.05)

println("Running power flow...")
pf_result = run_pf(eng)
print_summary(pf_result)
save_result("result/pf_result.json", pf_result)

# println("Running OPF...")
# opf_result = run_opf(eng)
# print_summary(opf_result)
# save_result("result/opf_result.json", opf_result)

println("Done.")
