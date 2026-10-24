
package pluginActivator;

import MPISkill.MPIDebug;
import MPISkill.MPIFunctions;

import java.io.FileNotFoundException;

import org.osgi.framework.BundleActivator;
import org.osgi.framework.BundleContext;

import gama.api.GAMA;
import gama.dev.DEBUG;
import gama.headless.common.Globals;
import gama.headless.job.IExperimentJob;
import mpi.MPI;
import mpi.MPIException;

/**
 * The MPIActivator.
 */
@SuppressWarnings ({ "unchecked", "rawtypes" })
public class MPIActivator implements BundleActivator {

	static
	{
		DEBUG.ON();
	}
	@Override
	public void start(final BundleContext context) throws Exception 
	{
		try {
			String[] args = {};
			MPI.InitThread(args, MPI.THREAD_MULTIPLE);
			
			MPIDebug.out("isInServerMode : " +  GAMA.isInServerMode());
			MPIDebug.out("isInHeadLessMode : " + GAMA.isInHeadLessMode());
			
			// keep the output directory given to headless GAMA; "output.log" only when none was given
			if (Globals.OUTPUT_PATH == null) { Globals.OUTPUT_PATH = "output.log"; }
			MPIDebug.out("MPI.COMM_WORLD.getRank() " + MPI.COMM_WORLD.getRank());
			
			DEBUG.REGISTER_LOG_WRITER(new IExperimentJob.DebugStream(MPI.COMM_WORLD.getRank()));
			
			MPIDebug.out("************* MPI Init : " + MPI.COMM_WORLD.getRank());

			// MPI is started here for every run, but only an MPI_EXP experiment ends it. When the run had none
			// (e.g. a centralised experiment started by mpirun), end MPI as the JVM exits, or mpirun reports an
			// abnormal termination. Not done after an MPI_EXP run that failed: MPI_Finalize could then wait
			// for the other ranks.
			Runtime.getRuntime().addShutdownHook(new Thread(() -> {
				if (!MPIFunctions.MPI_EXPERIMENT_STARTED) { MPIFunctions.MPI_FINALIZE(); }
			}, "MPI finalize at exit"));
		} catch (FileNotFoundException | MPIException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
	}

	@Override
	public void stop(final BundleContext context) throws Exception
	{
		MPIFunctions.MPI_FINALIZE();
	}

}
