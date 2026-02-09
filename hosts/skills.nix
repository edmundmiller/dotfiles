# Pinned agent skills — managed by `hey skills-add` and `hey skills-update`
# Each skill is fetched from GitHub with a verified SRI hash.
# Review diffs before accepting updates to prevent prompt injection.
{
  modules.shell.agents.skills = {
    enable = true;
    pinned = {
      # END_PINNED_SKILLS
    };
  };
}
