module tlp_tx #(
    DOUBLE_WORD             =        32,                                // 双字，32位
    HEADER_SIZE             =        4*DOUBLE_WORD,                     // Header4个双字，取决于host内存空间是否大于4GB
    PAYLOAD_SIZE            =        8*DOUBLE_WORD                      // 数据荷载8个双字
)(
    input                                                   clk,
    input                                                   rst_n,
    input                                                   in_ready,
    output      reg         [PAYLOAD_SIZE-1:0]              in_data,
    output      reg         [HEADER_SIZE-1:0]               in_hdr,
    output      reg                                         in_sop,
    output      reg                                         in_eop,
    output      reg                                         in_valid
);
    reg                     [PAYLOAD_SIZE-1:0]              in_data_nxt;
    reg                     [HEADER_SIZE-1:0]               in_hdr_nxt;
    reg                                                     in_sop_nxt;
    reg                                                     in_eop_nxt;
    reg                                                     in_valid_nxt;
    initial begin
        in_data_nxt  = 0;
        in_hdr_nxt   = 0;
        in_valid_nxt = 0;
        in_sop_nxt   = 0;
        in_eop_nxt   = 0;
        in_hdr_nxt[HEADER_SIZE-3] = 1'b1;
        forever begin
            @(posedge in_ready);
            in_valid_nxt                   = 0;
            in_data_nxt                    = in_data_nxt + 1'b1;
            in_hdr_nxt[HEADER_SIZE-2] = ~in_hdr_nxt[HEADER_SIZE-2];
            in_hdr_nxt                     = in_hdr_nxt + 1'b1;
            repeat(3) @(posedge clk);
            in_valid_nxt = 1;
        end
    end
    always @(posedge clk) begin
        if (!rst_n) begin
            in_data  <= 0;
            in_hdr   <= 0;
            in_sop   <= 0;
            in_eop   <= 0;
            in_valid <= 0;
        end
        else begin
            in_data  <= in_data_nxt;
            in_hdr   <= in_hdr_nxt;
            in_sop   <= in_sop_nxt;
            in_eop   <= in_eop_nxt;
            in_valid <= in_valid_nxt;
        end
    end
endmodule
