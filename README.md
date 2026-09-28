# IEA

本仓库保存国际环境协定（International Environmental Agreements, IEA）研究的数值模型、联盟稳定性模拟、参数标定代码和论文绘图代码。模型将世界划分为 12 个地区，使用 Chebyshev 配点法求解温度状态下的价值函数，并比较无突变、一次气候突变和两次气候突变情景中的稳定联盟、排放、温度、收益分配及政策参数。

## 研究流程

1. `code/Parameter Simulation` 从 RICE 数据中标定地区收益函数和损害函数参数。
2. `code/Chebyshev Coefs Simulation` 针对各种联盟与突变状态求解价值函数系数，并把结果保存为 `.mat` 文件。
3. `code/One Tipping Find Steady Coalition` 和 `code/Two Tippings Find Steady Coalition` 使用价值函数系数逐年搜索稳定联盟，并输出 `.xlsx` 结果。
4. `code/One Tipping Make Grand` 搜索使大联盟稳定所需的最低连接率或制裁率。
5. `R_code` 读取上述 Excel 结果，生成正文图 4.2–4.5 和附录图。

仓库同时包含预先计算的 `.mat` 系数、`.xlsx` 模拟结果和 `.pdf` 图件，便于直接检查和复现论文结果。

## 运行环境

- MATLAB；数值求解使用 Optimization Toolbox 中的 `fsolve`、`lsqcurvefit` 和 `lsqnonlin`。
- MATLAB 需要能够读取和写入 Excel 工作簿。
- R，以及以下包：`tidyverse`、`ggplot2`、`openxlsx`、`readxl`、`stringr`、`patchwork`、`cowplot`、`ggrepel`、`ggtext`、`scales` 和 `grid`。

所有脚本均使用相对路径。请先切换到脚本所在目录再运行，不要把 `code` 下所有子目录一次性递归加入 MATLAB 路径；多个模块包含同名的 `ChebyEval`、`GetRatiomatrix`、`Residuals*` 等函数，递归加路径可能调用到错误版本。

## 快速开始

### MATLAB

按研究目的进入对应目录：

```matlab
% 1. 可选：重新标定参数
cd('code/Parameter Simulation')
run('main_simulation.m')

% 2. 生成一次突变情景的价值函数系数
cd('../Chebyshev Coefs Simulation')
run('Main_Test_Value_Function.m')

% 3. 可选：生成无转移支付的地区价值函数分解
run('Main_Test_Value_Function_NT.m')

% 4. 计算一次突变情景的稳定联盟路径
cd('../One Tipping Find Steady Coalition')
run('Main_Test_Once_Tipping_Allocation.m')
```

两次突变的联盟模拟从 `code/Two Tippings Find Steady Coalition/Main_Test_Twice_Tipping_Allocation.m` 启动；大联盟政策参数搜索从 `code/One Tipping Make Grand/Main_Test_Once_MakeGrand.m` 启动。运行前应检查入口脚本开头的突变年份、损害幅度、连接率、贴现率、分配规则及输入目录设置。

### R

先把工作目录设为 `R_code`，再运行目标图对应的脚本。例如：

```r
setwd("R_code")
source("IEA_Plot_Figure_4.2.1.R")
```

R 脚本会从 `../code` 中读取模拟结果，并把 PDF 保存到 `R_code/IEA Figures ...` 对应目录。

## 目录与函数说明

### `code/Parameter Simulation`

- `main_simulation.m`：读取 `COPY_RICE_2010_BAU1.xlsx` 中 12 个地区的产出、排放、气候损失和温度序列；将十年数据插值为年度数据；用非线性最小二乘估计收益参数 `alpha`、`beta` 和损害参数 `eta`、`gamma`。
- `COPY_RICE_2010_BAU1.xlsx` / `.xls`：参数标定所需的 RICE 基准数据。

### `code/Chebyshev Coefs Simulation`

该目录是价值函数求解的核心模块。

