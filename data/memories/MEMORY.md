Obsidian vault path is /home/thomas/Documents/ThomasKRemoteVault
§
Chrome GPU/Vulkan (Radeon 8060S): --ozone-platform=x11 --ignore-gpu-blocklist --enable-features=Vulkan,DefaultANGLEVulkan --use-gl=angle --use-angle=vulkan --enable-gpu-rasterization --enable-zero-copy. User in render,video groups, libva-wayland2 installed.
§
Astra Monitor GNOME extension requires /usr/local/bin/amdgpu_top to collect AMD GPU metrics and needs the GPU enabled in gsettings gpu-data.
§
Flatfox auth: GET /api/v1/user/ (200 OK auth, 403 guest). Google SSO requires system /usr/bin/google-chrome persistent context with --disable-blink-features=AutomationControlled & ignore_default_args=['--enable-automation']. Priority: is_priority & flatfox_priority_exclusive_until.
§
Post-crash GNOME Shell safe mode disables extensions (disable-user-extensions: true). Re-enable with: gsettings set org.gnome.shell disable-user-extensions false && gnome-extensions enable <uuid>.
§
Flatfox API: /api/v1/pin/ uses bounding boxes & offset pagination. Canonical URLs: /en/flat/{slug}/{pk}/. Dynamic geocoding (hub dict > disk cache > Nominatim/SBB) resolves Swiss towns without Zurich fallback. Dual commute metrics: '##m Hub' (walking to local station) & '##m SBB ZH' (train to Zurich HB). Strict post-query radius check. SSR og:image thumbnails bypass 429 via crawler session. When APARTMENT, show room size, detect Agency/Direct, bypass roommate extraction.
§
TokenWatcher GNOME extension: multi-source LLM metrics (Hermes Agent ~/.hermes/state.db, OpenCode ~/.local/share/opencode/opencode.db, OpenWebUI & Lemonade). Topbar format: [Icon] <Model Alias> | <#,##M> | VRAM <X,X Go> | <Source>. Icons: utilities-terminal-symbolic (Hermes/OpenCode), chat-message-new-symbolic (OpenWebUI). GNOME 50 GJS requires GObject.registerClass + constructor. Wayland requires logout/login to reload modified JS. Daemon: ~/.local/bin/tokenwatcher-daemon -> /tmp/tokenwatcher_state.json.
§
CLI rule: always use `hermes chat -q` (or `<profile> chat -q`) for single queries, never bare `-q` on base binary.