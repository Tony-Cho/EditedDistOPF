# EditedDistOPF

## IEEE 33 节点配电网模型

本项目使用 OpenDSS 格式的 IEEE 33 节点配电网测试系统，包含以下数据文件：

### 数据文件结构

```
data/opendss_case33/
├── Master.dss      # 主文件，定义电路和求解设置
├── Lines.dss       # 线路参数定义
└── Loads.dss       # 负荷参数定义
```

### 参数说明

#### 1. Loads.dss - 负荷参数

| 参数 | 含义 | 示例值 |
|------|------|--------|
| `phases` | 负荷相数 | `3`（三相） |
| `bus1` | 连接母线及端子 | `bus2.1.2.3`（bus2 的 A、B、C 相） |
| `conn` | 连接方式 | `wye`（星形）/ `delta`（三角形） |
| `kv` | 额定电压（kV） | `12.66` |
| `kw` | 有功功率（kW） | `100.0` |
| `kvar` | 无功功率（kvar） | `60.0` |
| `model` | 负荷模型 | `1`（恒功率）/ `2`（恒电流）/ `3`（恒阻抗） |
| `status` | 负荷状态 | `variable`（可变）/ `fixed`（固定） |

**示例**：
```
New Load.Load1 phases=3 bus1=bus2.1.2.3 conn=wye kv=12.66 kw=100 kvar=60 model=1 status=variable
```

#### 2. Lines.dss - 线路参数

| 参数 | 含义 | 示例值 |
|------|------|--------|
| `phases` | 线路相数 | `3`（三相） |
| `bus1` | 起始母线及端子 | `bus1.1.2.3` |
| `bus2` | 终止母线及端子 | `bus2.1.2.3` |
| `r1` | 正序电阻（Ω） | `0.0922` |
| `x1` | 正序电抗（Ω） | `0.0470` |
| `r0` | 零序电阻（Ω） | `0.0922` |
| `x0` | 零序电抗（Ω） | `0.0470` |
| `c1` | 正序电容（μF） | `0` |
| `c0` | 零序电容（μF） | `0` |
| `length` | 线路长度 | `1`（单位由 units 指定） |
| `units` | 长度单位 | `km`（千米） |
| `enabled` | 是否启用 | `yes` / `no` |
| `switch` | 是否为开关 | `yes` / `no`（用于网络重构） |

**示例**：
```
New Line.L1_1_2 phases=3 bus1=bus1.1.2.3 bus2=bus2.1.2.3 r1=0.0922 x1=0.0470 r0=0.0922 x0=0.0470 c1=0 c0=0 length=1 units=km enabled=yes
```

**开关线路示例**（初始断开，用于重构）：
```
New Line.L33_21_8 phases=3 bus1=bus21.1.2.3 bus2=bus8.1.2.3 r1=2.0 x1=2.0 r0=2.0 x0=2.0 c1=0 c0=0 length=1 units=km switch=yes enabled=no
```

#### 3. Master.dss - 主控制文件

| 命令 | 作用 |
|------|------|
| `Clear` | 清除之前的电路定义 |
| `New Circuit.case33bw` | 创建电路，定义基准电压、相数、频率等 |
| `Set VoltageBases` | 设置电压基准值 |
| `CalcVoltageBases` | 计算电压基准 |
| `Redirect Lines.dss` | 导入线路定义文件 |
| `Redirect Loads.dss` | 导入负荷定义文件 |
| `Set mode=snapshot` | 设置求解模式为快照 |
| `Solve` | 执行潮流计算 |

**Circuit 参数**：
```
New Circuit.case33bw bus1=bus1.1.2.3 basekv=12.66 pu=1.0 phases=3 angle=0 frequency=50.0
```
- `bus1`：根节点（平衡节点）
- `basekv`：基准电压（kV）
- `pu`：标幺值基准
- `phases`：系统相数
- `angle`：参考相角（度）
- `frequency`：系统频率（Hz）

### MATPOWER 与 OpenDSS 数据对应关系

```
case33bw.m
│
├── mpc.baseMVA → Master.dss 中作为注释/基准信息
│
├── mpc.bus
│       ├── bus_i, baseKV → Master.dss 中的电压等级、母线名称
│       └── Pd, Qd → Loads.dss 中的 kw, kvar
│
├── mpc.branch
│       ├── fbus, tbus → Lines.dss 中的 bus1, bus2
│       ├── r, x → Lines.dss 中的 r1, x1
│       └── status → Lines.dss 中的 enabled=yes/no
│
└── mpc.gen → Master.dss 中的 Circuit source（根节点）
```


