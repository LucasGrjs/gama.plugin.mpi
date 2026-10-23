/**
* Name: mpi_scatter
* MPI_SCATTER: one rank (the root) splits work between all ranks.
* The root builds a map rank -> list (shares can have different sizes); every rank
* receives its own list. Here each rank sums its share, then MPI_GATHER brings the
* partial sums back to the root, which checks the total.
* Every rank calls the action; only the root's mesg is used (the others pass an empty map).
* Each rank writes "PASS rank r" or "FAIL rank r ...".
*/
model mpi_scatter

global {
	init {
		create comm;
		int r <- comm[0].MPI_RANK;
		int n <- comm[0].MPI_SIZE;
		int root <- 0;
		list<int> numbers <- list<int>(1 to 100);

		// root: share the numbers round-robin between ranks
		map<int, list<int>> shares;
		if (r = root) {
			loop k from: 0 to: n - 1 { shares[k] <- numbers where (each mod n = k); }
		}

		list my_share;
		list partial_sums;
		ask comm {
			my_share <- MPI_SCATTER(mesg: shares, root: root);
			partial_sums <- MPI_GATHER(mesg: [sum(list<int>(my_share))], dest: root);
		}
		list<string> errors;
		if (my_share != numbers where (each mod n = r)) { errors << "share: " + my_share; }
		if (r = root and sum(list<int>(partial_sums)) != sum(numbers)) { errors << "total: " + partial_sums; }
		write (empty(errors) ? "PASS rank " + r + " (share of " + length(my_share) + " numbers)" : "FAIL rank " + r + " " + errors);
	}
}

species comm skills: [MPI_SKILL] {}

experiment mpi_scatter type: MPI_EXP {}
