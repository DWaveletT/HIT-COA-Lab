## 哈工大计算机体系结构实验（2024 年秋）

造 CPU。

烈度显著强于前几周的处理器设计与实验，需要实现更进一步的优化比如流水线等，花了不少功夫。

挂在 Github 上留个纪念，供后人参考。只保留了源码，没有保留构建出来的程序以及测试环境。因为是边学边写，所以加了很多注释，个人认为挺全的。如果有帮助的话，希望给个 Star）

目录（因为每年实验课内容不完全一样）：

- 实验一：流水线处理器；
- 实验二：分支预测；
- 实验三：指令 Cache 的设计与实现。

## 施工进度

- 实验一已完成，但还没烧写测试，可以通过学校提供的测试环境；
- 实验二已完成，但还没烧写测试，可以通过学校提供的测试环境；
- 实验三还没写。

因为实验课推迟了，所以这段时间里我没有去烧写测试。如果有烧写测试过这些代码的同学，欢迎在 issue 里说明测试结果。

## 说明

### Lab 1

下有两个文件夹 partial-task 和 full-task，前者只完成了流水部分，但是没有加入暂停与定向；后者是完整实现。

说明：因为实验一的测试环境没有针对 BBT 和 J 指令的测试，同时这份代码的实现有缺陷，因此**对于分支跳转的实现有问题**。如果需要比较正确的实现可以看 Lab 2 的代码。

### Lab 2

下有文件夹 full-task，实现了分支预测功能。

代码里在从指令寄存器读取到指令的瞬间就会对 IR 进行基于组合逻辑的分析，并将预测结果立即写入到 PC 里，于是在下个时钟上边沿新的指令就能进入 IR 寄存器。代码实现的有点鬼畜，不清楚正确的实现应该是什么样。

测试数据集 0：

```plain
-------------------
   HIT COA Lab2    
 Branch Predictor
-------------------
Run test case 0
Your CPU is correct! It spent 415 cycles in total

PASS! You have done well!
-------------------
```

测试数据集 1：

```plain
-------------------
   HIT COA Lab2    
 Branch Predictor
-------------------
Run test case 1
Your CPU is correct! It spent 716 cycles in total

PASS! You have done well!
-------------------
```

测试数据集 2：

```plain
-------------------
   HIT COA Lab2    
 Branch Predictor
-------------------
Run test case 2
Your CPU is correct! It spent 987 cycles in total

PASS! You have done well!
-------------------
```

跑得还挺快。