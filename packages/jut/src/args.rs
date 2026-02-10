use std::path::PathBuf;

#[derive(Debug, clap::Parser)]
#[clap(
    name = "jut",
    about = "GitButler-inspired CLI for Jujutsu (jj)",
    version,
    disable_help_subcommand = true
)]
pub struct Args {
    /// Run as if started in PATH instead of cwd.
    #[clap(short = 'C', long, default_value = ".", value_name = "PATH")]
    pub current_dir: PathBuf,

    /// Output format.
    #[clap(long, short = 'f', env = "JUT_OUTPUT_FORMAT", default_value = "human")]
    pub format: OutputFormat,

    /// JSON output (shorthand for --format json).
    #[clap(long, short = 'j', global = true)]
    pub json: bool,

    /// After mutation, also output status.
    #[clap(long = "status-after", global = true)]
    pub status_after: bool,

    /// Source for rub (when no subcommand given).
    #[clap(value_name = "SOURCE")]
    pub source: Option<String>,

    /// Target for rub (when no subcommand given).
    #[clap(value_name = "TARGET", requires = "source")]
    pub target: Option<String>,

    #[clap(subcommand)]
    pub cmd: Option<Subcommands>,
}

#[derive(Debug, Copy, Clone, clap::ValueEnum, Default)]
pub enum OutputFormat {
    #[default]
    Human,
    Json,
}

#[derive(Debug, clap::Subcommand)]
pub enum Subcommands {
    /// Workspace status: changed files, bookmarks, log.
    Status {
        /// Show file-level details.
        #[clap(short = 'f', long)]
        files: bool,
        /// Verbose output with author/timestamp.
        #[clap(short = 'v', long)]
        verbose: bool,
    },

    /// Show diff of uncommitted changes or a specific revision.
    Diff {
        /// Revision or file to diff.
        target: Option<String>,
    },

    /// Show details of a revision or bookmark.
    Show {
        /// Revision ID or bookmark name.
        revision: String,
        /// Show full details.
        #[clap(short = 'v', long)]
        verbose: bool,
    },

    /// Create a new commit (describe + new).
    Commit {
        /// Commit message.
        #[clap(short = 'm', long)]
        message: Option<String>,
        /// Bookmark to commit on.
        #[clap(short = 'b', long)]
        branch: Option<String>,
    },

    /// Universal combine primitive. Rub SOURCE onto TARGET.
    ///
    /// ```text
    /// SOURCE / TARGET  │ zz (discard) │ Revision  │ Bookmark
    /// ─────────────────┼──────────────┼───────────┼──────────
    /// File             │ Restore      │ Squash in │ -
    /// Revision         │ Abandon      │ Squash    │ Move
    /// ```
    Rub {
        source: String,
        target: String,
    },

    /// Squash revisions together.
    Squash {
        /// Revisions to squash (last one is target).
        revisions: Vec<String>,
        /// New commit message.
        #[clap(short = 'm', long)]
        message: Option<String>,
    },

    /// Edit description of a revision or rename a bookmark.
    Reword {
        /// Revision or bookmark.
        target: String,
        /// New message. Opens editor if omitted.
        #[clap(short = 'm', long)]
        message: Option<String>,
    },

    /// Push bookmarks to remote.
    Push {
        /// Specific bookmark to push.
        bookmark: Option<String>,
    },

    /// Fetch and rebase on upstream.
    Pull,

    /// Create a PR via gh CLI.
    Pr {
        /// Bookmark for the PR.
        bookmark: Option<String>,
        /// PR description.
        #[clap(short = 'm', long)]
        message: Option<String>,
    },

    /// Discard changes to a file or revision.
    Discard {
        /// File path or revision ID.
        target: String,
    },

    /// Undo the last operation.
    Undo,

    /// Auto-amend changes into the right commits.
    Absorb {
        /// Show plan without applying.
        #[clap(long)]
        dry_run: bool,
    },

    /// Show revision log.
    Log {
        /// Max revisions to show.
        #[clap(short = 'n', long, default_value = "20")]
        limit: usize,
        /// Show all revisions.
        #[clap(long)]
        all: bool,
    },
}
