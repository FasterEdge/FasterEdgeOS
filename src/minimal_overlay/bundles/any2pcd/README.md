# any2pcd —— 文本/二进制点云转 PCD 工具(FasterEdge 系统初始工具)

用 Go 编写的点云格式转换器: 把 **bin / 文本 / CSV / PCD** 点云文件转换为标准
**PCD v0.7**(PCL Point Cloud Data)文件。纯标准库实现, 零第三方依赖。

- **保持时序**: 转换过程严格按输入点的**原始顺序**写出, 不做任何排序/去重/重排。
  带时间戳的雷达 bin(如 `x y z timestamp` 每点 4×float32)用
  `-fields "x,y,z,timestamp"` 即可把时间戳映射为 PCD 字段原样保留。
- **UTF-8 无 BOM**: 输出文件为 UTF-8(无 BOM)编码; PCD 内容为 ASCII 子集,
  任何环境下解码一致。
- **自动探测**: 按扩展名与内容识别输入格式, 无需手动指定 `-from`。

## 支持清单

| 输入 | 说明 |
| --- | --- |
| `.bin` | 二进制点云, 每点 N×float32(little-endian)。自动尝试 3..16 个字段, 取第一个能整除文件大小的; KITTI 常见 4 字段自动命名为 `x y z intensity` |
| `.txt` / `.xyz` / 无扩展名 | 逐行空格/Tab 分隔数字, 自动列数命名(3→xyz, 4→xyz+intensity, 6→xyz+rgb, 7→xyz+intensity+rgb, 其余→featureN) |
| `.csv` | 逗号分隔(同文本) |
| `.pcd` | 已是 PCD 的文件(ASCII 或 binary, 仅支持 4 字节数值字段)——可做格式重编码 |

## 用法

```
any2pcd [选项] [文件...]        # 转换文件, 缺省读标准输入
cat x.bin | any2pcd -from bin   # 从标准输入读取
```

| 选项 | 含义 |
| --- | --- |
| `-from 格式` | 输入格式: `auto`(默认)\|`bin`\|`text`\|`csv`\|`pcd` |
| `-fields 名称` | 字段名(逗号分隔), 如 `x,y,z,intensity` 或 `x,y,z,timestamp`; 也决定 bin 的每点字段数 |
| `-binary` | 输出二进制 PCD(`DATA binary`, little-endian float32, 体积最小) |
| `-output 文件` | 输出文件(仅单输入; 缺省标准输出) |
| `-outdir 目录` | 多输入时的输出目录(缺省 `.`, 输出 `<原名>.pcd`) |
| `-strict` | 严格模式: 出现 NaN/Inf/坏行/列数不一致即失败(exit 1) |
| `-skip-bad` | 跳过坏行(仅 text/csv; 默认失败) |
| `-version` | 打印版本 |

## 示例

```sh
any2pcd velodyne_000001.bin > velodyne_000001.pcd   # KITTI 风格 bin → ASCII PCD
any2pcd -fields "x,y,z,timestamp" lidar_frame.bin > lidar_frame.pcd  # 保留时间戳
any2pcd -binary lidar_frame.bin > lidar_frame_binary.pcd             # 二进制输出
any2pcd points.xyz > points.pcd                                      # 文本点云
any2pcd -outdir ./out scan1.bin scan2.bin scan3.bin                  # 批量转换
```

## 构建

随 `OVERLAY_BUNDLES` 启用(bundle 目录加入列表, 如
`OVERLAY_BUNDLES="dhcp,fasteredgeos,any2pcd"`)。需要宿主机 Go 1.25+
(CI 经 `actions/setup-go` 提供)。离线升级可设 `ANY2PCD_SOURCE_DIR`
指向本地新版源码目录(须含 `main.go` / `go.mod`)。
