use std::io::Write;
use std::process::ExitCode;

use broker::BrokerClient;
use clap::{Parser, Subcommand};

mod command_client;

#[derive(Parser, Debug)]
#[command(version, about = "RPC Broker", long_about = None)]
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
        /// One of convert, ffprobe, ffmpeg, file, gifsicle, identify,
        /// image-intensities, jpegtran, mediastat, optipng, safe-rsvg-convert.
        program: String,
        /// Arguments to pass to program.
        args: Vec<String>,
    },
}

#[tokio::main(flavor = "current_thread")]
async fn main() -> ExitCode {
    let args = Arguments::parse();
    let client = connect_to_socket_server(&args)
        .await
        .expect("failed to connect to server");

    match args.invocation_type {
        InvocationType::ExecuteCommand { program, args } => {
            run_command_client(&client, program, args).await
        }
    }
}

async fn connect_to_socket_server(args: &Arguments) -> Option<BrokerClient> {
    let codec = tarpc::tokio_serde::formats::Json::default;

    for addr in tokio::net::lookup_host(&args.server_addr).await.ok()? {
        let mut transport = tarpc::serde_transport::tcp::connect(addr, codec);
        transport.config_mut().max_frame_length(usize::MAX);

        let transport = match transport.await {
            Ok(transport) => transport,
            _ => continue,
        };

        return Some(BrokerClient::new(tarpc::client::Config::default(), transport).spawn());
    }

    None
}

async fn run_command_client(client: &BrokerClient, program: String, args: Vec<String>) -> ExitCode {
    let reply = command_client::execute_command(client, program, args)
        .await
        .unwrap();

    write_then_drop(std::io::stderr(), reply.stderr);
    write_then_drop(std::io::stdout(), reply.stdout);

    reply.status.into()
}

fn write_then_drop(mut stream: impl Write, data: Vec<u8>) {
    stream.write_all(&data).unwrap()
}
