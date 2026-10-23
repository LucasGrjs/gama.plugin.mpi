/**
* Name: mpi_migration
* A distributed simulation: agents move between ranks.
* The world is a ring of length n * strip, cut into n strips; rank r owns the walkers
* whose x is in [r * strip, (r + 1) * strip). Each cycle every walker moves; a walker
* that leaves its strip is sent to the rank that owns its new position and removed
* here. MPI_ALLTOALL_MIGRATION does the exchange: one list of walkers per destination
* rank, a map of received lists per source rank.
* A walker travels as a list of its attributes [id, x, speed] and is recreated on
* arrival.
* Each cycle, MPI_ALLGATHER of the ids checks that every walker exists exactly once.
* After the last cycle each rank writes the time spent in the exchanges
* (MPI_MIGRATION_TIME_MS, MPI_SERIALIZATION_TIME_MS, MPI_BARRIER_TIME_MS) and
* "PASS rank r" or "FAIL rank r ...".
*/
model mpi_migration

global {
	float strip <- 100.0;		// length of the part of the world owned by each rank
	int walkers_per_rank <- 50;
	int last_cycle <- 30;		// cycle that writes the result; finalStep in mpi_migration.xml is larger
	int r;
	int n;
	list<string> errors;

	init {
		create comm;
		r <- comm[0].MPI_RANK;
		n <- comm[0].MPI_SIZE;
		create walker number: walkers_per_rank {
			id <- r * walkers_per_rank + int(self);		// unique over all ranks
			x <- r * strip + rnd(strip - 0.001);
			speed <- rnd(-20.0, 20.0);
		}
	}

	reflex exchange {
		ask walker { x <- (x + speed + n * strip) mod (n * strip); }

		// walkers that left this rank's strip, by destination rank
		map<int, list> leaving;
		ask walker where (int(each.x / strip) != r) {
			int dest <- int(x / strip);
			leaving[dest] <- (leaving[dest] = nil ? [] : leaving[dest]) + [[id, x, speed]];
			do die;
		}

		map<int, list> arriving;
		list all_ids;
		ask comm {
			arriving <- MPI_ALLTOALL_MIGRATION(mesg: leaving);
			do MPI_BARRIER();
		}
		loop source over: arriving.keys {
			loop w over: list(arriving[source]) {
				list a <- list(w);
				create walker {
					id <- int(a[0]);
					x <- float(a[1]);
					speed <- float(a[2]);
				}
			}
		}

		// every walker is owned by exactly one rank, and by the right one
		ask comm { all_ids <- MPI_ALLGATHER(mesg: walker collect each.id); }
		if (length(all_ids) != n * walkers_per_rank or length(remove_duplicates(all_ids)) != length(all_ids)) {
			errors << "cycle " + cycle + ": " + length(all_ids) + " walkers";
		}
		if (walker one_matches (int(each.x / strip) != r)) { errors << "cycle " + cycle + ": walker outside the strip"; }

		if (cycle = last_cycle) {
			ask comm {
				write "rank " + r + ": " + length(walker) + " walkers; migration " + MPI_MIGRATION_TIME_MS()
					+ " ms, serialisation " + MPI_SERIALIZATION_TIME_MS() + " ms, barrier " + MPI_BARRIER_TIME_MS() + " ms";
			}
			write (empty(errors) ? "PASS rank " + r : "FAIL rank " + r + " " + errors);
		}
	}
}

species walker {
	int id;
	float x;
	float speed;
}

species comm skills: [MPI_SKILL] {}

experiment mpi_migration type: MPI_EXP {}