|文件|作用|类比|
|-|-|-|
|parse_case.jl|读取 DSS 文件|读数据|
|modify_case.jl|修改系统参数|改算例|
|run_pf.jl|跑潮流|检查模型|
|run_opf.jl|跑最优潮流|优化计算|
|postprocess.jl|保存和分析结果|后处理|
|main.jl|调用所有模块|总入口|

```
IM.instantiate_model(
    data,             # MATHEMATICAL 网络数据
    model_type,       # 电力网络数学 formulation，例如 ACPUPowerModel
    build_method,     # 问题类型，例如 build_mc_opf
    ref_add_core!,    # 构造内部 reference data
    global_keys,      # multinetwork 全局字段，普通 OPF 用空 Set
    it_name,          # infrastructure 名称，PMD 用 :pmd
)
```

可以，改 `PowerModelsDistribution.jl` 的 OPF 约束和目标函数，通常有 **三种层级**：

1. **只改数据里的上下限参数**：例如电压上下限、发电机出力上下限。
2. **先生成 JuMP 模型，再手动加约束 / 改目标函数**。
3. **写一个自定义 OPF builder，替代默认的 `build_mc_opf`**。

你的原函数：

```julia
function run_opf(eng)
    result = solve_mc_opf(
        eng,
        ACPUPowerModel,
        Ipopt.Optimizer
    )
    return result
end
```

