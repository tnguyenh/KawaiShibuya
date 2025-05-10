 /**
* Name: KawaiShibuyaCrossing
* 
* Author: Tri Nguyen-Huu, Patrick Taillandier
* 
* Graphics design by 
*
*
* 
* This is a simulation of Shibuya Crossing (Tokyo, Japan).
*
*
* Tags: pedestrian skill, driving skill, SFM, Shibuya, Tokyo, Kawai
*/

model KawaiShibuyaCrossing

import "EyeCandies/trains.gaml"
import "EyeCandies/props.gaml"
import "EyeCandies/vehicles.gaml"

global {
	
	int nb_people <- 20;
	float step <- 0.25#s;
	bool parallelize <- true;
	
	float precision <- 0.2;
	float factor <- 1.0;
	float mesh_size <- 2.0;
	
	bool show_fps <- true;
	float mtime <- gama.machine_time;
	
	shape_file bounds <- shape_file("../includes/Shibuya.shp");
	image_file photo <- (image_file(("../includes/Shibuya.png")));

	shape_file crosswalk_shape_file <- shape_file("../includes/crosswalk.shp");
	shape_file walking_area_shape_file <- shape_file("../includes/walking area.shp");
	shape_file traffic_signals_shape_file <- shape_file("../includes/traffic_signals.shp");

	map<string,map<int,list>> cameraPaths <- [
		"Overview" :: [
			0::[{98.4788,143.3489,64.7132},{98.6933,81.909,0.0}]
			],
		"From hotel" :: [
			0 :: [{32.816,86.3686,71.9106}, {76.6664,59.7071,0.0}]
		],
		"From cafe" :: [
			0 :: [{80.2911,20.2295,15.7393}, {81.228,43.5573,5.0},60]
		],
		"From cafe (left to right)"::[
			0 :: [{81.0254,22.4783,12}, {88.5952,42.4058,5.0}],
			300 :: [{81.0254,22.4783,12}, {81.0567,42.6362,5.5}]
		],
		"Timelapse" :: [
			0::[{98.4788,143.3489,64.7132},{98.6933,81.909,0.0}],
			1000::[{89.6265,108.4783,47.5701},{89.7842,63.3143,0.0}]
		],
		"Bird view" :: [
			0::[{4.4063,54.6104,84.8243},{7.3889,54.6208,0.0}],
			500::[{144.6128,57.1369,84.8243},{147.5954,57.1473,0.0}]
		],
		"Bird view (far)" :: [
			0 :: [{8.4863,59.3305,138.7569}, {15.7918,59.2922,0.0},30.0],
			500 :: [{140.0042,58.4734,138.7569},{147.3097,58.4351,0.0},30.0]
		],
		"Walk to the edge" :: [
			0 :: [{3.198,119.1418,68.7856}, {94.0765,64.9665,20.0},40],
			100 :: [{19.9273,106.9988,68.7856}, {112.8058,52.8235,0.0},40],
			170 :: [{35.215,98.1132,69.7071}, {110.7052,58.1287,-10.0}, 40]
		],
		"Trailer" :: [
			// timelapse
			0::[{98.4788,143.3489,64.7132},{98.6933,81.909,0.0},45],
			400::[{98.4788,143.3489,64.7132},{98.6933,81.909,4.0},41],
//			400::[{89.6265,108.4783,47.5701},{89.7842,63.3143,0.0}],
			// birdview
			401 :: [{8.4863,59.3305,138.7569}, {15.7918,59.2922,0.0},30.0],
			900 :: [{140.0042,58.4734,138.7569},{147.3097,58.4351,0.0},30.0],
			// edge
			901 :: [{3.198,119.1418,68.7856}, {94.0765,64.9665,20.0},40],
			960 :: [{19.9273,106.9988,68.7856}, {112.8058,52.8235,0.0},40],
			1070 :: [{35.215,98.1132,69.7071}, {110.7052,58.1287,-10.0}, 40],
			// edge fix until
			1120 :: [{35.215,98.1132,69.7071}, {110.7052,58.1287,-10.0}, 40],
			// cafe (left to right)
			1121 :: [{81.0254,22.4783,12}, {88.5952,42.4058,5.0}],
			1250 :: [{81.0254,22.4783,12}, {81.0567,42.6362,5.5}],
			// Kubrick fade out
			1251::[{98.4788,143.3489,64.7132},{98.6933,81.909,0.0}],
			1450::[{98.1771,229.7714,155.74}, {98.6933,81.909,3.0}, 23, 1.3]
		],
		"Kubrick" :: [
			0::[{98.4788,143.3489,64.7132},{98.6933,81.909,0.0}],
//			200::[{98.3439,181.9881,105.411},{98.6933,81.909,5.0},28.0]
			200::[{98.1771,229.7714,155.74}, {98.6933,81.909,3.0}, 23, 1.3]
//			200::[{97.3236,474.2321,413.2247}, {98.6933,81.909,10.0},10,1.5]
		]
		
	];
	
	list<string> dynamicCameraList <- ["Timelapse", "Bird view", "Bird view (far)", "Walk to the edge","Trailer","Kubrick", "From cafe (left to right)"];
	
	string currentScenario <- "Trailer";
	map<int,list> currentCameraPath <- cameraPaths[currentScenario];
	float videoSpeed <- 1.0;

//	point cameraPosition <- {98.4788,143.3489,64.7132};
//	point cameraTarget <- {98.6933,81.909,0.0} ;
//	float cameraLens <- 45.0;
	point cameraPosition <- currentCameraPath[currentCameraPath.keys[0]][0];
	point cameraTarget <- currentCameraPath[currentCameraPath.keys[0]][1];
	float cameraLens <- length(currentCameraPath[currentCameraPath.keys[0]]) = 3 ? float(currentCameraPath[currentCameraPath.keys[0]][2]) : 45.0;
	bool dynamicCamera <- currentScenario in dynamicCameraList;
	
	
	geometry shape <- envelope(bounds);
	
	
	float P_shoulder_length <- 1.0;
	float P_proba_detour <- 0.5 ;
	bool P_avoid_other <- true ;
	float P_obstacle_consideration_distance <- 3.0 ;
	float P_pedestrian_consideration_distance <- 3.0 ;
	float P_tolerance_target <- 0.1 ;
	bool P_use_geometry_target <- true ;
	
	
	string P_model_type <- "simple" among: ["simple", "advanced"] ; 
	string pedestrian_path_init <- "grid" among: ["voronoi", "grid"] ; 
	
	float P_A_pedestrian_SFM_advanced  <- 0.0001 ;
	float P_A_obstacles_SFM_advanced  <- 1.9 ;
	float P_B_pedestrian_SFM_advanced  <- 0.1 ;
	float P_B_obstacles_SFM_advanced  <- 1.0 ;
	float P_relaxion_SFM_advanced   <- 0.5 ;
	float P_gama_SFM_advanced  <- 0.35 ;
	float P_lambda_SFM_advanced <- 0.1  ;
	float P_minimal_distance_advanced <- 0.25  ;
	
	float P_n_prime_SFM_simple  <- 3.0 ;
	float P_n_SFM_simple  <- 2.0 ;
	float P_lambda_SFM_simple <- 2.0  ;
	float P_gama_SFM_simple  <- 0.35 ;
	float P_relaxion_SFM_simple  <- 0.54 ;
	float P_A_pedestrian_SFM_simple  <-4.5;
	
	graph network;
	

	bool can_cross <- false;
//	float time_since_last_spawn <- 0.0;
	
	people the_people;	
	
	geometry open_area;


	list<geometry> walking_area_divided;
	list<point> nodes;
	list<geometry> nodes_inside;
	list<geometry> voronoi_diagram;
	geometry bounds_shape;
	int target_pop <- nb_people;
	
	// update camera position along waypoints
	reflex updateCamera{
		int lastWaypoint <- last(currentCameraPath.keys);
		if (cycle >= lastWaypoint){
			cameraPosition <- currentCameraPath[lastWaypoint][0];
			cameraTarget <- currentCameraPath[lastWaypoint][1];
			cameraLens <- length(currentCameraPath[lastWaypoint]) >= 3 ? float(currentCameraPath[lastWaypoint][2]) : 45.0;
		} else {
			// determine the previous waypoint and the next one for the camera movement
			int previousWaypoint <- max(currentCameraPath.keys where (each <= cycle));
			int nextWaypoint <- currentCameraPath.keys[index_of(currentCameraPath.keys, previousWaypoint)+1];
			// compute the position and the orientation of the camera
			cameraPosition <- point(currentCameraPath[previousWaypoint][0]) * (nextWaypoint - cycle) / (nextWaypoint - previousWaypoint)
				+ point(currentCameraPath[nextWaypoint][0]) * (cycle - previousWaypoint) / (nextWaypoint - previousWaypoint);
			cameraTarget <- point(currentCameraPath[previousWaypoint][1]) * (nextWaypoint - cycle) / (nextWaypoint - previousWaypoint)
				+ point(currentCameraPath[nextWaypoint][1]) * (cycle - previousWaypoint) / (nextWaypoint - previousWaypoint);
			// adjust the camera lens
			float previousCameraLens <- length(currentCameraPath[previousWaypoint]) >= 3 ? float(currentCameraPath[previousWaypoint][2]) : 45.0;
			float nextCameraLens <- length(currentCameraPath[nextWaypoint]) >= 3 ? float(currentCameraPath[nextWaypoint][2]) : 45.0;
			
			if (length(currentCameraPath[nextWaypoint]) = 4){
				float pow <- float(currentCameraPath[nextWaypoint][3]);
				cameraLens <- previousCameraLens * ((nextWaypoint - cycle) / (nextWaypoint - previousWaypoint))^pow
				+ nextCameraLens * (1 - ((nextWaypoint - cycle) / (nextWaypoint - previousWaypoint))^pow);
			}else{
				cameraLens <- previousCameraLens * ((nextWaypoint - cycle) / (nextWaypoint - previousWaypoint))
				+ nextCameraLens * (1 - ((nextWaypoint - cycle) / (nextWaypoint - previousWaypoint)));
			}	
		}
	}
	
	init {
		
		// change film speed
		if (length(currentCameraPath) > 1)
		{
			map<int,list> acceleratedCameraPath <- [];
			int currentFrame <- 0;
			acceleratedCameraPath <+ currentCameraPath.keys[0]::currentCameraPath.values[0];
			loop i from: 1 to: length(currentCameraPath.keys)-1{
				int initialDuration <- currentCameraPath.keys[i] - currentCameraPath.keys[0];
				int nextFrame <- max(acceleratedCameraPath.keys[i-1]+1,int(ceil(initialDuration / videoSpeed)));
				acceleratedCameraPath <+ nextFrame::currentCameraPath.values[i];
			}
			currentCameraPath <- acceleratedCameraPath;
		}
		
		
		
		gama.pref_opengl_z_factor <- 0.0;
		

		
		create crosswalk from:crosswalk_shape_file with:[id::int(get("id"))];
		create walking_area from:walking_area_shape_file;
		
		ask crosswalk{
			ends <- walking_area overlapping self;
		}
		
		loop w over:  walking_area{
			loop c over: (crosswalk overlapping w){
				create waiting_area{
					shape <- intersection(w.shape,c.shape);
					my_crosswalk <- c;
					my_walking_area <- w;
					w.waiting_areas <+ self;
					c.waiting_areas <+ self;
				}
			}
		}
		
		loop c over: crosswalk{
			loop w over: c.waiting_areas{
				w.opposite <- first(c.waiting_areas - w);
			}
		}
		
		
		open_area <- union(walking_area collect each.shape);
		bounds_shape <- open_area - union(building collect each.shape);	

		if pedestrian_path_init = "voronoi"{
			list<geometry> lg;
			loop w over: walking_area{	
				walking_area_divided <- walking_area_divided + split_geometry(w - union(building collect (each.shape)),mesh_size);
			}
			
			voronoi_diagram <- voronoi(walking_area_divided accumulate(each.points));
			voronoi_diagram <- voronoi_diagram collect((each inter (open_area - 0.5)) - (union(building collect (each.shape))+0.5));
			lg <- voronoi_diagram accumulate (to_segments(each));
			create pedestrian_path from: lg;
		}else{
			float minx <- min(envelope(open_area).points accumulate each.x);
			float maxx <- max(envelope(open_area).points accumulate each.x);
			float miny <- min(envelope(open_area).points accumulate each.y);
			float maxy <- max(envelope(open_area).points accumulate each.y);
	
			float area_width <- maxx-minx;
			float area_height <- maxx-minx;
					
			list<geometry> lines;
			int num <- int(area_width/mesh_size);
			loop k from: 0 to: num {
				lines << line([{k * area_width/num, 0}, {k * area_width/num, area_height}]);
			}
			num <- int(area_height/mesh_size);
			loop k from: 0 to: num {
				lines << line([{0, k * area_height/num, 0}, {area_width, k * area_height/num}]);	
			}
				
			list<geometry> clean_lines <- [];
			loop w over: walking_area{
				list<geometry> tmp <- lines collect(inter(each,w));
				tmp <- clean_network(union(tmp).geometries, 0.001, true, true);
				list<point> pl <- remove_duplicates(tmp accumulate(each.points));
				loop p over: pl{
					list<point> np <- (pl where ((each distance_to p) < mesh_size*sqrt(2)*1.01))
						-(pl where ((each distance_to p) < mesh_size*1.01)); 
					tmp <- tmp + (np collect(polyline([p,each])));
				}
				clean_lines <- clean_lines + remove_duplicates(tmp);
			}
			clean_lines <- clean_lines where (bounds_shape covers each);		
			create pedestrian_path from: clean_lines{
				free_space <- shape + (mesh_size*0.6);
			}
		}
		
		nodes <-remove_duplicates(pedestrian_path accumulate ([first(each.shape.points),last(each.shape.points)]));		
		nodes_inside <- (nodes collect geometry(each)) inside open_area;
		
		ask waiting_area{
			do compute_direction;
		}
		
		network <- as_edge_graph(pedestrian_path);
		
//		ask pedestrian_path {
//			do build_intersection_areas pedestrian_graph: network;
//		}
		

		create people number:nb_people{
		//	do add_people;
		}	
	



		create traffic_signal from: traffic_signals_shape_file with:[group::int(get("group")),crosswalk_left::int(get("cw_l")),
				crosswalk_right::int(get("cw_r")),car_light::string(get("car_light")),direction_crosswalk::int(get("dir_crossw"))]{
			point dir <- (first(crosswalk where (each.id=direction_crosswalk)).waiting_areas closest_to self).direction;
			heading <- towards({0,0},dir);
			if crosswalk_left >0{
				point dir_l <- (first(crosswalk where (each.id=crosswalk_left)).waiting_areas closest_to self).direction;
				heading_l <- towards({0,0},dir_l);	
			}
			if crosswalk_right >0{
				point dir_r <- (first(crosswalk where (each.id=crosswalk_right)).waiting_areas closest_to self).direction;
				heading_r <- towards({0,0},dir_r);	
			}	
		}
		
		create screen {
			dimensions <- {6.05#m,1#m,20#m};
			location <- {72.15,20.35, 7};
			angle <- 10.0;
		}
		
		create screen {
			dimensions <- {7.7#m,1#m,20#m};
			location <- {78.85,20.7, 7};
			angle <- -2.5;
		}
		
		create screen {
			dimensions <- {6.4#m,1#m,20#m};
			location <- {85.5,19.36, 7};
			angle <- -22.0;
		}
		
//			draw box(6.05#m,1#m,20#m) at: {} color: color rotate: 10;
//		draw box() at: {78.85,20.7, 7} color: color rotate: -2.5;
//		draw box(6.4#m,1#m,20#m) at: {85.5,19.36, 7} color: color rotate: -22;
		
	}
	

	


	action switch_pedestrian_lights{
		can_cross <- !can_cross;
		if can_cross {
			ask people{
				waiting <- false;
			}
		}else{
			loop w over: waiting_area{
				ask people inside w{
					waiting <- true;
				}
			}
		}
	}
	
	reflex change_people_number{
		int variation <- nb_people - (people count(each.fade_status != "fade_away"));
		if variation < 0{
			ask (-variation among people where (each.fade_status != "fade_away")){
				fade_status <- "fade_away";
			}
		}
		if variation > 0{
			create people number: variation{
				fade_status <- "fade_in";
				fading <- 0.0;
			}
		}
	}
	
	reflex compute_fps when: show_fps and mod(cycle,100)=0 and cycle > 100{
		float newmtime <- gama.machine_time;
		if cycle > 0{
			write ""+round(100000/(newmtime-mtime)*10)/10+" fps.";
		}
		mtime <- newmtime;
	}
	
	reflex main_scheduler{

		// change traffic lights
		
		
		if schedule_step = 1{
			percent_time_remaining <- (schedule_times[1] - schedule_time)/(schedule_times[1] - schedule_times[0]);
		}else if schedule_step = 0{
			percent_time_remaining <- (schedule_times[0] - schedule_time)/(schedule_times[5] + schedule_times[0] - schedule_times[1]);
		}else{
			percent_time_remaining <- (schedule_times[0]+schedule_times[5] - schedule_time)/(schedule_times[5] + schedule_times[0] - schedule_times[1]);			
		}
				
		switch schedule_step{		
			match 0{
				if  schedule_time > schedule_times[0]{
					do switch_pedestrian_lights;
					schedule_step <- schedule_step + 1;
					percent_time_remaining <- 1.0;
				}
			}
			match 1{
				if schedule_time > schedule_times[1]{
					do switch_pedestrian_lights;
					schedule_step <- schedule_step + 1;
					time_to_clear_crossing <- schedule_times[2]-schedule_times[1];
					percent_time_remaining <- 1.0;
				}
			}
			match 2{
				time_to_clear_crossing <- time_to_clear_crossing - step;
				if schedule_time > schedule_times[2]{
					ask intersection where (each.group = 1){
						do to_green;
					}
					schedule_step <- schedule_step + 1;
				}
			}
			match 3 {
				if schedule_time > schedule_times[3]-3#s{
					ask intersection where (each.group = 1){
						do to_orange;
					}
				}
				if schedule_time > schedule_times[3]{
					ask intersection where (each.group = 1){
						do to_red;
					}
					schedule_step <- schedule_step + 1;
				}
			}
			match 4 {
				if schedule_time > schedule_times[4]{
					ask intersection where (each.group = 2){
						do to_green;
					}
					schedule_step <- schedule_step + 1;
				}
			}
			match 5{
					if schedule_time > schedule_times[5]-3#s{
					ask intersection where (each.group = 2){
						do to_orange;
					}
				}
				if schedule_time > schedule_times[5]{
					ask intersection where (each.group = 2){
						do to_red;
					}
					schedule_step <- 0;
					schedule_time <- - step;
				}
			}
		}
		
		schedule_time <- schedule_time + step;
	}
}

/*******************************************
 * 
 * 
 *     species definition
 * 
 * 
 * ***************************************** */


























species pedestrian_path skills: [pedestrian_road]{
	rgb color <- #gray;
	walking_area my_area;
	
	aspect default { 
		draw shape  color: color;
	}
	aspect free_area_aspect {
		draw shape  color: color;
		draw free_space color: rgb(color,20) border: #black;
	}
}



species walking_area {
	list<waiting_area> waiting_areas;
	aspect default {
		switch int(self){
			match 0 {
				draw shape color: #green border: #black;
			}
			match 1 {
				draw shape color: #blue border: #black;
			}
			match 2 {
				draw shape color: #orange border: #black;
			}
			match 3 {
				draw shape color: #red border: #black;
			}
		}
	}
}

species crosswalk {
	int id;
	list<walking_area> ends;
	list<waiting_area> waiting_areas;
	
	aspect default {
		draw shape color: #gray border: #black;
	}
}

species waiting_area{
	crosswalk my_crosswalk;
	walking_area my_walking_area;
	waiting_area opposite;
	point direction;
	geometry waiting_front;
	
	action compute_direction{
		float norm <- 0.0;
		direction <- {0,0};
		loop i from: 0 to: length(my_crosswalk.shape.points)-2{
			if norm(my_crosswalk.shape.points[i+1]-my_crosswalk.shape.points[i]) > norm{
				direction <- my_crosswalk.shape.points[i+1]-my_crosswalk.shape.points[i];
				norm <- norm(direction);
			}	
		}
		if direction.x * (opposite.location.x - self.location.x) + direction.y * (opposite.location.y - self.location.y) < 0{
			direction <- -direction;
		}
		waiting_front <- polyline((shape.points where (direction.x*(each.x -location.x)+direction.y*(each.y -location.y)>0)) collect each);
		
	}
	
	aspect default {
		draw shape color: #yellow border: #black;
		draw waiting_front width: 5 color: #red;
	}
}




species people skills: [pedestrian] control: fsm parallel: parallelize{
	rgb color <- rnd_color(255);
	float normal_speed <- gauss(5.2,1.5) #km/#h min: 2.5 #km/#h;
	float scale <- rnd(0.9,1.1);
	point dest;
	point final_dest;
	walking_area final_area;
	walking_area current_area;
	waiting_area current_waiting_area;
	waiting_area last_waiting_area;
	bool going_to_cross <- false;
	bool waiting <- false;
	point wait_location;
	list<point> tracking;
	string last_state;
	bool for_debug <- false;
	string fade_status <- "none";
	float fading <- 1.0;

	reflex fade_away when: fade_status="fade_away"{
		fading <- fading - 0.01;
		if fading < 0 {
			do die;
		}
	}
	
	reflex fade_in when: fade_status="fade_in"{
		fading <- fading + 0.01;
		if fading >= 1 {
			fade_status <- "none";
		}
	}
	
	init{
		obstacle_species <- [building];
		location <- any_location_in(world.bounds_shape);
		dest <- location;
		final_dest <- location;
		current_waiting_area <- nil;
		obstacle_consideration_distance <- P_obstacle_consideration_distance;
		pedestrian_consideration_distance <- P_pedestrian_consideration_distance;
		shoulder_length <- P_shoulder_length;
		avoid_other <- P_avoid_other;
		proba_detour <- P_proba_detour;
		use_geometry_waypoint <- P_use_geometry_target;
		tolerance_waypoint <- P_tolerance_target;
		pedestrian_species <- [people];
		pedestrian_model <- P_model_type;
			
		

		if (pedestrian_model = "simple") {
				A_pedestrians_SFM <- P_A_pedestrian_SFM_simple;
				relaxion_SFM <- P_relaxion_SFM_simple;
				gama_SFM <- P_gama_SFM_simple;
				lambda_SFM <- P_lambda_SFM_simple;
				n_prime_SFM <- P_n_prime_SFM_simple;
				n_SFM <- P_n_SFM_simple;
		} else {
				A_pedestrians_SFM <- P_A_pedestrian_SFM_advanced;
				A_obstacles_SFM <- P_A_obstacles_SFM_advanced;
				B_pedestrians_SFM <- P_B_pedestrian_SFM_advanced;
				B_obstacles_SFM <- P_B_obstacles_SFM_advanced;
				relaxion_SFM <- P_relaxion_SFM_advanced;
				gama_SFM <- P_gama_SFM_advanced;
				lambda_SFM <- P_lambda_SFM_advanced;
				minimal_distance <- P_minimal_distance_advanced;
		}
	}
	
	
	state find_new_destination initial: true{
		speed <- normal_speed;
		final_dest <- one_of(nodes_inside).location;
		final_area <- walking_area closest_to final_dest;
		current_waiting_area <- nil;
		current_area <- walking_area closest_to self.location;	
		tracking <- [location];
		transition to: go_to_grid_before_final_destination when: current_area = final_area;
		transition to: go_to_grid_before_crosswalk when: current_area != final_area;
		last_state <- "find_new_destination";
	}
	
	state go_to_grid_before_final_destination{
		enter{
			speed <- normal_speed;		
			dest <- nodes closest_to self;
		}
		do walk_to target: dest;
		if  norm(location - dest) < precision{
			location <- dest;
		}
		transition to: go_to_final_destination when: norm(location - dest) < precision;
	}
	
	state go_to_final_destination{
		enter{
			dest <- final_dest;
			dest <- nodes closest_to dest;
			tracking <+ location;
			if norm(location - dest)>= precision{	
				do compute_virtual_path pedestrian_graph:network target: dest;
			}
		}
		if norm(location - dest)>= precision{	
			do walk;
		}
		transition to: find_new_destination when: norm(location - dest) < precision;
	}
	
		state go_to_grid_before_crosswalk{
		enter{
			speed <- normal_speed;
			dest <- nodes closest_to self;
			tracking <+ location;
		}
		do walk_to target: dest;
		last_state <- "go_to_final_destination";
		if  norm(location - dest) < precision{
			location <- dest;
		}
		transition to: go_to_crosswalk when: norm(location - dest) < precision ;
	}
	
	state go_to_crosswalk{
		enter{
			current_waiting_area <- 
				first(current_area.waiting_areas where (each.opposite.my_walking_area = final_area));
			if current_waiting_area = nil{
				current_waiting_area <- one_of(current_area.waiting_areas);
			}				
			dest <- any_location_in(current_waiting_area);
			dest <- nodes closest_to dest;
			tracking <+ location;
			if norm(location - dest)>= precision{	
				do compute_virtual_path pedestrian_graph:network target: dest;
			}			
		}
		if norm(location - dest)>= precision{	
			do walk;
		}
		last_state <- "go_to_crosswalk";
		transition to: waiting_to_cross when: (norm(location - dest) < precision+2*shoulder_length);
	}
	
	state waiting_to_cross{
		enter{
			dest <- first(point(intersection(polyline(current_area.shape.points),polyline([location, location+current_waiting_area.direction]))));
			if dest = nil{
				dest <- any_location_in(current_waiting_area);
			}
			tracking <+ location;
		}	
		do walk_to target: dest;
		last_state <- "waiting_to_cross";
		transition to: crossing when: can_cross and (norm(location - dest) < 2);
	}
	
	state crossing{
		enter{
			geometry crossing_target <- intersection(current_waiting_area.opposite.shape,polyline([wait_location-current_waiting_area.direction,wait_location+current_waiting_area.direction]));
			if crossing_target != nil{
				dest <- any_location_in(crossing_target);
			}else{
				dest <- any_location_in(current_waiting_area.opposite);
			}
			tracking <+ location;
			current_area <- walking_area closest_to current_waiting_area.opposite;
		}
		if !can_cross{// boost to finish crossing before green light
			speed <- max(1,norm(dest-location)/(1#s+time_to_clear_crossing)) * normal_speed;
		}
		do walk_to target: dest;
		bool other_side_reached <- self.location distance_to current_area < 1#m;
		//transition to: go_to_crosswalk when: other_side_reached and (current_area != final_area);
		last_state <- "crossing";
		transition to: go_to_grid_before_crosswalk when: other_side_reached and (current_area != final_area);
		transition to: go_to_grid_before_final_destination when: other_side_reached and (current_area = final_area);
	}


	
	
	
	aspect default {
		draw square(shoulder_length/2 ) at: location+{shoulder_length/5, shoulder_length/5}color: #black;
		draw square(shoulder_length/2 ) at: location+{0,0,0.1} color: color;
	}
	
	aspect 3d {		
		draw pyramid(scale*shoulder_length/2) color: rgb(color,fading);
		draw sphere(scale*shoulder_length/4) at: location + {0,0,scale*shoulder_length/2} color: rgb(#black,fading);
		draw sphere(scale*shoulder_length*7/32) at: location + ({scale*shoulder_length/16,0,0} rotated_by (heading::{0,0,1}))+ {0,0,scale*shoulder_length*15/32} color: rgb(191,181,164,fading);	
		if for_debug{
			draw polyline(waypoints) width: 3 color: color;
		}
//		draw obj_file("../includes/obj/ShibuyaCharacter_01.obj")  at: location+{0,0,1} size: 1.5  color: #green  rotate: rotation_composition(-90::{1,0,0},heading::{0,0,1}) ;	
	}
	
		aspect debug {		
		draw pyramid(shoulder_length) color: color;
		draw sphere(shoulder_length/3) at: location + {0,0,shoulder_length*2/3} color: #black;
	
		draw circle(0.3*shoulder_length) color: color depth: 0.3 at: dest;
		draw cross(0.5*shoulder_length,0.2*shoulder_length) color: color at: final_dest depth: 0.3;
		int nb_segments <- int(perimeter(polyline([dest,final_dest])));
		loop i from: 0 to:nb_segments step:2{
			draw polyline(points_along(polyline([dest,final_dest]),[i/(nb_segments+1),(i+1)/(nb_segments+1)]))+0.1 color: color depth: 0.14;
		}

		if state = "go_to_crosswalk" or state = "go_to_final_destination"{
			point p <- centroid(first(waypoints));
			draw polyline(waypoints collect(centroid(each))) + 0.15 color: color depth: 0.15;
			draw polyline(tracking+p) + 0.15 depth: 0.15 color: rgb(color,0.2);
		}else{
			draw polyline([location,dest]) +0.15 color: color depth: 0.15;
			draw polyline(tracking+location) + 0.15 depth: 0.15 color: rgb(color,0.2);
		}
		
	}
}



species debug{
	aspect default{
//			loop e over: voronoi_diagram  {
//				draw e color: #blue border: #black;
//				draw circle(0.1) color: #red at: e.location;
//			}
		
		float sc <- 135.0;
//		draw photo at: {world.shape.width/2-15,world.shape.height/2-3.7} size: {3035/1609*sc,sc};
//		draw circle(10) at: {0,0} color: #yellow;
	}
	
	aspect traffic_light{
		draw union(crosswalk collect(each.shape)) color: can_cross?#green:#red;	
		ask intersection where each.is_traffic_signal{
			draw circle(3) at: location color: is_green?#green:#red;
		}
	}
	
	aspect grid{
		draw open_area color: #pink;
		loop p over: nodes{
			draw circle(0.5) at: p color: #yellow;
		}
		loop p over: nodes_inside{
			draw circle(0.2) at: p.location color: #red;
		}
	}
}





experiment "Parameter panel" virtual: true{
	parameter "Population" var: nb_people step: 10 min: 0 max: 5000 category: "Simulation";
	parameter "Cycle duration (s)" var: step step: 0.05 min: 0.05 max: 10.0 unit: "#s" category: "Simulation";
	category "Simulation"  expanded: true color: rgb(46, 204, 113);
	
	parameter "Parallelize computation" var: parallelize category: "Pedestrian simulation";
	parameter "P shoulder length" var: P_shoulder_length category: "Pedestrian simulation";
	parameter "P proba detour" var: P_proba_detour category: "Pedestrian simulation";
	parameter "P avoid other" var: P_avoid_other category: "Pedestrian simulation";
	parameter "P obstacle_consideration_distance" var: P_obstacle_consideration_distance  category: "Pedestrian simulation";
	parameter "P pedestrian consideration distance" var: P_pedestrian_consideration_distance  category: "Pedestrian simulation";
	parameter "P tolerance target" var: P_tolerance_target  category: "Pedestrian simulation";
	parameter "P use geometry target" var: P_use_geometry_target  category: "Pedestrian simulation";
	
	
	parameter "P model type" var: P_model_type among: ["simple", "advanced"]  category: "Pedestrian simulation"; 
	parameter "pedestrian path init" var: pedestrian_path_init among: ["voronoi", "grid"]  category: "Pedestrian simulation"; 
	
	parameter "P A pedestrian SFM advanced"  var: P_A_pedestrian_SFM_advanced category: "SFM advanced" ;
	parameter "P A obstacles SFM advanced"  var: P_A_obstacles_SFM_advanced category: "SFM advanced" ;
	parameter "P B_pedestrian_SFM_advanced"  var: P_B_pedestrian_SFM_advanced category: "SFM advanced" ;
	parameter "P B_obstacles_SFM_advanced"  var: P_B_obstacles_SFM_advanced category: "SFM advanced" ;
	parameter "P relaxion_SFM_advanced"  var: P_relaxion_SFM_advanced category: "SFM advanced" ;
	parameter "P gama_SFM_advanced"  var: P_gama_SFM_advanced category: "SFM advanced" ;
	parameter "P lambda_SFM_advanced" var: P_lambda_SFM_advanced  category: "SFM advanced" ;
	parameter "P minimal_distance_advanced" var: P_minimal_distance_advanced  category: "SFM advanced" ;
	
	parameter "P n_prime_SFM_simple"  var: P_n_prime_SFM_simple category: "SFM simple" ;
	parameter "P n_SFM_simple"  var: P_n_SFM_simple category: "SFM simple" ;
	parameter "P lambda_SFM_simple" var: P_lambda_SFM_simple  category: "SFM simple" ;
	parameter "P gama_SFM_simple"  var: P_gama_SFM_simple category: "SFM simple" ;
	parameter "P relaxion_SFM_simple"  var: P_relaxion_SFM_simple category: "SFM simple" ;
	parameter "P A_pedestrian_SFM_simple"  var: P_A_pedestrian_SFM_simple category: "SFM simple" ;
	
	parameter "Vehicle spawning interval" var: vehicle_spawning_interval category: "Simulation";
}




experiment "Shibuya Crossing" type: gui parent: "Parameter panel" {
	float minimum_cycle_duration <- 0.001#s;
	output  {
		display map type: 3d axes: false background: #darkgray toolbar: false{
			camera 'default' location: {98.4788,143.3489,64.7132} target: {98.6933,81.909,0.0};
			image photo refresh: false transparency: 0 ;	

			species train;// transparency: 0.03;
			species carriage;// transparency: 0.3;
			species fake_building transparency: 0.9;			
			species people aspect: 3d;
			species vehicle aspect: kawai;// transparency: 0.3;
			species traffic_signal;
			species building transparency: 0.3;
			species tree transparency: 0.3;
			species screen transparency: 0.2;
			

		}
	}
	
}


experiment "Shibuya Crossing with snapshots" type: gui parent: "Parameter panel" {
	float minimum_cycle_duration <- 0.001#s;
	output synchronized: true {
		display map type: 3d axes: false background: #darkgray toolbar: false{
//			camera 'default' location: {98.4788,143.3489,64.7132} target: {98.6933,81.909,0.0};
//			camera 'default' location: {98.4788,143.3489,64.7132}*(1-cycle/120) + {89.6265,108.4783,47.5701} *cycle/120
//			target:  {98.6933,81.909,0.0} * (1-cycle/120) + {89.7842,63.3143,0.0} * cycle/120;
//			camera 'default' location:pos target: targ;
			
			// view from other side
//			camera 'default' location:{0,143.3489,64.7132}*(1+cycle) target: {98.6933,81.909,0.0};
			
			camera 'default' location:cameraPosition target: cameraTarget dynamic: dynamicCamera lens: cameraLens;


			image photo refresh: false transparency: 0 ;	

			species train;// transparency: 0.03;
			species carriage;// transparency: 0.3;
			species fake_building transparency: 0.9;			
			species people aspect: 3d;
			species vehicle aspect: kawai;// transparency: 0.3;
			species traffic_signal;
			species building transparency: 0.3;
			species tree transparency: 0.3;
			species screen transparency: 0.3;
		}
	}
	
	reflex saveSnapshots when: (cycle>1) {
		ask simulation{
			save (snapshot("map")) to: "snapshots/img"+cycle+".png";
		}
	}
}


experiment "First person view" type: gui  {
	float minimum_cycle_duration <- 0.001#s;
	output {
		display map type: 3d axes: false background: #darkgray{
			camera #default dynamic: true location: {int(first(people).location.x), int(first(people).location.y), 1#m} target:
			{cos(first(people).heading) * first(people).speed + int(first(people).location.x), sin(first(people).heading) * first(people).speed + int(first(people).location.y), 1#m};
			species train;
			species fake_building transparency: 0.9;			
			image photo refresh: false transparency: 0 ;	
			species traffic_signal;
		 	species people aspect: 3d;
		 	species tree transparency: 0.6;
			species building transparency: 0.4;
			species vehicle transparency: 0.6;
			species screen transparency: 0.3;
		}
	}
}

experiment "Car view" type: gui  {
	float minimum_cycle_duration <- 0.001#s;
	output {
		display map type: 3d axes: false background: #darkgray{
			camera #default dynamic: true location: {int(first(vehicle).location.x), int(first(vehicle).location.y), 0.8#m} target:
			{cos(first(vehicle).heading) + int(first(vehicle).location.x), sin(first(vehicle).heading)  + int(first(vehicle).location.y), 0.8#m};
			species train;
			species fake_building transparency: 0.9;			
			image photo refresh: false transparency: 0 ;	
			species traffic_signal;
		 	species people aspect: 3d;
			species tree transparency: 0.6;
			species building transparency: 0.4;
			species vehicle transparency: 0.6;
			species screen transparency: 0.3;
		}
	}
}