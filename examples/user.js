
# disable dialog for HTTPS pages
user_pref("security.warn_entering_secure", false);
user_pref("security.warn_entering_weak", false);
user_pref("security.warn_leaving_secure", false);
user_pref("security.warn_viewing_mixed", false)

# Tune for Japanese
user_pref("intl.accept_languages", "ja, en-us, en");
user_pref("intl.charset.default", "Shift_JIS");
user_pref("intl.charset.detector", "ja_parallel_state_machine");

# disable javascript...
user_pref("javascript.enabled", false);

# speed tune...
user_pref("nglayout.initialpaint.delay", 50);
user_pref("network.http.max-connections", 45);
user_pref("network.http.pipelining", true);
user_pref("network.http.pipelining.firstrequest", true);
user_pref("network.http.pipelining.maxrequests", 8);

# save mem
user_pref("browser.sessionhistory.max_total_viewers", 0)
user_pref("browser.cache.memory.capacity", 2048)
