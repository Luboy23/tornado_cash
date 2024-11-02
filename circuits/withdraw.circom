// 引入 circomlib 库中的 pedersen.circom 和 bitify.circom 电路文件。
// 这两个电路文件提供了 Pedersen 哈希和比特转换的功能。
// - `pedersen.circom` 提供 Pedersen 哈希算法的实现，适用于 zk-SNARKs。
// - `bitify.circom` 提供 `Num2Bits` 电路，用于将数值转换为比特表示。
include "../node_modules/circomlib/circuits/pedersen.circom";
include "../node_modules/circomlib/circuits/bitify.circom";
include "../node_modules/circomlib/circuits/mimcsponge.circom";


// 定义 `commitmentHash` 模板
// 此模板用于生成两个输出信号：`commitment` 和 `nullifierHash`。
// `commitment` 是一个承诺哈希值，用于证明某个值的存在性。
// `nullifierHash` 是一个基于 `nullifier` 的哈希值，用于标记匿名交易或操作。
template CommitmentHash() {

    // 输入信号定义
    signal input nullifier; // nullifier 输入信号，用于标识交易或操作的唯一值
    signal input secret;    // secret 输入信号，用于隐私保护的秘密值

    // 输出信号定义
    signal output commitment;     // commitment 输出信号，表示 `commitmentHasher` 的哈希结果
    signal output nullifierHash;  // nullifierHash 输出信号，表示 `nullifierHasher` 的哈希结果

    // 组件实例化
    // 使用 Pedersen 哈希算法对 `commitment` 和 `nullifier` 进行加密处理。
    // - `Pedersen(496)` 和 `Pedersen(248)` 分别创建了不同位宽的哈希组件。
    component commitmentHasher = Pedersen(496); // 496 位宽的 Pedersen 哈希，用于生成 `commitment`
    component nullifierHasher = Pedersen(248);  // 248 位宽的 Pedersen 哈希，用于生成 `nullifierHash`

    // 组件用于将数值转换为比特表示。
    // `Num2Bits(248)` 将 `nullifier` 和 `secret` 分别转为 248 位的比特数组
    component nullifierBits = Num2Bits(248);    // 将 `nullifier` 转换为 248 位比特
    component secretBits = Num2Bits(248);       // 将 `secret` 转换为 248 位比特

    // 输入信号连接
    // 将 `nullifier` 和 `secret` 输入信号连接到 `Num2Bits` 组件的输入端口
    nullifierBits.in <== nullifier; // 将 `nullifier` 作为 `nullifierBits` 的输入
    secretBits.in <== secret;       // 将 `secret` 作为 `secretBits` 的输入

    // 使用循环将 `nullifierBits` 和 `secretBits` 的输出比特分配到哈希组件的输入
    // - 前 248 位比特用于 `nullifierHasher` 和 `commitmentHasher` 的输入
    // - 对于 `commitmentHasher`，将 `secretBits` 的输出比特接入 248 位后的位置
    for (var i = 0; i < 248; i++) {
        nullifierHasher.in[i] <== nullifierBits.out[i];            // 将 `nullifierBits` 的第 `i` 个比特连接到 `nullifierHasher` 的输入
        commitmentHasher.in[i] <== nullifierBits.out[i];           // 将 `nullifierBits` 的第 `i` 个比特连接到 `commitmentHasher` 的前 248 位输入
        commitmentHasher.in[i + 248] <== secretBits.out[i];        // 将 `secretBits` 的第 `i` 个比特连接到 `commitmentHasher` 的 248-495 位输入
    }

    // 输出信号连接
    // 将哈希结果的第一个元素作为 `commitment` 和 `nullifierHash` 的值
    commitment <== commitmentHasher.out[0];        // 将 `commitmentHasher` 的第一个输出元素赋值给 `commitment` 输出信号
    nullifierHash <== nullifierHasher.out[0];      // 将 `nullifierHasher` 的第一个输出元素赋值给 `nullifierHash` 输出信号
}

