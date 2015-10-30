import helpers::*;

class Vector#( parameter WIDTH = 32 );
  
    rand bit [ WIDTH - 1:0 ] vect;
    uint32_t last_rnd_rbn;
    uint32_t rnd_rbn;
    uint32_t mid_test_reqs;
  
    const uint32_t NOT_FOUND = 32'hffff_ffff;
  
    function new();
      this.srandom( 2352835 );
      last_rnd_rbn = WIDTH - 1;
    endfunction
  
/* **** */
  
    function uint32_t FindFirst( input uint32_t max );
      
        for ( int i = max; i >= 0; i-- )
            if ( vect[ i ] == 1'b1 )
                return( uint32_t'( i ) );
      
        return( NOT_FOUND );
      
    endfunction
  
/* **** */
  
  function void SetRR( input uint32_t max_val = this.last_rnd_rbn );
    
    uint32_t masked_rr;
    uint32_t unmasked_rr;
    
    masked_rr = FindFirst( max_val );
    unmasked_rr = FindFirst( WIDTH - 1 );
    
    if ( masked_rr != NOT_FOUND )
      rnd_rbn = masked_rr;
    
    else if ( unmasked_rr != NOT_FOUND )
      rnd_rbn = unmasked_rr;
    
    else
    begin
        $display( "@%t SetRR:  ERROR!  Expected rnd_rbn, but NOT_FOUND", $realtime );
        $finish;
    end
   
    return;
      
    endfunction
  
/* **** */
  
    function void ClearRR();
    
        last_rnd_rbn = rnd_rbn;
        vect = vect & ~( 1 << rnd_rbn );
    
    endfunction
  
/* **** */
  
    function void Show();
    
      $display( "@%t vect = %0h, last_rnd_rbn = %0d, rnd_rbn = %0d",
               $realtime, vect, last_rnd_rbn, rnd_rbn );
    
    endfunction
  
/* **** */
    
  function void AddReq();
    
    uint32_t req;
    
    // don't randomly pick a bit if there's less than four bits to
    // choose from
    if ( WIDTH - rnd_rbn < 5 )
      return;
    
    // request bit should be less than or equal to maximum requestor and
    // greater than last winner
    req = $urandom_range( WIDTH - 1, rnd_rbn + 1 );
    
    if ( vect[ req ] == 0 )
    begin
        vect[ req ] = 1'b1;
        mid_test_reqs++;
    end
    
    $display( "@%t AddReq:  req = %0d, vect = %0h", $realtime, req, vect );
    
  endfunction
  
endclass
      
// =======================================================================

class Agnt #( parameter CLIENTS = 8 );

    mailbox mbxA2D;
    mailbox mbxD2A;
    mailbox mbxA2SB;
    virtual ffs_arbiter_if#(CLIENTS).TB sig_h;
    Vector#(CLIENTS) tc;
    Vector#(CLIENTS) sb_copy;
    uint32_t loops;
    uint32_t MAX_LOOPS = 1;

    function new( mailbox a2d, mailbox d2a, mailbox a2sb, virtual ffs_arbiter_if#(CLIENTS).TB s );
        this.mbxA2D = a2d;
        this.mbxD2A = d2a;
        this.mbxA2SB = a2sb;
        sig_h = s;
    endfunction

    task run();
        tc = new();
      
    forever
    begin
      if ( tc.vect == {CLIENTS{1'b0}} && loops < MAX_LOOPS )
      begin
        assert( tc.randomize() );
        loops++;
      end
      
      else if ( tc.vect == {CLIENTS{1'b0}} && loops == MAX_LOOPS )
        begin
          mbxA2D.put( tc );
          repeat( 10 ) @( sig_h.cb );
          $display( "@%t TEST COMPLETED - PASSED", $realtime );
          $finish;
        end
      
      tc.SetRR();
      sb_copy = new tc;
      $display( "@%t Agnt: tc", $realtime );
      tc.Show();
      mbxA2D.put( tc );
      mbxA2SB.put( sb_copy );
      
      // wait for driver to return
      mbxD2A.get( tc );
      tc.ClearRR();
      
      // with some probability, add upper request bits
      if ( ( $urandom & 3 ) == 0 )
        tc.AddReq();
    end

    endtask

endclass

// =======================================================================

class Driver #( parameter CLIENTS = 10 );

    mailbox mbxA2D;
    mailbox mbxD2A;
    virtual ffs_arbiter_if#(CLIENTS).TB sig_h;

    function new( mailbox a2d, mailbox d2a, virtual ffs_arbiter_if#(CLIENTS).TB s );
        this.mbxA2D = a2d;
        this.mbxD2A = d2a;
        sig_h = s;
    endfunction

    task run();
        Vector#(CLIENTS) tc;
        
        forever
        begin
            mbxA2D.get( tc );
            sig_h.cb.req <= tc.vect;
      
            @( sig_h.cb )
          
            while( sig_h.cb.gnt == 0 )
            begin
                @( sig_h.cb );
            end
          
          $display( "@%t Driver:  gnt asserted for vector = %0h", $realtime, tc.vect );
            mbxD2A.put( tc );
        end

    endtask

endclass

// =======================================================================

class Monitor #( parameter CLIENTS = 4 );

    mailbox mbxM2SB;
    virtual ffs_arbiter_if#(CLIENTS).TB sig_h;

    function new( mailbox m2sb, virtual ffs_arbiter_if#(CLIENTS).TB s );
        this.mbxM2SB = m2sb;
        sig_h = s;
    endfunction

    task run();
        Vector#(CLIENTS) my_rsp;
      
        forever
        begin
            @( sig_h.cb )
            if ( sig_h.cb.gnt != 0 )
            begin
                my_rsp = new();
                my_rsp.vect = sig_h.cb.gnt;
              $display( "@%t Monitor:  my_rsp.vect = %0h", $realtime, my_rsp.vect );
                mbxM2SB.put( my_rsp );
            end
        end

    endtask

endclass

// =======================================================================

class ScoreBoard #( parameter CLIENTS = 4 );

    mailbox mbxA2SB;
    mailbox mbxM2SB;
    virtual ffs_arbiter_if#(CLIENTS).TB sig_h;
    uint32_t cnt;

  function new( mailbox a2sb, mailbox m2sb, virtual ffs_arbiter_if#(CLIENTS).TB s );
        this.mbxA2SB = a2sb;
        this.mbxM2SB = m2sb;
        sig_h = s;
    endfunction

    task run();
      Vector#(CLIENTS) tb;
      Vector#(CLIENTS) dut;
      pf_e chk;
      
      forever
      begin
      	  mbxA2SB.get( tb );
          mbxM2SB.get( dut );
      
          cnt++;
        
        // ensure find-first-set searches whole vector; use functions to
        // figure out which requester DUT has granted
        dut.SetRR( CLIENTS - 1 );
        
           chk = pf_e'( tb.rnd_rbn == dut.rnd_rbn );
        
         if ( chk == PASS )
           $display( "@%t PASS dut == tb == %0d, cnt = %0d, mid_test_reqs = %0d",
                    $realtime, tb.rnd_rbn, cnt, tb.mid_test_reqs );
        
         else
           begin
             $display( "@%t ERROR dut = %0d, tb = %0d, mid_test_reqs = %0d",
                      $realtime, dut.rnd_rbn, tb.rnd_rbn, tb.mid_test_reqs );
             repeat( 10 ) @( sig_h.cb );
             $finish;
           end
      end

    endtask;

endclass

// =======================================================================

class MyEnv #( parameter CLIENTS = 4 );

    Agnt#(CLIENTS) agnt;
    Driver#(CLIENTS) drv;
    Monitor#(CLIENTS) mon;
    ScoreBoard#(CLIENTS) scb;

    mailbox mbxA2D;
    mailbox mbxD2A;
    mailbox mbxA2SB;
    mailbox mbxM2SB;

    function new( virtual ffs_arbiter_if#(CLIENTS).TB s );
        mbxA2D = new();
        mbxD2A = new();
        mbxA2SB = new();
        mbxM2SB = new();

        agnt = new( .a2d( mbxA2D ), .d2a( mbxD2A ), .a2sb( mbxA2SB ), .s( s ) );
        drv = new( .a2d( mbxA2D ), .d2a( mbxD2A ), .s( s ) );
        mon = new( .m2sb( mbxM2SB ), .s( s ) );
        scb = new( .a2sb( mbxA2SB ), .m2sb( mbxM2SB ), .s( s ) );
    endfunction

    task run();
    fork
        agnt.run();
        drv.run();
        mon.run();
        scb.run();
    join_none
    endtask

endclass
