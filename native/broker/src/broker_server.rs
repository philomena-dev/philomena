use std::net::SocketAddr;

use broker::{Broker, CommandReply, ExecuteCommandError, FileMap};
use clap::Parser;
use futures::{future, Future, StreamExt};
use tarpc::context;
use tarpc::server::Channel;

mod command_server;
mod signal;

#[derive(Parser, Debug)]
#[command(version, about = "RPC Broker Server", long_about = None)]
struct Arguments {
    /// Socket address to bind to, like 127.0.0.1:1500
    server_addr: SocketAddr,
}

#[derive(Clone)]
struct BrokerServer;

impl Broker for BrokerServer {
    async fn execute_command(
        self,
        _: context::Context,
        program: String,
        arguments: Vec<String>,
        file_map: FileMap,
    ) -> Result<(CommandReply, FileMap), ExecuteCommandError> {
        command_server::execute_command(program, arguments, file_map).await
    }
}

fn main() {
    env_logger::init();

    let args = Arguments::parse();

    serve(&args);
}

async fn spawn(fut: impl Future<Output = ()> + Send + 'static) {
    tokio::spawn(fut);
}

#[tokio::main]
async fn serve(args: &Arguments) {
    signal::install_handlers();

    let codec = tarpc::tokio_serde::formats::Json::default;
    let mut listener = tarpc::serde_transport::tcp::listen(args.server_addr, codec)
        .await
        .unwrap();

    listener.config_mut().max_frame_length(usize::MAX);
    listener
        // Ignore accept errors.
        .filter_map(|r| future::ready(r.ok()))
        .map(tarpc::server::BaseChannel::with_defaults)
        .map(|channel| {
            tokio::spawn(channel.execute(BrokerServer.serve()).for_each(spawn));
        })
        .collect()
        .await
}
