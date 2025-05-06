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


model test


global{
		
	init{
		file f <- folder(carDirectory);
		
	}	
}



species car1 {
	rgb color <- rnd_color(255);
	
	carBody <- obj_file("../includes/obj/CarBody.obj");
	carOtherParts <- obj_file("../includes/obj/CarOthers.obj");
	carOtherPartsBraking <- obj_file("../includes/obj/CarOthersBraking.obj");
	
	obj_file carBody;
	obj_file carOtherParts;
	obj_file carOtherPartsBraking;
	
	// randomly choose one type of car when spawned
	
	
	
	
	// cars 3d models (car and truck)
	aspect default {
		draw carOtherParts  at: location+{0,0,0.93} size: 2  rotate: pair<float,point>(rotation_composition(-90::{1,0,0},heading+90::{0,0,1}) );	
		draw carBody  at: location+{0,0,1.26} size: 2 color: color rotate: rotation_composition(-90::{1,0,0},heading+90::{0,0,1}) ;	
	}

}
	
	
	
	






