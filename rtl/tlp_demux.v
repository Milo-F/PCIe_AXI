/*
 * @Author=Milo
 * @Function= pcie事务包读写解复用器，将读请求tlp与写请求tlp区分分别输出
 */

module tlp_demux #(
    PORTS                   =        2,                                 // 解复用输出端口，在此解复用器用作读写复用，故为2
    DOUBLE_WORD             =        32,                                // 双字，32位
    HEADER_SIZE             =        4*DOUBLE_WORD,                     // Header4个双字，取决于host内存空间是否大于4GB
    PAYLOAD_SIZE            =        8*DOUBLE_WORD                      // 数据荷载8个双字
) (
    input                                                   clk,
    input                                                   rst_n,
    input       wire        [PAYLOAD_SIZE - 1 : 0]          in_data,    // 输入TLP包数据
    input       wire        [HEADER_SIZE - 1 : 0]           in_header,  // 输入TLP包头
    input       wire                                        in_s_op,
    input       wire                                        in_e_op,
    input       wire                                        in_valid,
    output      reg                                         in_ready,
    output      reg         [PORTS*PAYLOAD_SIZE-1:0]        out_data, // 输出TLP包，高低两位一起输出
);
    
endmodule
