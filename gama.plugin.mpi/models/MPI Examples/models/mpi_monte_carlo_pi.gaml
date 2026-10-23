/**
* Name: mpi_monte_carlo_pi
* Estimating pi with random darts on all ranks, with snapshots to resume a run.
*
* The circle of radius 1 is split in 4 quadrants: rank r throws its darts in quadrant
* r mod 4 (0: x > 0, y > 0; 1: x < 0, y > 0; 2: x < 0, y < 0; 3: x > 0, y < 0), so 4 ranks
* cover the whole circle. Each cycle every rank throws darts_per_cycle random points in
* its quadrant's square and counts those inside the circle (x² + y² <= 1). MPI_ALLGATHER
* sums the counts of all ranks: pi ~ 4 * hits / darts. Each rank has its own random seed.
*
* Snapshots: every checkpoint_every cycles each rank saves its whole simulation
* (save simulation, GAMA's binary serialisation) in the folder slot_a or slot_b of
* checkpoint_dir, alternately. After an MPI_BARRIER, i.e. once every rank has saved,
* rank 0 writes "slot;cycle" in checkpoint_dir/latest.txt. A crash while saving thus
* never spoils the last complete snapshot.
* Run with resume = true: each rank restores its own file from the slot named in
* latest.txt (restore simulation) and the run goes on from that cycle. The random
* generator is part of the snapshot: a resumed run ends with the same counts as an
* uninterrupted one.
*
* Display "pi" (one per rank): this rank's quadrant with this cycle's darts (blue inside,
* orange outside; the circle's centre is the corner facing the other quadrants), the
* estimate over the cycles against pi, the snapshots (grey lines) and the resume (green).
*
* At cycle total_cycles each rank writes its counts, rank 0 the estimate, and each
* rank "PASS rank r" or "FAIL rank r ..." (darts = darts_per_cycle * cycles on every
* rank, estimate within 0.01 of pi).
*/
model mpi_monte_carlo_pi