| 文件/函数 | 功能 |
| --- | --- |
| `Main_Test_Value_Function.m` | 基准入口；设置地区参数和情景参数，调用一次突变求解器。文件末尾还保留两次突变等扩展情景的配置示例。 |
| `Main_Test_Value_Function_NT.m` | 读取联盟层面的系数，生成无转移支付（No Transfer, NT）下的地区价值函数系数。 |
| `No_Tipping_Chebyshev` | 求解无气候突变情景中各联盟及外部地区的 Chebyshev 价值函数。 |
| `Once_Tipping_Chebyshev` | 求解一次突变前后及不同温度区间的价值函数；支持二次或四次损害函数。 |
| `Twice_Tipping_Chebyshev` | 求解两次突变对应的多状态价值函数。 |
| `Once_Tipping_Chebyshev_NT` | 将一次突变情景的联盟价值分解为各成员无转移支付价值。 |
| `Twice_Tipping_Chebyshev_NT` | 将两次突变情景的联盟价值分解为各成员无转移支付价值。 |
| `InitialCoefs` | 构造低阶 Chebyshev 初值、节点、基函数矩阵和损害项。 |
| `UpdateInitCoefs` | 将低阶解延拓为高阶初值，并在新网格上重算损害项。 |
| `CalculateChebyshevMatrices` | 生成 Gauss–Chebyshev 节点、基函数及其温度导数矩阵。 |
| `Calculate_Q_and_Benefits` | 由价值函数导数恢复各地区排放、总排放和当期收益。 |
| `Residuals0` | 计算第一次突变前、含后续价值连接项的 HJB 配点残差。 |
| `Residuals1` | 计算下一次突变前、含后续价值连接项的 HJB 配点残差。 |
| `Residuals2` | 计算最终突变状态或无后续跳转状态的 HJB 配点残差。 |
| `AnalyticalSol` | 在二次收益/损害设定下计算解析价值函数参数，用于检验数值解。 |
| `funu1` | 为 `AnalyticalSol` 提供标量均衡条件残差，由 `fsolve` 求根。 |
| `ChebyEval` | 在给定温度区间上计算一元 Chebyshev 多项式近似值。 |
| `GetRatiomatrix` | 枚举非空联盟，并根据 2005 年 GDP 计算联盟的基准世界产出份额。 |

### `code/One Tipping Chebyshev Coefs`

保存一次突变模型的预计算 `.mat` 系数。子目录名编码了基准情景及敏感性分析设置，包括连接机制、制裁机制、无连接/制裁、成本性制裁、无转移支付、收益函数幂次、损害函数幂次、突变损害和突变事件等。文件名中的数字依次记录主要情景参数，供联盟模拟脚本自动扫描和解析。

### `code/One Tipping Find Steady Coalition`

该模块读取一次突变系数，比较所有非空联盟并形成 2025–2100 年逐年路径。

| 文件/函数 | 功能 |
| --- | --- |
| `Main_Test_Once_Tipping_Allocation.m` | 入口脚本；构造全部联盟状态、读取对应情景系数、选择 `Shapley` 或 `NoTransfer` 分配规则，并把轨迹写入 Excel。 |
| `Once_Tipping_Allocation` | 在给定突变年份下逐年更新温度、收益和排放，检验内外稳定性并选择稳定联盟。 |
| `GetNationFutureProfit` | 从“联盟总价值 + 外部地区价值”的系数布局中恢复各联盟的地区未来收益。 |
| `GetNationFutureProfit_NoTransfer` | 从无转移支付系数中直接恢复每个地区的未来收益。 |
| `PerformShapleyAllocation` | 根据各子联盟的边际贡献计算 Shapley 分配，并形成地区最终收益矩阵。 |
| `ChebyshevDeriv` | 计算 Chebyshev 价值函数对温度的导数，用于排放一阶条件和温度更新。 |
| `ChebyEval` | 在当前温度上计算 Chebyshev 价值函数。 |
| `GetRatiomatrix` | 生成联盟 GDP 份额矩阵。 |

子目录 `Results of ...` 保存正文基准情景、不同联盟、不同分配规则、连接/制裁机制以及收益、损害和突变敏感性分析的 Excel 结果；`One Tipping Chebyshev Coefs` 是该模块运行时使用的系数副本。

### `code/Two Tippings ChebyEval Results Power_b_2`

保存两次突变模型在基准二次收益函数下的五类状态系数：零次突变的低/高温区间、一次突变的低/高温区间，以及两次突变后的状态。

### `code/Two Tippings Find Steady Coalition`

| 文件/函数 | 功能 |
| --- | --- |
| `Main_Test_Twice_Tipping_Allocation.m` | 两次突变联盟模拟入口；读取五类状态系数，设置两个突变年份并输出年度结果。 |
| `Twice_Tipping_Allocation` | 在两次突变的状态切换下搜索稳定联盟，返回温度、状态、效用、联盟、排放和收益路径。 |
| `GetNationFutureProfit` | 从联盟和外部地区系数恢复地区未来收益。 |
| `GetNationFutureProfit_NoTransfer` | 从无转移支付系数恢复地区未来收益。 |
| `PerformShapleyAllocation` | 对联盟总价值执行 Shapley 分配。 |
| `ChebyshevDeriv` | 计算价值函数的温度导数。 |
| `ChebyEval` | 计算当前温度下的价值函数。 |
| `GetRatiomatrix` | 生成联盟 GDP 份额矩阵。 |

内部 `Two Tippings ChebyEval Results Power_b_2` 保存输入系数，`Extension` 保存两次突变情景的 Excel 输出。

### `code/One Tipping Make Grand`

该模块寻找能够让 12 地区大联盟保持稳定的最低连接率或制裁率。

