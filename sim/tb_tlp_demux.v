`timescale 1ns/1ps
module tb_tlp_demux();
    parameter PORTS          = 2;
    parameter DOUBLE_WORD    = 32;
    parameter HEADER_SIZE    = 4*DOUBLE_WORD;
    parameter TLP_DATA_WIDTH = 8*DOUBLE_WORD;
    //
    reg                                                     clk;
    reg                                                     rst_n;
    // input TLP
    wire                    [TLP_DATA_WIDTH-1:0]            in_data;
    wire                    [HEADER_SIZE-1:0]               in_hdr;
    wire                                                    in_sop;
    wire                                                    in_eop;
    wire                                                    in_valid;
    wire                                                    in_ready;
    // read TLP out
    wire                    [TLP_DATA_WIDTH-1:0]            r_out_data;
    wire                    [HEADER_SIZE-1:0]               r_out_hdr;
    wire                                                    r_out_sop;
    wire                                                    r_out_eop;
    wire                                                    r_out_valid;
    reg                                                     r_out_ready,r_out_ready_nxt;
    // write TLP out
    wire                    [TLP_DATA_WIDTH-1:0]            w_out_data;
    wire                    [HEADER_SIZE-1:0]               w_out_hdr;
    wire                                                    w_out_sop;
    wire                                                    w_out_eop;
    wire                                                    w_out_valid;
    reg                                                     w_out_ready,w_out_ready_nxt;
    // control
    reg                                                     enable;
    // generate clock
    initial begin
        clk            = 0;
        forever #1 clk = ~clk;
    end
    // reset
    initial begin
        enable    = 1;
        rst_n     = 1'b1;
        #10 rst_n = 0;
        #10 rst_n = 1'b1;
    end
    always @* begin
        w_out_ready_nxt = w_out_ready;
        r_out_ready_nxt = r_out_ready;
        if (w_out_ready == 0) begin
            w_out_ready_nxt = 1;
        end
        
        if (w_out_ready & w_out_valid) begin
            w_out_ready_nxt = 0;
        end
        
        if (r_out_ready == 0) begin
            r_out_ready_nxt = 1;
        end
        
        if (r_out_ready & r_out_valid) begin
            r_out_ready_nxt = 0;
        end
    end
    
    always @(posedge clk) begin
        if (!rst_n) begin
            w_out_ready <= 0;
            r_out_ready <= 0;
        end
        else begin
            w_out_ready <= w_out_ready_nxt;
            r_out_ready <= r_out_ready_nxt;
        end
    end
    // tlp包发送模块，用于产生随机的tlp包，包括读存储器包、写存储器包以及非法包。每当in_ready信号为1时，包持续1拍再变换。
    tlp_tx #(
        .DOUBLE_WORD(DOUBLE_WORD),
        .HEADER_SIZE(HEADER_SIZE),
        .TLP_DATA_WIDTH(TLP_DATA_WIDTH)
    ) tlp_tx (
        .clk(clk),
        .rst_n(rst_n),
        .in_ready(in_ready),
        .in_data(in_data),
        .in_hdr(in_hdr),
        .in_sop(in_sop),
        .in_eop(in_eop),
        .in_valid(in_valid)
    );
    tlp_demux #(
        .PORTS(PORTS),
        .DOUBLE_WORD(DOUBLE_WORD),
        .HEADER_SIZE(HEADER_SIZE),
        .TLP_DATA_WIDTH (TLP_DATA_WIDTH)
    ) tlp_demux_ins (
        .clk(clk),
        .rst_n(rst_n),
        .in_data(in_data),
        .in_hdr(in_hdr),
        .in_sop(in_sop),
        .in_eop(in_eop),
        .in_valid(in_valid),
        .in_ready(in_ready),
        .r_out_data(r_out_data),
        .r_out_hdr(r_out_hdr),
        .r_out_sop(r_out_sop),
        .r_out_eop(r_out_eop),
        .r_out_valid(r_out_valid),
        .r_out_ready(r_out_ready),
        .w_out_data(w_out_data),
        .w_out_hdr(w_out_hdr),
        .w_out_sop(w_out_sop),
        .w_out_eop(w_out_eop),
        .w_out_valid(w_out_valid),
        .w_out_ready(w_out_ready),
        .enable(enable)
    );
    
endmodule
