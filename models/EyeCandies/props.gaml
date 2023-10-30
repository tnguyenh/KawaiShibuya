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



