`timescale 1ns/1ps
module tb_tlp_demux();
    parameter PORTS        = 2;
    parameter DOUBLE_WORD  = 32;
    parameter HEADER_SIZE  = 4*DOUBLE_WORD;
    parameter PAYLOAD_SIZE = 8*DOUBLE_WORD;
    //
    reg                                                     clk;
    reg                                                     rst_n;
    // input TLP
    reg                     [PAYLOAD_SIZE-1:0]              in_data;
    reg                     [HEADER_SIZE-1:0]               in_hdr;
    reg                                                     in_sop;
    reg                                                     in_eop;
    reg                                                     in_valid;
    wire                                                    in_ready;
    // read TLP out
    wire                    [PAYLOAD_SIZE-1:0]              r_out_data;
    wire                    [HEADER_SIZE-1:0]               r_out_hdr;
    wire                                                    r_out_sop;
    wire                                                    r_out_eop;
    wire                                                    r_out_valid;
    reg                                                     r_out_ready;
    // write TLP out
    wire                    [PAYLOAD_SIZE-1:0]              w_out_data;
    wire                    [HEADER_SIZE-1:0]               w_out_hdr;
    wire                                                    w_out_sop;
    wire                                                    w_out_eop;
    wire                                                    w_out_valid;
    reg                                                     w_out_ready;
    // control
    reg                                                     enable;
    
    tlp_demux #(
        .PORTS(PORTS),
        .DOUBLE_WORD(DOUBLE_WORD),
        .HEADER_SIZE(HEADER_SIZE),
        .PAYLOAD_SIZE (PAYLOAD_SIZE)
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