| 文件/函数 | 功能 |
| --- | --- |
| `Main_Test_Once_MakeGrand.m` | 入口脚本；逐年用区间扩张与二分搜索求最低政策率，并输出温度、政策率、价值函数和效用轨迹。 |
| `EvaluateGrandCoalitionRate` | 在给定年份、温度和政策率下计算大联盟及单地区退出情景，按未来价值函数标准判断稳定性。 |
| `Once_Tipping_Chebyshev_for_Grand` | 只针对大联盟和单地区退出状态求解一次突变价值函数，减少重复计算。 |
| `AnalyticalSol` | 计算大联盟模块所用的二次设定解析解。 |
| `InitialCoefs` / `UpdateInitCoefs` | 构造并逐阶更新 Chebyshev 求解初值。 |
| `CalculateChebyshevMatrices` | 生成 Chebyshev 节点、基函数及导数矩阵。 |
| `Residuals1` / `Residuals2` | 分别计算突变前连接状态和突变后终态的 HJB 残差。 |
| `funu1` / `funu2` | 为解析解或低维系数系统提供非线性残差。 |
| `ChebyEval` / `ChebyshevDeriv` | 计算价值函数及其温度导数。 |
| `GetRatiomatrix` | 构造联盟 GDP 份额矩阵；入口脚本截取大联盟和单地区退出所需行。 |

`GrandCoalitionTrace_Once_Connection.xlsx` 与 `GrandCoalitionTrace_Once_Sanction.xlsx` 分别保存连接率和制裁率实验结果。

### `R_code`

| 脚本 | 图件与主要内部函数 |
| --- | --- |
| `IEA_Plot_Figure_4.2.1.R` | 绘制一次突变下的排放、温度与联盟成员网格。`extract_plot_data` 整理 Excel 数据，`make_emission_temp_plot` 绘制双轴时间序列，`make_membership_grid_plot` 绘制成员/排放网格，`get_axis_params` 统一双轴尺度。 |
| `IEA_Plot_Figure_4.2.2.R` | 比较不同联盟情景与大联盟。`extract_metrics` 提取指标，`calc_diff_vs_grand` 计算相对大联盟差异，`make_merged_plot_data` 合并情景，`get_ylim` 统一范围，`make_panel` 和 `make_custom_legend` 生成面板与图例。 |
| `IEA_Plot_Figure_4.2.3.R` | 绘制相对无联盟的收益、损害和利润差异。`extract_calibration_metrics`、`calc_diff_vs_no_coalition`、`make_calibration_plot_data` 完成数据整理；`get_ylim_diff`、`make_calibration_panel` 和 `make_custom_legend` 完成作图。 |
| `IEA_Plot_Figure_4.3.1.R` | 比较连接、制裁等收益政策情景。`read_scenario_data` 读取并标准化结果，`get_ylim_diff` 统一纵轴，`make_panel` 生成比较面板。 |
| `IEA_Plot_Figure_4.3.2.R` | 比较维持大联盟稳定所需的最低连接率与制裁率。`read_and_process` 读取、清洗并合并轨迹数据。 |
| `IEA_Plot_Figure_4.4.R` | 比较 Shapley 分配和无转移支付结果。`extract_plot_data` 整理情景，`get_axis_params` 设置双轴，`make_panel_plot` 绘制分配、排放和温度面板。 |
| `IEA_Plot_Figure_4.5.1.R` | 比较连接率与突变损害敏感性情景和基准情景。`extract_plot_data`、`build_scenario_diff_data` 构建差异数据，`get_dual_axis_params` 统一尺度，`make_top_diff_plot`、`make_membership_compare_grid` 和 `make_scenario_block` 组合图件。 |
| `IEA_Plot_Figure_4.5.2.R` | 收益函数敏感性分析。`extract_plot_data`、`make_emission_temp_plot`、`make_membership_grid_plot` 和 `get_axis_params` 分别负责数据提取、双轴曲线、成员网格和尺度。 |
| `IEA_Plot_Figure_4.5.3.R` | 损害函数敏感性分析，内部函数与图 4.5.2 的职责相同。 |
| `IEA_Plot_Figure_4.5.4.R` | 比较一次与两次突变。除通用的数据提取、双轴曲线、成员网格和尺度函数外，`make_scenario_block` 将单个突变情景组合成完整面板。 |
| `IEA_Plot_Figure_Appendix.R` | 使用内置地区参数绘制附录中的收益/损害参数散点图。 |

`IEA Figures 4.2`、`IEA Figures 4.3`、`IEA Figures 4.4`、`IEA Figures 4.5` 和 `IEA Figures Appendix` 保存各脚本生成的 PDF 图件。

## 数据与输出命名

- `.mat`：Chebyshev 系数；前缀说明突变状态和温度区间，后缀编码损害幅度、连接/制裁率、损失率、收益函数幂次、近似阶数和贴现率等参数。
- `.xlsx`：年度联盟状态、地区成员资格、排放、温度、收益/效用以及政策率轨迹。
- `.pdf`：论文正文和附录的最终图件。

## 说明

- 当前仓库保留研究输出以支持结果复核，因此体积主要来自 `.mat` 和 `.xlsx` 文件。
- `.RData`、`.RDataTmp*`、`.Rhistory` 等本地 R 会话文件不属于可复现流程，已通过 `.gitignore` 排除。
- `ChebyEval.m` 中保留了原作者和引用信息；使用该数值程序时请遵守源文件中的引用要求。

