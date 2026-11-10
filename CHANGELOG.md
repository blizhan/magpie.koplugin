# Changelog

## 0.4.0

- Configuration now comes only from `base_url.txt`, `gateway-key.txt`, `web_url.txt`, and `web-key.txt` under the KOReader settings directory `magpie/`.
- Loading the plugin removes legacy `api_key` and `base_url` values from `magpie.lua` and keeps other preferences. It does not read old external paths or a plugin `apikey.txt`, and it does not delete the user's old files.
- There is no built-in service address. Gateway and Web are configured separately. Web is not inferred from the Gateway URL.
- The public user-agent is `magpie-koreader/0.4.0`. This version string was the only one in the previous plugin. There is no git tag.
- Device compatibility, a clean KOReader install, and independent reader or developer timing are not verified for this version.
- Configuration saves now report buffered close failures. Cached quotas retain a visible failure warning until recovery; trend snapshots are shown only for their requested period.
- Project-cost errors include Web configuration recovery instructions. Obsolete text rendering was removed, and page dispatch, swipe navigation, packaging membership, and template preset ordering were consolidated.
- Both READMEs now describe source installation, development prerequisites, packaging, and contribution steps. Audit documents no longer repeat the reviewed private deployment values; runtime and independent acceptance remain blocked.
