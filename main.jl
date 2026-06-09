# main.jl

using PowerModelsDistribution
using Ipopt
using JSON

include("src/postprocess.jl")
include("src/run_vpp_opf.jl")

dss_path = "data/opendss_case33/Master.dss"

println("Loading case...")

println()
println("-------------------------------------")
println("Running VPP OPF...")
vpp_opf_result = run_vpp_demo(dss_path)
print_summary(vpp_opf_result)
save_result("result/vpp_opf_result.json", vpp_opf_result)

println("Done.")
