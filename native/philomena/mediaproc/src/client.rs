use std::collections::{HashMap, HashSet};
use std::ffi::OsString;
use std::path::Path;
use std::time::{Duration, Instant};

use crate::{CommandReply, ExecuteCommandError, FileMap, MediaProcessorClient};
use once_cell::sync::Lazy;
use tarpc::context::Context;

#[derive(Default)]
struct CallParameters {
    /// Mapping from replaced name to original name.
    replacements: HashMap<String, String>,
    /// List of post-processed arguments.
    arguments: Vec<String>,
    /// Mapping of replaced name to file contents.
    file_map: FileMap,
}

/// List of file extensions which can be forwarded.
static FORWARDED_EXTS: Lazy<HashSet<OsString>> = Lazy::new(|| {
    vec![
        "gif", "jpg", "jpeg", "png", "svg", "webm", "webp", "mp4", "icc",
    ]
    .into_iter()
    .map(Into::into)
    .collect()
});

fn forwarded_ext(path: &Path) -> Option<&str> {
    match path.extension() {
        Some(ext) if FORWARDED_EXTS.contains(ext) => ext.to_str(),
        _ => None,
    }
}

fn create_replacements(arguments: impl Iterator<Item = String>) -> CallParameters {
    use std::fs::read;

    // Maps original name to replaced name.
    let mut processed = HashMap::<String, String>::new();
    let mut counter: usize = 0;

    let mut output = CallParameters::default();

    output.arguments = arguments
        .map(|arg| {
            let path = Path::new(&arg);

            // Avoid adding additional replacements if the same file is passed multiple times.
            if let Some(replaced_name) = processed.get(&arg) {
                return replaced_name.clone();
            }

            // Only try things that look like paths.
            if !path.is_absolute() {
                return arg;
            }

            // Don't forward paths that don't exist or can't be read.
            let Ok(contents) = read(path) else {
                return arg;
            };

            // Only forward extension if extension is in allow list.
            let replaced_name = match forwarded_ext(path) {
                Some(ext) => format!("{}.{}", counter, ext),
                None => format!("{}", counter),
            };

            counter = counter.saturating_add(1);

            processed.insert(arg.clone(), replaced_name.clone()); // original -> replaced
            output.replacements.insert(replaced_name.clone(), arg); // replaced -> original
            output.file_map.insert(replaced_name.clone(), contents); // replaced -> [contents]

            replaced_name
        })
        .collect();

    output
}

fn update_replacements(
    replacements: HashMap<String, String>,
    file_map: FileMap,
) -> Result<(), ExecuteCommandError> {
    use std::fs::write;

    for (replaced_name, contents) in file_map {
        let original_name = replacements
            .get(&replaced_name)
            .ok_or(ExecuteCommandError::InvalidFileMapName)?;

        write(original_name, contents).map_err(|_| ExecuteCommandError::LocalFilesystemError)?;
    }

    Ok(())
}

pub fn context_with_deadline(secs_from_now: u64) -> Context {
    let mut context = Context::current();
    context.deadline = Instant::now() + Duration::from_secs(secs_from_now);
    context
}

pub fn context_with_1_hour_deadline() -> Context {
    context_with_deadline(60 * 60)
}

pub fn context_with_10_second_deadline() -> Context {
    context_with_deadline(10)
}

pub async fn execute_command(
    client: &MediaProcessorClient,
    program: String,
    arguments: Vec<String>,
    ctx: Context,
) -> Result<CommandReply, ExecuteCommandError> {
    let call_params = create_replacements(arguments.into_iter());
    let (reply, file_map) = client
        .execute_command(ctx, program, call_params.arguments, call_params.file_map)
        .await
        .map_err(|_| ExecuteCommandError::UnknownError)??;

    update_replacements(call_params.replacements, file_map)?;

    Ok(reply)
}

pub async fn connect_to_socket_server(server_addr: &str) -> Option<MediaProcessorClient> {
    let codec = tarpc::tokio_serde::formats::Bincode::default;

    for addr in tokio::net::lookup_host(server_addr).await.ok()? {
        let mut transport = tarpc::serde_transport::tcp::connect(addr, codec);
        transport.config_mut().max_frame_length(usize::MAX);

        let transport = match transport.await {
            Ok(transport) => transport,
            _ => continue,
        };

        return Some(
            MediaProcessorClient::new(tarpc::client::Config::default(), transport).spawn(),
        );
    }

    None
}
