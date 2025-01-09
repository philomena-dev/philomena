use mediaproc::CommandReply;
use mediaproc::client;
use mediaproc::client::{connect_to_socket_server, execute_command};
use rustler::{Encoder, Env, NifStruct, OwnedBinary, Term, atoms};

atoms! {
    nil,
    ok,
    error,
    get_features_reply,
    process_command_reply,
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
    let client = match client::connect_to_socket_server(&server_addr).await {
        Some(client) => client,
        None => {
            return CommandReply {
                stdout: vec![],
                stderr: "failed to connect to server".into(),
                status: 255,
            };
        }
    };

    let ctx = client::context_with_1_hour_deadline();
    match client::execute_command(&client, program, arguments, ctx).await {
        Ok(reply) => reply,
        Err(err) => CommandReply {
            stdout: vec![],
            stderr: format!("failed to execute command: {err:?}").into(),
            status: 255,
        },
    }
}

pub async fn get_features(
    server_addr: String,
    path: String,
) -> Result<Vec<f32>, FeatureExtractionError> {
    let client = match client::connect_to_socket_server(&server_addr).await {
        Some(client) => client,
        None => return Err(FeatureExtractionError::ConnectionError),
    };

    let image = std::fs::read(path).map_err(|_| FeatureExtractionError::LocalFilesystemError)?;
    let ctx = client::context_with_10_second_deadline();

    client
        .get_features(ctx, image)
        .await
        .map_err(|_| FeatureExtractionError::ConnectionError)?
}

/// Converts the response into a {:process_command_reply, %CommandReply{...}}
/// message which gets sent back to the caller.
pub fn command_reply_with_env<'a>(env: Env<'a>, r: CommandReply) -> Term<'a> {
    (
        process_command_reply(),
        CommandReply_ {
            stdout: binary_or_nil(env, r.stdout),
            stderr: binary_or_nil(env, r.stderr),
            status: r.status,
        },
    )
        .encode(env)
}

/// Converts the response into a {:get_features_reply, {:ok, [0.1, ..., 0.1]}}
/// message which gets sent back to the caller.
pub fn get_features_reply_with_env<'a>(
    env: Env<'a>,
    r: Result<Vec<f32>, FeatureExtractionError>,
) -> Term<'a> {
    match r {
        Ok(features) => (get_features_reply(), (ok(), features)).encode(env),
        Err(e) => (get_features_reply(), (error(), format!("{e:?}"))).encode(env),
    }
}
