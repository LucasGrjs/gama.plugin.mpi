/**
* Name: mpi_alltoall
* Smallest MPI example: each rank reads its rank and the number of ranks, sends one
* list of ints and one list of strings to every other rank with MPI_ALLTOALL, waits
* at a barrier, then checks what it received.
* Each rank writes "PASS rank r" or "FAIL rank r ...".
* Run it with run_mpi.sh (mpirun, one headless GAMA per rank).
*/
model mpi_alltoall

global {
	init {
		create comm;
		int r <- comm[0].MPI_RANK;
		int n <- comm[0].MPI_SIZE;

		// one message per destination rank
		map<int, list<int>> send_int;
		map<int, list<string>> send_str;
		loop dest from: 0 to: n - 1 {
			if dest != r {
				send_int[dest] <- [r * 100 + dest, r];
				send_str[dest] <- ["r" + r + "to" + dest];
			}
		}

		// exchange: each rank receives one entry per source rank
		map<int, list<int>> recv_int;
		map<int, list<string>> recv_str;
		ask comm {
			recv_int <- MPI_ALLTOALL(send_int);
			recv_str <- MPI_ALLTOALL(send_str);
			do MPI_BARRIER();
		}

		list<string> errors;
		loop src from: 0 to: n - 1 {
			if src != r {
				if recv_int[src] != [src * 100 + r, src] { errors << "int from " + src + ": " + recv_int[src]; }
				if recv_str[src] != ["r" + src + "to" + r] { errors << "str from " + src + ": " + recv_str[src]; }
			}
		}
		write (empty(errors) ? "PASS rank " + r : "FAIL rank " + r + " " + errors);
	}
}

species comm skills: [MPI_SKILL] {}

experiment mpi_alltoall type: MPI_EXP {}
