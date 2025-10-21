use std::io::Write;
use std::process::ExitCode;

use clap::{Parser, Subcommand};
use mediaproc::MediaProcessorClient;
use mediaproc::client::{connect_to_socket_server, execute_command};

#[derive(Parser, Debug)]
#[command(version, about = "RPC Media Processor Client", long_about = None)]
struct Arguments {
    /// Server address to connect to, like localhost:1500
    server_addr: String,

    /// Subcommand to execute.
    #[command(subcommand)]
    invocation_type: InvocationType,
}

#[derive(Subcommand, Debug)]
enum InvocationType {
    /// Execute a command with the given arguments on the remote server.
    ExecuteCommand {
        /// Program name to execute.
        ///
        /// One of magick, ffprobe, ffmpeg, file, gifsicle, image-intensities,
        /// jpegtran, mediastat, optipng, safe-rsvg-convert.
        program: String,
        /// Arguments to pass to program.
        args: Vec<String>,
    },
}

#[tokio::main(flavor = "current_thread")]
async fn main() -> ExitCode {
    let args = Arguments::parse();
    let client = connect_to_socket_server(&args.server_addr)
        .await
        .expect("failed to connect to server");

    match args.invocation_type {
        InvocationType::ExecuteCommand { program, args } => {
            run_command_client(&client, program, args).await
        }
    }
}

async fn run_command_client(
    client: &MediaProcessorClient,
    program: String,
    args: Vec<String>,
) -> ExitCode {
    let reply = execute_command(client, program, args).await.unwrap();

    write_then_drop(std::io::stderr(), reply.stderr);
    write_then_drop(std::io::stdout(), reply.stdout);

    reply.status.into()
}

fn write_then_drop(mut stream: impl Write, data: Vec<u8>) {
    stream.write_all(&data).unwrap()
}
