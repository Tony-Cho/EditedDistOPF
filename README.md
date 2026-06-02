# EditedDistOPF

```
case33bw.m
│
├── mpc.baseMVA
│       └── Master.dss 中作为注释/基准信息
│
├── mpc.bus
│       ├── bus_i, baseKV
│       │       └── Master.dss 中的电压等级、母线名称
│       └── Pd, Qd
│               └── Loads.dss 中的 kw, kvar
│
├── mpc.branch
│       ├── fbus, tbus
│       │       └── Lines.dss 中的 bus1, bus2
│       ├── r, x
│       │       └── Lines.dss 中的 r1, x1
│       └── status
│               └── Lines.dss 中的 enabled=yes/no
│
└── mpc.gen
        └── Master.dss 中的 Circuit source
```


|文件|作用|类比|
|-|-|-|
|parse_case.jl|读取 DSS 文件|读数据|
|modify_case.jl|修改系统参数|改算例|
|run_pf.jl|跑潮流|检查模型|
|run_opf.jl|跑最优潮流|优化计算|
|postprocess.jl|保存和分析结果|后处理|
|main.jl|调用所有模块|总入口|