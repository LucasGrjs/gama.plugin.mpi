# gama.plugin.mpi

MPI support for [GAMA](https://gama-platform.org): run one simulation over several processes with Open MPI.

The plugin adds:

- the `MPI_SKILL` skill: rank and size, point-to-point messages, barrier, broadcast, reduce, all-to-all, gather/scatter/allgather (and their `v` variants), with GAML values serialised by GAMA's binary serialisation;
- the `MPI_EXP` experiment type, which starts and stops MPI around a headless run.

## Requirements

- GAMA 2026.06 or later (Java 25), headless.
- Open MPI built with its Java bindings (`--enable-mpi-java`). `ext/mpi.jar` must come from the same Open MPI build as the `libmpi_java.so` found at run time (`-Djava.library.path=...` if it is not in a default location).

Messages larger than 64 KiB are sent through direct buffers: with `byte[]` arrays, the Open MPI 4.1/5.0 Java binding overruns its eager buffer on large messages.

## Build

```bash
REF_NAME=GAMA_2026-06 PLUGIN_REPO_NAME=gama.plugin.mpi bash build.sh
```

The GAMA version comes from the branch name (`GAMA_YYYY-MM` → `https://updates.gama-platform.org/YYYY-MM`). The update site is in `gama.plugin.p2updatesite/target/repository`.

## Run

Each rank is a headless GAMA started by `mpirun`:

```bash
mpirun -np 4 java -cp <gama>/plugins/org.eclipse.equinox.launcher_*.jar \
  --add-modules jdk.incubator.vector --enable-preview --sun-misc-unsafe-memory-access=allow \
  --add-opens=java.base/java.lang.invoke=ALL-UNNAMED <other GAMA headless options> \
  org.eclipse.equinox.launcher.Main -configuration <gama>/headless/configuration \
  -application gama.headless.product -data /tmp/ws_$OMPI_COMM_WORLD_RANK -v model.xml output_dir
```

Create `output_dir/snapshot/` before `mpirun`: ranks creating it at the same time make GAMA abort.

## Origin

Moved from `gama-platform/gama.experimental` (`gama.experimental.MPI`, not migrated to `gama-platform-plugins`), ported to the GAMA 2026 API, with the collective operations above rewritten on direct buffers.
