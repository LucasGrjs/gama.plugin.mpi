/**
* Name: mpi_end
* End of a distributed run when the ranks finish at different times (test of the end of a run).
* Every step: MPI_ALLTOALL and a barrier, then "STEP <rank> <cycle>". On the last step, after the
* exchange, rank r keeps working r x delay ms; then, depending on end_mode:
*   "sleep"  nothing more: the fast ranks shut down while the slow ones still run
*   "abort"  one more exchange in the global abort block, run when the simulation is closed (needs
*            GAMA distribution-gama with the abort fix): "ABORT <rank> <number of ranks it received from>"
*   "micro"  as "sleep", with a micro-model (mpi_end_micro.gaml, 2000 agents) stepped every step
* Clean end: every rank writes every step (and its ABORT line), exit 0, no error. Run all cases with
* mpi_end_test.sh.
*/
model mpi_end

import "mpi_end_micro.gaml" as Micro

global {
	string end_mode <- "sleep";
	int last_cycle <- 19;
	int delay <- 3000;
	int r;
	int n;
	init {
		create comm;
		r <- comm[0].MPI_RANK;
		n <- comm[0].MPI_SIZE;
		if (end_mode = "micro") { create Micro.Exp; }
	}
	reflex exchange {
		if (end_mode = "micro") { ask Micro.Exp[0].simulation { do _step_; } }
		map<int, list<int>> send;
		loop dest from: 0 to: n - 1 { if dest != r { send[dest] <- [cycle, r]; } }
		map<int, list<int>> recv;
		ask comm {
			recv <- MPI_ALLTOALL(send);
			do MPI_BARRIER();
		}
		write "STEP " + r + " " + cycle;
		if (cycle = last_cycle) {
			float t0 <- gama.machine_time;
			loop while: gama.machine_time - t0 < r * delay { }
		}
	}
	abort {
		if (end_mode = "abort") {
			map<int, list<int>> send;
			loop dest from: 0 to: n - 1 { if dest != r { send[dest] <- [-1, r]; } }
			map<int, list<int>> recv;
			ask comm {
				recv <- MPI_ALLTOALL(send);
				do MPI_BARRIER();
			}
			write "ABORT " + r + " " + length(recv);
		}
	}
}

species comm skills: [MPI_SKILL] {}

experiment mpi_end type: MPI_EXP {
	parameter "end_mode" var: end_mode;
}
