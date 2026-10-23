/**
* Name: mpi_isend_irecv
* Non-blocking point-to-point messages: MPI_ISEND and MPI_IRECV.
* MPI_ISEND returns at once. MPI_IRECV returns the message if one has arrived,
* nil otherwise: the rank can do other work between two checks.
* Each rank sends a string to the next rank in the ring, then polls until the
* message of the previous rank is there.
* Each rank writes "PASS rank r" or "FAIL rank r ...".
*/
model mpi_isend_irecv

global {
	init {
		create comm;
		int r <- comm[0].MPI_RANK;
		int n <- comm[0].MPI_SIZE;
		int next <- (r + 1) mod n;
		int previous <- (r - 1 + n) mod n;
		int tag <- 3;
		unknown received <- nil;
		int checks <- 0;
		ask comm {
			do MPI_ISEND(mesg: "message from " + r, dest: next, stag: tag);
			loop while: received = nil and checks < 1000000 {
				received <- MPI_IRECV(source: previous, rtag: tag);	// nil while nothing has arrived
				checks <- checks + 1;
			}
			do MPI_BARRIER();	// no rank leaves before its message has been received
		}
		bool ok <- received = "message from " + previous;
		write (ok ? "PASS rank " + r + " (" + checks + " checks)" : "FAIL rank " + r + " received " + received);
	}
}

species comm skills: [MPI_SKILL] {}

experiment mpi_isend_irecv type: MPI_EXP {}
