/**
* Name: mpi_migration_agents
* Same distributed simulation as mpi_migration, but the walkers themselves are sent,
* not lists of their attributes.
* An agent put in a message travels as a full copy (all its attributes) and is
* recreated on arrival, in its population on the receiving rank, with the same index:
* the map returned by MPI_ALLTOALL_MIGRATION holds the arrived agents, already alive.
* Two rules follow:
* - kill the sent agents after the exchange (they are copied during the call);
* - agent indexes must differ between ranks: an arriving agent whose index is already
*   used on the receiving rank overwrites that agent. Here rank r first uses up the
*   indexes 0 .. r * walkers_per_rank - 1, so that each rank creates its walkers in
*   its own range, and no new walker is created afterwards.
* Each cycle, MPI_ALLGATHER of the indexes checks that every walker exists exactly once.
* After the last cycle each rank writes the number of migrations and "PASS rank r" or
* "FAIL rank r ...".
*/
model mpi_migration_agents

global {
	float strip <- 100.0;		// length of the part of the world owned by each rank
	int walkers_per_rank <- 50;
	int last_cycle <- 30;		// cycle that writes the result; finalStep in mpi_migration_agents.xml is larger
	int r;
	int n;
	list<string> errors;

	init {
		create comm;
		r <- comm[0].MPI_RANK;
		n <- comm[0].MPI_SIZE;
		// indexes 0 .. r * walkers_per_rank - 1 are left to the ranks before this one
		create walker number: r * walkers_per_rank { do die; }
		create walker number: walkers_per_rank {
			x <- r * strip + rnd(strip - 0.001);
			speed <- rnd(-20.0, 20.0);
			born_on <- r;
		}
		if (walker one_matches (int(each) < r * walkers_per_rank or int(each) >= (r + 1) * walkers_per_rank)) {
			errors << "indexes outside this rank's range: " + (walker collect int(each));
		}
	}

	reflex exchange {
		ask walker { x <- (x + speed + n * strip) mod (n * strip); }

		// walkers that left this rank's strip, by destination rank: the agents themselves
		list<walker> leaving_agents <- walker where (int(each.x / strip) != r);
		map<int, list> leaving;
		loop w over: leaving_agents {
			int dest <- int(w.x / strip);
			w.hops <- w.hops + 1;
			leaving[dest] <- (leaving[dest] = nil ? [] : leaving[dest]) + [w];
		}

		map<int, list> arriving;
		ask comm {
			arriving <- MPI_ALLTOALL_MIGRATION(mesg: leaving);	// arrived walkers are already created here
			do MPI_BARRIER();
		}
		ask leaving_agents { do die; }	// only after the exchange: they were copied during the call

		// every walker is owned by exactly one rank, and by the right one
		list all_indexes;
		ask comm { all_indexes <- MPI_ALLGATHER(mesg: walker collect int(each)); }
		if (length(all_indexes) != n * walkers_per_rank or length(remove_duplicates(all_indexes)) != length(all_indexes)) {
			errors << "cycle " + cycle + ": " + length(all_indexes) + " walkers";
		}
		if (walker one_matches (int(each.x / strip) != r)) { errors << "cycle " + cycle + ": walker outside the strip"; }

		if (cycle = last_cycle) {
			write "rank " + r + ": " + length(walker) + " walkers, born on ranks " + remove_duplicates(walker collect each.born_on)
				+ ", " + sum(walker collect each.hops) + " migrations";
			write (empty(errors) ? "PASS rank " + r : "FAIL rank " + r + " " + errors);
		}
	}
}

species walker {
	float x;
	float speed;
	int born_on;	// rank that created it
	int hops;		// number of times it moved to another rank
}

species comm skills: [MPI_SKILL] {}

experiment mpi_migration_agents type: MPI_EXP {}
