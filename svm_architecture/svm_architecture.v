`timescale 1ns/1ps

module svm_architecture (
    input clk,
    input rst,
    input [31*13:0]X, //changed 36 to 32 
    input [31:0] support_vector,
    input [31:0] alpha,
    input [31:0] weights,
    output classification_result // Final classification result
);

    // Internal Wires for Data Fetching
    wire [32:0] support_vector_in;
    wire [32:0] support_vector_out;
    wire [32:0] alpha_out;
    wire [32:0] weights_out;
    wire [32:0] alpha_in;
    wire [32:0] weight_in;

    // Control Unit Outputs
    wire [13:0] sv_index;
    wire compute_enable;
    wire done;

    // SPRAM Control Signals
    reg we, oe, cs;
    
    // Compute SPRAM memory indices
    wire [9:0] local_addr ;   // Address inside selected SPRAM
    wire [9:0] spram_index ;// Select correct SPRAM instance

    // Instantiate Control Unit to manage addressing and computation
    control_unit control_inst (
        .clk(clk),
        .rst(rst),
        .sv_index(sv_index),
        .compute_enable(compute_enable),
        .done(done)
    );
    

    // Instantiate SPRAM Modules for Support Vectors, Alphas, and Weights
    /*spram_array_synth sv_mem (
        .clk(clk),
        .addr(local_addr),
        .data_out(support_vector_out)
    );

    spram_alpha_synth alpha_mem (
        .clk(clk),
        .addr(local_addr),        
        .data_out(alpha_out)
    );

    spram_weights_synth weight_mem (
        .clk(clk),
        .addr(local_addr),        
        .data_out(weight_out)
    );*/

    // Kernel and Weighted Sum Outputs
    wire [31:0] kernel_result;
    wire [31:0] decision_value;

    // Linear Kernel Module
    linear_kernel kernel (
        .clk(clk),
        .input_vector(X),  // Weighted input vector from memory
        .support_vector(support_vector),
        .kernel_result(kernel_result)
    );

    // Weighted Summation Module
    weighted_sum sum_module (
        .clk(clk),
        .alpha_y(alpha),
        .kernel_values(kernel_result),
        .bias(32'hFFFA0000), // Directly using fixed-point bias
        .decision_value(decision_value)
    );

    // Decision Block
    decision_block decision (
        .decision_value(decision_value),
        .classification_result(classification_result)
    );

    // Control Logic for SPRAM Access
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            we <= 1'b1;  // Disable writing
            oe <= 1'b0;  // Enable output
            cs <= 1'b0;  // Enable memory
        end
        else begin
            we <= 1'b1;  // Read Mode
            oe <= 1'b0;  // Enable output
            cs <= 1'b0;  // Enable memory access
        end
    end

endmodule


// Control Unit to manage support vector addressing and computation control
module control_unit (
    input clk,
    input rst,
    output reg [13:0] sv_index, // Support vector index
    output reg compute_enable,  // Enable signal for computation
    output reg done             // Done signal
);

    reg [13:0] input_index;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sv_index <= 0;
            input_index <= 0;
            compute_enable <= 0;
            done <= 0;
        end else begin
            if (sv_index < 11237*13) begin
                sv_index <= sv_index + 1;  // Iterate through support vectors
                compute_enable <= 1;       // Enable computation
            end else begin
                sv_index <= 0;
                if (input_index < 6667*13) begin
                    input_index <= input_index + 1; // Move to next input vector
                end else begin
                    done <= 1; // Indicate completion
                end
            end
        end
    end

endmodule


/*module spram_array_synth #(
    parameter NUM_VECTORS = 11237,  // Number of support vectors
    parameter FEATURE_SIZE = 18,    // Features per vector
    parameter DATA_WIDTH = 36,      // Bit width of each element
    parameter ADDR_WIDTH = 10,      // Address width for 1024-depth SPRAM
    parameter NUM_MEMORIES = (NUM_VECTORS * FEATURE_SIZE) / 1024 + 1 // Compute required SPRAMs
)(
    input clk,
    input [ADDR_WIDTH-1:0] addr,     // Address input
       // Data input
    output [DATA_WIDTH-1:0] data_out  // Data output
);

    // SPRAM instance array
    wire [DATA_WIDTH-1:0] data_out_array [0:NUM_MEMORIES-1];
    reg [ADDR_WIDTH-1:0] addr_array [0:NUM_MEMORIES-1];
    reg we_array [0:NUM_MEMORIES-1];
    reg oe_array [0:NUM_MEMORIES-1];
    reg cs_array [0:NUM_MEMORIES-1];
    reg [DATA_WIDTH-1:0] data_in_array [0:NUM_MEMORIES-1];

    // Instantiate multiple SPRAMs
    genvar k;
    generate
        for (k = 0; k < NUM_MEMORIES; k = k + 1) begin : spram_blocks
            SPRAM_1024x36 spram_inst (
                .A(addr_array[k]),
                .CE(clk),
                .WEB(1'b1),
                .OEB(1'b0),
                .CSB(1'b0),
                .I(data_in_array[k]),
                .O(data_out_array[k])
            );
            assign data_out = data_out_array[k];
        end
        
    endgenerate

    // Addressing Logic
    
    // Assign output from selected SPRAM
    

endmodule

module spram_weights_synth #(
    parameter DATA_WIDTH = 36,  // Bit width of each weight
    parameter ADDR_WIDTH = 10,  // Address width (for 1024-depth SPRAM)
    parameter NUM_WEIGHTS = 18  // Number of weights
)(
    input clk,
    input [ADDR_WIDTH-1:0] addr,     // Address input
       // Data input
    output [DATA_WIDTH-1:0] data_out  // Data output
);

    // Internal signals
    reg [ADDR_WIDTH-1:0] addr_reg;
    reg we_reg, oe_reg, cs_reg;
    reg [DATA_WIDTH-1:0] data_in_reg;
    wire [DATA_WIDTH-1:0] data_out_wire;

    // Instantiate a single SPRAM for weights (since only 18 weights are needed)
    SPRAM_1024x36 spram_inst (
        .A(addr_reg),
        .CE(clk),
        .WEB(1'b1),
        .OEB(1'b0),
        .CSB(1'b0),
        .I(data_in_reg),
        .O(data_out_wire)
    );
	assign data_out = data_out_wire;
    // Register inputs on clock edge for proper timing
    

endmodule


module spram_alpha_synth #(
    parameter DATA_WIDTH = 36,    // Bit width of each alpha value
    parameter ADDR_WIDTH = 10,    // Address width (for 1024-depth SPRAM)
    parameter NUM_ALPHA = 11237   // Number of alpha values
)(
    input clk,
    input [ADDR_WIDTH-1:0] addr,     // Address input
    output [DATA_WIDTH-1:0] data_out  // Data output
);

    // Internal signals
    reg [ADDR_WIDTH-1:0] addr_reg;
    reg we_reg, oe_reg, cs_reg;
    reg [DATA_WIDTH-1:0] data_in_reg;
    wire [DATA_WIDTH-1:0] data_out_wire;

    // Compute the number of SPRAMs required
    localparam NUM_MEMORIES = (NUM_ALPHA / 1024) + 1;

    // SPRAM instance array
    wire [DATA_WIDTH-1:0] data_out_array [0:NUM_MEMORIES-1];
    reg [ADDR_WIDTH-1:0] addr_array [0:NUM_MEMORIES-1];
    reg we_array [0:NUM_MEMORIES-1];
    reg oe_array [0:NUM_MEMORIES-1];
    reg cs_array [0:NUM_MEMORIES-1];
    reg [DATA_WIDTH-1:0] data_in_array [0:NUM_MEMORIES-1];

    // Instantiate multiple SPRAMs
    genvar i;
    generate
        for (i = 0; i < NUM_MEMORIES; i = i + 1) begin : alpha_spram_blocks
            SPRAM_1024x36 spram_inst (
                .A(addr_array[i]),
                .CE(clk),
                .WEB(1'b1),
                .OEB(1'b0),
                .CSB(1'b0),
                .I(data_in_array[i]),
                .O(data_out_array[i])
            );
            assign data_out = data_out_array[i];
        end
    endgenerate

   

endmodule*/


module weighted_sum #(
    parameter DATA_WIDTH = 32,
    parameter NUM_SV = 11237
)(
    input clk,
    input [DATA_WIDTH-1:0] alpha_y,
    input [DATA_WIDTH-1:0] kernel_values,
    input [DATA_WIDTH-1:0] bias,
    output reg [DATA_WIDTH-1:0] decision_value
);

    reg [71:0] weighted_sum;

    always @(posedge clk) begin
        weighted_sum = bias;
        weighted_sum = weighted_sum + (alpha_y * kernel_values);
        decision_value = weighted_sum[DATA_WIDTH-1:0];
    end
endmodule

module linear_kernel #(
    parameter DATA_WIDTH = 32,
    parameter FEATURE_SIZE = 13
)(
    input clk,
    input [FEATURE_SIZE*DATA_WIDTH-1:0] input_vector,
    input [DATA_WIDTH-1:0] support_vector,
    output reg [DATA_WIDTH-1:0] kernel_result
);

    reg [DATA_WIDTH-1:0] weights [0:FEATURE_SIZE-1];
    integer i;
    reg [71:0] sum;



    always @(posedge clk) begin
        sum = 0;
        for (i = 0; i < FEATURE_SIZE; i = i + 1) begin
            sum = sum + (input_vector[i*DATA_WIDTH +: DATA_WIDTH] * weights[i]) * 
                        (support_vector * weights[i]);
        end
        kernel_result = sum[DATA_WIDTH-1:0];
    end
endmodule

module decision_block #(
    parameter DATA_WIDTH = 32
)(
    input [DATA_WIDTH-1:0] decision_value, // Output of weighted summation
    output reg classification_result      // Binary classification result
);

    always @(*) begin
        classification_result = (decision_value > 0) ? 1 : 0;
    end

endmodule


