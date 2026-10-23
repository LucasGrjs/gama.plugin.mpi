/**
* Name: mpi_broadcast
* MPI_BROADCAST: one rank (the root) sends the same list to all ranks.
* Typical use: rank 0 reads or draws the parameters of a run, the others get them.
* Every rank calls the action; only the root's mesg is used (the others pass []).
* Each rank writes "PASS rank r" or "FAIL rank r ...".
*/
model mpi_broadcast

global {
	init {
		create comm;
		int r <- comm[0].MPI_RANK;
		int root <- 0;
		list parameters <- (r = root) ? ["scenario A", 42, 0.25] : [];
		list received;
		ask comm {
			received <- MPI_BROADCAST(mesg: parameters, root: root);
		}
		write (received = ["scenario A", 42, 0.25] ? "PASS rank " + r : "FAIL rank " + r + " received " + received);
	}
}

species comm skills: [MPI_SKILL] {}

experiment mpi_broadcast type: MPI_EXP {}
