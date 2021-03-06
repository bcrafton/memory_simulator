typedef bit [15:0] WORD;

class mrqst_t;
    WORD address;
    WORD data;
    // letting this be randomized to whatever
    // will say anything that matches the time or is ahead of it ships
    int response_time;
    function new(WORD address, WORD data);
    begin
        this.address = address;
        this.data = data;
        this.response_time = $time + $urandom_range(25, 100);
    end
    endfunction
endclass

mrqst_t rd_rqst;
mrqst_t wr_rqst;

mrqst_t rd_rqst_q[$];
mrqst_t wr_rqst_q[$];

// ideally would use a heap... but dont have that.
function add_to_rqst_q(ref mrqst_t rqst_q[$], ref mrqst_t rqst);
    int size, i;
    size = rqst_q.size();
    if(size == 0) begin
        rqst_q.push_back(rqst);
    end 
    else begin
        for(i=0; i<size; i++) begin
            if(rqst.response_time < rqst_q[i].response_time) begin
                rqst_q.insert(i, rqst);
                return;
            end
        end
        rqst_q.push_back(rqst);
    end
endfunction

module ram(
    clk,
    
    wr_address,
    wr_en,
    wr_data,
    wr_ret_address,
    wr_ret_ack,
    
    rd_address,
    rd_en,
    rd_ret_data,
    rd_ret_address,
    rd_ret_ack
    );
    
    input clk;

    // some of these need to be reg.
    // the ones we are driving
    // Net type cannot be used on the left side of this assignment
    //
    input [15:0]      wr_address;
    input             wr_en;
    input [15:0]      wr_data;
    output reg [15:0] wr_ret_address; // tag = address
    output reg        wr_ret_ack;

    input [15:0]      rd_address;
    input             rd_en;
    output reg [15:0] rd_ret_data;
    output reg [15:0] rd_ret_address; // tag = address
    output reg        rd_ret_ack;

    //reg [15:0] mem [0:1023];
    // use an associative array instead of reg.
    // saves memory and easier to use.
    WORD mem [WORD];

    initial begin
        int i;
        for(i=0; i<1024; i++) begin
            mem[i] = 0;
        end
    end

    always @(posedge clk) begin
        // unset these
        rd_ret_ack = 0;
        wr_ret_ack = 0;
        
        if(wr_en) begin
            
            wr_rqst = new(wr_address, wr_data);
            //wr_rqst_q.push_back(wr_rqst);
            //this will keep rqst in order
            add_to_rqst_q(wr_rqst_q, wr_rqst);
        end
        if (rd_en) begin
            rd_rqst = new(rd_address, 0);
            //rd_rqst_q.push_back(rd_rqst);
            //this will keep rqst in order
            add_to_rqst_q(rd_rqst_q, rd_rqst);
        end
        if(wr_rqst_q.size() > 0 && wr_rqst_q[0].response_time <= $time) begin
            // write to memory, ack with address
            wr_rqst = wr_rqst_q.pop_front();
            
            wr_ret_ack = 1;
            wr_ret_address = wr_rqst.address;
            mem[wr_rqst.address] = wr_rqst.data;
        end
        if(rd_rqst_q.size() > 0 && rd_rqst_q[0].response_time <= $time) begin
            // read from memory and respond
            rd_rqst = rd_rqst_q.pop_front();
            
            rd_ret_ack = 1;
            rd_ret_address = rd_rqst.address;
            rd_ret_data = mem[rd_rqst.address];
        end
    end

endmodule