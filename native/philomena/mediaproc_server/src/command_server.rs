use std::collections::HashSet;
use std::os::unix::process::ExitStatusExt;

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
    use std::fs::{read, write};

    // Check program name.
    if !PERMITTED_PROGRAMS.contains(&program.as_ref()) {
        return Err(ExecuteCommandError::UnpermittedProgram(program));
    }

    // Create a new temporary directory which we will work in.
    let dir = tempfile::tempdir().map_err(|_| ExecuteCommandError::RemoteFilesystemError)?;

    // Verify and write out all files.
    let mut files = HashSet::<String>::new();
    for (name, contents) in file_map {
        validate_name(&name)?;
        files.insert(name.clone());

        let path = dir.path().join(name);
        write(path, contents).map_err(|_| ExecuteCommandError::RemoteFilesystemError)?;
    }

    // Run the command.
    let output = Command::new(program)
        .args(arguments)
        .current_dir(dir.path())
        .output()
        .await
        .map_err(|_| ExecuteCommandError::ExecutionError)?;

    // Read back all files.
    let mut file_map = FileMap::new();
    for name in files {
        let path = dir.path().join(name.clone());
        let contents = read(path).map_err(|_| ExecuteCommandError::RemoteFilesystemError)?;
        file_map.insert(name, contents);
    }

    let reply = CommandReply {
        status: output.status.into_raw() as u8,
        stdout: output.stdout,
        stderr: output.stderr,
    };

    Ok((reply, file_map))
}

pub async fn get_mime(content: Vec<u8>) -> Result<String, ExecuteCommandError> {
    use std::fs::write;

    // Write the contents to a file in a new temporary directory.
    let dir = tempfile::tempdir().map_err(|_| ExecuteCommandError::RemoteFilesystemError)?;
    let path = dir.path().join("file");
    write(&path, content).map_err(|_| ExecuteCommandError::RemoteFilesystemError)?;

    let output = Command::new("file")
        .arg("-b")
        .arg("--mime-type")
        .arg(&path)
        .output()
        .await
        .map_err(|_| ExecuteCommandError::ExecutionError)?;

    if !output.status.success() {
        return Err(ExecuteCommandError::ExecutionError);
    }

    match String::from_utf8(output.stdout) {
        Ok(mime) => Ok(mime.trim().to_string()),
        Err(_) => Err(ExecuteCommandError::UnknownError),
    }
}
