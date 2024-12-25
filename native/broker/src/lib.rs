use once_cell::sync::Lazy;
use serde::{Deserialize, Serialize};
use std::collections::{HashMap, HashSet};

#[tarpc::service]
pub trait Broker {
    /// Executes a command on the broker server.
    async fn execute_command(
        program: String,
        arguments: Vec<String>,
        file_map: FileMap,
    ) -> Result<(CommandReply, FileMap), ExecuteCommandError>;
}

/// Errors which can occur during command execution.
#[derive(Debug, Deserialize, Serialize)]
pub enum ExecuteCommandError {
    /// Requested program was not allowed to be executed.
    UnpermittedProgram(String),
    /// Failed to launch program.
    ExecutionError,
    /// File map name character was not allowed ('..', '/', '\\').
    InvalidFileMapName,
    /// Generic filesystem error.
    RemoteFilesystemError,
}

/// Enumeration of permitted program names.
pub static PERMITTED_PROGRAMS: Lazy<HashSet<&'static str>> = Lazy::new(|| {
    vec![
        "convert",
        "ffprobe",
        "ffmpeg",
        "file",
        "gifsicle",
        "identify",
        "image-intensities",
        "jpegtran",
        "mediastat",
        "optipng",
        "safe-rsvg-convert",
    ]
    .into_iter()
    .collect()
});

/// Mapping between file name and file contents.
pub type FileMap = HashMap<String, Vec<u8>>;

/// Output reply from broker after command execution has finished.
#[derive(Debug, Deserialize, Serialize)]
pub struct CommandReply {
    pub status: u8,
    pub stdout: Vec<u8>,
    pub stderr: Vec<u8>,
}
