use once_cell::sync::Lazy;
use serde::{Deserialize, Serialize};
use std::collections::{HashMap, HashSet};

pub mod client;

#[tarpc::service]
pub trait MediaProcessor {
    /// Executes a command on the media processor server.
    async fn execute_command(
        program: String,
        arguments: Vec<String>,
        file_map: FileMap,
    ) -> Result<(CommandReply, FileMap), ExecuteCommandError>;

    /// Runs feature extraction on an image file bytes (PNG or JPEG).
    async fn get_features(image: Vec<u8>) -> Result<Vec<f32>, FeatureExtractionError>;
}

/// Errors which can occur during command execution.
#[derive(Debug, Deserialize, Serialize)]
pub enum ExecuteCommandError {
    /// Failed to connect to server.
    ConnectionError,
    /// Requested program was not allowed to be executed.
    UnpermittedProgram(String),
    /// Failed to launch program.
    ExecutionError,
    /// File map name character was not allowed ('..', '/', '\\').
    InvalidFileMapName,
    /// Generic filesystem error.
    RemoteFilesystemError,
    /// Generic filesystem error.
    LocalFilesystemError,
    /// Unknown error.
    UnknownError,
}

/// Errors which can occur during image feature extraction.
#[derive(Debug, Deserialize, Serialize)]
pub enum FeatureExtractionError {
    /// Failed to connect to server.
    ConnectionError,
    /// Generic filesystem error.
    LocalFilesystemError,
    /// Unrecognized image format.
    UnknownImageFormat,
    /// Failed to decode the image.
    ImageDecodeError,
}

/// Enumeration of permitted program names.
pub static PERMITTED_PROGRAMS: Lazy<HashSet<&'static str>> = Lazy::new(|| {
    vec![
        "ffprobe",
        "ffmpeg",
        "file",
        "gifsicle",
        "image-intensities",
        "jpegtran",
        "magick",
        "mediastat",
        "mediathumb",
        "optipng",
        "safe-rsvg-convert",
        "svgstat",
    ]
    .into_iter()
    .collect()
});

/// Mapping between file name and file contents.
pub type FileMap = HashMap<String, Vec<u8>>;

/// Output reply after command execution has finished.
#[derive(Debug, Deserialize, Serialize)]
pub struct CommandReply {
    pub status: u8,
    pub stdout: Vec<u8>,
    pub stderr: Vec<u8>,
}
