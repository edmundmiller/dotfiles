/** Typed QMD extension errors with user-facing messages for runtime and onboarding failures. */

export class QmdExtensionError extends Error {
  readonly code: string;
  readonly cause_value?: unknown;

  constructor(code: string, message: string, options?: { cause?: unknown }) {
    super(message);
    this.name = new.target.name;
    this.code = code;
    this.cause_value = options?.cause;
  }
}

export class QmdUnavailableError extends QmdExtensionError {
  constructor(action: string, cause?: unknown) {
    const suffix = cause instanceof Error ? ` ${cause.message}` : cause ? ` ${String(cause)}` : "";
    super(
      "qmd_unavailable",
      `QMD is unavailable while trying to ${action}. Verify that @tobilu/qmd is linked correctly and that the local QMD index can be opened.${suffix}`,
      { cause }
    );
  }
}

export class CollectionBindingMismatchError extends QmdExtensionError {
  constructor(message: string, cause?: unknown) {
    super("collection_binding_mismatch", message, { cause });
  }
}

export class InvalidInitProposalError extends QmdExtensionError {
  constructor(message: string, cause?: unknown) {
    super("invalid_init_proposal", message, { cause });
  }
}

export function get_error_message(error: unknown): string {
  if (error instanceof Error) {
    return error.message;
  }
  return String(error);
}