// 定义一个双路复用器模板 Dualmux
// Dualmux 模板根据选择信号 `s` 来选择输出。
// 如果 s == 0, 输出 `in[0]`，如果 s == 1, 输出 `in[1]`。
template Dualmux() {
    // 定义输入信号
    signal input in[2]; // 输入信号数组，包含两个候选信号
    signal input s;     // 选择信号，控制输出是 `in[0]` 还是 `in[1]`

    // 定义输出信号
    signal output out[2]; // 输出信号数组，包含两个结果信号

    // 验证 `s` 是否为 0 或 1
    // `s * (1 - s) === 0` 这一表达式用于约束 `s`，确保其值为 0 或 1。
    s * (1 - s) === 0;

    // 输出逻辑
    // 如果 s == 1, 则 `out[0]` = `in[1]`，否则为 `in[0]`
    out[0] <== (in[1] - in[0]) * s + in[0];
    // 如果 s == 1, 则 `out[1]` = `in[0]`，否则为 `in[1]`
    out[1] <== (in[0] - in[1]) * s + in[1];
}

// 定义 `hashLeftRight` 模板
// 此模板计算两个输入 `left` 和 `right` 的哈希值 `hash`。
// 使用 MiMC 哈希算法，通过 `MiMCSponge` 组件实现。
template hashLeftRight() {
    // 输入信号
    signal input left;    // 左输入信号
    signal input right;   // 右输入信号
    signal output hash;    // 输出哈希信号

    // 实例化 MiMC 哈希组件
    // - `MiMCSponge[2, 220, 1]` 表示 MiMC 海绵结构，处理 2 个输入，使用 220 轮，加密键为 1。
    component hasher = MiMCSponge(2, 220, 1);
    
    // 将 `left` 和 `right` 连接到 `MiMCSponge` 的输入端口
    hasher.ins[0] <== left;
    hasher.ins[1] <== right;

    // 设置 MiMC 的加密键 `k` 为 0
    hasher.k <== 0;

    // 将哈希结果的第一个输出赋值给 `hash`
    hash <== hasher.outs[0];
}

// 定义 `MerkleTreeChecker` 模板
// 该模板用于验证一个叶子节点是否在一个 Merkle 树中。
// `levels` 表示树的层数。此模板利用 Merkle 路径和相应的元素来计算根哈希值。
template MerkleTreeChecker(levels) {
    // 输入信号定义
    signal input leaf;                    // 待验证的叶子节点
    signal input root;                   // Merkle 证明哈希值
    signal input pathElements[levels];    // Merkle 路径上的哈希值
    signal input pathIndices[levels];     // 路径索引，用于指示每层位置（左或右）

    // 组件定义
    component selectors[levels];          // Dualmux 选择器数组，每层一个
    component hashers[levels];            // hashLeftRight 哈希器数组，每层一个

    // 循环遍历每一层
    for (var i = 0; i < levels; i++) {
        // 创建 Dualmux 选择器
        selectors[i] = Dualmux();
        
        // 选择器输入连接
        // - 如果是第 0 层，将 `leaf` 作为输入，否则连接上一级的哈希输出。
        selectors[i].in[0] <== i == 0 ? leaf : hashers[i - 1].hash;
        selectors[i].in[1] <== pathElements[i];  // 当前路径元素作为 `in[1]`
        
        // 设置选择信号，基于 pathIndices 选择路径中的元素
        selectors[i].s <== pathIndices[i];

        // 实例化哈希器，并连接选择器的输出
        hashers[i] = hashLeftRight();
        hashers[i].left <== selectors[i].out[0];  // 将选择器的 `out[0]` 作为左输入
        hashers[i].right <== selectors[i].out[1]; // 将选择器的 `out[1]` 作为右输入
    }

    // 将最终的哈希值与给定的根哈希值 `proof` 比较
    // 如果证明有效，`hashers[levels - 1].hash` 应该等于 `proof`
    root === hashers[levels - 1].hash;
}

template withdraw(levels) {
    // 输入信号定义
    // public
    signal input root;                   // Merkle 证明哈希值
    signal input nullifierHash;                  

    // private
    signal input nullifier;
    signal input secret;
    signal input pathElements[levels];    // Merkle 路径上的哈希值
    signal input pathIndices[levels];     // 路径索引，用于指示每层位置（左或右）

    component hasher = CommitmentHash();
    hasher.nullifier <== nullifier;
    hasher.secret <== secret;

    // check
    hasher.nullifierHash === nullifierHash;
    
    // MerkleCheck
    component tree = MerkleTreeChecker(levels);
    tree.leaf <== hasher.commitment; 
    tree.root <== root;

    for (var i = 0; i < levels; i++) {
        tree.pathElements[i] <== pathElements[i];
        tree.pathIndices[i] <== pathIndices[i];
    }
}

component main {public [root, nullifierHash]} = withdraw(20);