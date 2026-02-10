use anyhow::Result;
use clap::Parser;

mod args;
mod command;
mod id;
mod output;
mod repo;

use args::{Args, Subcommands};
use output::OutputChannel;

fn main() -> Result<()> {
    let args = Args::parse();
    let format = if args.json {
        args::OutputFormat::Json
    } else {
        args.format
    };
    let mut out = OutputChannel::new(format);

    // Handle default rub (no subcommand, two positional args)
    if args.cmd.is_none() && args.source.is_some() && args.target.is_some() {
        let source = args.source.as_ref().unwrap();
        let target = args.target.as_ref().unwrap();
        return command::rub::execute(&args, &mut out, source, target);
    }

    match &args.cmd {
        None => command::status::execute(&args, &mut out),
        Some(cmd) => dispatch(cmd, &args, &mut out),
    }
}

fn dispatch(cmd: &Subcommands, args: &Args, out: &mut OutputChannel) -> Result<()> {
    match cmd {
        Subcommands::Status { files, verbose } => {
            command::status::execute_with_opts(args, out, *files, *verbose)
        }
        Subcommands::Diff { target } => command::diff::execute(args, out, target.as_deref()),
        Subcommands::Show { revision, verbose } => {
            command::show::execute(args, out, revision, *verbose)
        }
        Subcommands::Commit { message, branch } => {
            command::commit::execute(args, out, message.as_deref(), branch.as_deref())
        }
        Subcommands::Rub { source, target } => command::rub::execute(args, out, source, target),
        Subcommands::Squash { revisions, message } => {
            command::squash::execute(args, out, revisions, message.as_deref())
        }
        Subcommands::Reword { target, message } => {
            command::reword::execute(args, out, target, message.as_deref())
        }
        Subcommands::Push { bookmark } => command::push::execute(args, out, bookmark.as_deref()),
        Subcommands::Pull => command::pull::execute(args, out),
        Subcommands::Pr { bookmark, message } => {
            command::pr::execute(args, out, bookmark.as_deref(), message.as_deref())
        }
        Subcommands::Discard { target } => command::discard::execute(args, out, target),
        Subcommands::Undo => command::undo::execute(args, out),
        Subcommands::Absorb { dry_run } => command::absorb::execute(args, out, *dry_run),
        Subcommands::Log { limit, all } => command::log::execute(args, out, *limit, *all),
    }
}