global {
	geometry shape <- rectangle(210, 120);
	int darts_per_cycle <- 20000;
	int total_cycles <- 20;
	int r;
	int n;
	int quadrant;		// r mod 4
	float xmin;			// this quadrant's square: [xmin, xmin + 1] x [ymin, ymin + 1]
	float ymin;
	int cycles_done <- 0;
	int hits <- 0;
	int darts <- 0;
	float estimate <- 0.0;			// all ranks
	list<float> estimates;			// estimate after each cycle
	list<point> recent_in;			// darts of this cycle shown in the display (first shown_darts)
	list<point> recent_out;
	int shown_darts <- 1500;
	list<int> snapshot_cycles;		// set by the experiment
	int resumed_from <- -1;			// set by the experiment

	init {
		create comm;
		r <- comm[0].MPI_RANK;
		n <- comm[0].MPI_SIZE;
		seed <- 1.0 + r;	// a different random stream on each rank
		quadrant <- r mod 4;
		xmin <- (quadrant = 1 or quadrant = 2) ? -1.0 : 0.0;
		ymin <- (quadrant >= 2) ? -1.0 : 0.0;
	}

	reflex throw when: cycles_done < total_cycles {
		recent_in <- [];
		recent_out <- [];
		loop i from: 1 to: darts_per_cycle {
			float x <- xmin + rnd(1.0);
			float y <- ymin + rnd(1.0);
			bool inside <- x * x + y * y <= 1.0;
			if (inside) { hits <- hits + 1; }
			if (i <= shown_darts) {
				if (inside) { recent_in << {x, y}; } else { recent_out << {x, y}; }
			}
		}
		darts <- darts + darts_per_cycle;
		cycles_done <- cycles_done + 1;

		list counts;
		ask comm { counts <- MPI_ALLGATHER(mesg: [myself.hits, myself.darts]); }	// [hits0, darts0, hits1, darts1, ...]
		int all_hits <- 0;
		int all_darts <- 0;
		loop k from: 0 to: n - 1 {
			all_hits <- all_hits + int(counts[2 * k]);
			all_darts <- all_darts + int(counts[2 * k + 1]);
		}
		estimate <- 4.0 * all_hits / all_darts;
		estimates << estimate;

		if (cycles_done = total_cycles) {
			write "RESULT rank " + r + " hits " + hits + " darts " + darts;
			if (r = 0) { write "pi ~ " + estimate + " from " + all_darts + " darts on " + n + " ranks"; }
			list<string> errors;
			if (darts != darts_per_cycle * total_cycles) { errors << "darts " + darts; }
			if (abs(estimate - #pi) > 0.01) { errors << "estimate " + estimate; }
			write (empty(errors) ? "PASS rank " + r : "FAIL rank " + r + " " + errors);
		}
	}

	// display coordinates: darts square on the left, estimate plot on the right
	point dart_at(point p) { return {5 + (p.x - xmin) * 100, 115 - (p.y - ymin) * 100}; }
	// this quadrant's quarter of the circle, as a polyline
	list<point> arc() {
		return (0 to 30) collect world.dart_at({cos(90.0 * quadrant + 3.0 * each), sin(90.0 * quadrant + 3.0 * each)});
	}
	point plot_at(int c, float e) {
		return {120 + (c - 1) / max(1, total_cycles - 1) * 85, 65 - max(-1.0, min(1.0, (e - #pi) / 0.02)) * 45};
	}
}

species comm skills: [MPI_SKILL] {}

experiment mpi_monte_carlo_pi type: MPI_EXP {
	string checkpoint_dir <- "checkpoints";
	int checkpoint_every <- 5;
	bool resume <- false;
	bool restored <- false;
	parameter "Snapshot folder" var: checkpoint_dir;
	parameter "Snapshot every (cycles)" var: checkpoint_every;
	parameter "Resume from the last snapshot" var: resume;

	// resume: replace the fresh simulation by this rank's last complete snapshot
	reflex restore_snapshot when: resume and !restored {
		restored <- true;
		file latest <- text_file(checkpoint_dir + "/latest.txt");
		list<string> slot_cycle <- string(latest.contents[0]) split_with ";";
		int rank <- simulation.r;
		restore simulation from: file(checkpoint_dir + "/" + slot_cycle[0] + "/rank" + rank + ".simulation");
		simulation.resumed_from <- int(slot_cycle[1]);
		write "rank " + rank + ": resumed from the snapshot of cycle " + slot_cycle[1] + " (" + slot_cycle[0] + ")";
	}

	// every checkpoint_every cycles: each rank saves, all wait, rank 0 marks the snapshot as complete
	reflex save_snapshot when: simulation.cycles_done > 0 and simulation.cycles_done mod checkpoint_every = 0
			and simulation.cycles_done < simulation.total_cycles and !(simulation.snapshot_cycles contains simulation.cycles_done) {
		int rank <- simulation.r;
		string slot <- (simulation.cycles_done div checkpoint_every) mod 2 = 0 ? "slot_a" : "slot_b";
		simulation.snapshot_cycles << simulation.cycles_done;	// recorded before saving, so the snapshot knows it
		save simulation to: checkpoint_dir + "/" + slot + "/rank" + rank + ".simulation";
		ask simulation.comm[0] { do MPI_BARRIER(); }
		if (rank = 0) {
			save slot + ";" + simulation.cycles_done to: checkpoint_dir + "/latest.txt" format: "text" rewrite: true;
		}
	}

	output {
		display pi type: 2d axes: false background: #white {
			graphics "darts and estimate" {
				// this quadrant: darts of this cycle and its quarter of the circle
				draw rectangle(100, 100) at: {55, 65} wireframe: true color: #black;
				draw line(world.arc()) color: #black width: 2;
				loop p over: recent_in { draw square(0.9) at: world.dart_at(p) color: #royalblue; }
				loop p over: recent_out { draw square(0.9) at: world.dart_at(p) color: #darkorange; }
				// estimate over the cycles, true pi dashed
				draw line([world.plot_at(1, #pi), world.plot_at(total_cycles, #pi)]) color: #gray;
				draw "π" at: world.plot_at(total_cycles, #pi) + {2, 1.5} color: #gray font: font("SansSerif", 12, #plain);
				loop c over: snapshot_cycles {
					draw line([world.plot_at(c, #pi + 0.02), world.plot_at(c, #pi - 0.02)]) color: #lightgray width: 2;
					draw "snapshot" at: world.plot_at(c, #pi + 0.02) + {-6, -2} color: #gray font: font("SansSerif", 9, #plain);
				}
				if (resumed_from > 0) {
					draw line([world.plot_at(resumed_from, #pi + 0.02), world.plot_at(resumed_from, #pi - 0.02)]) color: #green width: 3;
					draw "resumed" at: world.plot_at(resumed_from, #pi - 0.02) + {-6, 5} color: #green font: font("SansSerif", 10, #bold);
				}
				if (length(estimates) > 1) {
					loop c from: 1 to: length(estimates) - 1 {
						draw line([world.plot_at(c, estimates[c - 1]), world.plot_at(c + 1, estimates[c])]) color: #crimson width: 2;
					}
				}
				if (!empty(estimates)) { draw circle(1.2) at: world.plot_at(length(estimates), last(estimates)) color: #crimson; }
				// titles: this rank above its quadrant, the estimate (all ranks) above the plot
				draw "rank " + r at: {5, 9} color: #black font: font("SansSerif", 14, #bold);
				draw "cycle " + cycles_done + "   π ≈ " + (estimate with_precision 4)
					at: {120, 9} color: #black font: font("SansSerif", 14, #bold);
			}
		}
	}
}
