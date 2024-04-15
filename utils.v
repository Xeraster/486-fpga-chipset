//tested working
module mux_2to1 (i0,i1,sel,out);
	input i0,i1,sel;
	output reg out;
	always@(i0,i1,sel)
	begin
		if(sel)
			out = i1;
		else
			out = i0;
	end
endmodule

//make a 4 to 1 mux out of 2 to 1 mux.
//tested working
module mux_4to1 (i0,i1,i2,i3,s1,s0,out);
	input i0,i1,i2,i3,s0,s1;
	output out;
	wire x1,x2;

	mux_2to1 m1 (i0,i1,s1,x1);
	mux_2to1 m2 (i2,i3,s1,x2);
	mux_2to1 m3 (x1,x2,s0,out);
endmodule

//enable is active high
//tested working
module decoder_2to4_w_enable (a0, a1, d0, d1, d2, d3, en);
    input a0, a1, en;
    output reg d0, d1, d2, d3;
    always@(a0, a1, en)
    begin
        //if(en)
		d0<=(~a0 & ~a1 & en);
		d1<=(a0 & ~a1 & en);
		d2<=(~a0 & a1 & en);
		d3<=(a0 & a1 & en);
    end
endmodule

//tested working
module decoder_3to8 (a, b, c, o0, o1, o2, o3, o4, o5, o6, o7);
	input a, b, c;
	output reg o0, o1, o2, o3, o4, o5, o6, o7;

	//uuh, the 2 working examples i have of modules contain @always, so throw that in there
	always@(a, b, c)
	//as dumb as it is, this is smaller than all the other ways i found of doing this by a huge margin
	begin
		o0 = (~a & ~b & ~c); //000
		o1 = (~a & ~b & c);	//001
		o2 = (~a & b & ~c);	//010
		o3 = (~a & b & c);	//011
		o4 = (a & ~b & ~c);	//100
		o5 = (a & ~b & c);	//101
		o6 = (a & b & ~c);	//110
		o7 = (a & b & c);	//111
	end
endmodule

//testted working
//G=enable (active high). D=data in
module d_latch(Q, Qn, G, D);
   output Q;
   output Qn;
   input  G;   
   input  D;

   wire   Dn; 
   wire   D1;
   wire   Dn1;

   not(Dn, D);   
   and(D1, G, D);
   and(Dn1, G, Dn);   
   nor(Qn, D1, Q);
   nor(Q, Dn1, Qn);
endmodule

//tested working
module d3_latch(d0, d1, d2, q0, q1, q2, G);
    input d0, d1, d2, G;
    output q0, q1, q2;

    //hopefully it will be smart enough to define out this stuff
    wire dummy0, dummy1, dummy2;

    //a d4 latch is can be made up of 4 d_latch modules
    d_latch dl0(q0, dummy0, G, d0);
    d_latch dl1(q1, dummy1, G, d1);
    d_latch dl2(q2, dummy2, G, d2);
endmodule

//tested working
module d4_latch(d0, d1, d2, d3, q0, q1, q2, q3, G);
    input d0, d1, d2, d3, G;
    output q0, q1, q2, q3;

    //hopefully it will be smart enough to define out this stuff
    wire dummy0, dummy1, dummy2, dummy3;

    //a d4 latch is can be made up of 4 d_latch modules
    d_latch dl0(q0, dummy0, G, d0);
    d_latch dl1(q1, dummy1, G, d1);
    d_latch dl2(q2, dummy2, G, d2);
    d_latch dl3(q3, dummy3, G, d3);

endmodule