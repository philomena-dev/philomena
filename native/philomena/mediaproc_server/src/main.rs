use std::net::SocketAddr;
use std::sync::Arc;

use clap::Parser;
use dinov2::Executor;
use futures::{Future, StreamExt, future};
use mediaproc::{
    CommandReply, ExecuteCommandError, FeatureExtractionError, FileMap, MediaProcessor,
};
use tarpc::context;
use tarpc::server::Channel;

mod command_server;
mod dinov2;
mod io;
mod signal;

#[derive(Parser, Debug)]
#[command(version, about = "RPC Media Processor Server", long_about = None)]
struct Arguments {
    /// Socket address to bind to, like 127.0.0.1:1500
    server_addr: SocketAddr,

    /// DINOv2 with registers base model to load.
    model_path: String,
}

#[derive(Clone)]
struct MediaProcessorServer(Arc<Executor>);

impl MediaProcessor for MediaProcessorServer {
    async fn execute_command(
        self,
        _: context::Context,
        program: String,
        arguments: Vec<String>,
        file_map: FileMap,
    ) -> Result<(CommandReply, FileMap), ExecuteCommandError> {
        command_server::execute_command(program, arguments, file_map).await
    }

    async fn get_features(
        self,
        _: context::Context,
        image: Vec<u8>,
    ) -> Result<Vec<f32>, FeatureExtractionError> {
        self.0.extract(&image)
    }
}

fn main() {
    env_logger::init();

    let args = Arguments::parse();
    let executor = Executor::new(&args.model_path).expect("failed to load Torch JIT model");
    let executor = Arc::new(executor);

    serve(&args, executor);
}

async fn spawn(fut: impl Future<Output = ()> + Send + 'static) {
    tokio::spawn(fut);
}

#[tokio::main]
async fn serve(args: &Arguments, executor: Arc<Executor>) {
    signal::install_handlers();

    let codec = tarpc::tokio_serde::formats::Bincode::default;
    let mut listener = tarpc::serde_transport::tcp::listen(args.server_addr, codec)
        .await
        .unwrap();

    listener.config_mut().max_frame_length(usize::MAX);
    listener
        // Ignore accept errors.
        .filter_map(|r| future::ready(r.ok()))
        .map(tarpc::server::BaseChannel::with_defaults)
        .map(move |channel| {
            let server = MediaProcessorServer(executor.clone());

            tokio::spawn(channel.execute(server.serve()).for_each(spawn));
        })
        .collect()
        .await
}
