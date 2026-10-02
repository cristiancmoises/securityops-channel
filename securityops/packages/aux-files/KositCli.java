// SPDX-License-Identifier: Apache-2.0
package de.kosit.validationtool.cmd;

import picocli.CommandLine;
import de.kosit.validationtool.impl.EngineInformation;
import de.kosit.validationtool.impl.Printer;
import de.kosit.validationtool.cmd.report.Line;
import org.fusesource.jansi.AnsiConsole;
import org.fusesource.jansi.AnsiRenderer.Code;

/** Preserve documented argument-error exits without changing upstream JARs. */
public final class KositCli {
    private KositCli() { }

    public static void main(String[] args) {
        if (args.length == 1 && args[0].equals("--version")) {
            System.out.println(EngineInformation.getName() + " "
                    + EngineInformation.getVersion());
            return;
        }
        AnsiConsole.systemInstall();
        final CommandLine commandLine = new CommandLine(new CommandLineOptions());
        commandLine.setParameterExceptionHandler((error, arguments) -> {
            System.err.println(error.getMessage());
            return 255;
        });
        commandLine.setExecutionExceptionHandler((error, cli, parseResult) -> {
            Printer.writeErr(error, error.getMessage());
            return 255;
        });
        commandLine.setExecutionStrategy(parseResult -> {
            // Help skips Picocli's unmatched-argument validation by default.
            if (!parseResult.unmatched().isEmpty()) {
                throw new CommandLine.ParameterException(commandLine,
                        "Unknown arguments: " + parseResult.unmatched());
            }
            return new CommandLine.RunLast().execute(parseResult);
        });
        final ReturnValue resultStatus;
        try {
            // Convert and execute once: upstream's unnamed-definition converters
            // allocate IDs from static counters, so a preflight parse changes them.
            int commandStatus = commandLine.execute(args);
            if (commandStatus != 0) {
                System.exit(commandStatus);
                return;
            }
            if (commandLine.isUsageHelpRequested()) {
                System.exit(0);
                return;
            }
            ReturnValue result = commandLine.getExecutionResult();
            resultStatus = result == null ? ReturnValue.PARSING_ERROR : result;
            if (resultStatus.isError() && result != null) {
                commandLine.usage(System.out);
            }
        } catch (Exception error) {
            Printer.writeErr("Error processing command line arguments: {0}",
                    error.getMessage(), error);
            System.exit(255);
            return;
        }
        if (resultStatus == ReturnValue.DAEMON_MODE) {
            Runtime.getRuntime().addShutdownHook(new Thread(() ->
                    Printer.writeOut("Shutting down daemon ...")));
            return;
        }
        if (resultStatus.getCode() >= 0) {
            Printer.writeOut("\n##############################");
            Printer.writeOut(resultStatus == ReturnValue.SUCCESS
                    ? "#   " + new Line(Code.GREEN).add("Validation successful!").render(false, false) + "   #"
                    : "#     " + new Line(Code.RED).add("Validation failed!").render(false, false) + "     #");
            Printer.writeOut("##############################");
        }
        System.exit(resultStatus.getCode());
    }
}
