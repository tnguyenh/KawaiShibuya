/**
* Name: EyeCandies
* 
* Author: Tri Nguyen-Huu, Patrick Taillandier
* 
* Props for the Shibuya Crossing model. Includes several species used as eye candies:
* - buildings
* - fake buildings (to hide cars and pedestrian under bridges)
* - trees
*/



model props


global{
	// shape files declarations
	shape_file building_polygon_shape_file <- shape_file("../includes/building_polygon.shp");
	shape_file fake_building_polygon_shape_file <- shape_file("../includes/fake_buildings.shp");
	shape_file trees_shape_file <- shape_file("../includes/trees.shp");
	
	// the following map returns a list [height, radius,trunk_radius] for each kind of tree
	map<string,list<float>> tree_properties <- ["large"::[5#m,3#m,0.25#m],
												"medium"::[4#m,2.2#m,0.2#m],
												"small"::[1.5#m,0.75#m,0.15#m]];
	float trunk_radius <- 0.25#m;
	
	init{
		// buildings creation
		create building from: building_polygon_shape_file with:[height::float(get("height")),floor::float(get("floor")),invisible::bool(get("invisible"))]{
			location <- location + {0,0,floor};
		}
		
		// fake buildings creation
		create fake_building from: fake_building_polygon_shape_file{
			height <- 3.0;
		}
		
		// trees creation
		create tree from: trees_shape_file with:[size:string(get("size"))]{
			height <- tree_properties[size][0];
			radius <- tree_properties[size][1];
			trunk_radius <- tree_properties[size][2];
		}
	}
}

// species definitions

species building {
	float height;
	float floor <- 0.0;
	bool invisible <- false;
	
	aspect default {
		if !invisible{
		//	draw shape color: #yellow depth: height;
		}	
		if int(self)=0{
			draw obj_file("../includes/obj/ShibuyaBuildings.obj")  at: location+{73,-2,63} size: 320  color: #green rotate:-90::{1,0,0};	
		}
	}
}

species fake_building {
	float height;
	
	aspect default {
		draw shape color: #gray depth: height;		
	}
}


species tree{
	string size;
	float height;
	float radius;
	float trunk_radius;
	
	aspect default{
	//	draw circle(2*trunk_radius) depth: height color: #brown;
	//	draw sphere(2*radius) at: location+{0,0,height} color: #green;
		draw obj_file("../includes/obj/ShibuyaTree_01.obj")  at: location+{0,0,5} size: 10 color: #green rotate:-90::{1,0,0} ;	
	}
}

species screen{
	point dimensions;
	rgb color <- rgb(252,107,198);
	float angle;
	list<pair<int,list<rgb>>> sequence <-list( 
		10::[#black],
		50::[rgb(2,121,230),rgb(1,64,120)],
		5::[rgb(255,255,255)],
		5::[rgb(224,16,11)],
		5::[rgb(255,255,255)],
		5::[rgb(224,16,11)],
		5::[rgb(255,255,255)],
		5::[rgb(224,16,11)],
		5::[rgb(255,255,255)],
		20::[rgb(220,250,12)],
		35::[rgb(220,250,12),rgb(20,250,12)],
		10::[#black],
		12::[rgb(14,55,248)],
		7::[rgb(158,78,248)],
		10::[rgb(14,55,248)],
		20::[#black],
		55::[#black,#orange],
		5::[#white],
		10::[#orange],
		40::[rgb(12,50,152),rgb(15,64,193)],
		5::[#black],
		10::[#black,rgb(252,107,198)],
		50::[rgb(252,107,198)]
	);
	int currentState <- 0;
	int stepsToNextState <- sequence[currentState].key;
	
	reflex updateScreen{
		if (stepsToNextState = 0){
			currentState <- (currentState + 1) mod length(sequence);
			stepsToNextState <- sequence[currentState].key;
			if (length(sequence[currentState].value) = 1){
				color <- sequence[currentState].value[0];
			}
		}else{
			stepsToNextState <- stepsToNextState - 1;
			if (length(sequence[currentState].value) = 2){
				color <- blend(sequence[currentState].value[0],sequence[currentState].value[1],stepsToNextState/sequence[currentState].key);
			}
		}
		
	}
	
	aspect default{
		draw box(dimensions) color: color rotate: angle;
//		draw box(6.05#m,1#m,20#m) at: {72.15,20.35, 7} color: color rotate: 10;
//		draw box(7.7#m,1#m,20#m) at: {78.85,20.7, 7} color: color rotate: -2.5;
//		draw box(6.4#m,1#m,20#m) at: {85.5,19.36, 7} color: color rotate: -22;
		
	}
	
}



