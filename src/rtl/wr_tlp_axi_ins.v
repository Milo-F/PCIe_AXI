wr_tlp_axi #(
    DOUBLE_WORD             =        32,
    HEADER_SIZE             =        4*DOUBLE_WORD,
    TLP_DATA_WIDTH          =        8*DOUBLE_WORD,
    AXI_DATA_WIDTH          =        TLP_DATA_WIDTH,
    AXI_ADDR_WIDTH          =        64,
    AXI_STRB_WIDTH          =        AXI_DATA_WIDTH/8,
    AXI_ID_WIDTH            =        8,
    AXI_MAX_BURST_LEN       =        256
)  wr_tlp_axi_ins (
    .clk(clk),
    .rst_n(rst_n),
    .tlp_hdr(tlp_hdr),
    .tlp_data(tlp_data),
    .tlp_sop(tlp_sop),
    .tlp_eop(tlp_eop),
    .tlp_valid(tlp_valid),
    .tlp_ready(tlp_ready),
    .axi_awid(axi_awid),
    .axi_awaddr(axi_awaddr),
    .axi_awlen(axi_awlen),
    .axi_awsize(axi_awsize),
    .axi_awburst(axi_awburst),
    .axi_awlock(axi_awlock),
    .axi_awcache(axi_awcache),
    .axi_awprot(axi_awprot),
    .axi_awvalid(axi_awvalid),
    .axi_awready(axi_awready),
    .axi_wdata(axi_wdata),
    .axi_wvalid(axi_wvalid),
    .数据有效(数据有效)
    .axi_wlast  最后一次transfer(axi_wlast  最后一次transfer),
    .axi_wready(axi_wready),
    .axi_bid    回应ID，要与AWID匹配(axi_bid    回应ID，要与AWID匹配),
    .axi_bresp  回应，分为OK，EXOK，SLAVER和DECERR，OKAY是正常成功传输响应，EXOKAY是独占访问下的传输成功响应，SLAVER是传输失败响应，DECODERR是译码错误响应(axi_bresp  回应，分为OK，EXOK，SLAVER和DECERR，OKAY是正常成功传输响应，EXOKAY是独占访问下的传输成功响应，SLAVER是传输失败响应，DECODERR是译码错误响应),
    .axi_bvalid(axi_bvalid),
    .axi_bready(axi_bready),
    .tlp_error(tlp_error)
);