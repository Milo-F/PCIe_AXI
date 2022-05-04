tlp_demux #(
    PORTS                   =        2,
    DOUBLE_WORD             =        32,
    HEADER_SIZE             =        4*DOUBLE_WORD,
    PAYLOAD_SIZE            =        8*DOUBLE_WORD
)  tlp_demux_ins (
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