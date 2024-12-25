use std::collections::{HashMap, HashSet};
use std::ffi::OsString;
use std::path::Path;
use std::time::{Duration, Instant};

use broker::{BrokerClient, CommandReply, ExecuteCommandError, FileMap};
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

            // Only forward if file is in extension allow list.
            let Some(ext) = forwarded_ext(path) else {
                return arg;
            };

            // Don't forward paths that don't exist or can't be read.
            let Ok(contents) = read(path) else {
                return arg;
            };

            let replaced_name = format!("{}.{}", counter, ext);
            counter = counter.checked_add(1).unwrap();

            processed.insert(arg.clone(), replaced_name.clone()); // original -> replaced
            output.replacements.insert(replaced_name.clone(), arg); // replaced -> original
            output.file_map.insert(replaced_name.clone(), contents); // replaced -> [contents]

            replaced_name
        })
        .collect();

    output
}

fn update_replacements(replacements: HashMap<String, String>, file_map: FileMap) {
    use std::fs::write;

    for (replaced_name, contents) in file_map {
        // Intentionally panic if the original name didn't exist or writing fails.
        let original_name = replacements.get(&replaced_name).unwrap();
        write(original_name, contents).unwrap();
    }
}

fn context_with_1_hour_deadline() -> Context {
    let mut context = Context::current();
    context.deadline = Instant::now() + Duration::from_secs(60 * 60);
    context
}

pub async fn execute_command(
    client: &BrokerClient,
    program: String,
    arguments: Vec<String>,
) -> Result<CommandReply, ExecuteCommandError> {
    let call_params = create_replacements(arguments.into_iter());
    let (reply, file_map) = client
        .execute_command(
            context_with_1_hour_deadline(),
            program,
            call_params.arguments,
            call_params.file_map,
        )
        .await
        .unwrap()?;

    update_replacements(call_params.replacements, file_map);

    Ok(reply)
}
