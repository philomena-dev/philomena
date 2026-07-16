use std::collections::HashMap;
use std::os::unix::process::ExitStatusExt;
use std::path::Path;

use mediaproc::{CommandReply, ExecuteCommandError, FileMap, PERMITTED_PROGRAMS};
use tokio::process::Command;

fn validate_name(name: &str) -> Result<(), ExecuteCommandError> {
    if name == "." || name.contains("..") || name.contains('/') || name.contains('\\') {
        return Err(ExecuteCommandError::InvalidFileMapName);
    }

    Ok(())
}

pub async fn execute_command(
    program: String,
    arguments: Vec<String>,
    file_map: FileMap,
) -> Result<(CommandReply, FileMap), ExecuteCommandError> {
    use std::fs::write;

    // Check program name.
    if !PERMITTED_PROGRAMS.contains(&program.as_ref()) {
        return Err(ExecuteCommandError::UnpermittedProgram(program));
    }

    // Create a new temporary directory which we will work in.
    let dir = tempfile::tempdir().map_err(|_| ExecuteCommandError::RemoteFilesystemError)?;

    // Verify and write out all files, keeping the original contents so
    // unmodified files can be omitted from the reply.
    let mut files = HashMap::<String, Vec<u8>>::new();
    for (name, contents) in file_map {
        validate_name(&name)?;

        let path = dir.path().join(&name);
        write(path, &contents).map_err(|_| ExecuteCommandError::RemoteFilesystemError)?;

        files.insert(name, contents);
    }

    // Run the command.
    let output = Command::new(program)
        .args(arguments)
        .current_dir(dir.path())
        .output()
        .await
        .map_err(|_| ExecuteCommandError::ExecutionError)?;

    // Read back only the files the command modified; the client writes the
    // returned entries over its local paths, so returning unchanged inputs
    // would make every read-only use a needless (and racy) rewrite.
    let file_map = collect_modified_files(dir.path(), files)?;

    let reply = CommandReply {
        status: output.status.into_raw() as u8,
        stdout: output.stdout,
        stderr: output.stderr,
    };

    Ok((reply, file_map))
}

/// Read back the given files from `dir`, returning only those whose contents
/// no longer match the originals.
fn collect_modified_files(
    dir: &Path,
    files: HashMap<String, Vec<u8>>,
) -> Result<FileMap, ExecuteCommandError> {
    use std::fs::read;

    let mut file_map = FileMap::new();
    for (name, original_contents) in files {
        let path = dir.join(&name);
        let contents = read(path).map_err(|_| ExecuteCommandError::RemoteFilesystemError)?;

        if contents != original_contents {
            file_map.insert(name, contents);
        }
    }

    Ok(file_map)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs::write;

    fn files(entries: &[(&str, &[u8])]) -> HashMap<String, Vec<u8>> {
        entries
            .iter()
            .map(|(name, contents)| (name.to_string(), contents.to_vec()))
            .collect()
    }

    #[test]
    fn collect_modified_files_omits_unchanged_files() {
        let dir = tempfile::tempdir().unwrap();
        write(dir.path().join("0.png"), b"input").unwrap();
        write(dir.path().join("1.png"), b"populated output").unwrap();

        let file_map =
            collect_modified_files(dir.path(), files(&[("0.png", b"input"), ("1.png", b"")]))
                .unwrap();

        assert_eq!(
            file_map,
            FileMap::from([("1.png".to_string(), b"populated output".to_vec())])
        );
    }

    #[test]
    fn collect_modified_files_errors_on_missing_file() {
        let dir = tempfile::tempdir().unwrap();

        let result = collect_modified_files(dir.path(), files(&[("0.png", b"input")]));

        assert!(matches!(
            result,
            Err(ExecuteCommandError::RemoteFilesystemError)
        ));
    }
}
