# gama.plugin.mpi

MPI support for [GAMA](https://gama-platform.org): run one simulation over several processes with Open MPI.

The plugin adds:

- the `MPI_SKILL` skill: rank and size, point-to-point messages, barrier, broadcast, reduce, all-to-all, gather/scatter/allgather (and their `v` variants), with GAML values serialised by GAMA's binary serialisation;
- the `MPI_EXP` experiment type, which starts and stops MPI around a headless run.

It is for headless GAMA only: `mpirun` starts one headless GAMA per rank.

## Requirements

- Headless GAMA 2026.06 or later, Java 25.
- Open MPI built with its Java bindings (`--enable-mpi-java`). `ext/mpi.jar` must come from the same Open MPI build as the `libmpi_java.so` found at run time.

## Build

```bash
REF_NAME=GAMA_2026-06 PLUGIN_REPO_NAME=gama.plugin.mpi bash build.sh
```

The GAMA version comes from the branch name (`GAMA_YYYY-MM` → `https://updates.gama-platform.org/YYYY-MM`). The plugin jar is in `gama.plugin.p2updatesite/target/repository/plugins/`.

## Install

Headless GAMA has no plugin installer: the jar is added by hand to the GAMA folder (the one containing `plugins/` and `configuration/`, e.g. the content of `gama.headless-linux.gtk.x86_64.tar.gz`).

1. Copy `gama.plugin.mpi_<version>.jar` into `plugins/`.
2. Add one line for it at the end of `configuration/org.eclipse.equinox.simpleconfigurator/bundles.info`:

   ```
   gama.plugin.mpi,<version>,plugins/gama.plugin.mpi_<version>.jar,4,false
   ```

   `<version>` is the part of the file name after `gama.plugin.mpi_`, e.g. `1.0.0.202610231614`.

To update the plugin, replace the jar and the version in that line.

## Run

`models/MPI Examples/models/` (also inside the plugin jar) holds one example per group of MPI actions, each with its experiment plan (`.xml`), and a launch script. Each rank checks its result and writes `PASS rank r` or `FAIL rank r ...`.

| Example | Actions |
|---|---|
| `mpi_hello` | `MPI_RANK`, `MPI_SIZE` |
| `mpi_send_recv` | `MPI_SEND`, `MPI_RECV`: blocking messages around a ring of ranks |
| `mpi_isend_irecv` | `MPI_ISEND`, `MPI_IRECV`: non-blocking messages, polling until arrival |
| `mpi_broadcast` | `MPI_BROADCAST`: one rank sends the same list to all |
| `mpi_gather` | `MPI_GATHER` (to one rank), `MPI_ALLGATHER` (to all ranks) |
| `mpi_scatter` | `MPI_SCATTER`: one rank splits work between all ranks, then `MPI_GATHER` of the results |
| `mpi_alltoall` | `MPI_ALLTOALL`, `MPI_BARRIER`: every rank sends a list to every other rank |
| `mpi_migration` | `MPI_ALLTOALL_MIGRATION` over 30 cycles: agents move between ranks, sent as lists of their attributes and recreated on arrival; timers `MPI_MIGRATION_TIME_MS`, `MPI_SERIALIZATION_TIME_MS`, `MPI_BARRIER_TIME_MS` |
| `mpi_monte_carlo_pi` | Pi from random darts on all ranks (`MPI_ALLGATHER`), with snapshots: every few cycles each rank saves its simulation (`save simulation`), and a run restarted with `resume = true` goes on from the last complete snapshot (`restore simulation`), with the same result as an uninterrupted run |
| `mpi_migration_agents` | Same, sending the agents themselves: an agent in a message arrives as a full copy, already created on the receiving rank with the same index |

```bash
cd "gama.plugin.mpi/models/MPI Examples/models"
bash run_mpi.sh <GAMA folder> mpi_hello.xml 4 out
```

When the run ends, the script prints what each rank's model wrote:

```
── rank 0 ── full output: out/rank_0/output.txt
   hello from rank 0 of 4
   PASS rank 0
── rank 1 ── full output: out/rank_1/output.txt
   ...
```

### Results

Each rank has its own folder, `out/rank_<r>/`:

| File | Content |
|---|---|
| `output.txt` | everything the rank printed, GAMA's start-up messages included |
| `console-outputs-<r>.txt` | the plugin's log |
| `snapshot/` | the rank's display pictures, when the experiment plan saves a display |

Files the model writes itself (`save ... to:`) go where the model says: a relative path is relative to the model file. Put the rank in the file name (e.g. `"results_" + MPI_RANK + ".csv"`) so the ranks don't overwrite each other.

Environment: `MPI_JAVA_LIB` (folder of `libmpi_java.so`, default `/usr/local/lib`), `GAMA_XMX` (heap per rank, default `3g`), `MPI_DEBUG=1` to also print the plugin's progress messages.

### Displays

Headless GAMA draws a display only when the experiment plan asks for it, e.g. in the `.xml`:

```xml
<Outputs><Output id="1" name="pi" framerate="1" width="630" height="360"/></Outputs>
```

Each rank then saves one picture per cycle in `out/rank_<r>/snapshot/`. `mpi_display.py` (needs Pillow: `pip install pillow`) makes one animated GIF of them, the ranks side by side:

```bash
python3 mpi_display.py out pi                       # out/pi.gif, ranks in a grid
python3 mpi_display.py out pi --crop 15 45 316 346 --order 1 0 2 3 --columns 2   # mpi_monte_carlo_pi: the 4 quadrants as one circle
```

`--crop` keeps a part of each picture (pixels), `--order` places the ranks, `--columns`, `--gap`, `--scale`, `--delay` set the layout and speed (`python3 mpi_display.py -h`). `mpi_monte_carlo_pi.xml` already saves its display.

### Own mpirun line

To launch ranks without `run_mpi.sh`, keep what it does:

- **one empty configuration folder per rank** (`-configuration /tmp/ws_$OMPI_COMM_WORLD_RANK/configuration`). GAMA then reads the install's `configuration/` read-only. Ranks sharing the install's configuration while starting together corrupt GAMA's bundle cache: GAMA then fails at start (`Could not resolve module: org.apache.felix.scr`) until reinstalled. With one folder per rank, the GAMA folder can be read-only, e.g. a shared install on a cluster;
- one workspace per rank (`-data`) and one output folder per rank (last argument), or the ranks overwrite each other's files;
- `mkdir -p <output folder>/snapshot` before `mpirun`: ranks creating it at the same time make GAMA abort;
- the Java options in the script (`--add-modules jdk.incubator.vector --enable-preview`, `--add-opens ...`).

## Origin

Moved from `gama-platform/gama.experimental` (`gama.experimental.MPI`, not migrated to `gama-platform-plugins`), ported to the GAMA 2026 API, with the collective operations rewritten on direct buffers: with `byte[]` arrays, the Open MPI 4.1/5.0 Java binding overruns its eager buffer on messages above 64 KiB.
