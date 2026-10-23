/**
* Name: mpi_send_recv
* Blocking point-to-point messages: MPI_SEND and MPI_RECV.
* The ranks form a ring: each rank sends a message to the next one and receives
* from the previous one. Even ranks send first and odd ranks receive first, so no
* two neighbours wait on each other.
* Any GAML value can be sent (here a map); the tag identifies the message.
* Each rank writes "PASS rank r" or "FAIL rank r ...".
*/
model mpi_send_recv

global {
	init {
		create comm;
		int r <- comm[0].MPI_RANK;
		int n <- comm[0].MPI_SIZE;
		int next <- (r + 1) mod n;
		int previous <- (r - 1 + n) mod n;
		int tag <- 7;
		map<string, unknown> outgoing <- ["from"::r, "values"::[r, r * 10, r * 100]];
		unknown received;
		ask comm {
			if (r mod 2 = 0) {
				do MPI_SEND(mesg: outgoing, dest: next, stag: tag);
				received <- MPI_RECV(source: previous, rtag: tag);
			} else {
				received <- MPI_RECV(source: previous, rtag: tag);
				do MPI_SEND(mesg: outgoing, dest: next, stag: tag);
			}
		}
		map<string, unknown> m <- map<string, unknown>(received);
		bool ok <- m["from"] = previous and m["values"] = [previous, previous * 10, previous * 100];
		write (ok ? "PASS rank " + r : "FAIL rank " + r + " received " + received);
	}
}

species comm skills: [MPI_SKILL] {}

experiment mpi_send_recv type: MPI_EXP {}
