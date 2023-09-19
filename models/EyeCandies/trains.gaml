/**
* Name: EyeCandies
*  
* Author: Tri Nguyen-Huu, Patrick Taillandier
* Includes several species used for trains as eye candies
* 
* Species:
* - rail: railroad segments
* - rail_wp: railroad waypoints or intersections
* - train
* - carriage
* - rolling_stock: generic species for train and carriage, used for the train 3d models
*
*
*/

model trains

global{
	// parameters for trains behaviour
	float train_max_speed <- 90 #km/#h;
	float carriage_length <- 19.5#m;
	float space_between_carriages <- 0.3#m;
	map<string,int> nb_carriages <- ["Yamanote"::11,"Saikyo"::10];
	float time_stop_in_station <- 45#s;
	map<string,float> spawn_time <- ["Yamanote_1"::150#s,"Yamanote_2"::150#s,"Saikyo_1"::150#s,"Saikyo_2"::150#s];
	float coef_update_orientation <- 0.1; //0 is fast, 1 is slow
	
	// colors for trains design
	rgb yamanote_green <- rgb(154, 205, 50);
	rgb saikyo_green <- rgb(46,139,87);
	rgb window <- rgb(1,44,78);
	rgb shonan_orange <- rgb(246,139,30);
	rgb shonan_green <- rgb(100,185,102);
			
	// shape file
	shape_file rail_shape_file <- shape_file("../includes/rail_tracks.shp");

	// tolerance for railroad network intersections
	float node_tolerance <- 0.0001;

	// internal variables						  
	graph rail_network;
	graph rail_moving_graph;
	
	map<string,float> time_to_spawn;
	list<string> line_names;
	
	

	init{
		// create the railroad network
		create rail from: rail_shape_file with: [name::string(get("name"))]{
			if self.name = "Yamanote_1"{
				self.shape <- polyline(reverse(self.shape.points));
			}		
		}
		do clean_railroad;
		
		// create intersections and waypoints
		list<point> first_points <- rail collect first(each.shape.points);
		list<point> last_points <- rail collect last(each.shape.points);
			
		ask rail{
			create rail_wp{
				location <- last(myself.shape.points);
				is_traffic_signal <- true;
			}
		}
		
		// create spawning point for the trains (loco+carriages)
		float spacing <- carriage_length + space_between_carriages;
		ask rail where not(first(each.shape.points) in last_points){
			float len <- perimeter(self.shape);
			
			create rail_wp{
				location <- first(myself.shape.points);
				is_spawn_location <- true;
				last_carriage <- true;
				name <- myself.name;
				color <- #grey;
			}
			string train_type <- copy_between(name, 0,length(name)-2); 
			loop j from: 0 to: nb_carriages[train_type]-1 {
				point p <- first(points_along(shape,[(j+1)*spacing/len]));
				create rail{
					shape <- polyline([first(points_along(myself.shape,[j*spacing/len])), p]);
					name <- myself.name;
				}
				create rail_wp{
					location <- p;
					is_spawn_location <- true;
					name <- myself.name;
					color <- #grey;
					if j = nb_carriages[train_type]-1{
						loco_spawn <- true;
						color <- #green;
					}
				}
			}
			int last_index <- 0;
			
			loop while: perimeter(polyline(first(last_index,shape.points))) < nb_carriages[train_type]*spacing{
				last_index <- last_index + 1;
			}
			int tmp <- length(shape.points) - last_index;
			shape <- polyline([first(points_along(shape,[nb_carriages[train_type]*spacing/len]))] + last(tmp,shape.points));		
		}
	
		// create a graph from the railroad network that will we used to compute trains trajectories
		rail_network <- as_driving_graph(rail,rail_wp);
		rail_moving_graph <- as_edge_graph(rail);
		ask rail_wp where each.is_traffic_signal{
			do initialize;
		}
		ask rail_wp{
			final_intersection <- compute_target();
		}
		
		line_names <- remove_duplicates(rail collect(each.name));
		loop l over: line_names{
			time_to_spawn << l::rnd(57)#s;
		}
	}
	
	// clean the railroad (force intersections overlapping and graph connectivity)
	action clean_railroad{
		ask rail{
			list<point> extremities <- [first(shape.points),first(shape.points)];
			loop p over: extremities{
				ask rail - self{
					if distance_to(first(self.shape.points),p) < node_tolerance{
						self.shape <- polyline([p]+last(length(self.shape.points)-1,self.shape.points));
					}
					if distance_to(last(self.shape.points),p) < node_tolerance{
						self.shape <- polyline(first(length(self.shape.points)-1,self.shape.points)+p);
					}
					
				}
			}
		}
	}
	
	// scheduler that spawns trains at given time intervals
	reflex train_scheduler{
		loop l over: line_names{
			put (time_to_spawn[l]-step) at: l in: time_to_spawn;
			if time_to_spawn[l] < 0{
				do spawn_train(l);
				put (spawn_time[l]+rnd(10.0)#s) at: l in: time_to_spawn;
			}
		}		
	}
	
	// spawn trains
	action spawn_train(string line_name){
		list<carriage> created_carriages;
		train loco;
		string train_type <- copy_between(line_name,0,length(line_name)-2);
		bool shaikyo_type <- flip(0.5);
		
		// create the train locomotive
		ask rail_wp where (each.name = line_name and each.loco_spawn){
			rail out <- rail(first(roads_out));
			create train {
				type <- train_type;
				location <- myself.location;
				target <- myself.final_intersection;			
				heading <- angle_between(first(out.shape.points),first(out.shape.points)+{1.0,0},out.shape.points[1]);
				loco <- self;
				do init(shaikyo_type);
			}
		}

		// create the carriages following the previous locomotive
		ask rail_wp where (each.name = line_name and !each.loco_spawn){	
			rail out <- rail(first(roads_out));	
			create carriage {
				type <- train_type;
				location <- myself.location;
				target <- myself.final_intersection;
				heading <- angle_between(first(out.shape.points),first(out.shape.points)+{1.0,0},out.shape.points[1]);
				name <- line_name+" carriage "+int(self);
				created_carriages << self;
				locomotive <- loco;
				last_carriage <- myself.last_carriage;
				do init(shaikyo_type);
			}
		}	
		loco.carriages <- created_carriages;
	}
								  					  
}

/* Species definitions */


// species rail

species rail skills: [road_skill]{
	float maxspeed <- train_max_speed;
	rgb color <- #black;
	
	aspect default {
		draw shape color: color;
	}
}

// species rail_wp

species rail_wp skills: [intersection_skill] {
	bool is_traffic_signal <- false;
	bool is_spawn_location <- false;
	bool last_carriage <- false;
	rail_wp final_intersection <- nil;
	rgb color <- #white;
	bool loco_spawn <- false;
	float wait_time;

	//take into consideration the roads coming from both direction (for traffic light)
	list<rail> ways;
	
	//if the traffic light is green
	bool is_green;

	// initialize the intersections as nodes for the driving graph
	action initialize{
		is_traffic_signal <- true;
		stop << [];
		loop rd over: roads_in {
			ways << rail(rd);
		}
		do to_red;
	}
	
	// computes the final destination corresponding to the current node
	rail_wp compute_target{
		if empty(roads_out){
			return self;
		}else{
			return rail_wp(rail(first(roads_out)).target_node).compute_target();
		}
	}
	
	// toggles the train traffic light to green
	action to_green {
		stop[0] <- [];
		is_green <- true;
		color <- #green;
	}
	

	// toggles the train traffic light to red
	action to_red {
		stop[0] <- ways;
		is_green <- false;
		color <- #red;
	}
	
	// toogle the signal at the station to red after 15s after a train leaves the station
	reflex turn_to_red when: is_green {
		wait_time <- wait_time + step;
		if wait_time > 15#s{
			do to_red;
			wait_time <- 0.0;
		}
	}
	
	// a train stays time_stop_in_station, then the signal is toggled to green
	action trigger_signal{
		wait_time <- wait_time + step;
		if wait_time > time_stop_in_station{
			do to_green;
			wait_time <- 0.0;
		}
	}
	
	// this aspect is for debug. This species should not be displayed for regular use
	aspect default{
		draw circle(1.5) color: color;
		if length(roads_in)> 0{
			geometry r <- first(roads_in);
			draw polyline(points_along(polyline(last(2,r.points)),[0.6,1.0])) color: #blue;
		}
			if length(roads_out)> 0{
			geometry r <- first(roads_out);
			draw polyline(points_along(polyline(first(2,r.points)),[0.0, 0.4])) color: #white;
		}
	}
}

// species rolling_stock. Generic and parent species for trains and carriages, used for 3d models 

species rolling_stock{
	rgb color;
	rgb color2;
	float orientation;
	rail_wp target;
	bool is_carriage;	
	bool last_carriage <- false;
	string type;
	float heading;
	float speed;
	
	geometry g1 <- (rectangle({0,-1.175},{1.67,1.175})+0.3)
			+ polygon([{-0.11480502970952709,-1.452163859753386,0.0},{-0.65,-1.325},{-0.65,1.325},{-0.11480502970952691,1.4521638597533861,0.0}])
			- rectangle({1.5,-1.325},{-0.7,1.325});
	geometry top <- g1 - rectangle({1.5,-1.5},{-0.7,1.5});
	geometry section <- inter(g1, rectangle({1.5,-1.5},{-0.8,1.5}));
	geometry front <- (rectangle({0,2.35},{1.87,0})+0.3) - (rectangle({0,2.35},{1.87,0})+0.2) + (rectangle({1.4,2.35},{1.87,0})+0.2) + rectangle({1.2,2.65},{1.67,-0.3});			
	
	action init(bool t){
		if type = "Yamanote"{
			color <- yamanote_green;
		}else{
			if t{
				color <- saikyo_green;
				color2 <- saikyo_green;
			}else{
				color <- shonan_green;
				color2 <- shonan_orange;
			}		
		}
		speed <- 70#km/#h;
		orientation <- heading;
	}
	
	// several actions to draw parts of the rolling stock
	action draw_side_panels(point shift, float h, float w, point loc, float angle, rgb c){
		loop s over: [-1,1]{
			draw rectangle(w, h)  rotated_by((-90-s*angle)::{1,0,0}) color: c rotate: orientation 
				at: loc + ({shift.x,s*shift.y,shift.z} rotated_by (orientation::{0,0,1}));				
		}
	}
	
	action draw_windows(point shift, float h, float w, point loc, float r){
		loop s over: [-1,1]{
			draw (rectangle(w, h)+r) rotated_by(90::{1,0,0}) color: window rotate: orientation 
				at: loc  + ({shift.x,s*shift.y,shift.z} rotated_by (orientation::{0,0,1}));			
		}
	}
	
	action draw_front(int side){
		draw box(0.8,2.45,0.65) color: rgb(50,50,50) rotate: orientation 
			at: location + ({side*(carriage_length/2-0.4),0,0.35} rotated_by (orientation::{0,0,1}));			
		
		if type = "Yamanote"{
			draw (rectangle(1.67,2.35)+0.25)  rotated_by(90::{0,1,0})  color: window rotate: orientation  
				at: location  + ({side*(carriage_length/2+0.29),0,2.54} rotated_by (orientation::{0,0,1}));		
		draw (rectangle(1.67,2.85))  rotated_by(90::{0,1,0})  color: window rotate: orientation  
				at: location  + ({side*(carriage_length/2+0.291),0,2.54} rotated_by (orientation::{0,0,1}));		
		draw (rectangle(0.05,2.85))  rotated_by(90::{0,1,0})  color: #grey rotate: orientation  
				at: location  + ({side*(carriage_length/2+0.292),0,3.4} rotated_by (orientation::{0,0,1}));		
							
			draw front rotated_by(90::{0,1,0}) depth: 0.4 color: color rotate: orientation  
				at: location  + ({side*carriage_length/2 +0.4*(-1+side)/2,-0.15,2.44} rotated_by (orientation::{0,0,1}));	
		}else{
			draw top rotated_by(-90::{0,1,0}) rotate: orientation depth: side*0.2 
				at: location + ({side*carriage_length/2,0,3.49}  rotated_by (orientation::{0,0,1})) color: #black;
			draw polygon([{0,-1.48},{side*0.2, -1.48},{side*0.6,-1.18},{side*0.6,1.18},{side*0.2,1.48},{0,1.48}]) depth:0.5 color: #grey rotate: orientation
					at: location  + ({side*(carriage_length/2+0.265),0,1.005} rotated_by (orientation::{0,0,1}));		
			draw polygon([{0,-1.18},{0,1.18},{0.2,1.21},{0.2,-1.21}]) rotated_by(-(90+side*11.5)::{0,1,0}) rotate: orientation 
				at: location  + ({side*(carriage_length/2+0.58),0,1.6}  rotated_by (orientation::{0,0,1})) color: color;
			draw polygon([{0,-1.21},{0,1.21},{0.2,1.24},{0.2,-1.24}]) rotated_by(-(90+side*11.5)::{0,1,0}) rotate: orientation 
				at: location  + ({side*(carriage_length/2+0.54),0,1.79}  rotated_by (orientation::{0,0,1})) color: color2;
			draw polygon([{0,-1.24},{0,1.24},{0.2,1.27},{0.2,-1.27}]) rotated_by(-(90+side*11.5)::{0,1,0}) rotate: orientation 
				at: location  + ({side*(carriage_length/2+0.5),0,1.985}  rotated_by (orientation::{0,0,1})) color: #black;
			draw polygon([{0,-1.27},{0,1.27},{1.3,1.46},{1.3,-1.46}]) rotated_by(-(90+side*11.5)::{0,1,0}) rotate: orientation 
				at: location  + ({side*(carriage_length/2+0.35),0,2.72}  rotated_by (orientation::{0,0,1})) color: window;
			loop s over: [-1,1]{
				draw polygon([{-side*0.2,0,0},{0,0,0},{0,0,2},{-side*0.2,0,2}]) color: #white rotate: orientation
					at: location  + ({side*(carriage_length/2+0.1),-s*1.48,2.5} rotated_by (orientation::{0,0,1}));				
				draw polygon([{0,0,0},{side*0.4,s*0.3,0},{0,0,2}]) color: #white rotate: orientation
					at: location  + ({side*(carriage_length/2+0.33),-s*1.38,2.17} rotated_by (orientation::{0,0,1}));		
			}	
		}
	}
	
	aspect default {
		// ceiling
		draw top rotated_by(-90::{0,1,0}) rotate: orientation depth: carriage_length 
				at: location + {0,0,3.49} + ({-carriage_length/2,0,0}  rotated_by (orientation::{0,0,1})) 
				color: #grey;
				
		// Saikyo  stripe
		if type = "Saikyo"{
			do draw_side_panels({0,1.48,3.2}, 0.2, 19.5#m, location,0.0, color);
		}
		
		//floor
		draw rectangle(19.5#m, 2.65#m) depth: 0.15#m color: #grey rotate: orientation at: location+{0,0,1};
		
		//sections
		loop pos over: [0.0, 17.81]{
			draw section rotated_by(-90::{0,1,0}) rotate: orientation depth: 1.69 
				at: location + {0,0,2} + ({carriage_length/2-pos,0,0}  rotated_by (orientation::{0,0,1})) color: #grey;
			if type = "Saikyo"{
				do draw_side_panels({carriage_length/2-0.845-pos,1.48,1.8}, 0.2, 1.69, location,0.0, color2);
				do draw_side_panels({carriage_length/2-0.845-pos,1.47,1.6}, 0.2, 1.69, location,10.0, color);
			}
		}
		loop pos over: [2.99, 7.93, 12.87]{
			draw section rotated_by(-90::{0,1,0}) rotate: orientation depth: 3.64 
				at: location + {0,0,2} + ({carriage_length/2-pos,0,0}  rotated_by (orientation::{0,0,1})) 
				color: #grey;
				do draw_windows({carriage_length/2-pos-1.82,1.48,2.5}, 0.84, 1.93, location, 0.05);
				if type = "Saikyo"{
					do draw_side_panels({carriage_length/2-1.82-pos,1.48,1.8}, 0.2, 3.64, location,0.0, color2);
					do draw_side_panels({carriage_length/2-1.82-pos,1.47,1.6}, 0.2, 3.64, location,10.0, color);
				}
			
		}	
		
		// doors
		loop pos over: [2.34,7.28,12.22,17.16]{
			loop s over:[-1,1]{
				draw rectangle(1.3#m, 2.3#m) rotated_by(90::{1,0,0}) color: type="Yamanote"?color:#grey rotate: orientation 
					at: location+{0,0,2.3}  + ({carriage_length/2-pos,s*1.325,0} rotated_by (orientation::{0,0,1}));			
				// windows
				do draw_windows({carriage_length/2-pos-0.3,1.33,2.5}, 0.934, 0.494, location, 0.03);
				do draw_windows({carriage_length/2-pos+0.3,1.33,2.5}, 0.934, 0.494, location, 0.03);
				if type = "Saikyo"{
					do draw_side_panels({carriage_length/2-pos,1.33,1.8}, 0.2, 1.3, location, 0.0, color2);
					do draw_side_panels({carriage_length/2-pos,1.33,1.6}, 0.2, 1.3, location, 0.0, color);
				}
			}
		}			
						
		// rear section
		if !last_carriage{
			do draw_windows({-carriage_length/2+0.5,1.48,2.5}, 0.84, 0.6, location, 0.05);
			draw box(0.6,1.20,2.10) color: #grey rotate: orientation 
					at: location+{0,0,1.15}  + ({-carriage_length/2+-space_between_carriages/2,0,0} rotated_by (orientation::{0,0,1}));			
		} else{
			do draw_windows({-carriage_length/2+0.5,1.48,2.5}, 0.54, 0.6, location, 0.05);
		}
		
		// panels at the end of the carriages
			draw rectangle(2.1,2.65)  rotated_by(90::{0,1,0})  color: #grey rotate: orientation  
				at: location + {0,0,2.2} + ({carriage_length/2,0} rotated_by (orientation::{0,0,1}));
			draw rectangle(2.1,2.65)  rotated_by(90::{0,1,0})  color: #grey rotate: orientation  
				at: location + {0,0,2.2} + ({-carriage_length/2,0} rotated_by (orientation::{0,0,1}));

	
		// front section
		if !is_carriage{
			do draw_windows({carriage_length/2-0.5,1.48,2.75}, 0.54, 0.6, location, 0.05);
		}else{
			do draw_windows({carriage_length/2-0.5,1.48,2.5}, 0.84, 0.6, location, 0.05);
		}
	
		// roof engine
		draw box(4.1,2,0.3) color: #grey rotate: orientation 
			at: location+{0,0,3.60}  + ({-0.8,0,0} rotated_by (orientation::{0,0,1}));			
		
		// wheels
		loop pos over:[1.8,3.9,15.6,17.7]{
			loop s over:[-1,1]{
				draw circle(0.44#m) rotated_by(90::{1,0,0}) depth: 0.05 color: rgb(50,50,50) rotate: orientation 
					at: location+{0,0,0.44}  + ({carriage_length/2-pos,s*0.54,0} rotated_by (orientation::{0,0,1}));			
			}
		}
		// underbox
		draw box(9,2.4,0.7) color: rgb(50,50,50) rotate: orientation 
			at: location+{0,0,0.3}  ;	
		
		draw box(2.2,1.4,0.5) color: rgb(50,50,50) rotate: orientation 
			at: location+{0,0,0.3}  + ({carriage_length/2-2.9,0,0} rotated_by (orientation::{0,0,1}));	
		draw box(2.2,1.4,0.5) color: rgb(50,50,50) rotate: orientation 
			at: location+{0,0,0.3}  + ({-carriage_length/2+2.9,0,0} rotated_by (orientation::{0,0,1}));	
					
				
		// front face
		if ! is_carriage{
			do draw_front(1);						
		}
		
		// rear face
		if last_carriage{
			do draw_front(-1);
		}	
	}
}

// species train

species train skills: [driving] parent: rolling_stock{
	float loco_speed;
	list<carriage> carriages;
	bool is_carriage <- false;
	float max_deceleration <- 2#km/#h/#s;
	float vehicle_length <- carriage_length;
	float max_speed <- train_max_speed;
	
	//choose a random target and compute the path to it
	reflex choose_path when: final_target = nil {
		do compute_path graph: rail_network target: target; 
	}
	
	// make the loco move and force the carriages to follow synchronously (at same speed)
	reflex loco_move when: final_target != nil {
		point old_location <- location;
		do drive;	
		loco_speed <- norm(location - old_location)/step;
		orientation <- heading + coef_update_orientation*(orientation - heading);
		ask carriages{
			do carriage_move;
		}

		//if arrived at target, die and remove carriages
		if (final_target = nil) {
			do unregister;
			ask carriages{
				do die;
			}
			do die;
		}

		if  distance_to_current_target = 0{
			ask rail_wp(current_target){
				do trigger_signal;
			}
		}
	}
	
	// reflex to show stats for the trains. Turn the condition to true to display
	reflex stat when: false{
		float speed_kmh <- round(10 * self.speed * 3600 / 1000) / 10;
		float acceleration_kmh_s <- round(10 * acceleration * 3600 / 1000) / 10;
		write ""+self+" Speed: "+speed_kmh+"km/h. Acc: "+acceleration_kmh_s+"km/h/s.";	
	}
}

// species carriages

species carriage skills: [moving] parent: rolling_stock{
	train locomotive;
	bool is_carriage <- true;
	
	action carriage_move  {
		do goto target: target on: rail_moving_graph speed: locomotive.loco_speed;
		orientation <- heading + coef_update_orientation*(orientation - heading);
	}
}



