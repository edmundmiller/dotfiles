import fs from "node:fs";
import type { ImageContent } from "./content.ts";
import { inferMimeType, looksLikeImagePath } from "./path-utils.ts";

export type ImageResizer = (image: ImageContent) => Promise<ImageContent>;

export function readImageContentFromPath(filePath: string): ImageContent | null {
  if (!looksLikeImagePath(filePath)) {
    return null;
  }

  const mimeType = inferMimeType(filePath)!;
  const bytes = fs.readFileSync(filePath);
  return {
    type: "image",
    data: bytes.toString("base64"),
    mimeType,
  };
}

export async function maybeResizeImage(
  image: ImageContent,
  resizeImage?: ImageResizer | null
): Promise<ImageContent> {
  if (!resizeImage) {
    return image;
  }
  try {
    return await resizeImage(image);
  } catch {
    return image;
  }
}

export async function loadImageContentFromPath(
  filePath: string,
  resizeImage?: ImageResizer | null
): Promise<ImageContent | null> {
  const image = readImageContentFromPath(filePath);
  if (!image) {
    return null;
  }
  return maybeResizeImage(image, resizeImage);
}
