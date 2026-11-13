import { Type } from "typebox";
import { Value } from "typebox/value";

/** JSON returned by Thimble's native analysis and persisted session entries. */
export type ThimbleJson = null | boolean | number | string | readonly ThimbleJson[] | ThimbleRecord;

/** A parsed Thimble record permits JSON fields, not arbitrary runtime objects. */
export interface ThimbleRecord {
  [key: string]: ThimbleJson;
}

/** Recursive JSON schema; Type.Unsafe supplies the recursive TypeScript type. */
export const thimbleJsonSchema = Type.Unsafe<ThimbleJson>(
  Type.Cyclic(
    {
      value: Type.Union([
        Type.Null(),
        Type.Boolean(),
        Type.Number(),
        Type.String(),
        Type.Array(Type.Ref("value")),
        Type.Record(Type.String(), Type.Ref("value")),
      ]),
    },
    "value"
  )
);

/** Validate the JSON object boundary shared by engine reports and card rows. */
export const thimbleRecordSchema = Type.Record(Type.String(), thimbleJsonSchema);

/** Parse external JSON text before the adapter uses any of its fields. */
export function parseThimbleJson(text: string): ThimbleJson {
  return Value.Parse(thimbleJsonSchema, JSON.parse(text));
}
