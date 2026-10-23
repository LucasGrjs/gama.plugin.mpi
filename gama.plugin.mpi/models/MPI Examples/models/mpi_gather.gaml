/**
* Name: mpi_gather
* Collecting values from all ranks:
* - MPI_GATHER: the lists of all ranks, concatenated in rank order, on one rank
*   (dest). The other ranks get an empty list.
* - MPI_ALLGATHER: the same concatenation, on every rank.
* Lists can have different lengths on each rank: here rank r contributes r + 1 values.
* Each rank writes "PASS rank r" or "FAIL rank r ...".
*/
model mpi_gather

global {
	init {
		create comm;
		int r <- comm[0].MPI_RANK;
		int n <- comm[0].MPI_SIZE;
		list<int> mine <- list_with(r + 1, r);	// rank 2 contributes [2, 2, 2]

		list<int> expected;
		loop k from: 0 to: n - 1 { expected <- expected + list_with(k + 1, k); }

		list gathered;
		list everyone;
		ask comm {
			gathered <- MPI_GATHER(mesg: mine, dest: 0);
			everyone <- MPI_ALLGATHER(mesg: mine);
		}
		list<string> errors;
		if (r = 0 and gathered != expected) { errors << "gather: " + gathered; }
		if (r != 0 and !empty(gathered)) { errors << "gather on a non-root rank: " + gathered; }
		if (everyone != expected) { errors << "allgather: " + everyone; }
		write (empty(errors) ? "PASS rank " + r : "FAIL rank " + r + " " + errors);
	}
}

species comm skills: [MPI_SKILL] {}

experiment mpi_gather type: MPI_EXP {}
