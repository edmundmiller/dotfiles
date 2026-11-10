import Base
import ./task-text.bend as Text

def quote_argument(text: String) -> String:
  Text.quote_shell_argument(text)

def quote_command(args: List<&2, String>) -> String:
  match args:
    case Nil{}:
      ""
    case head <> Nil{}:
      quote_argument(head)
    case head <> rest:
      Text.concat_task_text([quote_argument(head), " ", quote_command(rest)])

def service_status_command(service: String) -> String:
  "systemctl status " ++ quote_argument(service)

def journal_command(unit: String, lines: U32) -> String:
  match unit:
    case SNil{}:
      "sudo journalctl -n " ++ U32.show(lines)
    case unit:
      "sudo journalctl -u " ++ quote_argument(unit) ++ " -n " ++ U32.show(lines)
