/******************************************************************************\
*
*    File Name:  axi_lite_m.v
*      Version:  1.00
* Dependencies:  
*   Description:  axi_lite 主机
*       Model:  
*    Limitation:  
* 	Rev   	Author   	Date        Changes
* 	----------------------------------------------------------------------------
* 	1.00  	linhuiyi	04/9/18    Initial Release
\******************************************************************************/

module axi_lite_m #(
//数据起始值
parameter	AXI_START_DATA_VALUE=32'hAA00_0000,
//从机基地址
parameter	AXI_SLAVE_ADDR_BASE=32'h4000_0000,
//地址位宽
parameter	AXI_ADDR_WIDTH=32,
//数据位宽
parameter	AXI_DATA_WIDTH=32,
//
parameter   AXI_TRANS_NUM=10
)
(
//时钟
input    wire    i_axi_lite_clk,
//开始传输标志
input    wire    i_init_axi_txn,
//全局复位
input    wire    i_axi_lite_rstn,
//写地址(主机提供，从机接收)
output   reg[31:0] 	  o_axi_awaddr,
//写地址保护,表示一次传输的特权等级及安全等级
output    wire[2:0]    o_axi_awport,
//写地址有效
output    reg   	 o_axi_awvalid,
//从机准备接收写地址
input    wire		  i_axi_awready,
//写数据
output    reg[31:0]   o_axi_wdata,
//写数据有效字节线，表明哪8个数据有效
output 	 wire [3:0]    o_axi_wstrb,
//写数据有效
output    reg     	  o_axi_wvalid,
//写准备
input   wire          i_axi_wready,
//写响应，表明写传输的状态
input    wire 			i_axi_bresp,
//写响应有效
input    wire			i_axi_bvalid,
//表示主机能够接收响应
output    reg           o_axi_bready,
//读地址(主机提供，从机接收)
output    reg[31:0]   o_axi_araddr,
//读地址保护，表示一次传输的特权等级及安全等级
output    wire[2:0]    o_axi_arport,
//读地址有效，表明此通道读控制信号有效
output    reg	    o_axi_arvalid,
//从机准备接收读地址
input    wire		  i_axi_arready,
//读数据
input    wire[31:0]  i_axi_rdata,
//读响应，表明读传输的状态
input    wire [3:0]    i_axi_rresp,
//读有效，表明此通道信号有效
input    wire    	  i_axi_rvalid,
//读准备,表明主机可以接收数据和响应
output    reg          o_axi_rready 
);

//状态机初始状态
localparam IDLE=2'b00;
//初始化读状态
localparam INIT_WRITE=2'b01;
//初始化写状态
localparam INIT_READ=2'b10;
//预期数据与从从机接收的数据对比
localparam INIT_COMPARE=2'b11;

assign o_axi_arport=3'b000;
assign o_axi_awport=3'b000;
assign o_axi_wstrb=4'b1111;

//预期数据
reg[31:0] r_expect_data;
//
reg r_write_issued;
//
reg r_read_issued;
//开始写标志
reg r_start_single_write;
//开始读标志
reg r_start_single_read;

//写完标志
reg r_write_done;
//读完标志
reg r_read_done;
//对比完标志
reg r_compare_done;
//写最后一个数
reg r_last_write;
//读最后一个数
reg r_last_read;

//状态机 状态
reg[1:0] r_state;

//写指针，表示写到第几个数
reg[31:0]  r_write_index;
//读指针，表示读到第几个数
reg[31:0]  r_read_index;

//开始传输标志
wire r_init_txn_pulse;
reg r_init_ff;
reg r_init_ff2;



//传输标志为1个节拍
assign r_init_txn_pulse=r_init_ff&&~r_init_ff2;
always @(posedge i_axi_lite_clk or negedge i_axi_lite_rstn)
	if(!i_axi_lite_rstn)
		r_init_ff<=0;
	else 
		r_init_ff<=i_init_axi_txn;
always @(posedge i_axi_lite_clk or negedge i_axi_lite_rstn)
	if(!i_axi_lite_rstn)
		r_init_ff2<=0;
	else 
		r_init_ff2<=r_init_ff;
		
