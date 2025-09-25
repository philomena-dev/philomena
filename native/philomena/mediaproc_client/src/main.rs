use std::io::Write;
use std::process::ExitCode;

use clap::{Parser, Subcommand};
use mediaproc::MediaProcessorClient;
use mediaproc::client;

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
    /// Get DINOv2 features from the given image file (PNG or JPEG).
    ExtractFeatures {
        /// Filename to extract from.
        file_name: String,
    },
}

#[tokio::main(flavor = "current_thread")]
async fn main() -> ExitCode {
    let args = Arguments::parse();
    let client = client::connect_to_socket_server(&args.server_addr)
        .await
        .expect("failed to connect to server");

    match args.invocation_type {
        InvocationType::ExecuteCommand { program, args } => {
            run_command_client(&client, program, args).await
        }
        InvocationType::ExtractFeatures { file_name } => {
            run_feature_extraction_client(&client, file_name).await
        }
    }
}

async fn run_command_client(
    client: &MediaProcessorClient,
    program: String,
    args: Vec<String>,
) -> ExitCode {
    let ctx = client::context_with_1_hour_deadline();
    let reply = client::execute_command(client, program, args, ctx)
        .await
        .unwrap();

    write_then_drop(std::io::stderr(), reply.stderr);
    write_then_drop(std::io::stdout(), reply.stdout);

    reply.status.into()
}

fn write_then_drop(mut stream: impl Write, data: Vec<u8>) {
    stream.write_all(&data).unwrap()
}

async fn run_feature_extraction_client(
    client: &MediaProcessorClient,
    file_name: String,
) -> ExitCode {
    let image = std::fs::read(file_name).unwrap();
    let features = client
        .get_features(client::context_with_10_second_deadline(), image)
        .await
        .unwrap()
        .unwrap();

    // Manual intersperse implementation, until rust adds it properly
    let mut started = false;
    for component in features {
        if started {
            print!(" {}", component);
        } else {
            print!("{}", component);
            started = true;
        }
    }
    println!();

    ExitCode::SUCCESS
}
