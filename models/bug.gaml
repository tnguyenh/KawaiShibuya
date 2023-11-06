
model bug

global{
	init{
		pair<float,point> var0 <- rotation_composition([38.0::{1,1,1},90.0::{1,0,0}]);
		write var0;
	}
}


experiment bug type: gui {
}