//状态转移
always @(posedge i_axi_lite_clk or negedge i_axi_lite_rstn)
	if(!i_axi_lite_rstn)
		r_state<=IDLE;
	else case(r_state)
		IDLE: if(r_init_txn_pulse)
				begin
					r_state<=INIT_WRITE;
				end
			 else
				begin
					r_state<=IDLE;
				end 
		INIT_WRITE: if(r_write_done)
						begin
							r_state<=INIT_READ;
						end 
					else 
						begin
							r_state<=INIT_WRITE;
						end 
		INIT_READ:  if(r_read_done)
						begin
							r_state<=INIT_COMPARE;
						end 
					else
						begin
							r_state<=INIT_READ;
						end 
		INIT_COMPARE: 
						begin
							r_state<=IDLE;
						end
		default:
				begin
					r_state<=IDLE;
				end
	endcase	
		
always @(posedge i_axi_lite_clk or negedge i_axi_lite_rstn)
	if(!i_axi_lite_rstn)
		begin
			r_write_issued<=0;
		end 
	else if(r_state==INIT_WRITE)
		begin
			if(~o_axi_awvalid&&~o_axi_wvalid&&~i_axi_bvalid&&~r_write_issued&&~r_start_single_write&&~r_last_write)
				begin
					r_write_issued<=1;
				end 
			else if(o_axi_bready)
				begin
					r_write_issued<=0;
				end 
		end 
		
always @(posedge i_axi_lite_clk or negedge i_axi_lite_rstn)
	if(!i_axi_lite_rstn)
		begin
			r_read_issued<=0;
		end 
	else if(r_state==INIT_READ)
		begin
			if(~o_axi_arvalid&&~i_axi_rvalid&&~r_read_issued&&~r_start_single_read&&~r_last_read)
				begin
					r_read_issued<=1;
				end 
			else if(o_axi_rready)
				begin
					r_read_issued<=0;
				end 
		end 
//开始写
always @(posedge i_axi_lite_clk or negedge i_axi_lite_rstn)
	if(!i_axi_lite_rstn)
		begin
			r_start_single_write<=0;
		end 
	else if(r_state==INIT_WRITE)
		begin
			if(~o_axi_awvalid&&~o_axi_wvalid&&~i_axi_bvalid&&~r_write_issued&&~r_start_single_write&&~r_last_write)
				begin
					r_start_single_write<=1;
				end 
			else
				begin
					r_start_single_write<=0;
				end 
		end 
//开始读
always @(posedge i_axi_lite_clk or negedge i_axi_lite_rstn)
	if(!i_axi_lite_rstn)
		begin
			r_start_single_read<=0;
		end 
	else if(r_state==INIT_READ)
		begin
			if(~o_axi_arvalid&&~i_axi_rvalid&&~r_read_issued&&~r_start_single_read&&~r_last_read)
				begin
					r_start_single_read<=1;
				end 
			else
				begin
					r_start_single_read<=0;
				end 
		end 

always @(posedge i_axi_lite_clk or negedge i_axi_lite_rstn)
	if(!i_axi_lite_rstn)
		begin
			o_axi_awvalid<=0;
		end 
	else if(r_start_single_write)
		begin
			o_axi_awvalid<=1;
		end 
	else if(i_axi_awready&&o_axi_awvalid)
		begin
			o_axi_awvalid<=0;
		end 

always @(posedge i_axi_lite_clk or negedge i_axi_lite_rstn)
	if(!i_axi_lite_rstn)
		begin
			r_write_index<=0;
		end 
	else if(r_start_single_write)
		begin
			r_write_index<=r_write_index+1;
		end 
always @(posedge i_axi_lite_clk or negedge i_axi_lite_rstn)
	if(!i_axi_lite_rstn)
		begin
			r_read_index<=0;
		end 
	else if(r_start_single_read)
		begin
			r_read_index<=r_read_index+1;
		end 
				
always @(posedge i_axi_lite_clk or negedge i_axi_lite_rstn)
	if(!i_axi_lite_rstn)
		begin
			o_axi_wvalid<=0;
		end 
	else if(r_start_single_write)
		begin
			o_axi_wvalid<=1;
		end 	
	else if(i_axi_wready&&o_axi_wvalid)
		begin
			o_axi_wvalid<=0;
		end 
			
	
//响应准备只维持一个周期
always @(posedge i_axi_lite_clk or negedge i_axi_lite_rstn)
	if(!i_axi_lite_rstn)
		begin
			o_axi_bready<=0;
		end 
	else if(~o_axi_bready&&i_axi_bvalid)
		begin
			o_axi_bready<=1;
		end 
	else if(o_axi_bready)
		begin
			o_axi_bready<=0;
		end 

