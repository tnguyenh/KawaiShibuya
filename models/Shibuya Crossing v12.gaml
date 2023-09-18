/**
* Name: ShibuyaCrossing
* Based on the internal skeleton template. 
* Author: Tri Nguyen-Huu, Patrick Taillandier
* Tags: 
*/

model ShibuyaCrossing

global {
	int nb_people <- 200;
	float step <- 0.25#s;
	
	float car_spawning_interval <- 5#s;
	float global_max_speed <- 40 #km / #h;
	float precision <- 0.2;
	float factor <- 1.0;
	float mesh_size <- 2.0;
	float coef_update_orientation <- 0.1; //0 is fast, 1 is slow
	
	float node_tolerance <- 0.0001;
	
	float train_max_speed <- 90 #km/#h;
	float carriage_length <- 19.5#m;
	float space_between_carriages <- 0.3#m;
	map<string,int> nb_carriages <- ["Yamanote"::11,"Saikyo"::10];
	float time_stop_in_station <- 45#s;
	map<string,float> spawn_time <- ["Yamanote_1"::150#s,"Yamanote_2"::150#s,"Saikyo_1"::150#s,"Saikyo_2"::150#s];
	
	rgb yamanote_green <- rgb(154, 205, 50);
	rgb saikyo_green <- rgb(46,139,87);
	rgb window <- rgb(1,44,78);
	rgb shonan_orange <- rgb(246,139,30);
	rgb shonan_green <- rgb(100,185,102);
			
	list<float> schedule_times <- [ 15#s, // pedestrian light to green
									60#s, // pedestrian light to red
									85#s, // car group 1 to green
									100#s,// car group 1 to red
									105#s,// car group 2 to green
									120#s // car group 2 to red
								  ];
	
	shape_file bounds <- shape_file("../includes/Shibuya.shp");
	//shape_file bounds <- shape_file("../includes/Shibuya.shp");
	//shape_file bounds_extended <- shape_file("../includes/Shibuya_extended_boundaries.shp");
	//shape_file bounds <- shape_file("../includes/walking area.shp");

	
	image_file photo <- (image_file(("../includes/Shibuya.png")));

	shape_file building_polygon_shape_file <- shape_file("../includes/building_polygon.shp");
	shape_file fake_building_polygon_shape_file <- shape_file("../includes/fake_buildings.shp");
	shape_file crosswalk_shape_file <- shape_file("../includes/crosswalk.shp");
	shape_file walking_area_shape_file <- shape_file("../includes/walking area.shp");
	shape_file road_shape_file <- shape_file("../includes/roads.shp");
	shape_file traffic_signals_shape_file <- shape_file("../includes/traffic_signals.shp");
	shape_file trees_shape_file <- shape_file("../includes/trees.shp");
	shape_file rail_shape_file <- shape_file("../includes/rail_tracks.shp");

	
	geometry shape <- envelope(bounds);
	//geometry shape <- envelope(road_shape_file);
	
	
	float P_shoulder_length <- 1.0 parameter: true;
	float P_proba_detour <- 0.5 parameter: true ;
	bool P_avoid_other <- true parameter: true ;
	float P_obstacle_consideration_distance <- 3.0 parameter: true ;
	float P_pedestrian_consideration_distance <- 3.0 parameter: true ;
	float P_tolerance_target <- 0.1 parameter: true;
	bool P_use_geometry_target <- true parameter: true;
	
	
	string P_model_type <- "simple" among: ["simple", "advanced"] parameter: true ; 
	string pedestrian_path_init <- "grid" among: ["voronoi", "grid"] parameter: true ; 
	
	float P_A_pedestrian_SFM_advanced parameter: true <- 0.0001 category: "SFM advanced" ;
	float P_A_obstacles_SFM_advanced parameter: true <- 1.9 category: "SFM advanced" ;
	float P_B_pedestrian_SFM_advanced parameter: true <- 0.1 category: "SFM advanced" ;
	float P_B_obstacles_SFM_advanced parameter: true <- 1.0 category: "SFM advanced" ;
	float P_relaxion_SFM_advanced  parameter: true <- 0.5 category: "SFM advanced" ;
	float P_gama_SFM_advanced parameter: true <- 0.35 category: "SFM advanced" ;
	float P_lambda_SFM_advanced <- 0.1 parameter: true category: "SFM advanced" ;
	float P_minimal_distance_advanced <- 0.25 parameter: true category: "SFM advanced" ;
	
	float P_n_prime_SFM_simple parameter: true <- 3.0 category: "SFM simple" ;
	float P_n_SFM_simple parameter: true <- 2.0 category: "SFM simple" ;
	float P_lambda_SFM_simple <- 2.0 parameter: true category: "SFM simple" ;
	float P_gama_SFM_simple parameter: true <- 0.35 category: "SFM simple" ;
	float P_relaxion_SFM_simple parameter: true <- 0.54 category: "SFM simple" ;
	float P_A_pedestrian_SFM_simple parameter: true <-4.5category: "SFM simple" ;
	graph network;
	

	bool can_cross <- false;
	float time_since_last_spawn <- 0.0;
	
	people the_people;
	point endpoint;
	int schedule_step <- 0;
	float schedule_time <- 0.0;
	float time_to_clear_crossing <- 0.0;
	float percent_time_remaining <- (schedule_times[0] )/(schedule_times[5] + schedule_times[0] - schedule_times[1]);

	
	geometry open_area;

	graph road_network;	
	graph rail_network;
	graph rail_moving_graph;

	list<geometry> walking_area_divided;
	list<point> nodes;
	list<geometry> nodes_inside;
	list<geometry> voronoi_diagram;
	
	map<string,float> time_to_spawn;
	list<string> line_names;
	
	init {
		gama.pref_opengl_z_factor <- 0.0;
		
		create rail from: rail_shape_file with: [name::string(get("name"))]{
			if self.name = "Yamanote_1"{
				self.shape <- polyline(reverse(self.shape.points));
			}		
		}
		do clean_railroad;
		
		list<point> first_points <- rail collect first(each.shape.points);
		list<point> last_points <- rail collect last(each.shape.points);
			
		ask rail{
			create rail_wp{
				location <- last(myself.shape.points);
				is_traffic_signal <- true;
			}
		}
		
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
	//		time_to_spawn << l::0;
			time_to_spawn << l::rnd(57)#s;
		}
		
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
		
		road_network <- as_driving_graph(road,intersection);
		
		
		ask intersection where (each.group > 0) {
			do initialize;
		}
		
		ask intersection where (each.is_spawn_location){
			final_intersection <- compute_target();
		}
			
		create building from: building_polygon_shape_file with:[height::float(get("height")),floor::float(get("floor")),invisible::bool(get("invisible"))]{
			location <- location + {0,0,floor};
		}
		
		create tree from: trees_shape_file with:[size:string(get("size"))]{
			if size = "large"{
				height <- 5#m;
				radius <- 3#m;
			}
			if size = "small"{
				height <- 1.5#m;
				radius <- 0.75#m;
			}
		}
		
		create fake_building from: fake_building_polygon_shape_file{
			height <- 3.0;
		}
		

		
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
		geometry bounds_shape;
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
			obstacle_species<-[building];
			location <- any_location_in(bounds_shape);
			dest <- location;
			final_dest <- location;
			current_waiting_area <- nil;

			obstacle_consideration_distance <-P_obstacle_consideration_distance;
			pedestrian_consideration_distance <-P_pedestrian_consideration_distance;
			shoulder_length <- P_shoulder_length;
			avoid_other <- P_avoid_other;
			proba_detour <- P_proba_detour;
			
			use_geometry_waypoint <- P_use_geometry_target;
			tolerance_waypoint<- P_tolerance_target;
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
	
		create debug;
		loop times: 12{
			do spawn_car;
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
	}
	
	action spawn_car{
		intersection i <- one_of(intersection where (each.is_spawn_location));
		create car with: (location: i.location, target: i.final_intersection);
		
	}

action spawn_train(string line_name){
		write "Spawning "+line_name;
		list<carriage> created_carriages;
		train loco;
		string train_type <- copy_between(line_name,0,length(line_name)-2);
		bool shaikyo_type <- flip(0.5);
		
		ask rail_wp where (each.name = line_name and each.loco_spawn){
			rail out <- rail(first(roads_out));
			create train {
				type <- train_type;
				location <- myself.location;
				target <- myself.final_intersection;
//				safety_distance_coeff <- 0.0;
//				min_safety_distance <- 0.0#m;
//				min_security_distance <- 0.0#m;
//				security_distance_coeff <- 0.0;
//				time_headway <- 0.0;			
				heading <- angle_between(first(out.shape.points),first(out.shape.points)+{1.0,0},out.shape.points[1]);
				loco <- self;
				max_deceleration <- 2#km/#h/#s;
				do init(shaikyo_type);
			}
		}

		ask rail_wp where (each.name = line_name and !each.loco_spawn){	
			rail out <- rail(first(roads_out));	
			create carriage {
				type <- train_type;
				location <- myself.location;
				target <- myself.final_intersection;
				heading <- angle_between(first(out.shape.points),first(out.shape.points)+{1.0,0},out.shape.points[1]);
				speed <- 70#km/#h;
				name <- line_name+" carriage "+int(self);
				created_carriages << self;
				locomotive <- loco;
				last_carriage <- myself.last_carriage;
				do init(shaikyo_type);
			}
		}	
		loco.carriages <- created_carriages;
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
	
	
	reflex train_scheduler{
		loop l over: line_names{
			put (time_to_spawn[l]-step) at: l in: time_to_spawn;
			if time_to_spawn[l] < 0{
				do spawn_train(l);
				put (spawn_time[l]+rnd(10.0)#s) at: l in: time_to_spawn;
			}
		}
		
		
	}
	
	reflex main_scheduler{
		int cycle_time <- 1200;
		bool advance_step <- false;
		
		// spawn cars
		
		if time_since_last_spawn > car_spawning_interval {
			do spawn_car;
			time_since_last_spawn <- 0.0;
		}else{
			time_since_last_spawn <- time_since_last_spawn + step;
		}
		
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

species rail skills: [road_skill]{
	float maxspeed <- train_max_speed;
	rgb color <- #black;
	
	aspect default {
		draw shape color: color;
	}
}


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
//	string current_color <- "red";
	
	action initialize{
		is_traffic_signal <- true;
		stop << [];
		loop rd over: roads_in {
			ways << rail(rd);
		}
		do to_red;
	}
	
	rail_wp compute_target{
		if empty(roads_out){
			return self;
		}else{
			return rail_wp(rail(first(roads_out)).target_node).compute_target();
		}
	}
	
	action to_green {
		stop[0] <- [];
		is_green <- true;
		color <- #green;
	}
	

	//shift the traffic light to red
	action to_red {
		stop[0] <- ways;
		is_green <- false;
		color <- #red;
	}
	
	reflex turn_to_red when: is_green {
		wait_time <- wait_time + step;
		if wait_time > 15#s{
			do to_green;
			wait_time <- 0.0;
		}
	}
	
	action trigger_signal{
		wait_time <- wait_time + step;
		if wait_time > time_stop_in_station{
			do to_green;
			wait_time <- 0.0;
		}
	}
	
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
	
	aspect debug {
		draw rectangle(19.5#m, 2.95#m ) depth: 2#m color: rgb(#grey,40) rotate: orientation at: location;	
	}
	
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
		// wireframe box
		//draw rectangle(19.5#m, 2.95#m ) depth: 2.62#m  wireframe: true rotate: orientation at: location+{0,0,1} border: #black;		

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

species train skills: [driving] parent: rolling_stock{
	float loco_speed;
	list<carriage> carriages;
	bool is_carriage <- false;
	
	init {
		vehicle_length <- 19.5 #m;
		max_speed <- train_max_speed;
	}
	
	//choose a random target and compute the path to it
	reflex choose_path when: final_target = nil {
		do compute_path graph: rail_network target: target; 
	}
	
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
	
	reflex stat when: false{
		float speed_kmh <- round(10 * self.speed * 3600 / 1000) / 10;
		float acceleration_kmh_s <- round(10 * acceleration * 3600 / 1000) / 10;
		write ""+self+" Speed: "+speed_kmh+"km/h. Acc: "+acceleration_kmh_s+"km/h/s.";	
	}
}


species carriage skills: [moving] parent: rolling_stock{
	train locomotive;
	bool is_carriage <- true;
	
	action carriage_move  {
		do goto target: target on: rail_moving_graph speed: locomotive.loco_speed;
		orientation <- heading + coef_update_orientation*(orientation - heading);
	}
}




















species road skills: [road_skill]{
	int group;
	int num_lanes <- 1;
	float maxspeed <- global_max_speed;
	
	aspect default {
		draw shape color: #red;
	}
}





species intersection skills: [intersection_skill] {
	bool is_traffic_signal <- false;
	bool is_spawn_location <- false;
	int group;
	intersection final_intersection <- nil;
	rgb color <- #white;

	//take into consideration the roads coming from both direction (for traffic light)
	list<road> ways;
	
	//if the traffic light is green
	bool is_green;
	string current_color <- "red";
//	rgb color <- #yellow;

	aspect default{
		draw circle(0.5) color: color;
	}
	
	action initialize{
		is_traffic_signal <- true;
		stop << [];
		loop rd over: roads_in {
			ways << road(rd);
		}
		do to_red;
	}
	
	intersection compute_target{
		if empty(roads_out){
			return self;
		}else{
			return intersection(road(first(roads_out)).target_node).compute_target();
		}
	}
	
	action to_green {
		stop[0] <- [];
		is_green <- true;
		color <- #green;
		current_color <- "green";
	}
	
	action to_orange{
		current_color <- "orange";
	}

	//shift the traffic light to red
	action to_red {
		stop[0] <- ways;
		is_green <- false;
		current_color <- "red";
		color <- #red;
	}
}

species car skills: [driving] {
	rgb color <- rnd_color(255);
	rgb color2;
	intersection target;
	string type <- "car" among: ["car","truck"];
	
	init {
		type <- rnd_choice(["car"::0.9,"truck"::0.1]);
		switch type {
			match "car"{
				vehicle_length <- 4.0 #m;
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
	
	reflex move when: final_target != nil {
		do drive;
		//if arrived at target, die and create a new car
		if (final_target = nil) {
			do unregister;
			do die;
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
//					draw (triangle(0.5#m,0.5#m)rotated_by(-90::{1,0,0})) rotate: heading  color: #black depth: 1.6#m at: location +  {0,0,1} + ({-1#m,0.8,0} rotated_by (heading::{0,0,1}));
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


species building {
	float height;
	float floor <- 0.0;
	bool invisible <- false;
	
	aspect default {
		if !invisible{
			draw shape color: #gray depth: height;
		}	
	}
}

species fake_building {
	float height;
	
	aspect default {
		draw shape color: #gray depth: height;		
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




species people skills: [pedestrian] control: fsm{
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
	bool tester <- false;

	
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
	//	transition to: waiting_to_cross when: (norm(location - dest) < precision) or (distance_to(self,current_waiting_area)< shoulder_length);
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
		draw pyramid(scale*shoulder_length/2) color: color;
		draw sphere(scale*shoulder_length/4) at: location + {0,0,scale*shoulder_length/2} color: #black;
		draw sphere(scale*shoulder_length*7/32) at: location + ({scale*shoulder_length/16,0,0} rotated_by (heading::{0,0,1}))+ {0,0,scale*shoulder_length*15/32} color: rgb(191,181,164);	
		if tester{
			draw polyline(waypoints) width: 3 color: color;
		}
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
	float t_z <- 3.5#m;
	float heading;

	
	reflex find_color{
		current_color <- first(intersection where (each.group = self.group)).current_color;
	}
	
	
	aspect default{
		// draw the pole
		draw circle(0.15#m) depth: light_z+1#m color: #grey;
		// draw the car lights
		if car_light != "none"{
			draw circle(0.05#m) rotated_by(-90,{0,1,0}) depth: light_x at: location+{0,0,light_z} rotate: heading color: #grey;
		}
		if (car_light = "normal" or car_light = "both"){
			draw rectangle(1,0.1) depth: 0.3#m at: location+({light_x,0.1,light_z-0.15} rotated_by (heading::{0,0,1})) 
				rotate: heading color: #grey;
			draw sphere(0.1#m) at: location+({light_x-0.3,0.15,light_z-0.1} rotated_by (heading::{0,0,1}))
				color: current_color="green"?#green:rgb(100,100,100);
			draw sphere(0.1#m) at: location+({light_x,0.15,light_z-0.1} rotated_by (heading::{0,0,1}))
				color: current_color="orange"?#orange:rgb(100,100,100);
			draw sphere(0.1#m) at: location+({light_x+0.3,0.15,light_z-0.1} rotated_by (heading::{0,0,1}))
				color: current_color="red"?#red:rgb(100,100,100);			
		}
		if (car_light = "reverse" or car_light = "both"){
			draw rectangle(1,0.1) depth: 0.3#m at: location+({light_x,-0.1,light_z-0.15} rotated_by (heading::{0,0,1})) 
				rotate: heading color: #grey;
			draw sphere(0.1#m) at: location+({light_x-0.3,-0.15,light_z-0.1} rotated_by (heading::{0,0,1}))
				color: current_color="green"?#green:rgb(100,100,100);
			draw sphere(0.1#m) at: location+({light_x,-0.15,light_z-0.1} rotated_by (heading::{0,0,1}))
				color: current_color="orange"?#orange:rgb(100,100,100);
			draw sphere(0.1#m) at: location+({light_x+0.3,-0.15,light_z-0.1} rotated_by (heading::{0,0,1}))
				color: current_color="red"?#red:rgb(100,100,100);			
		}	
		//draw left crossing signal
		if crosswalk_left > 0{
			draw square(0.04#m) rotated_by(-90,{0,1,0}) depth: t_x at: location+{0,0,t_z} rotate: heading_l+90 color: #grey;
			draw rectangle(0.3,0.15) depth: 0.6 at: location+({0,t_x,t_z-0.65} rotated_by (heading_l::{0,0,1})) rotate: heading_l+90 color: #grey;
			draw square(0.04) depth: 0.05 at: location+({0,t_x-0.02,t_z-0.05} rotated_by (heading_l::{0,0,1})) rotate: heading_l+90 color: #grey;
			
			if world.schedule_step = 1{
				draw rectangle(0.05,0.02) depth: 0.2*world.percent_time_remaining at: location+({0.07,t_x+0.07,t_z-0.31} rotated_by (heading_l::{0,0,1})) 
					rotate: heading_l+90 color: #green;
				draw rectangle(0.05,0.02) depth: 0.2*world.percent_time_remaining at: location+({0.07,t_x-0.07,t_z-0.31} rotated_by (heading_l::{0,0,1})) 
					rotate: heading_l+90 color: #green;
				draw triangle(0.15,0.2) rotated_by(-90,{1,0,0}) at: location+({0.08,t_x,t_z-0.55} rotated_by (heading_l::{0,0,1})) 
					rotate: heading_l+90 color: #green;
				draw circle(0.05) rotated_by(-90,{1,0,0}) at: location+({0.08,t_x,t_z-0.45} rotated_by (heading_l::{0,0,1})) 
					rotate: heading_l+90 color: #green;
				
			}else{
				draw rectangle(0.05,0.02) depth: 0.2*world.percent_time_remaining at: location+({0.07,t_x+0.07,t_z-0.61} rotated_by (heading_l::{0,0,1})) 
				rotate: heading_l+90 color: #red;
				draw rectangle(0.05,0.02) depth: 0.2*world.percent_time_remaining at: location+({0.07,t_x-0.07,t_z-0.61} rotated_by (heading_l::{0,0,1})) 
				rotate: heading_l+90 color: #red;
					draw triangle(0.15,0.2) rotated_by(-90,{1,0,0}) at: location+({0.08,t_x,t_z-0.25} rotated_by (heading_l::{0,0,1})) 
					rotate: heading_l+90 color: #red;
				draw circle(0.05) rotated_by(-90,{1,0,0}) at: location+({0.08,t_x,t_z-0.15} rotated_by (heading_l::{0,0,1})) 
					rotate: heading_l+90 color: #red;
			}	
		}
		
		if crosswalk_right > 0{
			draw square(0.04#m) rotated_by(-90,{0,1,0}) depth: t_x at: location+{0,0,t_z} rotate: heading_r-90 color: #grey;
			draw rectangle(0.3,0.15) depth: 0.6 at: location+({0,-t_x,t_z-0.65} rotated_by (heading_r::{0,0,1})) rotate: heading_r-90 color: #grey;
			draw square(0.04) depth: 0.05 at: location+({0,-t_x+0.02,t_z-0.05} rotated_by (heading_r::{0,0,1})) rotate: heading_r-90 color: #grey;
			if world.schedule_step = 1{
				draw rectangle(0.05,0.02) depth: 0.2*world.percent_time_remaining at: location+({0.07,-t_x+0.07,t_z-0.31} rotated_by (heading_r::{0,0,1})) 
					rotate: heading_r+90 color: #green;
				draw rectangle(0.05,0.02) depth: 0.2*world.percent_time_remaining at: location+({0.07,-t_x-0.07,t_z-0.31} rotated_by (heading_r::{0,0,1})) 
					rotate: heading_r+90 color: #green;
				draw triangle(0.15,0.2) rotated_by(-90,{1,0,0}) at: location+({0.08,-t_x,t_z-0.55} rotated_by (heading_r::{0,0,1})) 
					rotate: heading_r+90 color: #green;
				draw circle(0.05) rotated_by(-90,{1,0,0}) at: location+({0.08,-t_x,t_z-0.45} rotated_by (heading_r::{0,0,1})) 
					rotate: heading_r+90 color: #green;
			}else{
				draw rectangle(0.05,0.02) depth: 0.2*world.percent_time_remaining at: location+({0.07,-t_x+0.07,t_z-0.61} rotated_by (heading_r::{0,0,1})) 
				rotate: heading_r+90 color: #red;
				draw rectangle(0.05,0.02) depth: 0.2*world.percent_time_remaining at: location+({0.07,-t_x-0.07,t_z-0.61} rotated_by (heading_r::{0,0,1})) 
				rotate: heading_r+90 color: #red;
				draw triangle(0.15,0.2) rotated_by(-90,{1,0,0}) at: location+({0.08,-t_x,t_z-0.25} rotated_by (heading_r::{0,0,1})) 
					rotate: heading_r+90 color: #red;
				draw circle(0.05) rotated_by(-90,{1,0,0}) at: location+({0.08,-t_x,t_z-0.15} rotated_by (heading_r::{0,0,1})) 
					rotate: heading_r+90 color: #red;
			}	
			
		}
	}
}

species tree{
	string size;
	float height <- 4#m;
	float radius <- 2.2#m;
	
	aspect default{
		draw circle(0.5) depth: height color: #brown;
		draw sphere(2*radius) at: location+{0,0,height} color: #green;
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










experiment "Shibuya Crossing" type: gui  {
	float minimum_cycle_duration <- 0.001#s;
	output {
		display map type: 3d axes: false background: #darkgray{
			camera 'default' location: {98.4788,143.3489,64.7132} target: {98.6933,81.909,0.0};
//			camera 'default' location: {198.4788+50,143.3489-300,14.7132} target: {198.6933,81.909-300+40,0.0};
		//			species debug;
		//	species rail;
			species train transparency: 0.6;
			species carriage transparency: 0.6;
			species fake_building transparency: 0.9;			
		//	image im refresh: false transparency: 0 position: {-100,0,0} size: {3035,1609};	
			image photo refresh: false transparency: 0 ;	
			
			species traffic_signal;
		//	species pedestrian_path aspect: default;
			species people aspect: 3d;
		//	species people aspect: debug;
			species car transparency: 0.6;

			species rail_wp;

			species building transparency: 0.4;
			species tree transparency: 0.7;

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
			species car transparency: 0.6;
		}
	}
}

experiment "Car view" type: gui  {
	float minimum_cycle_duration <- 0.001#s;
	output {
		display map type: 3d axes: false background: #darkgray{
			camera #default dynamic: true location: {int(first(car).location.x), int(first(car).location.y), 0.8#m} target:
			{cos(first(car).heading) + int(first(car).location.x), sin(first(car).heading)  + int(first(car).location.y), 0.8#m};
			species train;
			species fake_building transparency: 0.9;			
			image photo refresh: false transparency: 0 ;	
			species traffic_signal;
		 	species people aspect: 3d;
			species tree transparency: 0.6;
			species building transparency: 0.4;
			species car transparency: 0.6;
		}
	}
}