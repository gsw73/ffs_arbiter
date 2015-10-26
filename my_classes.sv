class Vector#( parameter WIDTH = 32 );
  
    rand bit [ WIDTH - 1:0 ] vect;
    uint32_t high_val;
    uint32_t rnd_rbn;
  
/* **** */
  
    function uint32_t FindFirst( input uint32_t max );
    
        for ( uint32_t i = max; i >= 0; i-- )
            if ( vect[ i ] == 1'b1 )
                return( i );
    endfunction
  
/* **** */
  
    function void SetHighVal();
    
        high_val = FindFirst( WIDTH - 1 );
        return;
    
    endfunction
  
/* **** */
  
    function void SetRR();
    
    	rnd_rbn = FindFirst( high_val );
    
    	return;
      
    endfunction
  
/* **** */
  
    function void ClearRR();
    
        vect = vect & ~( 1 << rnd_rbn );
    
    endfunction
  
/* **** */
  
    function void Show();
    
        $display( "vect = %0h, high_val = %0d, rnd_rbn = %0d", vect, high_val, rnd_rbn );
    
    endfunction
  
  
endclass
      
// =======================================================================

class Agnt #( parameter CLIENTS = 8 );

    mailbox mbxA2D;
    mailbox mbxD2A;
    mailbox mbxA2SB;
    virtual ffs_arbiter_if#(CLIENTS).TB sig_h;
    Vector#(CLIENTS) tc;
    Vector#(CLIENTS) rsp;
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
        tc.SetHighVal();
        loops++;
      end
      
      else
      begin
          repeat( 100 ) @( sig_h.cb );
          $finish;
      end
      
      tc.SetRR();
      $display( "@%t Agnt: ", $realtime );
      tc.Show();
      mbxA2D.put( tc );
      mbxA2SB.put( tc );
      
      // wait for driver to return
      mbxD2A.get( rsp );
      rsp.ClearRR();
      
      // start over
      tc = rsp;
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
          $display( "@%t Driver ", $realtime );
          tc.Show();
            sig_h.cb.req <= tc.vect;
      
            @( sig_h.cb )
          
            while( sig_h.cb.gnt == 0 )
                @( sig_h.cb );
          
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
                my_rsp.vect <= sig_h.cb.gnt;
                mbxM2SB.put( my_rsp );
            end
        end

    endtask

endclass

// =======================================================================

class ScoreBoard #( parameter CLIENTS = 4 );

    mailbox mbxA2SB;
    mailbox mbxM2SB;
    uint32_t cnt;

    function new( mailbox a2sb, mailbox m2sb );
        this.mbxA2SB = a2sb;
        this.mbxM2SB = m2sb;
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
          dut.rnd_rbn = dut.FindFirst( CLIENTS - 1 );
        
          chk = pf_e'( tb.rnd_rbn == dut.rnd_rbn );
        
          if ( chk == PASS )
          	  $display( "@%t dut == tb == %h", $realtime, tb.rnd_rbn );
        
          else
              $display( "@%t ERROR dut = %h, tb = %b", $realtime, dut.rnd_rbn, tb.rnd_rbn );
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
        scb = new( .a2sb( mbxA2SB ), .m2sb( mbxM2SB ) );
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
