/**
* Name: cars
*  
* Author: Tri Nguyen-Huu, Patrick Taillandier
* 
* Generate car traffic using driving skill. Cars follow a simple network with intersections and traffic lights. 
* 
* Contains the following species: 
* - car
* - road
* - intersection
* - traffic_signal
*/


model cars


global{
	float car_spawning_interval <- 5#s;
	float global_max_speed <- 40 #km / #h;
	
	int schedule_step <- 0;
	float schedule_time <- 0.0;
	float time_to_clear_crossing <- 0.0;
	float percent_time_remaining <- (schedule_times[0] )/(schedule_times[5] + schedule_times[0] - schedule_times[1]);
	float time_since_last_spawn <- 0.0;
	
	list<string> carModels;
	list<string> carModelsb;

	// traffic lights cycle schedule (based on observations)
	list<float> schedule_times <- [ 15#s, // pedestrian light to green
									60#s, // pedestrian light to red
									85#s, // car group 1 to green
									100#s,// car group 1 to red
									105#s,// car group 2 to green
									120#s // car group 2 to red
								  ];	
	
	shape_file road_shape_file <- shape_file("../includes/roads.shp");
	graph road_network;	
	
//	map<rgb,int> palette <- [
//		rgb(246, 229, 141)::1,
//		rgb(249, 202, 36)::1,
//		rgb(126, 214, 223)::1,
//		rgb(34, 166, 179)::1,
//		rgb(255, 190, 118)::1,
//		rgb(240, 147, 43)::1,
//		rgb(255, 121, 121)::1,
//		rgb(235, 77, 75)::1,
//		rgb(104, 109, 224)::1,
//		rgb(72, 52, 212)::1,
//		rgb(186, 220, 88)::1,
//		rgb(106, 176, 76)::1,
//		rgb(48, 51, 107)::1,
//		rgb(19, 15, 64)::1,
//		rgb(149, 175, 192)::1,
//		rgb(83, 92, 104)::1
//	];

	map<rgb,int> palette <- [
		rgb(249, 202, 36)::1,
		rgb(240, 147, 43)::1,
		rgb(235, 77, 75)::1,
		rgb(106, 176, 76)::1,
		rgb(126, 214, 223)::1,
		rgb(224, 86, 253)::1,
		rgb(104, 109, 224)::1,
		rgb(48, 51, 107)::1,
		rgb(34, 166, 179)::1,
		rgb(190, 46, 221)::1,
		rgb(72, 52, 212)::1,
		rgb(26, 188, 156)::1,
		rgb(46, 204, 113)::1,
		rgb(52, 152, 219)::1,
		rgb(41, 128, 185)::1,
		rgb(241, 196, 15)::1,
		rgb(230, 126, 34)::1,
		rgb(231, 76, 60)::1,
		rgb(236, 240, 241)::1,
		rgb(243, 156, 18)::1,
		rgb(211, 84, 0)::1,
		rgb(192, 57, 43)::1,
		rgb(113, 128, 147)::1,
		rgb(245, 246, 250)::1,
		rgb(232, 65, 24)::1,
		rgb(39, 60, 117)::1,
		rgb(76, 209, 55)::1,
		rgb(235, 47, 6)::1,
		rgb(30, 55, 153)::1
	];
	
	
	init{

		//create the roads
		create road from: road_shape_file with: [group::int(get("group"))];
		ask road {
			point p <- last(shape.points);
			if length(intersection where (each.location = p))=0{
				create intersection{
					location <- p;
					group <- myself.group;
				}
			}
		}
		
		// create spawn intersections and the corresponding destination
		ask road where (each.group > 0){
			create intersection{
				location <- first(myself.shape.points);
				color <- #blue;
				is_spawn_location <- true;
			}
		}
		
		// create the driving skill graph from the road graph
		road_network <- as_driving_graph(road,intersection);
		
		// initialize intersections with possible destinations
		ask intersection where (each.group > 0) {
			do initialize;
		}
		
		ask intersection where (each.is_spawn_location){
			final_intersection <- compute_target();
		}
		
		// spawn cars at initialization
		loop times: 12{
			do spawn_car;
		}
		
		
	}
	
	// spawn one car on the edge of the map
	action spawn_car{
		intersection i <- one_of(intersection where (each.is_spawn_location));
		create car with: (location: i.location, target: i.final_intersection);
	}
	
	// spawn cars at given time intervals
	reflex car_scheduler{
		if time_since_last_spawn > car_spawning_interval {
			do spawn_car;
			time_since_last_spawn <- 0.0;
		}else{
			time_since_last_spawn <- time_since_last_spawn + step;
		}
	}
}

