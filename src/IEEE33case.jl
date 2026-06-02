# run_case33bw_opf.jl

using PowerModelsDistribution
using Ipopt
using JSON

dss_path = "data/case33bw_dss/Master.dss"

# 读取 OpenDSS 文件
eng = parse_file(dss_path)

# 求解多导体 AC-OPF
result = solve_mc_opf(
    eng,
    ACPUPowerModel,
    Ipopt.Optimizer
)

println("Termination status: ", result["termination_status"])
println("Objective value: ", result["objective"])

# 保存结果
open("case33bw_opf_result.json", "w") do io
    JSON.print(io, result, 4)
end