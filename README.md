# Trap_Frequency_Stablization
> 实现数字PID离子阱频锁定的实验步骤和程序，更多说明请在Wiki上查看：[Trap Frequency Stablization Wiki](https://github.com/DaojiePENG/Trap_Frequency_Stablization/wiki)

也可点击上方的Wiki访问：
![image](https://github.com/DaojiePENG/Trap_Frequency_Stablization/assets/49547589/e60af2d3-b86b-4700-92b4-ad761120d528)

***

Welcome to the Trap_Frequency_Stablization wiki!
> 实现数字PID离子阱频锁定的实验步骤和程序
## 1. 项目背景
### 理论上离子阱中影响阱频率的各种因素

### 物理上离子阱中影响阱频率的各种因素
受环境振动和温度变化影响，谐振腔的几何形状，主要是螺旋线的长度和腔体长度会发生变化，进而导致谐振腔的中心频率发生偏移。从谐振腔的S参数图中可以看出螺线管谐振腔的Q值很大，透过峰较尖锐，即中心频率附近信号透过衰减较大。因此在输入信号频率抖动极小的情况下，受谐振腔中心频率偏移影响，信号的透过幅度将会发生较大的变化。

<img src="https://github.com/DaojiePENG/Trap_Frequency_Stablization/assets/49547589/3ac732ee-e5a3-4912-b7f7-c39bbcab69c3" height="50%" width="50%">

## 2. 项目目标
通过上面的分析可知，阱频率稳定的关键在于稳定谐振腔的电压输出幅度。为此我们采用PID回路对谐振腔输出端信号进行稳定，如下图所示。

<img src="https://github.com/DaojiePENG/Trap_Frequency_Stablization/assets/49547589/54f40b64-7f38-449f-bfc5-9142f181c6b2" height="50%" width="50%">

上图为模拟PID反馈调节回路，与上图中展示方法不同的是本项目中我们将采用数字PID和DDS来实现整个稳定回路。数字化给了我们跟大的自由度来操作整个回路系统中的关键特性。当然，数字系统的延时会比模拟系统大，从而影响真个系统的最大反馈带宽。
## 3. 项目器件
### 项目主体器件
1. 螺线管谐振腔：
2. 分压板：
3. 检波器：
4. 低通滤波器：
5. 射频功率放大器：
6. RTMQ板卡：
3. 同轴缆线若干：


### 项目辅助仪器
1. 示波器：
2. 频谱分析仪or网络分析仪：
3. 同轴缆线若干：

## 4. 项目步骤
### 1. 设计和加工谐振腔
谐振腔是整个阱频稳定系统的关键器件，如果已经有了现成的谐振腔可以跳过此部分；如果没有那么可以按照如下参数进行谐振腔的加工。

***

腔外圆筒内径：103mm；
腔外圆通高度：110mm；

大线圈线：3mm直径空心铜管；
大线圈直径：52mm；
螺旋圈圈数：6圈；
大线圈螺距：12mm；

小线圈线：1mm直径漆包铜线；
小线圈直径：30mm；
小线圈圈数：3圈；
小线圈螺距：5mm；

***

关于谐振腔的装配设计参考下图：

![image](https://github.com/DaojiePENG/Trap_Frequency_Stablization/assets/49547589/af7b3ab4-f66a-48e4-a260-47678e75e1c1)

### 2. 测试谐振腔裸Q和中心频率

<image src="https://github.com/DaojiePENG/Trap_Frequency_Stablization/assets/49547589/c0241b57-bff4-40c8-b7fc-0a02f6f7c915" width="50%">

用S参数法测量，按照上面建议的参数加工出来的谐振腔中心频率应该在60MHz左右，Q值一般在450左右。中心频率一般不会有太大问题，如果在60MHz $+-$ 20MHz的范围内看不到吸收峰，则应检查是否有虚焊。

这里需要重点关注一下Q值，如果Q值过小则可能是焊接出现问题，需要检查各个焊点是是否牢固且接触充分；也可能是螺线管螺距出现问题，比如螺距不均匀等。

如果检查上述都没有问题，继续进入下一部分。

### 3. 焊接和测试分压板

### 4. 测试谐振腔含分压板的Q值和中心频率

### 5. 测试检波器

### 6. 测试RTMQ板卡

### 7. 阱频稳定系统构建


