user_pref("general.useragent.override", "Mozilla/5.0 (Gecko/20070310 Mozshot/0.0.20070628; http://mozshot.nemui.org/)");

# disable dialog for HTTPS pages
user_pref("security.warn_entering_secure", false);
user_pref("security.warn_entering_secure.show_once", false);
user_pref("security.warn_entering_weak", false);
user_pref("security.warn_leaving_secure", false);
user_pref("security.warn_leaving_secure.show_once", false);
user_pref("security.warn_viewing_mixed", false);
user_pref("security.warn_viewing_mixed.show_once", false);

# tweak for infomation store
user_pref("network.cookie.lifetimePolicy", 2);
user_pref("browser.download.manager.retention", 0);
user_pref("browser.formfill.enable", false);
user_pref("browser.history_expire_days", 0);

# Tune for Japanese
user_pref("intl.accept_languages", "ja, en-us, en");
user_pref("intl.charset.default", "Shift_JIS");
user_pref("intl.charset.detector", "ja_parallel_state_machine");

# disable javascript...
user_pref("javascript.enabled", false);

# disable default plugin
user_pref("plugin.default_plugin_disabled", true);

# disable netscape style plugin scan
user_pref("plugin.scan.4xPluginFolder", false);

# speed tune...
user_pref("nglayout.initialpaint.delay", 250);
user_pref("network.http.max-connections", 45);
user_pref("network.http.pipelining", true);
user_pref("network.http.pipelining.firstrequest", true);
user_pref("network.http.pipelining.maxrequests", 8);

# save mem
user_pref("browser.sessionhistory.max_total_viewers", 0);
user_pref("browser.cache.memory.capacity", 2048);

# proxy
#user_pref("network.proxy.type", 1);
#user_pref("network.proxy.http", "localhost");
#user_pref("network.proxy.http_port", 3128);
#user_pref("network.http.proxy.pipelining", true);
