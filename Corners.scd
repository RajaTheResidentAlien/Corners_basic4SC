(		/*<-Double-Click just after opening Parentheses or Select All and Execute*/

Server.default = Server.local;

s = Server.default;

m = MonomeGrid.new(rotation:0, prefix: "/box", fps: 60);

~pulsbus = Bus.control(s, 1);
~panbus = Bus.control(s, 1);
~modfreqbus = Bus.control(s, 1);    //<-control busses map ball's constant movement to synth args
~indexbus = Bus.control(s, 1);
~outbus = Bus.control(s, 1).set(0);

~fx = 3.collect({Bus.audio(s, 2)});  //<-audio busses allow for dynamic fx routing

~tmpclck = TempoClock.default.tempo_(50);

					/*____GrainFM SOUND SOURCE SYNTHDEF____*/

SynthDef(\corner_synth, { | puls, freq, pan, modfreq, index, out |

	var env = Env.perc(0.001, 2, 1, -16);
	var envgen = EnvGen.ar(env, T2A.ar(\trygr.tr), doneAction: 2);

	var grain = GrainFM.ar(2, Impulse.kr(puls), 0.1, freq-500/200*5.5, modfreq, index, pan, -1);
				//^ball's movement mapped to GrainFM's args(carr, mod, index, pan)

� � Out.ar(out, grain.tanh * envgen);

}).load(s);

						/*____FX SYNTHDEFS____*/

SynthDef(\reverb, {| noff |    //<-noff args in fx synthdefs triggered by number of buttons pressed
												                 //at the same time
		var receive = In.ar(~fx[0].index, 2);
		var input = FreeVerb.ar(receive, 1, 1, 0.8, 0.5);
		var send = Mix.ar([receive*Lag.ar(K2A.ar((1-noff)), 0.1),input*Lag.ar(K2A.ar(noff),0.1)]);
		                                         //^\reverb on = 100%wet, off = 100%dry

		Out.ar(~fx[1].index, send.tanh);

}).load(s);

SynthDef(\comber, {| noff |

		var clocktime = ~tmpclck.tempo;
		var freqsteppa = 1/(TIRand.kr(1, 16, \trygr.tr));   //<-choose new delay time
												//each time ball hits/crosses a boundary
		var receive = In.ar(~fx[1].index, 2);
		var input =
			CombN.ar(receive*1.2, 4,
			Lag.kr(freqsteppa*clocktime*0.001*2, 1), Lag.kr(freqsteppa*3, 1)) * Lag.kr(noff, 0.1);
		var send = Mix.ar([receive, input]);

		Out.ar(~fx[2].index, send.tanh);

		}).load(s);

SynthDef(\tapdelay, {| noff |

		var time = ~tmpclck.beatDur*8;
		var trig = T2A.ar(\trygr.tr);  //<-sharper/more-accurate audio-rate trigger

		var trigdel = TDelay.ar(trig, 0.01);
		var nrffenv = Env([1,0,0,1],[0.005, 0.01, 0.005], 'sine');//<-duck signal for delay change
		var nrff = EnvGen.ar(nrffenv, trig);


		var receiveL = In.ar(~fx[2].index, 1);
		var receiveR = In.ar(~fx[2].index+1, 1);
		var timeL = TIRand.kr(1,8,trigdel)/2; //<-choose delay time same as with \comber
		var timeR = TIRand.kr(1,8,trigdel)/2; //but delayed until after signal-ducking the change
		var dryL = receiveL * nrff;           //to reduce clicks/speed-change surges
		var dryR = receiveR * nrff;

		var inputL = AllpassC.ar(dryL, 4, Lag.kr(time * timeL,0.004), Lag.kr(timeL,0.004));
		var inputR = AllpassC.ar(dryR, 4, Lag.kr(time * timeR,0.004), Lag.kr(timeL,0.004));
								//^different delay times for left and right channels
		var send = Mix.ar([
						[inputL*Lag.ar(K2A.ar(noff),0.01), inputR*Lag.ar(K2A.ar(noff),0.01)],
						[receiveL, receiveR]
					    ]);					//<-mix stereo delay with stereo input

		Out.ar(0, send.tanh);

		}).load(s);

						/*____MAIN EXECUTION____*/

s.waitForBoot({



var hier = Group.new(s, 'addToHead');//<-instead of 1 Group 'hier',
						//could've just used server (or 's'), but just to introduce the idea�
var fx1 = Synth(\reverb, target: hier, addAction: 'addToTail');
var fx2 = Synth(\comber, target: fx1, addAction: 'addAfter');     //<-'AddTo..' messages specify
var fx3 = Synth(\tapdelay, target: fx2, addAction: 'addAfter');   //FX should come after synths

var createsynthfunc = {Synth(\corner_synth,
        				[puls: ~pulsbus.asMap, pan: ~panbus.asMap,
        				 freq: ~modfreqbus.asMap, modfreq: ~modfreqbus.asMap,
        				 index: ~indexbus.asMap, out: ~outbus.asMap, trygr: 1], hier, 'addToHead')};
        				 	//'addToHead' message always creates synths before FX nodes on server

var uipoint = Point(0,-1);    //<-Point object also useful for monome coords, but here...
var uiback = Color.red(0.25); 	//just used to draw 'reflections' toggles in diamond-pattern

var msgin1 = "/box/grid/key";

var dx = 0;					//<-most of this variable list is the same as in corners.js
var dy = 0;
var bx, by;
var keys = 0;
var ref, viz, fric, grr;

r = Array.fill(4, {1});
p = Array.fill(256, {0});
x = 0; y = 0; g = 100; f = 0.95;

m.connect(0);	   //<-need to pick which monome device we're using(out of all connected)...
bx = m.rows - 0.5;    //<-...before we have access..
by = m.cols - 0.5;	  //..to the '.rws' and '.cls' methods



OSCFunc.newMatching(
	{ arg msg, time, addr, rcvprt;

	p[msg[1] + (msg[2]*16)] = msg[3];  //<-same as "function point" from corners.js

		}, msgin1);



w = Window.new("Synth_Corners", Rect(500, 680, 290, 220)).background_(Color.cyan(0.2));


fric = Slider(w, Rect(20, 20, 180, 20)).background_(uiback)
			.action_({|sli| f = (((1-sli.value)*200)+800)/1000})
			.valueAction_(0.05);
							 //^same as "function fric" from corners.js (but with UI drawn)

StaticText(w, Rect(205, 20, 80, 20)).string_("<-Friction").stringColor_(Color.white);

grr = Slider(w, Rect(20, 50, 180, 20)).background_(uiback)
			.action_({|sli| g = ((1-sli.value)*1000) + 4}).valueAction_(0.95);
			 				//^same as "function grr" from corners.js (but with UI�)

StaticText(w, Rect(205, 50, 80, 20)).string_("<-Gravity").stringColor_(Color.white);

StaticText(w, Rect(35, 80, 80, 20)).string_("Visualized:").stringColor_(Color.white);
StaticText(w, Rect(175, 100, 80, 20)).string_("Reflections:").stringColor_(Color.white);

ref = 4.collect({ |i|        //<-draws reflection boxes in diamond-shape pattern using Point object
	Button(w, Rect(			//to draw each, mathematically rotated, around a center point
	(uipoint.rotate(((i+1)/4)*2pi).x*20)+200, 		//<-See Point helpfile,...
	(uipoint.rotate(((i+1)/4)*2pi).y*20)+145, 20, 20) ) //..'.rotate' is in radians(0 to 2pi)
� � � � .states_([
� � � � � � ["", Color.white, Color.black],
� � � � � � ["", Color.black, Color.white],
� � � � � � ]).action_({|rf| r[i]=rf.value}).valueAction_(1)
			 });		        //^same as "function ref" from corners.js



viz = Slider2D(w, Rect(20, 100, 100, 100))
		.background_(Color.red(0.30)).acceptsMouse_(false).canFocus_(false);
		                   //^same as the visualization 'pictslider' in the corners max patch

w.front;

t = Task({			//<-This task is the same as "function bang" from corners.js...
	inf.do{|i|		//...but with synths triggered and their parameters directly controlled
	keys = 0;
    for(0,15,{|i1|
		for(0,15,{|i2|
        		if(p[i1+(i2*16)] == 1)
        		  {
            	   dx = (dx + (i1 - x + 0.5 / g)).clip(-1,1);
            	   dy = (dy + (i2 - y + 0.5 / g)).clip(-1,1);
		   	   keys=keys+1;
		   	   case {keys==2}       //<-case routes dry to fx based on multiple button presses
		   	   			{~outbus.set(~fx[2].index); fx3.set("noff", 1);} //2=delay
		   		   {keys==3}
		   		   		{~outbus.set(~fx[1].index); fx2.set("noff", 1);} //3=delay->comb
		   		   {keys==4}
		   		   		{~outbus.set(~fx[0].index); fx1.set("noff", 1);} //4=delay->comb->rvrb
		   	   {~outbus.set(0); fx1.set("noff", 0); fx2.set("noff", 0); fx3.set("noff",0);};
        		};		//^last line of a case sets function for all 'other' cases(0 or 1)
   		   });
       });

    dx = dx * f;
    dy = dy * f;

    x = x + dx;
    y = y + dy;

    case {x>bx} //<-case just as efficient as 'if' statements(search 'Control Structures' in help)
	    			{
        			if(r[0]==1, { dx = dx.neg; x = bx; }, { x = x - bx; });
        			createsynthfunc.value; fx1.set(\trygr,1); fx2.set(\trygr,1); //<-trigger change�
    				}     //^'createsynthfunc.value explained in online tutorial
    		{x<0}
    				{
        			if(r[2]==1, { dx = dx.neg; x = 0; }, { x = x + bx; });
        			createsynthfunc.value; fx1.set(\trygr,1); fx2.set(\trygr,1); //...in effects'...
    				}
 		{y>by}
				{
        			if(r[1]==1, { dy = dy.neg; y = by; }, { y = y - by; });
        			createsynthfunc.value; fx1.set(\trygr,1); fx2.set(\trygr,1); //...delay times...
    				}
    		{y<0}
        			{
	        		if(r[3]==1, { dy = dy.neg; y = 0; }, { y = y + by; });
        			createsynthfunc.value; fx1.set(\trygr,1); fx2.set(\trygr,1); //when ball
    				};							                            //hits boundaries.

    m.all(0);             //<-same as in corners max patch, turn off all leds(clears previous)
    m.ledset(x, y, 1);      //<-turn on led at current coordinate
    r{ viz.x = x/m.rows; viz.y = 1-(y/m.cols); }.play(AppClock);   //<-set UI 'Visualization:'

    ~pulsbus.set( ((1-(y/m.cols))*50)+10 );      //<-set control busses which synth args...
    ~panbus.set( ((x/m.rows)*2)-1 );					//...are mapped to upon synth creation
    ~pulsbus.get({|fr| ~modfreqbus.set( (dx*20)+(fr+80)*4.rand ) });
    ~indexbus.set( (dy * 19) + 2);

	1.wait;
	};
}, ~tmpclck).play;    //<-play task on the TempoClock(set above to tempo:50bps)...
												//...same as 'metro 20' in Max

w.onClose_{t.stop;
		  hier.free;
		  ~pulsbus.free;				//when user closes UI window
		  ~panbus.free;				//perform garbage collection & shutdown:
		  ~modfreqbus.free;	//stop clock, free synths & busses, turn-off-leds/free-monome
		  ~indexbus.free;
		  3.do({|i| ~fx[i].free});
		  ~outbus.free;
		  m.cleanup;
		 };

});
)