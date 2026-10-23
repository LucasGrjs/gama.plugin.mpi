/**
* Name: mpi_hello
* MPI_RANK and MPI_SIZE: each rank says who it is.
* An agent with MPI_SKILL gives access to MPI; any species can have it.
* Each rank writes "PASS rank r" or "FAIL rank r ...".
*/
model mpi_hello

global {
	init {
		create comm;
		int r <- comm[0].MPI_RANK;	// this process: 0 .. MPI_SIZE - 1
		int n <- comm[0].MPI_SIZE;	// number of processes started by mpirun
		write "hello from rank " + r + " of " + n;
		write (r >= 0 and r < n ? "PASS rank " + r : "FAIL rank " + r + " size " + n);
	}
}

species comm skills: [MPI_SKILL] {}

experiment mpi_hello type: MPI_EXP {}
