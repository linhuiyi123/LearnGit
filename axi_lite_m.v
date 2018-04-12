/******************************************************************************\
*
*    File Name:  axi_lite_m.v
*      Version:  1.00
* Dependencies:  
*   Description:  axi_lite ����
*       Model:  
*    Limitation:  
* 	Rev   	Author   	Date        Changes
* 	----------------------------------------------------------------------------
* 	1.00  	linhuiyi	04/9/18    Initial Release
\******************************************************************************/

module axi_lite_m #(
//������ʼֵ
parameter	AXI_START_DATA_VALUE=32'hAA00_0000,
//�ӻ�����ַ
parameter	AXI_SLAVE_ADDR_BASE=32'h4000_0000,
//��ַλ��
parameter	AXI_ADDR_WIDTH=32,
//����λ��
parameter	AXI_DATA_WIDTH=32,
//
parameter   AXI_TRANS_NUM=10
)
(
//ʱ��
input    wire    i_axi_lite_clk,
//��ʼ�����־
input    wire    i_init_axi_txn,
//ȫ�ָ�λ
input    wire    i_axi_lite_rstn,
//д��ַ(�����ṩ���ӻ�����)
output   reg[31:0] 	  o_axi_awaddr,
//д��ַ����,��ʾһ�δ������Ȩ�ȼ�����ȫ�ȼ�
output    wire[2:0]    o_axi_awport,
//д��ַ��Ч
output    reg   	 o_axi_awvalid,
//�ӻ�׼������д��ַ
input    wire		  i_axi_awready,
//д����
output    reg[31:0]   o_axi_wdata,
//д������Ч�ֽ��ߣ�������8��������Ч
output 	 wire [3:0]    o_axi_wstrb,
//д������Ч
output    reg     	  o_axi_wvalid,
//д׼��
input   wire          i_axi_wready,
//д��Ӧ������д�����״̬
input    wire 			i_axi_bresp,
//д��Ӧ��Ч
input    wire			i_axi_bvalid,
//��ʾ�����ܹ�������Ӧ
output    reg           o_axi_bready,
//����ַ(�����ṩ���ӻ�����)
output    reg[31:0]   o_axi_araddr,
//����ַ��������ʾһ�δ������Ȩ�ȼ�����ȫ�ȼ�
output    wire[2:0]    o_axi_arport,
//����ַ��Ч��������ͨ���������ź���Ч
output    reg	    o_axi_arvalid,
//�ӻ�׼�����ն���ַ
input    wire		  i_axi_arready,
//������
input    wire[31:0]  i_axi_rdata,
//����Ӧ�������������״̬
input    wire [3:0]    i_axi_rresp,
//����Ч��������ͨ���ź���Ч
input    wire    	  i_axi_rvalid,
//��׼��,�����������Խ������ݺ���Ӧ
output    reg          o_axi_rready 
);

//״̬����ʼ״̬
localparam IDLE=2'b00;
//��ʼ����״̬
localparam INIT_WRITE=2'b01;
//��ʼ��д״̬
localparam INIT_READ=2'b10;
//Ԥ��������Ӵӻ����յ����ݶԱ�
localparam INIT_COMPARE=2'b11;

assign o_axi_arport=3'b000;
assign o_axi_awport=3'b000;
assign o_axi_wstrb=4'b1111;

//Ԥ������
reg[31:0] r_expect_data;
//
reg r_write_issued;
//
reg r_read_issued;
//��ʼд��־
reg r_start_single_write;
//��ʼ����־
reg r_start_single_read;

//д���־
reg r_write_done;
//�����־
reg r_read_done;
//�Ա����־
reg r_compare_done;
//д���һ����
reg r_last_write;
//�����һ����
reg r_last_read;

//״̬�� ״̬
reg[1:0] r_state;

//дָ�룬��ʾд���ڼ�����
reg[31:0]  r_write_index;
//��ָ�룬��ʾ�����ڼ�����
reg[31:0]  r_read_index;

//��ʼ�����־
wire r_init_txn_pulse;
reg r_init_ff;
reg r_init_ff2;



//�����־Ϊ1������
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
		
//״̬ת��
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
//��ʼд
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
//��ʼ��
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
			
	
//��Ӧ׼��ֻά��һ������
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
			o_axi_awaddr<=o_axi_awaddr+32'h0000_0004;  //ÿ�ε�ַ��4
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
			o_axi_araddr<=o_axi_araddr+32'h0000_0004;  //ÿ�ε�ַ��4
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
	