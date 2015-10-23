module ffs_arbiter
#(
    parameter CLIENTS = 16
)
(
    input logic clk,
    input logic rst_n,

    input logic [ CLIENTS - 1:0 ] req,
    output logic [ CLIENTS - 1:0 ] gnt
);

// =======================================================================
// Declarations & Parameters

logic [ CLIENTS - 1:0 ] mask;
logic [ 15:0 ] req_location;
logic [ 15:0 ] reqm_location;
logic vld_ffs_req;
logic vld_ffs_reqm;

logic [ CLIENTS - 1:0 ] req_masked;

logic [ 15:0 ] winner;
logic win_vld;

// =======================================================================
// Logic

assign req_masked = req & mask;

// find first set bit in both request and masked request; priority shifts
// down the bit vector, but returns to the to of the bit vector when no
// lower bits are set

assign { vld_ffs_req, req_location } = ffs( req );
assign { vld_ffs_reqm, reqm_location } = ffs( req_masked );

// determine the winner--either the masked version (because a lower-priority
// request was set) or the unmasked version (because we started over from
// the top)

always_comb
begin
    if ( vld_ffs_reqm )
    begin
        winner = reqm_location;
        win_vld = 1'b1;
    end

    else if ( vld_ffs_req )
    begin
        winner = req_location;
        win_vld = 1'b1;
    end

    else
    begin
        winner = 16'd0;
        win_vld = 1'b0;
    end

// Register:  mask
//
// The mask depends on the previous winner.

genvar i;

always @( posedge clk )

    if ( !rst_n )
        mask <= {CLIENTS{1'b0}};

    else
    begin

        case( winner )

            generate
                for ( i = 0; i < CLIENTS - 1; i++ )
                    case i:  mask <= {i{1'b1}};
            endgenerate

            default:  mask <= {CLIENTS{1'b0}};

        endcase

    end
            
// Register:  gnt
//
// Priority is given to lower bits i.e., those getting a gnt when using
// the mask vector.  If no lower bits are set, the unmasked request result
// is used.

always @( posedge clk )

    if ( !rst_n )
        gnt <= {CLIENTS{1'b0}};

    else if ( win_vld )
    begin
        gnt <= {CLIENTS{1'b0}};
        gnt[ winner ] <= 1'b1;
    end

    else
        gnt <= {CLIENTS{1'b0}};

// =======================================================================
// Function

// Function:  ffs
//
// Returns the first set bit starting with the most-significant bit.
// Format for return is { vld, location[ 15:0 ] }

function automatic [ 16:0 ] ffs( input bit [ CLIENTS - 1:0 ] vector )

    bit vld;
    logic [ 15:0 ] location;

    vld = 1'b0;

    for ( int i = 0; i < CLIENTS - 1; i++ )
        if ( vector[ i ] == 1'b1 )
        begin
            vld = 1'b1;
            location = i[ 15:0 ];
        end

    return( { vld, location } );

endfunction