/* species declarations */

species road skills: [road_skill]{
	int group;
	int num_lanes <- 1;
	float maxspeed <- global_max_speed;
	
	aspect default {
		draw shape color: #red;
	}
}


species car skills: [driving] {
//	rgb color <- rnd_color(255);
	rgb color <- rnd_choice(palette);
	rgb color2;
	intersection target;
	string type <- "car" among: ["car","truck"];
	int version;
	obj_file carBody;
	obj_file carOtherParts;
	obj_file carOtherPartsBraking;
	
	// randomly choose one type of car when spawned
	init {
		type <- rnd_choice(["car"::0.9,"truck"::0.1]);
		version <- rnd(length(carModels)-1);
		switch type {
			match "car"{
				vehicle_length <- 5 #m;
				carBody <- obj_file("../includes/obj/CarBody.obj");
				carOtherParts <- obj_file("../includes/obj/CarOthers.obj");
				carOtherPartsBraking <- obj_file("../includes/obj/CarOthersBraking.obj");
			}
			match "truck"{
				vehicle_length <- 8.0 #m;
				color2 <- rnd_color(180,255);
			}
		}
		max_speed <- global_max_speed;
	}
	
	//choose a random target and compute the path to it
	reflex choose_path when: final_target = nil {
		do compute_path graph: road_network target: target; 
	}
	
	// move along the graphe using the driving skill
	reflex move when: final_target != nil {
		do drive;
		//if arrived at target, die and create a new car
		if (final_target = nil) {
			do unregister;
			do die;
		}
	}
	
	// cars 3d models (car and truck)
	aspect kawai {
		if (current_road != nil) {
			switch type{
				match "car"{
//					if acceleration > 0{
//						draw obj_file(carModels[version])  at: location+{0,0,0.7} size: 1.5  
//						rotate: rotation_composition(-90::{1,0,0},heading+90::{0,0,1}) ;	
//					}else{
//						draw obj_file(carModelsb[version])  at: location+{0,0,0.7} size: 1.5   
//						rotate: rotation_composition(-90::{1,0,0},heading+90::{0,0,1}) ;	
//					}	
					if acceleration > 0{	
						draw carOtherParts  at: location+{0,0,0.93} size: 2  rotate: pair<float,point>(rotation_composition(-90::{1,0,0},heading+90::{0,0,1}) );	
					}else{
						draw carOtherPartsBraking  at: location+{0,0,0.93} size: 2  rotate: pair<float,point>(rotation_composition(-90::{1,0,0},heading+90::{0,0,1}) );						
					}
					draw carBody  at: location+{0,0,1.26} size: 2 color: color rotate: rotation_composition(-90::{1,0,0},heading+90::{0,0,1}) ;	
					draw rectangle(1.9#m,3.9#m) at: location+{0,0,0.01} color: rgb(50,50,50,0.3) rotate: heading+90::{0,0,1};
				}
				match "truck"{
					draw rectangle(7.8#m, 1.9#m ) depth: 0.2#m color: color rotate: heading at: location+{0,0,0.3#m};	
					draw (circle(0.4#m)rotated_by(90::{1,0,0})) rotate: heading  color: #black depth: 0.3#m at: location + {0,0,0.4} + ({3#m,0.7,0} rotated_by (heading::{0,0,1}));
					draw (circle(0.4#m)rotated_by(90::{1,0,0})) rotate: heading  color: #black depth: 0.28#m at: location +  {0,0,0.4} + ({-2#m,0.7,0} rotated_by (heading::{0,0,1}));
					draw (circle(0.4#m)rotated_by(-90::{1,0,0})) rotate: heading  color: #black depth: 0.3#m at: location +  {0,0,0.4} + ({3#m,-0.7,0} rotated_by (heading::{0,0,1}));
					draw (circle(0.4#m)rotated_by(-90::{1,0,0})) rotate: heading  color: #black depth: 0.28#m at: location +  {0,0,0.4} + ({-2#m,-0.7,0} rotated_by (heading::{0,0,1}));
					draw rectangle(1.7#m, 1.9#m ) depth: 0.9#m color: color rotate: heading at: location+({3.05,0,0.3#m} rotated_by (heading::{0,0,1}));	
					draw (triangle(0.6#m,0.66#m)rotated_by(-90::{1,0,0})) rotate: heading  color: #black depth: 1.8#m at: location +  {0,0,1.4} + ({3.57#m,0.9,0} rotated_by (heading::{0,0,1}));
		 			draw (square(0.05#m)rotated_by(-24::{0,1,0})) rotate: heading  color: color depth: 0.72#m at: location +  {0,0,1.18} + ({3.87#m,0.9,0} rotated_by (heading::{0,0,1}));
		 			draw (square(0.05#m)rotated_by(-24::{0,1,0})) rotate: heading  color: color depth: 0.72#m at: location +  {0,0,1.18} + ({3.87#m,-0.9,0} rotated_by (heading::{0,0,1}));
		 			draw rectangle(1.4#m, 1.85#m ) depth: 0.05#m color: color rotate: heading at: location+{0,0,1.8#m}+ ({2.9#m,0,0} rotated_by (heading::{0,0,1}));	
	 				draw rectangle(1#m, 1.8#m ) depth: 0.6#m color: #black rotate: heading at: location+{0,0,1.2}+ ({2.9#m,0,0} rotated_by (heading::{0,0,1}));	
	 				draw rectangle(0.5#m, 1.85#m ) depth: 0.6#m color: color rotate: heading at: location+{0,0,1.2}+ ({2.45#m,0,0} rotated_by (heading::{0,0,1}));	
	 				draw rectangle(6#m, 2#m ) depth: 2.2#m color: color2 rotate: heading at: location+{0,0,0.2}+ ({-0.95#m,0,0} rotated_by (heading::{0,0,1}));	
				}
			}
  		}
	}
	
	
	
	aspect default {
		if (current_road != nil) {
			switch type{
				match "car"{
					draw rectangle(3.8#m, 1.7#m ) depth: 0.7#m color: color rotate: heading at: location+{0,0,0.2#m};
					draw (circle(0.3#m)rotated_by(90::{1,0,0})) rotate: heading  color: #black depth: 0.3#m at: location + {0,0,0.3} + ({1#m,0.6,0} rotated_by (heading::{0,0,1}));
					draw (circle(0.3#m)rotated_by(90::{1,0,0})) rotate: heading  color: #black depth: 0.3#m at: location +  {0,0,0.3} + ({-1#m,0.6,0} rotated_by (heading::{0,0,1}));
					draw (circle(0.3#m)rotated_by(-90::{1,0,0})) rotate: heading  color: #black depth: 0.3#m at: location +  {0,0,0.3} + ({1#m,-0.6,0} rotated_by (heading::{0,0,1}));
					draw (circle(0.3#m)rotated_by(-90::{1,0,0})) rotate: heading  color: #black depth: 0.3#m at: location +  {0,0,0.3} + ({-1#m,-0.6,0} rotated_by (heading::{0,0,1}));
					draw (triangle(0.5#m,0.5#m)rotated_by(-90::{1,0,0})) rotate: heading  color: #black depth: 1.6#m at: location +  {0,0,1} + ({-1#m,0.8,0} rotated_by (heading::{0,0,1}));
					draw (triangle(1#m,0.5#m)rotated_by(-90::{1,0,0})) rotate: heading  color: #black depth: 1.6#m at: location +  {0,0,1} + ({0.6#m,0.8,0} rotated_by (heading::{0,0,1}));
					draw (square(0.05#m)rotated_by(26::{0,1,0})) rotate: heading  color: color depth: 0.52#m at: location +  {0,0,0.87} + ({-1.22#m,0.8,0} rotated_by (heading::{0,0,1}));
		 			draw (square(0.05#m)rotated_by(26::{0,1,0})) rotate: heading  color: color depth: 0.52#m at: location +  {0,0,0.87} + ({-1.22#m,-0.8,0} rotated_by (heading::{0,0,1}));
		 			draw (square(0.05#m)rotated_by(-45::{0,1,0})) rotate: heading  color: color depth: 0.65#m at: location +  {0,0,0.87} + ({1.08#m,0.8,0} rotated_by (heading::{0,0,1}));
		 			draw (square(0.05#m)rotated_by(-45::{0,1,0})) rotate: heading  color: color depth: 0.65#m at: location +  {0,0,0.87} + ({1.08#m,-0.8,0} rotated_by (heading::{0,0,1}));
		 			draw rectangle(1.65#m, 1.65#m ) depth: 0.05#m color: color rotate: heading at: location+{0,0,1.3#m}+ ({-0.19#m,0,0} rotated_by (heading::{0,0,1}));	
		 			draw rectangle(1.65#m, 1.6#m ) depth: 0.4#m color: #black rotate: heading at: location+{0,0,0.9#m}+ ({-0.19#m,0,0} rotated_by (heading::{0,0,1}));	
					draw (square(0.05#m)rotated_by(3::{1,0,0})) rotate: heading  color: color depth: 0.47#m at: location +  {0,0,0.87} + ({-0.4#m,0.825,0} rotated_by (heading::{0,0,1}));
		 			draw (square(0.05#m)rotated_by(-3::{1,0,0})) rotate: heading  color: color depth: 0.47#m at: location +  {0,0,0.87} + ({-0.4#m,-0.825,0} rotated_by (heading::{0,0,1}));			
				}
				match "truck"{
					draw rectangle(7.8#m, 1.9#m ) depth: 0.2#m color: color rotate: heading at: location+{0,0,0.3#m};	
					draw (circle(0.4#m)rotated_by(90::{1,0,0})) rotate: heading  color: #black depth: 0.3#m at: location + {0,0,0.4} + ({3#m,0.7,0} rotated_by (heading::{0,0,1}));
					draw (circle(0.4#m)rotated_by(90::{1,0,0})) rotate: heading  color: #black depth: 0.28#m at: location +  {0,0,0.4} + ({-2#m,0.7,0} rotated_by (heading::{0,0,1}));
					draw (circle(0.4#m)rotated_by(-90::{1,0,0})) rotate: heading  color: #black depth: 0.3#m at: location +  {0,0,0.4} + ({3#m,-0.7,0} rotated_by (heading::{0,0,1}));
					draw (circle(0.4#m)rotated_by(-90::{1,0,0})) rotate: heading  color: #black depth: 0.28#m at: location +  {0,0,0.4} + ({-2#m,-0.7,0} rotated_by (heading::{0,0,1}));
					draw rectangle(1.7#m, 1.9#m ) depth: 0.9#m color: color rotate: heading at: location+({3.05,0,0.3#m} rotated_by (heading::{0,0,1}));	
					draw (triangle(0.6#m,0.66#m)rotated_by(-90::{1,0,0})) rotate: heading  color: #black depth: 1.8#m at: location +  {0,0,1.4} + ({3.57#m,0.9,0} rotated_by (heading::{0,0,1}));
		 			draw (square(0.05#m)rotated_by(-24::{0,1,0})) rotate: heading  color: color depth: 0.72#m at: location +  {0,0,1.18} + ({3.87#m,0.9,0} rotated_by (heading::{0,0,1}));
		 			draw (square(0.05#m)rotated_by(-24::{0,1,0})) rotate: heading  color: color depth: 0.72#m at: location +  {0,0,1.18} + ({3.87#m,-0.9,0} rotated_by (heading::{0,0,1}));
		 			draw rectangle(1.4#m, 1.85#m ) depth: 0.05#m color: color rotate: heading at: location+{0,0,1.8#m}+ ({2.9#m,0,0} rotated_by (heading::{0,0,1}));	
	 				draw rectangle(1#m, 1.8#m ) depth: 0.6#m color: #black rotate: heading at: location+{0,0,1.2}+ ({2.9#m,0,0} rotated_by (heading::{0,0,1}));	
	 				draw rectangle(0.5#m, 1.85#m ) depth: 0.6#m color: color rotate: heading at: location+{0,0,1.2}+ ({2.45#m,0,0} rotated_by (heading::{0,0,1}));	
	 				draw rectangle(6#m, 2#m ) depth: 2.2#m color: color2 rotate: heading at: location+{0,0,0.2}+ ({-0.95#m,0,0} rotated_by (heading::{0,0,1}));	
				}
			}
  		}
	}
}




species intersection skills: [intersection_skill] {
	bool is_traffic_signal <- false;
	bool is_spawn_location <- false;
	int group;
	intersection final_intersection <- nil;
	rgb color <- #white;

	//register the roads coming from both direction (for traffic light)
	list<road> ways;
	
	//if the traffic light is green
	bool is_green;
	string current_color <- "red";

	// aspects for debug
	aspect debug{
		draw circle(0.5) color: color;
	}
	
	// initialize and set the light to red
	action initialize{
		is_traffic_signal <- true;
		stop << [];
		loop rd over: roads_in {
			ways << road(rd);
		}
		do to_red;
	}
	
	// compute the last accessible intersection (destination)
	intersection compute_target{
		if empty(roads_out){
			return self;
		}else{
			return intersection(road(first(roads_out)).target_node).compute_target();
		}
	}
	
	// turn the car light to green
	action to_green {
		stop[0] <- [];
		is_green <- true;
		color <- #green;
		current_color <- "green";
	}
	
	// turn the car light to orange
	action to_orange{
		current_color <- "orange";
	}

	// turn the car light to red
	action to_red {
		stop[0] <- ways;
		is_green <- false;
		current_color <- "red";
		color <- #red;
	}
}


// 3d model of the traffic signal, with lights for cars and pedestrians
species traffic_signal{
	int group;
	int crosswalk_left;
	int crosswalk_right;
	float heading_l;
	float heading_r;
	int direction_crosswalk;
	string car_light <- "normal";
	string current_color <- "red";
	float light_z <- 5.5#m;
	float light_x <- 3.5#m;
	float t_x <- 1.4#m;
	float t_z <- 3.8#m;
	float heading;

	//find the light color of the corresponding intersection on the road network
	reflex find_color{
		current_color <- first(intersection where (each.group = self.group)).current_color;
	}
	
	// draws the pedestrian traffic light
	action draw_box(string side, float hdg){
		int s<- side="left"?1:-1;
		draw square(0.06#m) rotated_by(-90,{0,1,0}) depth: t_x at: location+{0,0,t_z} rotate: hdg+s*90 color: #grey;
		draw rectangle(0.6,0.15) depth: 1.2 at: location+({0,s*t_x,t_z-1.27} rotated_by (hdg::{0,0,1})) rotate: hdg+s*90 color: #grey;
		draw square(0.06) depth: 0.05 at: location+({0,s*(t_x-0.03),t_z-0.08} rotated_by (hdg::{0,0,1})) rotate: hdg+s*90 color: #grey;		
		loop i over: [-1,1]{
			draw rectangle(0.12,0.02) depth: 0.4*world.percent_time_remaining 
				at: location+({0.07,s*t_x+i*0.16,t_z-(world.schedule_step=1?1:2)*0.61} rotated_by (hdg::{0,0,1})) 
				rotate: hdg+90 color: (world.schedule_step=1)?#green:#red;
		}	
		if world.schedule_step = 1{
			draw triangle(0.3,0.4) rotated_by(-90,{1,0,0}) at: location+({0.08,s*t_x,t_z-1.05} rotated_by (hdg::{0,0,1})) 
				rotate: hdg+90 color: #green;
			draw circle(0.1) rotated_by(-90,{1,0,0}) at: location+({0.08,s*t_x,t_z-0.8} rotated_by (hdg::{0,0,1})) 
				rotate: hdg+90 color: #green;	
		}else{
			draw triangle(0.3,0.4) rotated_by(-90,{1,0,0}) at: location+({0.08,s*t_x,t_z-0.5} rotated_by (hdg::{0,0,1})) 
				rotate: hdg+90 color: #red;
			draw circle(0.1) rotated_by(-90,{1,0,0}) at: location+({0.08,s*t_x,t_z-0.25} rotated_by (hdg::{0,0,1})) 
				rotate: hdg+90 color: #red;
		}	
	}
	

	
	aspect default{
		// draw the pole
		draw circle(0.2#m) depth: light_z+1#m color: #grey;
		// draw the car lights
		if car_light != "none"{
			draw circle(0.1#m) rotated_by(-90,{0,1,0}) depth: light_x at: location+{0,0,light_z} rotate: heading color: #grey;
		}
		if (car_light = "normal" or car_light = "both"){
			draw rectangle(3,0.35) depth: 0.8#m at: location+({light_x,0.1,light_z-0.4} rotated_by (heading::{0,0,1})) 
				rotate: heading color: #grey;
			draw sphere(0.3#m) at: location+({light_x-0.9,0.25,light_z-0.3} rotated_by (heading::{0,0,1}))
				color: current_color="green"?#green:rgb(100,100,100);
			draw sphere(0.3#m) at: location+({light_x,0.25,light_z-0.3} rotated_by (heading::{0,0,1}))
				color: current_color="orange"?#orange:rgb(100,100,100);
			draw sphere(0.3#m) at: location+({light_x+0.9,0.25,light_z-0.3} rotated_by (heading::{0,0,1}))
				color: current_color="red"?#red:rgb(100,100,100);			
		}
		if (car_light = "reverse" or car_light = "both"){
			draw rectangle(3,0.35) depth: 0.8#m at: location+({light_x,-0.1,light_z-0.4} rotated_by (heading::{0,0,1})) 
				rotate: heading color: #grey;
			draw sphere(0.3#m) at: location+({light_x-0.9,-0.25,light_z-0.3} rotated_by (heading::{0,0,1}))
				color: current_color="green"?#green:rgb(100,100,100);
			draw sphere(0.3#m) at: location+({light_x,-0.25,light_z-0.3} rotated_by (heading::{0,0,1}))
				color: current_color="orange"?#orange:rgb(100,100,100);
			draw sphere(0.3#m) at: location+({light_x+0.9,-0.25,light_z-0.3} rotated_by (heading::{0,0,1}))
				color: current_color="red"?#red:rgb(100,100,100);			
		}	
		//draw left pedestrian crossing signal
		if crosswalk_left > 0{
			do draw_box("left", heading_l);
		}	
		//draw right pedestrian crossing signal
		if crosswalk_right > 0{
			do draw_box("right", heading_r);
		}
	}
	
}