always @(posedge i_axi_lite_clk or negedge i_axi_lite_rstn)
	if(!i_axi_lite_rstn)
		begin
			r_read_index<=0;
		end 
	else if(r_start_single_read)
		begin
			r_read_index<=r_read_index+1;
		end 

always @(posedge i_axi_lite_clk or negedge i_axi_lite_rstn)
	if(!i_axi_lite_rstn)
		begin
			o_axi_arvalid<=0;
		end 
	else if(r_start_single_write)
		begin
			o_axi_arvalid<=1;
		end 
	else  if(i_axi_arready&&o_axi_arvalid)
		begin
			o_axi_arvalid<=0;
		end 
	
always @(posedge i_axi_lite_clk or negedge i_axi_lite_rstn)
	if(!i_axi_lite_rstn)
		begin
			o_axi_rready<=0;
		end 
	else  if(i_axi_rvalid&&~o_axi_rready)
		begin
			o_axi_rready<=1;
		end 
	else if(o_axi_rready)
		begin
			o_axi_rready<=0;
		end 

always @(posedge i_axi_lite_clk or negedge i_axi_lite_rstn)
	if(!i_axi_lite_rstn)
		begin
			o_axi_awaddr<=AXI_SLAVE_ADDR_BASE;
		end 
	else if(i_axi_awready&&o_axi_awvalid)
		begin
			o_axi_awaddr<=o_axi_awaddr+32'h0000_0004;  //每次地址加4
		end 
		
always @(posedge i_axi_lite_clk or negedge i_axi_lite_rstn)
	if(!i_axi_lite_rstn)
		begin
			o_axi_wdata<=AXI_START_DATA_VALUE;
		end 
	else if(i_axi_wready&&o_axi_wvalid)
		begin
			o_axi_wdata<=o_axi_wdata+1;//r_write_index;  
		end 	
		
always @(posedge i_axi_lite_clk or negedge i_axi_lite_rstn)
	if(!i_axi_lite_rstn)
		begin
			o_axi_araddr<=AXI_SLAVE_ADDR_BASE;
		end 
	else if(i_axi_arready&&o_axi_arvalid)
		begin
			o_axi_araddr<=o_axi_araddr+32'h0000_0004;  //每次地址加4
		end 
		
always @(posedge i_axi_lite_clk or negedge i_axi_lite_rstn)
	if(!i_axi_lite_rstn)
		begin
			r_expect_data<=AXI_START_DATA_VALUE;
		end 
	else if(o_axi_rready&&i_axi_rvalid)
		begin
			r_expect_data<=r_expect_data+1;//r_read_index;  
		end 	


		
always @(posedge i_axi_lite_clk or negedge i_axi_lite_rstn)
	if(!i_axi_lite_rstn)
		begin
			r_last_write<=0;
		end 
	else if(r_write_index==AXI_TRANS_NUM&&i_axi_awready)
		begin
			r_last_write<=1;
		end 
	else 
		begin
			r_last_write<=r_last_write;
		end 
		
always @(posedge i_axi_lite_clk or negedge i_axi_lite_rstn)
	if(!i_axi_lite_rstn)
		begin
			r_write_done<=0;
		end 
	else if(r_write_index==AXI_TRANS_NUM&&i_axi_wready)
		begin
			r_write_done<=1;
		end 
	else 
		begin
			r_write_done<=r_write_done;
		end 


always @(posedge i_axi_lite_clk or negedge i_axi_lite_rstn)
	if(!i_axi_lite_rstn)
		begin
			r_last_read<=0;
		end 
	else if(r_read_index==AXI_TRANS_NUM&&i_axi_arready)
		begin
			r_last_read<=1;
		end 
	else 
		begin
			r_last_read<=r_last_read;
		end 
		
always @(posedge i_axi_lite_clk or negedge i_axi_lite_rstn)
	if(!i_axi_lite_rstn)
		begin
			r_read_done<=0;
		end 
	else if(r_read_index==AXI_TRANS_NUM&&o_axi_rready)
		begin
			r_read_done<=1;
		end 
	else 
		begin
			r_read_done<=r_read_done;
		end 
always @(posedge i_axi_lite_clk or negedge i_axi_lite_rstn)
	if(!i_axi_lite_rstn)
		begin
			r_compare_done<=0;
		end 
	else if(r_state==INIT_COMPARE)
		begin
			r_compare_done<=1;
		end 

endmodule
	