本质上是直接调用默认的 `build_mc_opf`。如果你想改约束和目标函数，就不能只用这个高层封装，而是要把建模过程拆开。官方文档也说明，可以把 `solve_mc_opf` 拆成“生成模型”和“求解模型”两步，从而检查和修改 JuMP 模型；示例里用的是 `instantiate_model(..., build_mc_opf)` 和 `optimize_model!`。 [\[lanl-ansi.github.io\]](https://lanl-ansi.github.io/PowerModelsDistribution.jl/stable/manual/quickguide.html)

***

## 方法一：直接改输入数据里的约束参数

如果你只是想改已有约束的上下限，比如：

* 母线电压范围：`0.95 <= V <= 1.05`
* 发电机有功 / 无功上下限
* 线路容量
* 负荷大小
* 光伏出力上限

那优先建议直接改 `eng` 或 `math` 数据，而不是手动加 JuMP 约束。

例如：

```julia
eng = parse_file("case3_unbalanced.dss")
```

PowerModelsDistribution 默认可以把 OpenDSS 文件解析成 engineering model，也可以进一步转成 mathematical model；文档里也说明 `parse_file` 和 `transform_data_model` 可用于这两个数据层级。 [\[lanl-ansi.github.io\]](https://lanl-ansi.github.io/PowerModelsDistribution.jl/stable/manual/quickguide.html)

例如你可以先转成数学模型：

```julia
math = transform_data_model(eng)
```

然后查看数据结构：

```julia
keys(math)
keys(math["bus"])
keys(math["gen"])
```

假设你要改母线电压上下限，可以类似这样：

```julia
for (i, bus) in math["bus"]
    bus["vmin"] = 0.95
    bus["vmax"] = 1.05
end
```

或者在某些版本 / 数据模型中，电压上下限可能是多相数组，例如：

```julia
for (i, bus) in math["bus"]
    bus["vm_lb"] = [0.95, 0.95, 0.95]
    bus["vm_ub"] = [1.05, 1.05, 1.05]
end
```

然后求解：

```julia
result = solve_mc_opf(
    math,
    ACPUPowerModel,
    Ipopt.Optimizer
)
```

这种方法适合 **改已有约束的参数**，但不适合加一个全新的约束，例如“所有 DG 总出力不得超过某个值”。

***

## 方法二：生成 JuMP 模型后，手动改目标函数和加约束

这是最灵活、也最推荐你做研究时用的方法。

基本结构如下：

```julia
using PowerModelsDistribution
using Ipopt
using JuMP

function run_custom_opf(eng)
    # 1. 转成 MATHEMATICAL model
    math = transform_data_model(eng)

    # 2. 生成 PowerModelsDistribution / JuMP 模型
    pm = instantiate_model(
        math,
        ACPUPowerModel,
        build_mc_opf
    )

    # 3. 修改 JuMP 模型
    model = pm.model

    # 4. 这里添加你自己的约束 / 目标函数
    # ...

    # 5. 求解
    result = optimize_model!(
        pm,
        optimizer = Ipopt.Optimizer
    )

    return result
end
```

这里的关键是：

```julia
pm.model
```

它就是底层的 **JuMP model**。Julia Discourse 上关于 PMD 自定义目标函数的讨论也明确提到，`instantiate_model` 得到的 `pm` 里有 `.model` 字段，它是 JuMP 模型，可以用 `JuMP.@objective(pm.model, Min, ...)` 来替换目标函数。 [\[discourse....ialang.org\]](https://discourse.julialang.org/t/customised-objective-function-using-pmd-jl/126253)

***

## 例子 1：把目标函数改成最小化电压偏差

比如你想把默认目标函数改为：

$$
\min \sum_{i,\phi} (V_{i,\phi} - 1)^2
$$

可以写：

```julia
using PowerModelsDistribution
using Ipopt
using JuMP

function run_voltage_deviation_opf(eng)
    math = transform_data_model(eng)

    pm = instantiate_model(
        math,
        ACPUPowerModel,
        build_mc_opf
    )

    model = pm.model

    # 获取电压幅值变量 vm
    vm = PowerModelsDistribution.var(pm, 0)[:vm]

    # 替换默认目标函数：最小化所有节点所有相的电压偏差
    @objective(model, Min,
        sum((vm[i][c] - 1.0)^2 for i in keys(vm) for c in eachindex(vm[i]))
    )

    result = optimize_model!(
        pm,
        optimizer = Ipopt.Optimizer
    )

    return result
end
```

这段代码里：

```julia
@objective(model, Min, ...)
```

会覆盖原来的默认 OPF 目标函数。

***

## 例子 2：把目标函数改成最小化发电机总有功出力

如果负荷固定，最小化总发电出力在很多情况下相当于间接最小化网损或购电量。

```julia
function run_min_pg_opf(eng)
    math = transform_data_model(eng)

    pm = instantiate_model(
        math,
        ACPUPowerModel,
        build_mc_opf
    )

    model = pm.model

    pg = PowerModelsDistribution.var(pm, 0)[:pg]

    @objective(model, Min,
        sum(pg[g][c] for g in keys(pg) for c in eachindex(pg[g]))
    )

    result = optimize_model!(
        pm,
        optimizer = Ipopt.Optimizer
    )

    return result
end
```

注意：这个目标函数不一定等价于严格的“最小网损”，因为如果系统里有多个分布式电源、储能或可调负荷，它可能改变经济含义。

***

## 例子 3：添加新的电压约束

假设你想强制所有母线所有相电压满足：

$$
0.97 \leq V_{i,\phi} \leq 1.03
$$

可以这样写：

```julia
function run_tight_voltage_opf(eng)
    math = transform_data_model(eng)

    pm = instantiate_model(
        math,
        ACPUPowerModel,
        build_mc_opf
    )

    model = pm.model

    vm = PowerModelsDistribution.var(pm, 0)[:vm]

    for i in keys(vm)
        for c in eachindex(vm[i])
            @constraint(model, vm[i][c] >= 0.97)
            @constraint(model, vm[i][c] <= 1.03)
        end
    end

    result = optimize_model!(
        pm,
        optimizer = Ipopt.Optimizer
    )

    return result
end
```

这个做法是在默认 OPF 约束之外，额外加了一组更严格的电压约束。

***

## 例子 4：添加总发电出力约束

比如你想限制所有发电机总有功出力：

$$
\sum_g \sum_\phi P_{g,\phi} \leq P_{\max}^{\text{total}}
$$

可以写：

```julia
function run_opf_with_total_pg_limit(eng; total_pg_max = 5.0)
    math = transform_data_model(eng)

    pm = instantiate_model(
        math,
        ACPUPowerModel,
        build_mc_opf
    )

    model = pm.model

    pg = PowerModelsDistribution.var(pm, 0)[:pg]

    @constraint(model,
        sum(pg[g][c] for g in keys(pg) for c in eachindex(pg[g])) <= total_pg_max
    )

    result = optimize_model!(
        pm,
        optimizer = Ipopt.Optimizer
    )

    return result
end
```

如果你的模型用的是标幺制，那么 `total_pg_max = 5.0` 是标幺值；如果数据是 SI 单位，则含义会不一样。PowerModelsDistribution 的 `solve_mc_model` 文档里也提到，它会处理 engineering / mathematical model、per-unit / SI 等转换问题，因此改约束时一定要注意当前数据单位。 [\[lanl-ansi.github.io\]](https://lanl-ansi.github.io/PowerModelsDistribution.jl/v0.11/reference/problems.html)

***

## 方法三：写自定义 `build_mc_opf`

如果你希望以后反复使用同一个自定义 OPF，最好写一个新的 builder 函数。

默认 `solve_mc_opf` 实际上就是用默认的 `build_mc_opf` 建立 OPF 问题。PowerModelsDistribution 的文档里列出了 `solve_mc_model(data, model_type, optimizer, build_mc::Function; ...)`，说明你可以传入自己的建模函数。 [\[lanl-ansi.github.io\]](https://lanl-ansi.github.io/PowerModelsDistribution.jl/v0.11/reference/problems.html)

例如：

```julia
using PowerModelsDistribution
using Ipopt
using JuMP

function build_my_mc_opf(pm)
    # 先建立默认 OPF
    build_mc_opf(pm)

    model = pm.model

    # 取变量
    vm = PowerModelsDistribution.var(pm, 0)[:vm]
    pg = PowerModelsDistribution.var(pm, 0)[:pg]

    # 添加自定义电压约束
    for i in keys(vm)
        for c in eachindex(vm[i])
            @constraint(model, vm[i][c] >= 0.97)
            @constraint(model, vm[i][c] <= 1.03)
        end
    end

    # 替换目标函数：最小化发电有功总和
    @objective(model, Min,
        sum(pg[g][c] for g in keys(pg) for c in eachindex(pg[g]))
    )
end

function run_my_opf(eng)
    result = solve_mc_model(
        eng,
        ACPUPowerModel,
        Ipopt.Optimizer,
        build_my_mc_opf
    )

    return result
end
```

这样你之后只需要调用：

```julia
result = run_my_opf(eng)
```

就会执行你自己定义的 OPF。

***

## 如何知道变量名是什么？

这是非常关键的一步。建议你先把模型打印出来：

```julia
math = transform_data_model(eng)

pm = instantiate_model(
    math,
    ACPUPowerModel,
    build_mc_opf
)

print(pm.model)
```

官方 quick guide 也展示了这种做法：用 `instantiate_model` 生成模型，再 `print(pm.model)` 检查 JuMP 模型，然后用 `optimize_model!` 求解。 [\[lanl-ansi.github.io\]](https://lanl-ansi.github.io/PowerModelsDistribution.jl/stable/manual/quickguide.html)

你还可以查看变量字典：

```julia
PowerModelsDistribution.var(pm, 0) |> keys
```

常见变量可能包括：

```julia
:vm   # 电压幅值
:va   # 电压相角
:pg   # 发电机有功
:qg   # 发电机无功
:pd   # 负荷有功，若负荷可调
:qd   # 负荷无功，若负荷可调
```

但具体变量名会随模型类型变化。例如 `ACPUPowerModel`、`ACRUPowerModel`、`IVRPowerModel` 的变量空间不一样。PowerModelsDistribution 本身就是把“问题类型”，例如 OPF，和“网络数学表达形式”，例如 ACP、ACR、IVR、LinDistFlow 等，分离开的框架。 [\[github.com\]](https://github.com/lanl-ansi/PowerModelsDistribution.jl)

***

## 你现在这个函数可以改成这样

如果你只是想保留接口 `run_opf(eng)`，但内部改成自定义 OPF，可以写：

```julia
using PowerModelsDistribution
using Ipopt
using JuMP

function run_opf(eng)
    math = transform_data_model(eng)

    pm = instantiate_model(
        math,
        ACPUPowerModel,
        build_mc_opf
    )

    model = pm.model

    # =========================
    # 自定义约束
    # =========================
    vm = PowerModelsDistribution.var(pm, 0)[:vm]

    for i in keys(vm)
        for c in eachindex(vm[i])
            @constraint(model, vm[i][c] >= 0.97)
            @constraint(model, vm[i][c] <= 1.03)
        end
    end

    # =========================
    # 自定义目标函数
    # =========================
    pg = PowerModelsDistribution.var(pm, 0)[:pg]

    @objective(model, Min,
        sum(pg[g][c] for g in keys(pg) for c in eachindex(pg[g]))
    )

    # =========================
    # 求解
    # =========================
    result = optimize_model!(
        pm,
        optimizer = Ipopt.Optimizer
    )

    return result
end
```
