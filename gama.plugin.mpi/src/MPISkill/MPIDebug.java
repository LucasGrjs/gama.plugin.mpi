package MPISkill;

import gama.dev.DEBUG;

/**
 * Messages of the MPI plugin. Progress messages are printed only when the JVM runs with
 * {@code -Dgama.mpi.debug=true}, so that a rank's output holds the model's own output; errors are always printed.
 */
public final class MPIDebug {

	/** JVM property that turns the progress messages on. */
	public static final String DEBUG_PROPERTY = "gama.mpi.debug";

	/** True with -Dgama.mpi.debug=true. */
	public static final boolean ON = Boolean.getBoolean(DEBUG_PROPERTY);

	private MPIDebug() {}

	/** A progress message, printed only in debug mode. */
	public static void out(final Object message) {
		if (ON) { DEBUG.LOG(message); }
	}

	/** An error, always printed (standard error). */
	public static void err(final Object message) {
		DEBUG.ERR(message);
	}
}
