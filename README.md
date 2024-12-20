## 哈工大计算机体系结构实验（2024 年秋）

造 CPU，以及 Cache。

烈度显著强于前几周的处理器设计与实验，需要实现更进一步的优化比如流水线等，花了不少功夫。

挂在 Github 上留个纪念，供后人参考。只保留了源码，没有保留构建出来的程序以及测试环境。一般来说只要添加到 Vivado 项目的 Design Sources 下，就可以进行仿真测试了。因为是边学边写，所以加了很多注释，个人认为挺全的。如果有帮助的话，希望给个 Star）

目录（**每年实验课内容不完全一样**，注意查看）：

- 实验一：流水线处理器；
- 实验二：分支预测；
- 实验三：指令 Cache 的设计与实现。

## 施工进度

- 实验一已完成，通过烧写测试，但是代码比较旧，谨慎使用；
- 实验二已完成，通过烧写测试，不过分支预测的实现仍然可能有缺陷；
- 实验三已完成，通过烧写测试。

因为已经通过验收，所以可能以后不太会主动修改这些代码了，如果还存在问题，可以提 issue，看情况修）

## 说明

### Lab 1

下有两个文件夹 partial-task 和 full-task，前者只完成了流水部分，但是没有加入暂停与定向；后者是完整实现。

说明：因为实验一的测试环境没有针对 BBT 和 J 指令的测试，同时这份代码的实现有缺陷，因此**对于分支跳转的实现有问题**。如果需要比较正确的实现可以看 Lab 2 的代码。

### Lab 2

下有文件夹 full-task，实现了分支预测功能。

代码里在从指令寄存器读取到指令的瞬间就会对 IR 进行基于组合逻辑的分析，并将预测结果立即写入到 PC 里，于是在下个时钟上边沿新的指令就能进入 IR 寄存器。代码实现的有点鬼畜，可能不是很标准的实现。

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

### Lab 3

下有文件夹 full-task，实现的 Cache 具有如下参数：

- 二路组相联，每路 128 行，每行 32 字节；
- 二级流水；
- 使用 LRU 替换策略。

测试数据集结果：

```plain
-------------------
   HIT COA Lab3    
Instruction Cache
-------------------
Your cache is correct! In total 100011 requests:
Total 439 misses (miss rate: 0.43%)
Total 104842 cycles (1.04 cycles per request)

PASS! You have done well!
-------------------
```

- 在一级流水（IF1 阶段）会将两路 RAM 对应的数据、tag 以及当前处理的 `cpu_addr` 存入寄存器文件；
- 在二级流水（IF2 阶段）会根据是否发生 Cache Miss 来决定直接返回一级流水从 RAM 里得到的数据，还是向主存要一块数据。

使用组合逻辑实现了变量 stall，当发生了 Cache Miss，且二级流水还没从主存获取到期望的数据时设置为真，此时一级流水向二级流水泵来信息的过程会被暂停，同时 `cache_addr_ok` 也会被赋值为假，停止 CPU 向一级流水输送请求地址的过程。

当发生 Cache Miss，二级流水的内部状态会从 0 转变为 1，此时会向主存请求数据。一共要请求 8 个字，每次请求来一个字都会向 RAM 里写入。因此会延缓一个周期的时间用来完成 RAM 的写入，为了防止写地址和读地址相同产生错误，还要再延缓一个周期让一级流水有时间从 RAM 读取下一个信息。尽管减少这个周期的延迟，在仿真下也是能通过的（但是会报 Warning），但为了保险起见防止烧写不过，并且通过测试数据的限制比较宽松，所以还是延缓了这个周期。

整体而言这个实验还挺简单的。