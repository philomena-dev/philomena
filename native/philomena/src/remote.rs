use mediaproc::CommandReply;
use mediaproc::client::{connect_to_socket_server, execute_command};
use rustler::types::atom::{error, ok};
use rustler::{Encoder, Env, NifStruct, OwnedBinary, Term, atoms};

atoms! {
    nil,
    command_reply,
    mime_reply,
}

#[derive(NifStruct)]
#[module = "Elixir.Philomena.Native.CommandReply"]
struct CommandReply_<'a> {
    stdout: Term<'a>,
    stderr: Term<'a>,
    status: u8,
}

fn binary_or_nil<'a>(env: Env<'a>, data: Vec<u8>) -> Term<'a> {
    match OwnedBinary::new(data.len()) {
        Some(mut binary) => {
            binary.copy_from_slice(&data);
            binary.release(env).to_term(env)
        }
        None => nil().to_term(env),
    }
}

pub async fn process_command(
    server_addr: String,
    program: String,
    arguments: Vec<String>,
) -> CommandReply {
    let client = match connect_to_socket_server(&server_addr).await {
        Some(client) => client,
        None => {
            return CommandReply {
                stdout: vec![],
                stderr: "failed to connect to server".into(),
                status: 255,
            };
        }
    };

    match execute_command(&client, program, arguments).await {
        Ok(reply) => reply,
        Err(err) => CommandReply {
            stdout: vec![],
            stderr: format!("failed to execute command: {err:?}").into(),
            status: 255,
        },
    }
}

pub async fn get_mime(server_addr: String, path: String) -> Option<String> {
    let client = connect_to_socket_server(&server_addr).await?;

    mediaproc::client::get_mime(&client, &path).await.ok()
}

/// Converts the response into a {:mime_reply, {:ok, mime} | :error} message
/// which gets sent back to the caller.
pub fn mime_with_env<'a>(env: Env<'a>, r: Option<String>) -> Term<'a> {
    match r {
        Some(mime) => (mime_reply(), (ok(), mime)).encode(env),
        None => (mime_reply(), error()).encode(env),
    }
}

/// Converts the response into a {:command_reply, %CommandReply{...}} message
/// which gets sent back to the caller.
pub fn with_env<'a>(env: Env<'a>, r: CommandReply) -> Term<'a> {
    (
        command_reply(),
        CommandReply_ {
            stdout: binary_or_nil(env, r.stdout),
            stderr: binary_or_nil(env, r.stderr),
            status: r.status,
        },
    )
        .encode(env)
}
