/**
* Name: mpi_end_micro
* Micro-model of mpi_end (end_mode "micro"): 2000 agents moving every step.
*/
model mpi_end_micro

global {
	init { create walker number: 2000; }
}

species walker skills: [moving] {
	reflex walk { do wander amplitude: 30.0; }
}

experiment Exp {}
