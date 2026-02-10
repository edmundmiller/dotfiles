//! Short CLI ID system.
//!
//! Maps jj's change IDs to short (4+ char) IDs for ergonomic CLI use.
//! IDs are extended when collisions occur.

use std::collections::HashMap;

/// Map between short CLI IDs and full change ID hex strings.
#[allow(dead_code)]
pub struct IdMap {
    /// short_id -> full_change_id_hex
    short_to_full: HashMap<String, String>,
    /// full_change_id_hex -> short_id
    full_to_short: HashMap<String, String>,
}

#[allow(dead_code)]
const MIN_ID_LEN: usize = 4;

impl IdMap {
    /// Build an ID map from a list of change ID hex strings.
    #[allow(dead_code)]
    pub fn build(change_ids: &[String]) -> Self {
        let mut short_to_full: HashMap<String, String> = HashMap::new();
        let mut full_to_short: HashMap<String, String> = HashMap::new();

        // Start with MIN_ID_LEN chars, extend on collision
        for id in change_ids {
            let mut len = MIN_ID_LEN.min(id.len());
            loop {
                let short = &id[..len];
                if let Some(existing) = short_to_full.get(short) {
                    if existing == id {
                        break; // Already mapped
                    }
                    // Collision: extend both
                    let existing_full = existing.clone();
                    short_to_full.remove(short);

                    // Re-insert existing with longer prefix
                    let new_existing_len = (len + 1).min(existing_full.len());
                    let new_existing_short = existing_full[..new_existing_len].to_string();
                    short_to_full.insert(new_existing_short.clone(), existing_full.clone());
                    full_to_short.insert(existing_full, new_existing_short);

                    len = (len + 1).min(id.len());
                    if len == id.len() {
                        short_to_full.insert(id.clone(), id.clone());
                        full_to_short.insert(id.clone(), id.clone());
                        break;
                    }
                } else {
                    short_to_full.insert(short.to_string(), id.clone());
                    full_to_short.insert(id.clone(), short.to_string());
                    break;
                }
            }
        }

        Self {
            short_to_full,
            full_to_short,
        }
    }

    /// Resolve a short ID to a full change ID hex.
    #[allow(dead_code)]
    pub fn resolve(&self, short: &str) -> Option<&str> {
        // Try exact match first
        if let Some(full) = self.short_to_full.get(short) {
            return Some(full);
        }
        // Try prefix match
        let mut matches: Vec<&str> = Vec::new();
        for (s, f) in &self.short_to_full {
            if s.starts_with(short) || f.starts_with(short) {
                matches.push(f);
            }
        }
        if matches.len() == 1 {
            Some(matches[0])
        } else {
            None
        }
    }

    /// Get the short ID for a full change ID hex.
    #[allow(dead_code)]
    pub fn short_id(&self, full: &str) -> String {
        self.full_to_short
            .get(full)
            .cloned()
            .unwrap_or_else(|| full[..MIN_ID_LEN.min(full.len())].to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn no_collision() {
        let ids = vec!["abcd1234".into(), "efgh5678".into()];
        let map = IdMap::build(&ids);
        assert_eq!(map.resolve("abcd"), Some("abcd1234"));
        assert_eq!(map.resolve("efgh"), Some("efgh5678"));
        assert_eq!(map.short_id("abcd1234"), "abcd");
    }

    #[test]
    fn collision_extends() {
        let ids = vec!["abcd1234".into(), "abcd5678".into()];
        let map = IdMap::build(&ids);
        // Both should be resolvable
        assert!(map.resolve("abcd1").is_some());
        assert!(map.resolve("abcd5").is_some());
        // The 4-char prefix should NOT resolve (ambiguous)
        assert!(map.resolve("abcd").is_none());
    }
}
